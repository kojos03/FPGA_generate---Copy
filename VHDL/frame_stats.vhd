library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.CONFIG.ALL;

-- Frame-level wildfire statistics from aligned pixel-class stream.
-- Latches one frame result at the next frame start (vs rising edge).
entity frame_stats is
  generic (
    X_BITS      : natural := FRAME_X_BITS;
    Y_BITS      : natural := FRAME_Y_BITS;
    COUNT_BITS  : natural := FIRE_COUNT_BITS;
    SUM_X_BITS  : natural := FIRE_SUM_X_BITS;
    SUM_Y_BITS  : natural := FIRE_SUM_Y_BITS
  );
  port (
    clk            : in  std_logic;
    reset          : in  std_logic;
    vs_in          : in  std_logic;
    de_in          : in  std_logic;
    fire_pix       : in  std_logic;
    secondary_pix  : in  std_logic;
    x_pos          : in  std_logic_vector(X_BITS-1 downto 0);
    y_pos          : in  std_logic_vector(Y_BITS-1 downto 0);

    frame_done       : out std_logic;
    fire_count       : out std_logic_vector(COUNT_BITS-1 downto 0);
    secondary_count  : out std_logic_vector(COUNT_BITS-1 downto 0);
    sum_x_fire       : out std_logic_vector(SUM_X_BITS-1 downto 0);
    sum_y_fire       : out std_logic_vector(SUM_Y_BITS-1 downto 0);
    xmin_out         : out std_logic_vector(X_BITS-1 downto 0);
    xmax_out         : out std_logic_vector(X_BITS-1 downto 0);
    ymin_out         : out std_logic_vector(Y_BITS-1 downto 0);
    ymax_out         : out std_logic_vector(Y_BITS-1 downto 0);
    bbox_valid_out   : out std_logic;
    centroid_x       : out std_logic_vector(X_BITS-1 downto 0);
    centroid_y       : out std_logic_vector(Y_BITS-1 downto 0);
    centroid_valid   : out std_logic
  );
end entity;

architecture rtl of frame_stats is
  signal vs_prev           : std_logic := '0';
  signal frame_seen        : std_logic := '0';

  signal fire_count_acc      : unsigned(COUNT_BITS-1 downto 0) := (others => '0');
  signal secondary_count_acc : unsigned(COUNT_BITS-1 downto 0) := (others => '0');
  signal sum_x_fire_acc      : unsigned(SUM_X_BITS-1 downto 0) := (others => '0');
  signal sum_y_fire_acc      : unsigned(SUM_Y_BITS-1 downto 0) := (others => '0');
  signal xmin_acc            : unsigned(X_BITS-1 downto 0) := (others => '0');
  signal xmax_acc            : unsigned(X_BITS-1 downto 0) := (others => '0');
  signal ymin_acc            : unsigned(Y_BITS-1 downto 0) := (others => '0');
  signal ymax_acc            : unsigned(Y_BITS-1 downto 0) := (others => '0');
  signal fire_seen_acc       : std_logic := '0';

  signal frame_done_r        : std_logic := '0';
  signal fire_count_r        : unsigned(COUNT_BITS-1 downto 0) := (others => '0');
  signal secondary_count_r   : unsigned(COUNT_BITS-1 downto 0) := (others => '0');
  signal sum_x_fire_r        : unsigned(SUM_X_BITS-1 downto 0) := (others => '0');
  signal sum_y_fire_r        : unsigned(SUM_Y_BITS-1 downto 0) := (others => '0');
  signal xmin_r              : unsigned(X_BITS-1 downto 0) := (others => '0');
  signal xmax_r              : unsigned(X_BITS-1 downto 0) := (others => '0');
  signal ymin_r              : unsigned(Y_BITS-1 downto 0) := (others => '0');
  signal ymax_r              : unsigned(Y_BITS-1 downto 0) := (others => '0');
  signal bbox_valid_r        : std_logic := '0';
  signal centroid_x_r        : unsigned(X_BITS-1 downto 0) := (others => '0');
  signal centroid_y_r        : unsigned(Y_BITS-1 downto 0) := (others => '0');
  signal centroid_valid_r    : std_logic := '0';

  signal sof_rise_s          : std_logic;
  signal x_pos_u             : unsigned(X_BITS-1 downto 0);
  signal y_pos_u             : unsigned(Y_BITS-1 downto 0);

  constant COUNT_ALL_ONES    : unsigned(COUNT_BITS-1 downto 0) := (others => '1');
