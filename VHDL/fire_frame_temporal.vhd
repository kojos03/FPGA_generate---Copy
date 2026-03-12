library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.CONFIG.ALL;

-- Temporal wildfire behavior estimation from frame-level metadata.
-- Compares the current frame metadata with the previous frame metadata
-- and provides hardware-friendly trend and movement indicators.
entity fire_frame_temporal is
  generic (
    X_BITS             : natural := FRAME_X_BITS;
    Y_BITS             : natural := FRAME_Y_BITS;
    COUNT_BITS         : natural := FIRE_COUNT_BITS;
    AREA_DELTA_TH_G    : natural := TEMP_AREA_DELTA_TH;
    MOVE_DELTA_TH_G    : natural := TEMP_MOVE_DELTA_TH;
    SPREAD_DELTA_TH_G  : natural := TEMP_SPREAD_DELTA_TH
  );
  port (
    clk               : in  std_logic;
    reset             : in  std_logic;

    -- Latched frame metadata from fire_frame_aggregator.
    frame_stats_valid : in  std_logic;
    frame_bbox_valid  : in  std_logic;
    frame_fire_count  : in  std_logic_vector(COUNT_BITS-1 downto 0);
    frame_min_x       : in  std_logic_vector(X_BITS-1 downto 0);
    frame_max_x       : in  std_logic_vector(X_BITS-1 downto 0);
    frame_min_y       : in  std_logic_vector(Y_BITS-1 downto 0);
    frame_max_y       : in  std_logic_vector(Y_BITS-1 downto 0);

    -- One-cycle pulse when temporal outputs are updated.
    temporal_stats_valid : out std_logic;
    -- '1' only when two consecutive fire-positive frames are available.
    temporal_valid       : out std_logic;

    -- Area trend.
    fire_growing      : out std_logic;
    fire_shrinking    : out std_logic;
    -- Signed delta, two's complement.
    fire_count_delta  : out std_logic_vector(COUNT_BITS downto 0);

    -- Current-frame centroid estimate from bounding box.
    centroid_x        : out std_logic_vector(X_BITS-1 downto 0);
    centroid_y        : out std_logic_vector(Y_BITS-1 downto 0);
    -- Signed centroid shift vs previous frame, two's complement.
    delta_x           : out std_logic_vector(X_BITS downto 0);
    delta_y           : out std_logic_vector(Y_BITS downto 0);

    -- Coarse movement flags.
    move_left         : out std_logic;
    move_right        : out std_logic;
    move_up           : out std_logic;
    move_down         : out std_logic;
    -- Encoded direction:
    -- 0000 none, 0001 left, 0010 right, 0011 up, 0100 down,
    -- 0101 up-left, 0110 up-right, 0111 down-left, 1000 down-right.
    move_dir_code     : out std_logic_vector(3 downto 0);

    -- Spatial spread trend from bbox dimensions.
    bbox_width_growing  : out std_logic;
    bbox_height_growing : out std_logic;
    spread_detected     : out std_logic
  );
end entity;

