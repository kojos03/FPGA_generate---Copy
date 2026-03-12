library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.CONFIG.ALL;

-- Frame-level post-processing of pixel-level fire decisions.
-- Aggregates per-frame wildfire metadata:
--   * fire pixel count
--   * fire bounding box
--   * threshold-based frame fire_detected flag
-- Results are latched at start-of-frame (rising edge of vs_in), i.e. they
-- correspond to the immediately previous frame.
entity fire_frame_aggregator is
  generic (
    X_BITS                 : natural := FRAME_X_BITS;
    Y_BITS                 : natural := FRAME_Y_BITS;
    COUNT_BITS             : natural := FIRE_COUNT_BITS;
    FIRE_COUNT_THRESHOLD_G : natural := FIRE_COUNT_THRESHOLD
  );
  port (
    clk   : in  std_logic;
    reset : in  std_logic;
    vs_in : in  std_logic;
    hs_in : in  std_logic;
    de_in : in  std_logic;

    -- Asserted for the current valid output pixel when classified as fire.
    fire_pixel_in : in  std_logic;

    -- One-cycle pulse when a new frame result is latched.
    frame_stats_valid      : out std_logic;
    frame_fire_detected    : out std_logic;
    frame_fire_count       : out std_logic_vector(COUNT_BITS-1 downto 0);
    frame_bbox_valid       : out std_logic;
    frame_min_x            : out std_logic_vector(X_BITS-1 downto 0);
    frame_max_x            : out std_logic_vector(X_BITS-1 downto 0);
    frame_min_y            : out std_logic_vector(Y_BITS-1 downto 0);
    frame_max_y            : out std_logic_vector(Y_BITS-1 downto 0)
  );
end entity;

architecture rtl of fire_frame_aggregator is
  signal vs_prev : std_logic := '0';
  signal de_prev : std_logic := '0';

  signal frame_seen      : std_logic := '0';
  signal line_seen_acc   : std_logic := '0';
  signal x_curr          : unsigned(X_BITS-1 downto 0) := (others => '0');
  signal y_curr          : unsigned(Y_BITS-1 downto 0) := (others => '0');

  signal fire_count_acc  : unsigned(COUNT_BITS-1 downto 0) := (others => '0');
  signal fire_seen_acc   : std_logic := '0';
  signal min_x_acc       : unsigned(X_BITS-1 downto 0) := (others => '0');
  signal max_x_acc       : unsigned(X_BITS-1 downto 0) := (others => '0');
  signal min_y_acc       : unsigned(Y_BITS-1 downto 0) := (others => '0');
  signal max_y_acc       : unsigned(Y_BITS-1 downto 0) := (others => '0');

  signal frame_stats_valid_r   : std_logic := '0';
  signal frame_fire_detected_r : std_logic := '0';
  signal frame_fire_count_r    : unsigned(COUNT_BITS-1 downto 0) := (others => '0');
  signal frame_bbox_valid_r    : std_logic := '0';
  signal frame_min_x_r         : unsigned(X_BITS-1 downto 0) := (others => '0');
  signal frame_max_x_r         : unsigned(X_BITS-1 downto 0) := (others => '0');
  signal frame_min_y_r         : unsigned(Y_BITS-1 downto 0) := (others => '0');
  signal frame_max_y_r         : unsigned(Y_BITS-1 downto 0) := (others => '0');

  constant COUNT_ALL_ONES  : unsigned(COUNT_BITS-1 downto 0) := (others => '1');
  constant X_ALL_ONES      : unsigned(X_BITS-1 downto 0) := (others => '1');
  constant Y_ALL_ONES      : unsigned(Y_BITS-1 downto 0) := (others => '1');
  constant FIRE_THRESHOLD_U: unsigned(COUNT_BITS-1 downto 0) :=
    to_unsigned(FIRE_COUNT_THRESHOLD_G, COUNT_BITS);

  signal sof_rise_s        : std_logic;
  signal de_rise_s         : std_logic;
  signal x_base_s          : unsigned(X_BITS-1 downto 0);
  signal y_base_s          : unsigned(Y_BITS-1 downto 0);
  signal line_seen_base_s  : std_logic;
  signal x_next_s          : unsigned(X_BITS-1 downto 0);
  signal y_next_s          : unsigned(Y_BITS-1 downto 0);
  signal line_seen_next_s  : std_logic;
