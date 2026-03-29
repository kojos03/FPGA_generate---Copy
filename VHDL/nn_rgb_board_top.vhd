-- nn_rgb_board_top.vhd
--
-- FPGA board-oriented top wrapper for nn_rgb.
-- Keeps extended analysis buses internal so they are not exported as package pins.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use work.CONFIG.ALL;

entity nn_rgb_board_top is
  generic (
    FIRE_COUNT_THRESHOLD_G : natural := FIRE_COUNT_THRESHOLD;
    TEMP_AREA_DELTA_TH_G   : natural := TEMP_AREA_DELTA_TH;
    TEMP_MOVE_DELTA_TH_G   : natural := TEMP_MOVE_DELTA_TH;
    TEMP_SPREAD_DELTA_TH_G : natural := TEMP_SPREAD_DELTA_TH;
    DEC_FIRE_PRESENT_THRESHOLD_G : natural := FIRE_PRESENT_THRESHOLD;
    DEC_GROWTH_THRESHOLD_G       : natural := GROWTH_THRESHOLD;
    DEC_MOVEMENT_THRESHOLD_G     : natural := MOVEMENT_THRESHOLD;
    DEC_PERSISTENCE_FRAMES_G     : natural := PERSISTENCE_FRAMES
  );
  port (
    clk              : in  std_logic;
    reset_n          : in  std_logic;
    enable_in        : in  std_logic_vector(2 downto 0);
    -- video in
    vs_in            : in  std_logic;
    hs_in            : in  std_logic;
    de_in            : in  std_logic;
    r_in             : in  std_logic_vector(7 downto 0);
    g_in             : in  std_logic_vector(7 downto 0);
    b_in             : in  std_logic_vector(7 downto 0);
    -- video out
    vs_out           : out std_logic;
    hs_out           : out std_logic;
    de_out           : out std_logic;
    r_out            : out std_logic_vector(7 downto 0);
    g_out            : out std_logic_vector(7 downto 0);
    b_out            : out std_logic_vector(7 downto 0);
    -- compact status outputs
    fire_present     : out std_logic;
    persistent_fire  : out std_logic;
    growth_alert     : out std_logic;
    movement_alert   : out std_logic;
    risk_level       : out std_logic_vector(1 downto 0);
    --
    clk_o            : out std_logic;
    led              : out std_logic_vector(2 downto 0)
  );
end nn_rgb_board_top;

architecture rtl of nn_rgb_board_top is
  -- internal-only outputs from nn_rgb (not exported as FPGA package pins)
  signal fire_pixel_s          : std_logic;
  signal frame_stats_valid_s   : std_logic;
  signal frame_fire_detected_s : std_logic;
  signal frame_fire_count_s    : std_logic_vector(FIRE_COUNT_BITS-1 downto 0);
  signal frame_bbox_valid_s    : std_logic;
  signal frame_min_x_s         : std_logic_vector(FRAME_X_BITS-1 downto 0);
  signal frame_max_x_s         : std_logic_vector(FRAME_X_BITS-1 downto 0);
  signal frame_min_y_s         : std_logic_vector(FRAME_Y_BITS-1 downto 0);
  signal frame_max_y_s         : std_logic_vector(FRAME_Y_BITS-1 downto 0);
  signal frame_done_s          : std_logic;
  signal fire_count_s          : std_logic_vector(FIRE_COUNT_BITS-1 downto 0);
  signal secondary_count_s     : std_logic_vector(FIRE_COUNT_BITS-1 downto 0);
  signal sum_x_fire_s          : std_logic_vector(FIRE_SUM_X_BITS-1 downto 0);
  signal sum_y_fire_s          : std_logic_vector(FIRE_SUM_Y_BITS-1 downto 0);
  signal xmin_out_s            : std_logic_vector(FRAME_X_BITS-1 downto 0);
  signal xmax_out_s            : std_logic_vector(FRAME_X_BITS-1 downto 0);
  signal ymin_out_s            : std_logic_vector(FRAME_Y_BITS-1 downto 0);
  signal ymax_out_s            : std_logic_vector(FRAME_Y_BITS-1 downto 0);
  signal bbox_valid_out_s      : std_logic;
  signal centroid_x_s          : std_logic_vector(FRAME_X_BITS-1 downto 0);
  signal centroid_y_s          : std_logic_vector(FRAME_Y_BITS-1 downto 0);
  signal centroid_valid_s      : std_logic;
  signal temporal_stats_valid_s: std_logic;
  signal temporal_valid_s      : std_logic;
  signal fire_growing_s        : std_logic;
  signal fire_shrinking_s      : std_logic;
  signal fire_count_delta_s    : std_logic_vector(FIRE_COUNT_BITS downto 0);
  signal delta_x_s             : std_logic_vector(FRAME_X_BITS downto 0);
  signal delta_y_s             : std_logic_vector(FRAME_Y_BITS downto 0);
  signal move_left_s           : std_logic;
  signal move_right_s          : std_logic;
  signal move_up_s             : std_logic;
  signal move_down_s           : std_logic;
  signal move_dir_code_s       : std_logic_vector(3 downto 0);
  signal bbox_width_growing_s  : std_logic;
  signal bbox_height_growing_s : std_logic;
  signal spread_detected_s     : std_logic;
  signal decision_valid_s      : std_logic;