begin
  sof_rise_s <= '1' when (vs_prev = '0') and (vs_in = '1') else '0';
  x_pos_u <= unsigned(x_pos);
  y_pos_u <= unsigned(y_pos);

  process
  begin
    wait until rising_edge(clk);

    if reset = '1' then
      vs_prev <= '0';
      frame_seen <= '0';

      fire_count_acc <= (others => '0');
      secondary_count_acc <= (others => '0');
      sum_x_fire_acc <= (others => '0');
      sum_y_fire_acc <= (others => '0');
      xmin_acc <= (others => '0');
      xmax_acc <= (others => '0');
      ymin_acc <= (others => '0');
      ymax_acc <= (others => '0');
      fire_seen_acc <= '0';

      frame_done_r <= '0';
      fire_count_r <= (others => '0');
      secondary_count_r <= (others => '0');
      sum_x_fire_r <= (others => '0');
      sum_y_fire_r <= (others => '0');
      xmin_r <= (others => '0');
      xmax_r <= (others => '0');
      ymin_r <= (others => '0');
      ymax_r <= (others => '0');
      bbox_valid_r <= '0';
      centroid_x_r <= (others => '0');
      centroid_y_r <= (others => '0');
      centroid_valid_r <= '0';
    else
      frame_done_r <= '0';

      -- Latch previous frame results when a new frame starts.
      if sof_rise_s = '1' then
        if frame_seen = '1' then
          frame_done_r <= '1';
          fire_count_r <= fire_count_acc;
          secondary_count_r <= secondary_count_acc;
          sum_x_fire_r <= sum_x_fire_acc;
          sum_y_fire_r <= sum_y_fire_acc;
          bbox_valid_r <= fire_seen_acc;

          if fire_seen_acc = '1' then
            xmin_r <= xmin_acc;
            xmax_r <= xmax_acc;
            ymin_r <= ymin_acc;
            ymax_r <= ymax_acc;
            centroid_x_r <= resize(sum_x_fire_acc / resize(fire_count_acc, SUM_X_BITS), X_BITS);
            centroid_y_r <= resize(sum_y_fire_acc / resize(fire_count_acc, SUM_Y_BITS), Y_BITS);
            centroid_valid_r <= '1';
          else
            xmin_r <= (others => '0');
            xmax_r <= (others => '0');
            ymin_r <= (others => '0');
            ymax_r <= (others => '0');
            centroid_x_r <= (others => '0');
            centroid_y_r <= (others => '0');
            centroid_valid_r <= '0';
          end if;
        end if;

        frame_seen <= '1';
        fire_count_acc <= (others => '0');
        secondary_count_acc <= (others => '0');
        sum_x_fire_acc <= (others => '0');
        sum_y_fire_acc <= (others => '0');
        xmin_acc <= (others => '0');
        xmax_acc <= (others => '0');
        ymin_acc <= (others => '0');
        ymax_acc <= (others => '0');
        fire_seen_acc <= '0';
      end if;

      if de_in = '1' then
        if fire_pix = '1' then
          if fire_count_acc /= COUNT_ALL_ONES then
            fire_count_acc <= fire_count_acc + 1;
          end if;

          sum_x_fire_acc <= sum_x_fire_acc + resize(x_pos_u, SUM_X_BITS);
          sum_y_fire_acc <= sum_y_fire_acc + resize(y_pos_u, SUM_Y_BITS);

          if fire_seen_acc = '0' then
            fire_seen_acc <= '1';
            xmin_acc <= x_pos_u;
            xmax_acc <= x_pos_u;
            ymin_acc <= y_pos_u;
            ymax_acc <= y_pos_u;
          else
            if x_pos_u < xmin_acc then xmin_acc <= x_pos_u; end if;
            if x_pos_u > xmax_acc then xmax_acc <= x_pos_u; end if;
            if y_pos_u < ymin_acc then ymin_acc <= y_pos_u; end if;
            if y_pos_u > ymax_acc then ymax_acc <= y_pos_u; end if;
          end if;
        end if;

        if secondary_pix = '1' then
          if secondary_count_acc /= COUNT_ALL_ONES then
            secondary_count_acc <= secondary_count_acc + 1;
          end if;
        end if;
      end if;

      vs_prev <= vs_in;
    end if;
  end process;

  frame_done <= frame_done_r;
  fire_count <= std_logic_vector(fire_count_r);
  secondary_count <= std_logic_vector(secondary_count_r);
  sum_x_fire <= std_logic_vector(sum_x_fire_r);
  sum_y_fire <= std_logic_vector(sum_y_fire_r);
  xmin_out <= std_logic_vector(xmin_r);
  xmax_out <= std_logic_vector(xmax_r);
  ymin_out <= std_logic_vector(ymin_r);
  ymax_out <= std_logic_vector(ymax_r);
  bbox_valid_out <= bbox_valid_r;
  centroid_x <= std_logic_vector(centroid_x_r);
  centroid_y <= std_logic_vector(centroid_y_r);
  centroid_valid <= centroid_valid_r;
end architecture;