begin
  sof_rise_s <= '1' when (vs_prev = '0') and (vs_in = '1') else '0';
  de_rise_s  <= '1' when (de_prev = '0') and (de_in = '1') else '0';

  x_base_s         <= (others => '0') when sof_rise_s = '1' else x_curr;
  y_base_s         <= (others => '0') when sof_rise_s = '1' else y_curr;
  line_seen_base_s <= '0'             when sof_rise_s = '1' else line_seen_acc;

  x_next_s <= (others => '0') when de_rise_s = '1' else
              (x_base_s + 1) when (de_in = '1') and (x_base_s /= X_ALL_ONES) else
              x_base_s;

  y_next_s <= (others => '0') when (de_rise_s = '1') and (line_seen_base_s = '0') else
              (y_base_s + 1) when (de_rise_s = '1') and (line_seen_base_s = '1') and (y_base_s /= Y_ALL_ONES) else
              y_base_s;

  line_seen_next_s <= '1' when de_rise_s = '1' else line_seen_base_s;

  -- hs_in is reserved for future variants where line tracking is derived from HS.
  -- Current implementation uses de rising edges to track active-pixel coordinates.
  process(clk)
  begin
    if rising_edge(clk) then
      if reset = '1' then
        vs_prev <= '0';
        de_prev <= '0';

        frame_seen    <= '0';
        line_seen_acc <= '0';
        x_curr        <= (others => '0');
        y_curr        <= (others => '0');

        fire_count_acc <= (others => '0');
        fire_seen_acc  <= '0';
        min_x_acc      <= (others => '0');
        max_x_acc      <= (others => '0');
        min_y_acc      <= (others => '0');
        max_y_acc      <= (others => '0');

        frame_stats_valid_r   <= '0';
        frame_fire_detected_r <= '0';
        frame_fire_count_r    <= (others => '0');
        frame_bbox_valid_r    <= '0';
        frame_min_x_r         <= (others => '0');
        frame_max_x_r         <= (others => '0');
        frame_min_y_r         <= (others => '0');
        frame_max_y_r         <= (others => '0');
      else
        frame_stats_valid_r <= '0';

        -- Start of frame: latch previous frame statistics and clear accumulators.
        if sof_rise_s = '1' then
          if frame_seen = '1' then
            frame_stats_valid_r <= '1';
            frame_fire_count_r  <= fire_count_acc;
            frame_bbox_valid_r  <= fire_seen_acc;

            if fire_count_acc > FIRE_THRESHOLD_U then
              frame_fire_detected_r <= '1';
            else
              frame_fire_detected_r <= '0';
            end if;

            if fire_seen_acc = '1' then
              frame_min_x_r <= min_x_acc;
              frame_max_x_r <= max_x_acc;
              frame_min_y_r <= min_y_acc;
              frame_max_y_r <= max_y_acc;
            else
              frame_min_x_r <= (others => '0');
              frame_max_x_r <= (others => '0');
              frame_min_y_r <= (others => '0');
              frame_max_y_r <= (others => '0');
            end if;
          end if;

          frame_seen     <= '1';
          fire_count_acc <= (others => '0');
          fire_seen_acc  <= '0';
          min_x_acc      <= (others => '0');
          max_x_acc      <= (others => '0');
          min_y_acc      <= (others => '0');
          max_y_acc      <= (others => '0');
        end if;

        -- Coordinate tracking inside active image area.
        x_curr        <= x_next_s;
        y_curr        <= y_next_s;
        line_seen_acc <= line_seen_next_s;

        -- Per-pixel fire accumulation.
        if (de_in = '1') and (fire_pixel_in = '1') then
          if sof_rise_s = '1' then
            fire_count_acc <= to_unsigned(1, COUNT_BITS);
          elsif fire_count_acc /= COUNT_ALL_ONES then
            fire_count_acc <= fire_count_acc + 1;
          end if;

          if (sof_rise_s = '1') or (fire_seen_acc = '0') then
            fire_seen_acc <= '1';
            min_x_acc <= x_next_s;
            max_x_acc <= x_next_s;
            min_y_acc <= y_next_s;
            max_y_acc <= y_next_s;
          else
            if x_next_s < min_x_acc then min_x_acc <= x_next_s; end if;
            if x_next_s > max_x_acc then max_x_acc <= x_next_s; end if;
            if y_next_s < min_y_acc then min_y_acc <= y_next_s; end if;
            if y_next_s > max_y_acc then max_y_acc <= y_next_s; end if;
          end if;
        end if;

        vs_prev <= vs_in;
        de_prev <= de_in;
      end if;
    end if;
  end process;

  frame_stats_valid   <= frame_stats_valid_r;
  frame_fire_detected <= frame_fire_detected_r;
  frame_fire_count    <= std_logic_vector(frame_fire_count_r);
  frame_bbox_valid    <= frame_bbox_valid_r;
  frame_min_x         <= std_logic_vector(frame_min_x_r);
  frame_max_x         <= std_logic_vector(frame_max_x_r);
  frame_min_y         <= std_logic_vector(frame_min_y_r);
  frame_max_y         <= std_logic_vector(frame_max_y_r);
end architecture;