begin

  dut : entity work.nn_rgb
    generic map (
      FIRE_COUNT_THRESHOLD_G       => FIRE_COUNT_THRESHOLD_G,
      TEMP_AREA_DELTA_TH_G         => TEMP_AREA_DELTA_TH_G,
      TEMP_MOVE_DELTA_TH_G         => TEMP_MOVE_DELTA_TH_G,
      TEMP_SPREAD_DELTA_TH_G       => TEMP_SPREAD_DELTA_TH_G,
      DEC_FIRE_PRESENT_THRESHOLD_G => DEC_FIRE_PRESENT_THRESHOLD_G,
      DEC_GROWTH_THRESHOLD_G       => DEC_GROWTH_THRESHOLD_G,
      DEC_MOVEMENT_THRESHOLD_G     => DEC_MOVEMENT_THRESHOLD_G,
      DEC_PERSISTENCE_FRAMES_G     => DEC_PERSISTENCE_FRAMES_G
    )
    port map (
      clk                 => clk,
      reset_n             => reset_n,
      enable_in           => enable_in,
      vs_in               => vs_in,
      hs_in               => hs_in,
      de_in               => de_in,
      r_in                => r_in,
      g_in                => g_in,
      b_in                => b_in,
      vs_out              => vs_out,
      hs_out              => hs_out,
      de_out              => de_out,
      r_out               => r_out,
      g_out               => g_out,
      b_out               => b_out,
      fire_pixel          => fire_pixel_s,
      frame_stats_valid   => frame_stats_valid_s,
      frame_fire_detected => frame_fire_detected_s,
      frame_fire_count    => frame_fire_count_s,
      frame_bbox_valid    => frame_bbox_valid_s,
      frame_min_x         => frame_min_x_s,
      frame_max_x         => frame_max_x_s,
      frame_min_y         => frame_min_y_s,
      frame_max_y         => frame_max_y_s,
      frame_done          => frame_done_s,
      fire_count          => fire_count_s,
      secondary_count     => secondary_count_s,
      sum_x_fire          => sum_x_fire_s,
      sum_y_fire          => sum_y_fire_s,
      xmin_out            => xmin_out_s,
      xmax_out            => xmax_out_s,
      ymin_out            => ymin_out_s,
      ymax_out            => ymax_out_s,
      bbox_valid_out      => bbox_valid_out_s,
      centroid_x          => centroid_x_s,
      centroid_y          => centroid_y_s,
      centroid_valid      => centroid_valid_s,
      temporal_stats_valid => temporal_stats_valid_s,
      temporal_valid       => temporal_valid_s,
      fire_growing         => fire_growing_s,
      fire_shrinking       => fire_shrinking_s,
      fire_count_delta     => fire_count_delta_s,
      delta_x              => delta_x_s,
      delta_y              => delta_y_s,
      move_left            => move_left_s,
      move_right           => move_right_s,
      move_up              => move_up_s,
      move_down            => move_down_s,
      move_dir_code        => move_dir_code_s,
      bbox_width_growing   => bbox_width_growing_s,
      bbox_height_growing  => bbox_height_growing_s,
      spread_detected      => spread_detected_s,
      fire_present         => fire_present,
      persistent_fire      => persistent_fire,
      growth_alert         => growth_alert,
      movement_alert       => movement_alert,
      risk_level           => risk_level,
      decision_valid       => decision_valid_s,
      clk_o                => clk_o,
      led                  => led
    );

end rtl;