architecture rtl of fire_frame_temporal is
  signal frame_fire_count_u : unsigned(COUNT_BITS-1 downto 0);
  signal frame_min_x_u      : unsigned(X_BITS-1 downto 0);
  signal frame_max_x_u      : unsigned(X_BITS-1 downto 0);
  signal frame_min_y_u      : unsigned(Y_BITS-1 downto 0);
  signal frame_max_y_u      : unsigned(Y_BITS-1 downto 0);

  signal centroid_sum_x_u   : unsigned(X_BITS downto 0);
  signal centroid_sum_y_u   : unsigned(Y_BITS downto 0);
  signal centroid_x_u       : unsigned(X_BITS-1 downto 0);
  signal centroid_y_u       : unsigned(Y_BITS-1 downto 0);

  signal bbox_width_u       : unsigned(X_BITS downto 0);
  signal bbox_height_u      : unsigned(Y_BITS downto 0);

  signal prev_frame_seen    : std_logic := '0';
  signal prev_bbox_valid_r  : std_logic := '0';
  signal prev_fire_count_r  : unsigned(COUNT_BITS-1 downto 0) := (others => '0');
  signal prev_centroid_x_r  : unsigned(X_BITS-1 downto 0) := (others => '0');
  signal prev_centroid_y_r  : unsigned(Y_BITS-1 downto 0) := (others => '0');
  signal prev_bbox_width_r  : unsigned(X_BITS downto 0) := (others => '0');
  signal prev_bbox_height_r : unsigned(Y_BITS downto 0) := (others => '0');

  signal temporal_stats_valid_r : std_logic := '0';
  signal temporal_valid_r       : std_logic := '0';
  signal fire_growing_r         : std_logic := '0';
  signal fire_shrinking_r       : std_logic := '0';
  signal fire_count_delta_r     : signed(COUNT_BITS downto 0) := (others => '0');
  signal centroid_x_r           : unsigned(X_BITS-1 downto 0) := (others => '0');
  signal centroid_y_r           : unsigned(Y_BITS-1 downto 0) := (others => '0');
  signal delta_x_r              : signed(X_BITS downto 0) := (others => '0');
  signal delta_y_r              : signed(Y_BITS downto 0) := (others => '0');
  signal move_left_r            : std_logic := '0';
  signal move_right_r           : std_logic := '0';
  signal move_up_r              : std_logic := '0';
  signal move_down_r            : std_logic := '0';
  signal move_dir_code_r        : std_logic_vector(3 downto 0) := (others => '0');
  signal bbox_width_growing_r   : std_logic := '0';
  signal bbox_height_growing_r  : std_logic := '0';
  signal spread_detected_r      : std_logic := '0';

  constant AREA_DELTA_TH_U  : unsigned(COUNT_BITS-1 downto 0) := to_unsigned(AREA_DELTA_TH_G, COUNT_BITS);
  constant SPREAD_TH_X_U    : unsigned(X_BITS downto 0) := to_unsigned(SPREAD_DELTA_TH_G, X_BITS+1);
  constant SPREAD_TH_Y_U    : unsigned(Y_BITS downto 0) := to_unsigned(SPREAD_DELTA_TH_G, Y_BITS+1);
  constant MOVE_TH_X_S      : signed(X_BITS downto 0) := to_signed(MOVE_DELTA_TH_G, X_BITS+1);
  constant MOVE_TH_Y_S      : signed(Y_BITS downto 0) := to_signed(MOVE_DELTA_TH_G, Y_BITS+1);

  constant DIR_NONE       : std_logic_vector(3 downto 0) := "0000";
  constant DIR_LEFT       : std_logic_vector(3 downto 0) := "0001";
  constant DIR_RIGHT      : std_logic_vector(3 downto 0) := "0010";
  constant DIR_UP         : std_logic_vector(3 downto 0) := "0011";
  constant DIR_DOWN       : std_logic_vector(3 downto 0) := "0100";
  constant DIR_UP_LEFT    : std_logic_vector(3 downto 0) := "0101";
  constant DIR_UP_RIGHT   : std_logic_vector(3 downto 0) := "0110";
  constant DIR_DOWN_LEFT  : std_logic_vector(3 downto 0) := "0111";
  constant DIR_DOWN_RIGHT : std_logic_vector(3 downto 0) := "1000";
begin
  frame_fire_count_u <= unsigned(frame_fire_count);
  frame_min_x_u <= unsigned(frame_min_x);
  frame_max_x_u <= unsigned(frame_max_x);
  frame_min_y_u <= unsigned(frame_min_y);
  frame_max_y_u <= unsigned(frame_max_y);

  centroid_sum_x_u <= resize(frame_min_x_u, X_BITS+1) + resize(frame_max_x_u, X_BITS+1);
  centroid_sum_y_u <= resize(frame_min_y_u, Y_BITS+1) + resize(frame_max_y_u, Y_BITS+1);
  centroid_x_u <= centroid_sum_x_u(X_BITS downto 1);
  centroid_y_u <= centroid_sum_y_u(Y_BITS downto 1);

  bbox_width_u <= resize(frame_max_x_u, X_BITS+1) - resize(frame_min_x_u, X_BITS+1)
                  when frame_max_x_u >= frame_min_x_u else
                  (others => '0');

  bbox_height_u <= resize(frame_max_y_u, Y_BITS+1) - resize(frame_min_y_u, Y_BITS+1)
                   when frame_max_y_u >= frame_min_y_u else
                   (others => '0');

  process
  begin
    wait until rising_edge(clk);

    if reset = '1' then
      prev_frame_seen    <= '0';
      prev_bbox_valid_r  <= '0';
      prev_fire_count_r  <= (others => '0');
      prev_centroid_x_r  <= (others => '0');
      prev_centroid_y_r  <= (others => '0');
      prev_bbox_width_r  <= (others => '0');
      prev_bbox_height_r <= (others => '0');

      temporal_stats_valid_r <= '0';
      temporal_valid_r       <= '0';
      fire_growing_r         <= '0';
      fire_shrinking_r       <= '0';
      fire_count_delta_r     <= (others => '0');
      centroid_x_r           <= (others => '0');
      centroid_y_r           <= (others => '0');
      delta_x_r              <= (others => '0');
      delta_y_r              <= (others => '0');
      move_left_r            <= '0';
      move_right_r           <= '0';
      move_up_r              <= '0';
      move_down_r            <= '0';
      move_dir_code_r        <= DIR_NONE;
      bbox_width_growing_r   <= '0';
      bbox_height_growing_r  <= '0';
      spread_detected_r      <= '0';
    else
      temporal_stats_valid_r <= '0';

      if frame_stats_valid = '1' then
        temporal_stats_valid_r <= '1';

        -- Always publish current-frame centroid and raw deltas.
        centroid_x_r <= centroid_x_u;
        centroid_y_r <= centroid_y_u;
        fire_count_delta_r <= signed('0' & frame_fire_count_u) - signed('0' & prev_fire_count_r);
        delta_x_r <= signed('0' & centroid_x_u) - signed('0' & prev_centroid_x_r);
        delta_y_r <= signed('0' & centroid_y_u) - signed('0' & prev_centroid_y_r);

        -- Default flags for frames without meaningful temporal comparison.
        temporal_valid_r      <= '0';
        fire_growing_r        <= '0';
        fire_shrinking_r      <= '0';
        move_left_r           <= '0';
        move_right_r          <= '0';
        move_up_r             <= '0';
        move_down_r           <= '0';
        move_dir_code_r       <= DIR_NONE;
        bbox_width_growing_r  <= '0';
        bbox_height_growing_r <= '0';
        spread_detected_r     <= '0';

        -- Valid only when two consecutive frames both contain fire.
        if (prev_frame_seen = '1') and (prev_bbox_valid_r = '1') and (frame_bbox_valid = '1') then
          temporal_valid_r <= '1';

          -- Fire area trend.
          if frame_fire_count_u > prev_fire_count_r then
            if (frame_fire_count_u - prev_fire_count_r) >= AREA_DELTA_TH_U then
              fire_growing_r <= '1';
            end if;
          elsif prev_fire_count_r > frame_fire_count_u then
            if (prev_fire_count_r - frame_fire_count_u) >= AREA_DELTA_TH_U then
              fire_shrinking_r <= '1';
            end if;
          end if;

          -- Coarse movement from centroid shift.
          if (signed('0' & centroid_x_u) - signed('0' & prev_centroid_x_r)) > MOVE_TH_X_S then
            move_right_r <= '1';
          elsif (signed('0' & centroid_x_u) - signed('0' & prev_centroid_x_r)) < -MOVE_TH_X_S then
            move_left_r <= '1';
          end if;

          if (signed('0' & centroid_y_u) - signed('0' & prev_centroid_y_r)) > MOVE_TH_Y_S then
            move_down_r <= '1';
          elsif (signed('0' & centroid_y_u) - signed('0' & prev_centroid_y_r)) < -MOVE_TH_Y_S then
            move_up_r <= '1';
          end if;

          if (signed('0' & centroid_x_u) - signed('0' & prev_centroid_x_r)) > MOVE_TH_X_S then
            if (signed('0' & centroid_y_u) - signed('0' & prev_centroid_y_r)) > MOVE_TH_Y_S then
              move_dir_code_r <= DIR_DOWN_RIGHT;
            elsif (signed('0' & centroid_y_u) - signed('0' & prev_centroid_y_r)) < -MOVE_TH_Y_S then
              move_dir_code_r <= DIR_UP_RIGHT;
            else
              move_dir_code_r <= DIR_RIGHT;
            end if;
          elsif (signed('0' & centroid_x_u) - signed('0' & prev_centroid_x_r)) < -MOVE_TH_X_S then
            if (signed('0' & centroid_y_u) - signed('0' & prev_centroid_y_r)) > MOVE_TH_Y_S then
              move_dir_code_r <= DIR_DOWN_LEFT;
            elsif (signed('0' & centroid_y_u) - signed('0' & prev_centroid_y_r)) < -MOVE_TH_Y_S then
              move_dir_code_r <= DIR_UP_LEFT;
            else
              move_dir_code_r <= DIR_LEFT;
            end if;
          else
            if (signed('0' & centroid_y_u) - signed('0' & prev_centroid_y_r)) > MOVE_TH_Y_S then
              move_dir_code_r <= DIR_DOWN;
            elsif (signed('0' & centroid_y_u) - signed('0' & prev_centroid_y_r)) < -MOVE_TH_Y_S then
              move_dir_code_r <= DIR_UP;
            else
              move_dir_code_r <= DIR_NONE;
            end if;
          end if;

          -- Spatial spread trend from bounding box dimensions.
          if bbox_width_u > prev_bbox_width_r then
            if (bbox_width_u - prev_bbox_width_r) >= SPREAD_TH_X_U then
              bbox_width_growing_r <= '1';
            end if;
          end if;

          if bbox_height_u > prev_bbox_height_r then
            if (bbox_height_u - prev_bbox_height_r) >= SPREAD_TH_Y_U then
              bbox_height_growing_r <= '1';
            end if;
          end if;

          if (bbox_width_u > prev_bbox_width_r and (bbox_width_u - prev_bbox_width_r) >= SPREAD_TH_X_U) or
             (bbox_height_u > prev_bbox_height_r and (bbox_height_u - prev_bbox_height_r) >= SPREAD_TH_Y_U) then
            spread_detected_r <= '1';
          end if;
        end if;

        -- Store current frame metadata for next temporal comparison.
        prev_frame_seen    <= '1';
        prev_bbox_valid_r  <= frame_bbox_valid;
        prev_fire_count_r  <= frame_fire_count_u;
        prev_centroid_x_r  <= centroid_x_u;
        prev_centroid_y_r  <= centroid_y_u;
        prev_bbox_width_r  <= bbox_width_u;
        prev_bbox_height_r <= bbox_height_u;
      end if;
    end if;
  end process;

  temporal_stats_valid <= temporal_stats_valid_r;
  temporal_valid <= temporal_valid_r;
  fire_growing <= fire_growing_r;
  fire_shrinking <= fire_shrinking_r;
  fire_count_delta <= std_logic_vector(fire_count_delta_r);
  centroid_x <= std_logic_vector(centroid_x_r);
  centroid_y <= std_logic_vector(centroid_y_r);
  delta_x <= std_logic_vector(delta_x_r);
  delta_y <= std_logic_vector(delta_y_r);
  move_left <= move_left_r;
  move_right <= move_right_r;
  move_up <= move_up_r;
  move_down <= move_down_r;
  move_dir_code <= move_dir_code_r;
  bbox_width_growing <= bbox_width_growing_r;
  bbox_height_growing <= bbox_height_growing_r;
  spread_detected <= spread_detected_r;
end architecture;
