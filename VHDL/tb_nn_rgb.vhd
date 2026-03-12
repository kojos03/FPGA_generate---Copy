--- Testbench for nn_rgb from Dionysiou

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use std.textio.all;
use ieee.std_logic_textio.all;
use work.CONFIG.ALL;

entity tb_nn_rgb is
end entity;

architecture sim of tb_nn_rgb is
  -- simulation config
  constant H_ACTIVE  : integer := 16;
  constant V_ACTIVE  : integer := 8;
  constant H_BLANK   : integer := 8;
  constant NUM_FRAMES: integer := 3;
  constant FIRE_THRESHOLD_TB : natural := 8;
  constant CLK_PER   : time    := 13.47 ns; -- 74.25 MHz

  -- DUT ports
  signal clk       : std_logic := '0';
  signal reset_n   : std_logic := '0';
  signal enable_in : std_logic_vector(2 downto 0) := (others => '1');

  signal vs_in     : std_logic := '0';
  signal hs_in     : std_logic := '0';
  signal de_in     : std_logic := '0';
  signal r_in      : std_logic_vector(7 downto 0) := (others => '0');
  signal g_in      : std_logic_vector(7 downto 0) := (others => '0');
  signal b_in      : std_logic_vector(7 downto 0) := (others => '0');

  signal vs_out    : std_logic;
  signal hs_out    : std_logic;
  signal de_out    : std_logic;
  signal r_out     : std_logic_vector(7 downto 0);
  signal g_out     : std_logic_vector(7 downto 0);
  signal b_out     : std_logic_vector(7 downto 0);
  signal fire_pixel: std_logic;
  signal frame_stats_valid   : std_logic;
  signal frame_fire_detected : std_logic;
  signal frame_fire_count    : std_logic_vector(FIRE_COUNT_BITS-1 downto 0);
  signal frame_bbox_valid    : std_logic;
  signal frame_min_x         : std_logic_vector(FRAME_X_BITS-1 downto 0);
  signal frame_max_x         : std_logic_vector(FRAME_X_BITS-1 downto 0);
  signal frame_min_y         : std_logic_vector(FRAME_Y_BITS-1 downto 0);
  signal frame_max_y         : std_logic_vector(FRAME_Y_BITS-1 downto 0);
  signal frame_done          : std_logic;
  signal fire_count          : std_logic_vector(FIRE_COUNT_BITS-1 downto 0);
  signal secondary_count     : std_logic_vector(FIRE_COUNT_BITS-1 downto 0);
  signal sum_x_fire          : std_logic_vector(FIRE_SUM_X_BITS-1 downto 0);
  signal sum_y_fire          : std_logic_vector(FIRE_SUM_Y_BITS-1 downto 0);
  signal xmin_out            : std_logic_vector(FRAME_X_BITS-1 downto 0);
  signal xmax_out            : std_logic_vector(FRAME_X_BITS-1 downto 0);
  signal ymin_out            : std_logic_vector(FRAME_Y_BITS-1 downto 0);
  signal ymax_out            : std_logic_vector(FRAME_Y_BITS-1 downto 0);
  signal bbox_valid_out      : std_logic;
  signal temporal_stats_valid : std_logic;
  signal temporal_valid       : std_logic;
  signal fire_growing         : std_logic;
  signal fire_shrinking       : std_logic;
  signal fire_count_delta     : std_logic_vector(FIRE_COUNT_BITS downto 0);
  signal centroid_x           : std_logic_vector(FRAME_X_BITS-1 downto 0);
  signal centroid_y           : std_logic_vector(FRAME_Y_BITS-1 downto 0);
  signal centroid_valid       : std_logic;
  signal delta_x              : std_logic_vector(FRAME_X_BITS downto 0);
  signal delta_y              : std_logic_vector(FRAME_Y_BITS downto 0);
  signal move_left            : std_logic;
  signal move_right           : std_logic;
  signal move_up              : std_logic;
  signal move_down            : std_logic;
  signal move_dir_code        : std_logic_vector(3 downto 0);
  signal bbox_width_growing   : std_logic;
  signal bbox_height_growing  : std_logic;
  signal spread_detected      : std_logic;
  signal fire_present         : std_logic;
  signal persistent_fire      : std_logic;
  signal growth_alert         : std_logic;
  signal movement_alert       : std_logic;
  signal risk_level           : std_logic_vector(1 downto 0);
  signal decision_valid       : std_logic;
  signal clk_o     : std_logic;
  signal led       : std_logic_vector(2 downto 0);
  signal checks_done : integer := 0;
  signal temporal_checks_done : integer := 0;
  signal frame_stats_checks_done : integer := 0;
  signal decision_checks_done : integer := 0;

  -- directed temporal-module stimulus/check signals
  signal t_frame_done       : std_logic := '0';
  signal t_frame_bbox_valid  : std_logic := '0';
  signal t_frame_fire_count  : std_logic_vector(FIRE_COUNT_BITS-1 downto 0) := (others => '0');
  signal t_frame_min_x       : std_logic_vector(FRAME_X_BITS-1 downto 0) := (others => '0');
  signal t_frame_max_x       : std_logic_vector(FRAME_X_BITS-1 downto 0) := (others => '0');
  signal t_frame_min_y       : std_logic_vector(FRAME_Y_BITS-1 downto 0) := (others => '0');
  signal t_frame_max_y       : std_logic_vector(FRAME_Y_BITS-1 downto 0) := (others => '0');
  signal t_centroid_x_in     : std_logic_vector(FRAME_X_BITS-1 downto 0) := (others => '0');
  signal t_centroid_y_in     : std_logic_vector(FRAME_Y_BITS-1 downto 0) := (others => '0');
  signal t_centroid_valid_in : std_logic := '0';

  signal t_temporal_stats_valid : std_logic;
  signal t_temporal_valid       : std_logic;
  signal t_fire_growing         : std_logic;
  signal t_fire_shrinking       : std_logic;
  signal t_fire_count_delta     : std_logic_vector(FIRE_COUNT_BITS downto 0);
  signal t_centroid_x           : std_logic_vector(FRAME_X_BITS-1 downto 0);
  signal t_centroid_y           : std_logic_vector(FRAME_Y_BITS-1 downto 0);
  signal t_delta_x              : std_logic_vector(FRAME_X_BITS downto 0);
  signal t_delta_y              : std_logic_vector(FRAME_Y_BITS downto 0);
  signal t_move_left            : std_logic;
  signal t_move_right           : std_logic;
  signal t_move_up              : std_logic;
  signal t_move_down            : std_logic;
  signal t_move_dir_code        : std_logic_vector(3 downto 0);
  signal t_bbox_width_growing   : std_logic;
  signal t_bbox_height_growing  : std_logic;
  signal t_spread_detected      : std_logic;

  -- directed decision-layer stimulus/check signals
  signal d_frame_done        : std_logic := '0';
  signal d_fire_count        : std_logic_vector(FIRE_COUNT_BITS-1 downto 0) := (others => '0');
  signal d_centroid_valid    : std_logic := '0';
  signal d_centroid_x        : std_logic_vector(FRAME_X_BITS-1 downto 0) := (others => '0');
  signal d_centroid_y        : std_logic_vector(FRAME_Y_BITS-1 downto 0) := (others => '0');
  signal d_dx                : std_logic_vector(FRAME_X_BITS downto 0) := (others => '0');
  signal d_dy                : std_logic_vector(FRAME_Y_BITS downto 0) := (others => '0');
  signal d_dA                : std_logic_vector(FIRE_COUNT_BITS downto 0) := (others => '0');
  signal d_temporal_valid    : std_logic := '0';
  signal d_fire_present      : std_logic;
  signal d_persistent_fire   : std_logic;
  signal d_growth_alert      : std_logic;
  signal d_movement_alert    : std_logic;
  signal d_risk_level        : std_logic_vector(1 downto 0);
  signal d_decision_valid    : std_logic;

  -- directed frame-stats stimulus/check signals
  signal fs_vs_in          : std_logic := '0';
  signal fs_de_in          : std_logic := '0';
  signal fs_fire_pix       : std_logic := '0';
  signal fs_secondary_pix  : std_logic := '0';
  signal fs_x_pos          : std_logic_vector(FRAME_X_BITS-1 downto 0) := (others => '0');
  signal fs_y_pos          : std_logic_vector(FRAME_Y_BITS-1 downto 0) := (others => '0');
  signal fs_frame_done     : std_logic;
  signal fs_fire_count     : std_logic_vector(FIRE_COUNT_BITS-1 downto 0);
  signal fs_secondary_count: std_logic_vector(FIRE_COUNT_BITS-1 downto 0);
  signal fs_sum_x_fire     : std_logic_vector(FIRE_SUM_X_BITS-1 downto 0);
  signal fs_sum_y_fire     : std_logic_vector(FIRE_SUM_Y_BITS-1 downto 0);
  signal fs_xmin_out       : std_logic_vector(FRAME_X_BITS-1 downto 0);
  signal fs_xmax_out       : std_logic_vector(FRAME_X_BITS-1 downto 0);
  signal fs_ymin_out       : std_logic_vector(FRAME_Y_BITS-1 downto 0);
  signal fs_ymax_out       : std_logic_vector(FRAME_Y_BITS-1 downto 0);
  signal fs_bbox_valid_out : std_logic;
  signal fs_centroid_x     : std_logic_vector(FRAME_X_BITS-1 downto 0);
  signal fs_centroid_y     : std_logic_vector(FRAME_Y_BITS-1 downto 0);
  signal fs_centroid_valid : std_logic;

  -- response file
  constant response_filename : string := "tb_nn_rgb_response.ppm";
begin
  -- clock
  clk <= not clk after CLK_PER/2;

  -- DUT
  dut: entity work.nn_rgb
    generic map (
      FIRE_COUNT_THRESHOLD_G => FIRE_THRESHOLD_TB
    )
    port map (
      clk       => clk,
      reset_n   => reset_n,
      enable_in => enable_in,
      vs_in     => vs_in,
      hs_in     => hs_in,
      de_in     => de_in,
      r_in      => r_in,
      g_in      => g_in,
      b_in      => b_in,
      vs_out    => vs_out,
      hs_out    => hs_out,
      de_out    => de_out,
      r_out     => r_out,
      g_out     => g_out,
      b_out     => b_out,
      fire_pixel          => fire_pixel,
      frame_stats_valid   => frame_stats_valid,
      frame_fire_detected => frame_fire_detected,
      frame_fire_count    => frame_fire_count,
      frame_bbox_valid    => frame_bbox_valid,
      frame_min_x         => frame_min_x,
      frame_max_x         => frame_max_x,
      frame_min_y         => frame_min_y,
      frame_max_y         => frame_max_y,
      frame_done          => frame_done,
      fire_count          => fire_count,
      secondary_count     => secondary_count,
      sum_x_fire          => sum_x_fire,
      sum_y_fire          => sum_y_fire,
      xmin_out            => xmin_out,
      xmax_out            => xmax_out,
      ymin_out            => ymin_out,
      ymax_out            => ymax_out,
      bbox_valid_out      => bbox_valid_out,
      centroid_valid      => centroid_valid,
      temporal_stats_valid => temporal_stats_valid,
      temporal_valid       => temporal_valid,
      fire_growing         => fire_growing,
      fire_shrinking       => fire_shrinking,
      fire_count_delta     => fire_count_delta,
      centroid_x           => centroid_x,
      centroid_y           => centroid_y,
      delta_x              => delta_x,
      delta_y              => delta_y,
      move_left            => move_left,
      move_right           => move_right,
      move_up              => move_up,
      move_down            => move_down,
      move_dir_code        => move_dir_code,
      bbox_width_growing   => bbox_width_growing,
      bbox_height_growing  => bbox_height_growing,
      spread_detected      => spread_detected,
      fire_present         => fire_present,
      persistent_fire      => persistent_fire,
      growth_alert         => growth_alert,
      movement_alert       => movement_alert,
      risk_level           => risk_level,
      decision_valid       => decision_valid,
      clk_o     => clk_o,
      led       => led
    );

  -- directed temporal estimator instance for deterministic checks
  temporal_duv: entity work.temporal_tracker
    generic map (
      X_BITS            => FRAME_X_BITS,
      Y_BITS            => FRAME_Y_BITS,
      COUNT_BITS        => FIRE_COUNT_BITS
    )
    port map (
      clk                 => clk,
      reset               => not reset_n,
      frame_done          => t_frame_done,
      frame_bbox_valid    => t_frame_bbox_valid,
      frame_fire_count    => t_frame_fire_count,
      frame_min_x         => t_frame_min_x,
      frame_max_x         => t_frame_max_x,
      frame_min_y         => t_frame_min_y,
      frame_max_y         => t_frame_max_y,
      centroid_x_in       => t_centroid_x_in,
      centroid_y_in       => t_centroid_y_in,
      centroid_valid_in   => t_centroid_valid_in,
      temporal_stats_valid => t_temporal_stats_valid,
      temporal_valid       => t_temporal_valid,
      fire_growing         => t_fire_growing,
      fire_shrinking       => t_fire_shrinking,
      fire_count_delta     => t_fire_count_delta,
      centroid_x           => t_centroid_x,
      centroid_y           => t_centroid_y,
      delta_x              => t_delta_x,
      delta_y              => t_delta_y,
      move_left            => t_move_left,
      move_right           => t_move_right,
      move_up              => t_move_up,
      move_down            => t_move_down,
      move_dir_code        => t_move_dir_code,
      bbox_width_growing   => t_bbox_width_growing,
      bbox_height_growing  => t_bbox_height_growing,
      spread_detected      => t_spread_detected
    );

  -- directed decision layer instance for deterministic checks
  decision_duv: entity work.decision_layer
    generic map (
      X_BITS                   => FRAME_X_BITS,
      Y_BITS                   => FRAME_Y_BITS,
      COUNT_BITS               => FIRE_COUNT_BITS,
      FIRE_PRESENT_THRESHOLD_G => 5,
      GROWTH_THRESHOLD_G       => 3,
      MOVEMENT_THRESHOLD_G     => 1,
      PERSISTENCE_FRAMES_G     => 2
    )
    port map (
      clk             => clk,
      reset           => not reset_n,
      frame_done      => d_frame_done,
      fire_count      => d_fire_count,
      centroid_valid  => d_centroid_valid,
      centroid_x      => d_centroid_x,
      centroid_y      => d_centroid_y,
      dx              => d_dx,
      dy              => d_dy,
      dA              => d_dA,
      temporal_valid  => d_temporal_valid,
      fire_present    => d_fire_present,
      persistent_fire => d_persistent_fire,
      growth_alert    => d_growth_alert,
      movement_alert  => d_movement_alert,
      risk_level      => d_risk_level,
      decision_valid  => d_decision_valid
    );

  -- directed frame-stats instance for deterministic checks
  frame_stats_duv: entity work.frame_stats
    generic map (
      X_BITS     => FRAME_X_BITS,
      Y_BITS     => FRAME_Y_BITS,
      COUNT_BITS => FIRE_COUNT_BITS,
      SUM_X_BITS => FIRE_SUM_X_BITS,
      SUM_Y_BITS => FIRE_SUM_Y_BITS
    )
    port map (
      clk             => clk,
      reset           => not reset_n,
      vs_in           => fs_vs_in,
      de_in           => fs_de_in,
      fire_pix        => fs_fire_pix,
      secondary_pix   => fs_secondary_pix,
      x_pos           => fs_x_pos,
      y_pos           => fs_y_pos,
      frame_done      => fs_frame_done,
      fire_count      => fs_fire_count,
      secondary_count => fs_secondary_count,
      sum_x_fire      => fs_sum_x_fire,
      sum_y_fire      => fs_sum_y_fire,
      xmin_out        => fs_xmin_out,
      xmax_out        => fs_xmax_out,
      ymin_out        => fs_ymin_out,
      ymax_out        => fs_ymax_out,
      bbox_valid_out  => fs_bbox_valid_out,
      centroid_x      => fs_centroid_x,
      centroid_y      => fs_centroid_y,
      centroid_valid  => fs_centroid_valid
    );

  -- stimulus
  stim: process
    variable x, y, f : integer;
  begin
    -- reset for ~20 cycles
    wait for 20*CLK_PER;
    reset_n <= '1';
    wait for 5*CLK_PER;

    -- generate several frames so the DUT can latch previous-frame metadata
    -- at each new frame start.
    for f in 0 to NUM_FRAMES-1 loop
      for y in 0 to V_ACTIVE-1 loop
        -- vertical sync only on first line of each frame
        if y = 0 then vs_in <= '1'; else vs_in <= '0'; end if;

        -- horizontal sync pulse + blanking
        hs_in <= '1';
        for x in 0 to H_BLANK-1 loop
          wait until rising_edge(clk);
        end loop;
        hs_in <= '0';

        -- active pixels
        de_in <= '1';
        for x in 0 to H_ACTIVE-1 loop
          -- deterministic but frame-varying color pattern
          r_in <= std_logic_vector(to_unsigned((x*16 + f*13) mod 256, 8));
          g_in <= std_logic_vector(to_unsigned((y*32 + f*21) mod 256, 8));
          b_in <= std_logic_vector(to_unsigned((x*16 + y*32 + f*17) mod 256, 8));
          wait until rising_edge(clk);
        end loop;
        de_in <= '0';
        r_in  <= (others => '0');
        g_in  <= (others => '0');
        b_in  <= (others => '0');

        -- small line gap
        for x in 0 to 7 loop
          wait until rising_edge(clk);
        end loop;
      end loop;

      -- short inter-frame idle
      vs_in <= '0';
      hs_in <= '0';
      de_in <= '0';
      for x in 0 to 15 loop
        wait until rising_edge(clk);
      end loop;
    end loop;

    -- trailing clocks then finish
    for x in 0 to 200 loop
      wait until rising_edge(clk);
    end loop;

    assert checks_done > 0
      report "No frame-level metadata checks were executed."
      severity error;

    assert temporal_checks_done > 0
      report "No temporal behavior checks were executed."
      severity error;

    assert frame_stats_checks_done > 0
      report "No frame_stats checks were executed."
      severity error;

    assert decision_checks_done > 0
      report "No decision-layer checks were executed."
      severity error;

    assert false report "Simulation completed" severity failure;
  end process;

  -- response capture: write active pixels to PPM
  writer: process
    file f                : text;
    variable l            : line;
    variable opened       : file_open_status;
    variable r_i, g_i, b_i: integer;
    variable started      : boolean := false;
    variable px_written   : integer := 0;
  begin
    -- wait until DUT starts a line
    wait until hs_out = '1';
    started := true;

    file_open(opened, f, response_filename, write_mode);
    -- header
    write(l, string'("P3"));                writeline(f, l);
    write(l, string'("# tb_nn_rgb output")); writeline(f, l);
    write(l, H_ACTIVE); write(l, string'(" ")); write(l, V_ACTIVE); writeline(f, l);
    write(l, string'("255"));               writeline(f, l);

    while started loop
      wait until rising_edge(clk);
      if de_out = '1' then
        r_i := to_integer(unsigned(r_out));
        g_i := to_integer(unsigned(g_out));
        b_i := to_integer(unsigned(b_out));
        write(l, r_i); write(l, string'(" "));
        write(l, g_i); write(l, string'(" "));
        write(l, b_i); writeline(f, l);
        px_written := px_written + 1;
        if px_written = H_ACTIVE*V_ACTIVE then
          exit;
        end if;
      end if;
    end loop;

    file_close(f);
    wait;
  end process;

  -- Scoreboard for frame-level metadata:
  -- build expected count/bbox from outgoing fire_pixel stream and compare with
  -- latched frame outputs when frame_stats_valid is asserted.
  metadata_check: process
    variable prev_vs, prev_de      : std_logic := '0';
    variable line_seen             : boolean := false;
    variable x_cur, y_cur          : integer := 0;
    variable fire_count_exp        : integer := 0;
    variable fire_seen_exp         : boolean := false;
    variable min_x_exp, max_x_exp  : integer := 0;
    variable min_y_exp, max_y_exp  : integer := 0;
    variable detected_exp          : std_logic := '0';
    variable count_latched_i       : integer := 0;
  begin
    wait until falling_edge(clk);

    if reset_n = '0' then
      prev_vs       := '0';
      prev_de       := '0';
      line_seen     := false;
      x_cur         := 0;
      y_cur         := 0;
      fire_count_exp:= 0;
      fire_seen_exp := false;
    else
      -- start-of-frame on output stream
      if (prev_vs = '0') and (vs_out = '1') then
        if frame_stats_valid = '1' then
          count_latched_i := to_integer(unsigned(frame_fire_count));
          assert count_latched_i = fire_count_exp
            report "frame_fire_count mismatch: expected "
              & integer'image(fire_count_exp)
              & ", got "
              & integer'image(count_latched_i)
            severity error;

          if fire_seen_exp then
            assert frame_bbox_valid = '1'
              report "frame_bbox_valid should be '1' when fire pixels exist."
              severity error;

            assert to_integer(unsigned(frame_min_x)) = min_x_exp
              report "frame_min_x mismatch."
              severity error;
            assert to_integer(unsigned(frame_max_x)) = max_x_exp
              report "frame_max_x mismatch."
              severity error;
            assert to_integer(unsigned(frame_min_y)) = min_y_exp
              report "frame_min_y mismatch."
              severity error;
            assert to_integer(unsigned(frame_max_y)) = max_y_exp
              report "frame_max_y mismatch."
              severity error;
          else
            assert frame_bbox_valid = '0'
              report "frame_bbox_valid should be '0' when no fire pixels exist."
              severity error;
          end if;

          if fire_count_exp > integer(FIRE_THRESHOLD_TB) then
            detected_exp := '1';
          else
            detected_exp := '0';
          end if;
          assert frame_fire_detected = detected_exp
            report "frame_fire_detected mismatch."
            severity error;

          checks_done <= checks_done + 1;
        end if;

        -- reset expected values for new frame
        line_seen      := false;
        x_cur          := 0;
        y_cur          := 0;
        fire_count_exp := 0;
        fire_seen_exp  := false;
      end if;

      -- coordinate tracking in active output region
      if (prev_de = '0') and (de_out = '1') then
        x_cur := 0;
        if not line_seen then
          y_cur := 0;
          line_seen := true;
        else
          y_cur := y_cur + 1;
        end if;
      elsif de_out = '1' then
        x_cur := x_cur + 1;
      end if;

      -- build expected fire statistics from DUT pixel-level output
      if (de_out = '1') and (fire_pixel = '1') then
        fire_count_exp := fire_count_exp + 1;
        if not fire_seen_exp then
          fire_seen_exp := true;
          min_x_exp := x_cur;
          max_x_exp := x_cur;
          min_y_exp := y_cur;
          max_y_exp := y_cur;
        else
          if x_cur < min_x_exp then min_x_exp := x_cur; end if;
          if x_cur > max_x_exp then max_x_exp := x_cur; end if;
          if y_cur < min_y_exp then min_y_exp := y_cur; end if;
          if y_cur > max_y_exp then max_y_exp := y_cur; end if;
        end if;
      end if;

      prev_vs := vs_out;
      prev_de := de_out;
    end if;
  end process;

  -- Directed temporal behavior verification.
  -- Provides synthetic consecutive frame metadata to verify:
  -- growth/shrink, centroid movement, direction encoding, spread flags,
  -- and valid handling for first-frame and intermittent no-fire cases.
  temporal_stim_check: process
  begin
    t_frame_done <= '0';
    t_frame_bbox_valid  <= '0';
    t_frame_fire_count  <= (others => '0');
    t_frame_min_x       <= (others => '0');
    t_frame_max_x       <= (others => '0');
    t_frame_min_y       <= (others => '0');
    t_frame_max_y       <= (others => '0');
    t_centroid_x_in     <= (others => '0');
    t_centroid_y_in     <= (others => '0');
    t_centroid_valid_in <= '0';

    wait until reset_n = '1';
    wait until rising_edge(clk);

    -- Frame A: baseline fire frame.
    t_frame_bbox_valid <= '1';
    t_frame_fire_count <= std_logic_vector(to_unsigned(20, FIRE_COUNT_BITS));
    t_frame_min_x <= std_logic_vector(to_unsigned(2, FRAME_X_BITS));
    t_frame_max_x <= std_logic_vector(to_unsigned(5, FRAME_X_BITS));
    t_frame_min_y <= std_logic_vector(to_unsigned(2, FRAME_Y_BITS));
    t_frame_max_y <= std_logic_vector(to_unsigned(5, FRAME_Y_BITS));
    t_centroid_x_in <= std_logic_vector(to_unsigned(3, FRAME_X_BITS));
    t_centroid_y_in <= std_logic_vector(to_unsigned(3, FRAME_Y_BITS));
    t_centroid_valid_in <= '1';
    t_frame_done <= '1';
    wait until rising_edge(clk);
    wait until falling_edge(clk);
    assert t_temporal_stats_valid = '1' report "Frame A: temporal_stats_valid expected '1'." severity error;
    assert t_temporal_valid = '0' report "Frame A: temporal_valid expected '0' (no previous frame)." severity error;
    assert to_integer(unsigned(t_centroid_x)) = 3 report "Frame A: centroid_x mismatch." severity error;
    assert to_integer(unsigned(t_centroid_y)) = 3 report "Frame A: centroid_y mismatch." severity error;
    t_frame_done <= '0';

    -- Frame B: larger fire area, shifted right/down, spatially expanded.
    wait until rising_edge(clk);
    t_frame_bbox_valid <= '1';
    t_frame_fire_count <= std_logic_vector(to_unsigned(30, FIRE_COUNT_BITS));
    t_frame_min_x <= std_logic_vector(to_unsigned(4, FRAME_X_BITS));
    t_frame_max_x <= std_logic_vector(to_unsigned(8, FRAME_X_BITS));
    t_frame_min_y <= std_logic_vector(to_unsigned(1, FRAME_Y_BITS));
    t_frame_max_y <= std_logic_vector(to_unsigned(5, FRAME_Y_BITS));
    t_centroid_x_in <= std_logic_vector(to_unsigned(6, FRAME_X_BITS));
    t_centroid_y_in <= std_logic_vector(to_unsigned(3, FRAME_Y_BITS));
    t_centroid_valid_in <= '1';
    t_frame_done <= '1';
    wait until rising_edge(clk);
    wait until falling_edge(clk);
    assert t_temporal_valid = '1' report "Frame B: temporal_valid expected '1'." severity error;
    assert t_fire_growing = '1' report "Frame B: fire_growing expected '1'." severity error;
    assert t_fire_shrinking = '0' report "Frame B: fire_shrinking expected '0'." severity error;
    assert to_integer(signed(t_fire_count_delta)) = 10 report "Frame B: fire_count_delta mismatch." severity error;
    assert to_integer(signed(t_delta_x)) = 3 report "Frame B: delta_x mismatch." severity error;
    assert to_integer(signed(t_delta_y)) = 0 report "Frame B: delta_y mismatch." severity error;
    assert t_move_right = '1' report "Frame B: move_right expected '1'." severity error;
    assert t_move_left = '0' report "Frame B: move_left expected '0'." severity error;
    assert t_move_down = '0' report "Frame B: move_down expected '0'." severity error;
    assert t_move_up = '0' report "Frame B: move_up expected '0'." severity error;
    assert t_move_dir_code = "0010" report "Frame B: move_dir_code expected RIGHT." severity error;
    assert t_bbox_width_growing = '1' report "Frame B: bbox_width_growing expected '1'." severity error;
    assert t_bbox_height_growing = '1' report "Frame B: bbox_height_growing expected '1'." severity error;
    assert t_spread_detected = '1' report "Frame B: spread_detected expected '1'." severity error;
    t_frame_done <= '0';

    -- Frame C: smaller area, shifted left/up, no spread growth.
    wait until rising_edge(clk);
    t_frame_bbox_valid <= '1';
    t_frame_fire_count <= std_logic_vector(to_unsigned(10, FIRE_COUNT_BITS));
    t_frame_min_x <= std_logic_vector(to_unsigned(3, FRAME_X_BITS));
    t_frame_max_x <= std_logic_vector(to_unsigned(5, FRAME_X_BITS));
    t_frame_min_y <= std_logic_vector(to_unsigned(1, FRAME_Y_BITS));
    t_frame_max_y <= std_logic_vector(to_unsigned(3, FRAME_Y_BITS));
    t_centroid_x_in <= std_logic_vector(to_unsigned(4, FRAME_X_BITS));
    t_centroid_y_in <= std_logic_vector(to_unsigned(2, FRAME_Y_BITS));
    t_centroid_valid_in <= '1';
    t_frame_done <= '1';
    wait until rising_edge(clk);
    wait until falling_edge(clk);
    assert t_temporal_valid = '1' report "Frame C: temporal_valid expected '1'." severity error;
    assert t_fire_growing = '0' report "Frame C: fire_growing expected '0'." severity error;
    assert t_fire_shrinking = '1' report "Frame C: fire_shrinking expected '1'." severity error;
    assert to_integer(signed(t_fire_count_delta)) = -20 report "Frame C: fire_count_delta mismatch." severity error;
    assert to_integer(signed(t_delta_x)) = -2 report "Frame C: delta_x mismatch." severity error;
    assert to_integer(signed(t_delta_y)) = -1 report "Frame C: delta_y mismatch." severity error;
    assert t_move_left = '1' report "Frame C: move_left expected '1'." severity error;
    assert t_move_up = '1' report "Frame C: move_up expected '1'." severity error;
    assert t_move_right = '0' report "Frame C: move_right expected '0'." severity error;
    assert t_move_down = '0' report "Frame C: move_down expected '0'." severity error;
    assert t_move_dir_code = "0101" report "Frame C: move_dir_code expected UP_LEFT." severity error;
    assert t_bbox_width_growing = '0' report "Frame C: bbox_width_growing expected '0'." severity error;
    assert t_bbox_height_growing = '0' report "Frame C: bbox_height_growing expected '0'." severity error;
    assert t_spread_detected = '0' report "Frame C: spread_detected expected '0'." severity error;
    t_frame_done <= '0';

    -- Frame D: no fire -> temporal comparison not valid.
    wait until rising_edge(clk);
    t_frame_bbox_valid <= '0';
    t_frame_fire_count <= (others => '0');
    t_frame_min_x <= (others => '0');
    t_frame_max_x <= (others => '0');
    t_frame_min_y <= (others => '0');
    t_frame_max_y <= (others => '0');
    t_centroid_x_in <= (others => '0');
    t_centroid_y_in <= (others => '0');
    t_centroid_valid_in <= '0';
    t_frame_done <= '1';
    wait until rising_edge(clk);
    wait until falling_edge(clk);
    assert t_temporal_valid = '0' report "Frame D: temporal_valid expected '0' (no fire)." severity error;
    assert t_fire_growing = '0' report "Frame D: fire_growing expected '0'." severity error;
    assert t_fire_shrinking = '0' report "Frame D: fire_shrinking expected '0'." severity error;
    t_frame_done <= '0';

    -- Frame E: fire returns after no-fire frame -> still invalid comparison.
    wait until rising_edge(clk);
    t_frame_bbox_valid <= '1';
    t_frame_fire_count <= std_logic_vector(to_unsigned(12, FIRE_COUNT_BITS));
    t_frame_min_x <= std_logic_vector(to_unsigned(1, FRAME_X_BITS));
    t_frame_max_x <= std_logic_vector(to_unsigned(4, FRAME_X_BITS));
    t_frame_min_y <= std_logic_vector(to_unsigned(1, FRAME_Y_BITS));
    t_frame_max_y <= std_logic_vector(to_unsigned(3, FRAME_Y_BITS));
    t_centroid_x_in <= std_logic_vector(to_unsigned(2, FRAME_X_BITS));
    t_centroid_y_in <= std_logic_vector(to_unsigned(2, FRAME_Y_BITS));
    t_centroid_valid_in <= '1';
    t_frame_done <= '1';
    wait until rising_edge(clk);
    wait until falling_edge(clk);
    assert t_temporal_valid = '0' report "Frame E: temporal_valid expected '0' (previous frame had no fire)." severity error;
    t_frame_done <= '0';

    -- Frame F: second consecutive fire frame after return -> valid again.
    wait until rising_edge(clk);
    t_frame_bbox_valid <= '1';
    t_frame_fire_count <= std_logic_vector(to_unsigned(18, FIRE_COUNT_BITS));
    t_frame_min_x <= std_logic_vector(to_unsigned(2, FRAME_X_BITS));
    t_frame_max_x <= std_logic_vector(to_unsigned(6, FRAME_X_BITS));
    t_frame_min_y <= std_logic_vector(to_unsigned(2, FRAME_Y_BITS));
    t_frame_max_y <= std_logic_vector(to_unsigned(5, FRAME_Y_BITS));
    t_centroid_x_in <= std_logic_vector(to_unsigned(4, FRAME_X_BITS));
    t_centroid_y_in <= std_logic_vector(to_unsigned(3, FRAME_Y_BITS));
    t_centroid_valid_in <= '1';
    t_frame_done <= '1';
    wait until rising_edge(clk);
    wait until falling_edge(clk);
    assert t_temporal_valid = '1' report "Frame F: temporal_valid expected '1'." severity error;
    assert t_fire_growing = '1' report "Frame F: fire_growing expected '1'." severity error;
    assert t_move_right = '1' report "Frame F: move_right expected '1'." severity error;
    assert t_move_down = '1' report "Frame F: move_down expected '1'." severity error;
    assert t_move_dir_code = "1000" report "Frame F: move_dir_code expected DOWN_RIGHT." severity error;
    assert t_spread_detected = '1' report "Frame F: spread_detected expected '1'." severity error;
    t_frame_done <= '0';

    temporal_checks_done <= temporal_checks_done + 1;
    wait;
  end process;

  -- Directed decision-layer verification.
  -- Scenario A: no fire
  -- Scenario B: stable fire becomes persistent
  -- Scenario C: growing fire
  -- Scenario D: moving and growing fire
  -- Scenario E: fire disappears
  decision_stim_check: process
  begin
    d_frame_done <= '0';
    d_fire_count <= (others => '0');
    d_centroid_valid <= '0';
    d_centroid_x <= (others => '0');
    d_centroid_y <= (others => '0');
    d_dx <= (others => '0');
    d_dy <= (others => '0');
    d_dA <= (others => '0');
    d_temporal_valid <= '0';

    wait until reset_n = '1';
    wait until rising_edge(clk);

    -- Scenario A: no fire
    d_fire_count <= (others => '0');
    d_centroid_valid <= '0';
    d_temporal_valid <= '0';
    d_dx <= (others => '0');
    d_dy <= (others => '0');
    d_dA <= (others => '0');
    d_frame_done <= '1';
    wait until rising_edge(clk);
    d_frame_done <= '0';
    wait until rising_edge(clk);
    wait until falling_edge(clk);
    assert d_decision_valid = '1' report "Scenario A: decision_valid expected '1'." severity error;
    assert d_fire_present = '0' report "Scenario A: fire_present expected '0'." severity error;
    assert d_persistent_fire = '0' report "Scenario A: persistent_fire expected '0'." severity error;
    assert d_growth_alert = '0' report "Scenario A: growth_alert expected '0'." severity error;
    assert d_movement_alert = '0' report "Scenario A: movement_alert expected '0'." severity error;
    assert d_risk_level = "00" report "Scenario A: risk_level expected 00." severity error;

    -- Scenario B1: first stable fire frame -> low risk
    d_fire_count <= std_logic_vector(to_unsigned(6, FIRE_COUNT_BITS));
    d_centroid_valid <= '1';
    d_centroid_x <= std_logic_vector(to_unsigned(4, FRAME_X_BITS));
    d_centroid_y <= std_logic_vector(to_unsigned(3, FRAME_Y_BITS));
    d_temporal_valid <= '0';
    d_dx <= (others => '0');
    d_dy <= (others => '0');
    d_dA <= (others => '0');
    d_frame_done <= '1';
    wait until rising_edge(clk);
    d_frame_done <= '0';
    wait until rising_edge(clk);
    wait until falling_edge(clk);
    assert d_fire_present = '1' report "Scenario B1: fire_present expected '1'." severity error;
    assert d_persistent_fire = '0' report "Scenario B1: persistent_fire expected '0'." severity error;
    assert d_risk_level = "01" report "Scenario B1: risk_level expected 01." severity error;

    -- Scenario B2: second stable fire frame -> persistent, medium risk
    d_fire_count <= std_logic_vector(to_unsigned(7, FIRE_COUNT_BITS));
    d_centroid_valid <= '1';
    d_centroid_x <= std_logic_vector(to_unsigned(4, FRAME_X_BITS));
    d_centroid_y <= std_logic_vector(to_unsigned(3, FRAME_Y_BITS));
    d_temporal_valid <= '0';
    d_dx <= (others => '0');
    d_dy <= (others => '0');
    d_dA <= (others => '0');
    d_frame_done <= '1';
    wait until rising_edge(clk);
    d_frame_done <= '0';
    wait until rising_edge(clk);
    wait until falling_edge(clk);
    assert d_fire_present = '1' report "Scenario B2: fire_present expected '1'." severity error;
    assert d_persistent_fire = '1' report "Scenario B2: persistent_fire expected '1'." severity error;
    assert d_growth_alert = '0' report "Scenario B2: growth_alert expected '0'." severity error;
    assert d_movement_alert = '0' report "Scenario B2: movement_alert expected '0'." severity error;
    assert d_risk_level = "10" report "Scenario B2: risk_level expected 10." severity error;

    -- Scenario C: growing fire -> high risk (persistent + growth)
    d_fire_count <= std_logic_vector(to_unsigned(12, FIRE_COUNT_BITS));
    d_centroid_valid <= '1';
    d_centroid_x <= std_logic_vector(to_unsigned(5, FRAME_X_BITS));
    d_centroid_y <= std_logic_vector(to_unsigned(3, FRAME_Y_BITS));
    d_temporal_valid <= '1';
    d_dx <= std_logic_vector(to_signed(0, FRAME_X_BITS+1));
    d_dy <= std_logic_vector(to_signed(0, FRAME_Y_BITS+1));
    d_dA <= std_logic_vector(to_signed(5, FIRE_COUNT_BITS+1));
    d_frame_done <= '1';
    wait until rising_edge(clk);
    d_frame_done <= '0';
    wait until rising_edge(clk);
    wait until falling_edge(clk);
    assert d_growth_alert = '1' report "Scenario C: growth_alert expected '1'." severity error;
    assert d_movement_alert = '0' report "Scenario C: movement_alert expected '0'." severity error;
    assert d_risk_level = "11" report "Scenario C: risk_level expected 11." severity error;

    -- Scenario D: moving and growing fire -> high risk
    d_fire_count <= std_logic_vector(to_unsigned(14, FIRE_COUNT_BITS));
    d_centroid_valid <= '1';
    d_centroid_x <= std_logic_vector(to_unsigned(7, FRAME_X_BITS));
    d_centroid_y <= std_logic_vector(to_unsigned(2, FRAME_Y_BITS));
    d_temporal_valid <= '1';
    d_dx <= std_logic_vector(to_signed(2, FRAME_X_BITS+1));
    d_dy <= std_logic_vector(to_signed(-2, FRAME_Y_BITS+1));
    d_dA <= std_logic_vector(to_signed(4, FIRE_COUNT_BITS+1));
    d_frame_done <= '1';
    wait until rising_edge(clk);
    d_frame_done <= '0';
    wait until rising_edge(clk);
    wait until falling_edge(clk);
    assert d_growth_alert = '1' report "Scenario D: growth_alert expected '1'." severity error;
    assert d_movement_alert = '1' report "Scenario D: movement_alert expected '1'." severity error;
    assert d_risk_level = "11" report "Scenario D: risk_level expected 11." severity error;

    -- Scenario E: fire disappears -> no risk
    d_fire_count <= (others => '0');
    d_centroid_valid <= '0';
    d_centroid_x <= (others => '0');
    d_centroid_y <= (others => '0');
    d_temporal_valid <= '0';
    d_dx <= std_logic_vector(to_signed(0, FRAME_X_BITS+1));
    d_dy <= std_logic_vector(to_signed(0, FRAME_Y_BITS+1));
    d_dA <= std_logic_vector(to_signed(-8, FIRE_COUNT_BITS+1));
    d_frame_done <= '1';
    wait until rising_edge(clk);
    d_frame_done <= '0';
    wait until rising_edge(clk);
    wait until falling_edge(clk);
    assert d_fire_present = '0' report "Scenario E: fire_present expected '0'." severity error;
    assert d_persistent_fire = '0' report "Scenario E: persistent_fire expected '0'." severity error;
    assert d_growth_alert = '0' report "Scenario E: growth_alert expected '0'." severity error;
    assert d_movement_alert = '0' report "Scenario E: movement_alert expected '0'." severity error;
    assert d_risk_level = "00" report "Scenario E: risk_level expected 00." severity error;

    decision_checks_done <= decision_checks_done + 1;
    wait;
  end process;

  -- Directed frame_stats verification.
  -- Creates synthetic classified pixels with explicit coordinates and checks:
  -- fire_count, secondary_count, sums, bbox, and frame_done behavior.
  frame_stats_stim_check: process
  begin
    fs_vs_in <= '0';
    fs_de_in <= '0';
    fs_fire_pix <= '0';
    fs_secondary_pix <= '0';
    fs_x_pos <= (others => '0');
    fs_y_pos <= (others => '0');

    wait until reset_n = '1';
    wait until rising_edge(clk);

    -- Start Frame A
    fs_vs_in <= '1';
    wait until rising_edge(clk);
    fs_vs_in <= '0';

    -- Fire pixels: (2,1), (4,3); secondary pixel: (1,0)
    fs_de_in <= '1';
    fs_fire_pix <= '1'; fs_secondary_pix <= '0';
    fs_x_pos <= std_logic_vector(to_unsigned(2, FRAME_X_BITS));
    fs_y_pos <= std_logic_vector(to_unsigned(1, FRAME_Y_BITS));
    wait until rising_edge(clk);

    fs_fire_pix <= '1'; fs_secondary_pix <= '0';
    fs_x_pos <= std_logic_vector(to_unsigned(4, FRAME_X_BITS));
    fs_y_pos <= std_logic_vector(to_unsigned(3, FRAME_Y_BITS));
    wait until rising_edge(clk);

    fs_fire_pix <= '0'; fs_secondary_pix <= '1';
    fs_x_pos <= std_logic_vector(to_unsigned(1, FRAME_X_BITS));
    fs_y_pos <= std_logic_vector(to_unsigned(0, FRAME_Y_BITS));
    wait until rising_edge(clk);

    fs_de_in <= '0';
    fs_fire_pix <= '0';
    fs_secondary_pix <= '0';

    -- Start Frame B: latches Frame A results
    wait until rising_edge(clk);
    fs_vs_in <= '1';
    wait until rising_edge(clk);
    wait until falling_edge(clk);
    assert fs_frame_done = '1' report "Frame A: frame_done expected '1'." severity error;
    assert to_integer(unsigned(fs_fire_count)) = 2 report "Frame A: fire_count mismatch." severity error;
    assert to_integer(unsigned(fs_secondary_count)) = 1 report "Frame A: secondary_count mismatch." severity error;
    assert to_integer(unsigned(fs_sum_x_fire)) = 6 report "Frame A: sum_x_fire mismatch." severity error;
    assert to_integer(unsigned(fs_sum_y_fire)) = 4 report "Frame A: sum_y_fire mismatch." severity error;
    assert fs_bbox_valid_out = '1' report "Frame A: bbox_valid_out expected '1'." severity error;
    assert to_integer(unsigned(fs_xmin_out)) = 2 report "Frame A: xmin mismatch." severity error;
    assert to_integer(unsigned(fs_xmax_out)) = 4 report "Frame A: xmax mismatch." severity error;
    assert to_integer(unsigned(fs_ymin_out)) = 1 report "Frame A: ymin mismatch." severity error;
    assert to_integer(unsigned(fs_ymax_out)) = 3 report "Frame A: ymax mismatch." severity error;
    assert fs_centroid_valid = '1' report "Frame A: centroid_valid expected '1'." severity error;
    assert to_integer(unsigned(fs_centroid_x)) = 3 report "Frame A: centroid_x mismatch." severity error;
    assert to_integer(unsigned(fs_centroid_y)) = 2 report "Frame A: centroid_y mismatch." severity error;
    fs_vs_in <= '0';

    -- Frame B pixels: fire (3,1), (5,3), (6,4); secondary (2,0), (1,1)
    fs_de_in <= '1';
    fs_fire_pix <= '1'; fs_secondary_pix <= '0';
    fs_x_pos <= std_logic_vector(to_unsigned(3, FRAME_X_BITS));
    fs_y_pos <= std_logic_vector(to_unsigned(1, FRAME_Y_BITS));
    wait until rising_edge(clk);

    fs_fire_pix <= '1'; fs_secondary_pix <= '0';
    fs_x_pos <= std_logic_vector(to_unsigned(5, FRAME_X_BITS));
    fs_y_pos <= std_logic_vector(to_unsigned(3, FRAME_Y_BITS));
    wait until rising_edge(clk);

    fs_fire_pix <= '1'; fs_secondary_pix <= '0';
    fs_x_pos <= std_logic_vector(to_unsigned(6, FRAME_X_BITS));
    fs_y_pos <= std_logic_vector(to_unsigned(4, FRAME_Y_BITS));
    wait until rising_edge(clk);

    fs_fire_pix <= '0'; fs_secondary_pix <= '1';
    fs_x_pos <= std_logic_vector(to_unsigned(2, FRAME_X_BITS));
    fs_y_pos <= std_logic_vector(to_unsigned(0, FRAME_Y_BITS));
    wait until rising_edge(clk);

    fs_fire_pix <= '0'; fs_secondary_pix <= '1';
    fs_x_pos <= std_logic_vector(to_unsigned(1, FRAME_X_BITS));
    fs_y_pos <= std_logic_vector(to_unsigned(1, FRAME_Y_BITS));
    wait until rising_edge(clk);

    fs_de_in <= '0';
    fs_fire_pix <= '0';
    fs_secondary_pix <= '0';

    -- Start Frame C: latches Frame B results
    wait until rising_edge(clk);
    fs_vs_in <= '1';
    wait until rising_edge(clk);
    wait until falling_edge(clk);
    assert fs_frame_done = '1' report "Frame B: frame_done expected '1'." severity error;
    assert to_integer(unsigned(fs_fire_count)) = 3 report "Frame B: fire_count mismatch." severity error;
    assert to_integer(unsigned(fs_secondary_count)) = 2 report "Frame B: secondary_count mismatch." severity error;
    assert to_integer(unsigned(fs_sum_x_fire)) = 14 report "Frame B: sum_x_fire mismatch." severity error;
    assert to_integer(unsigned(fs_sum_y_fire)) = 8 report "Frame B: sum_y_fire mismatch." severity error;
    assert fs_bbox_valid_out = '1' report "Frame B: bbox_valid_out expected '1'." severity error;
    assert to_integer(unsigned(fs_xmin_out)) = 3 report "Frame B: xmin mismatch." severity error;
    assert to_integer(unsigned(fs_xmax_out)) = 6 report "Frame B: xmax mismatch." severity error;
    assert to_integer(unsigned(fs_ymin_out)) = 1 report "Frame B: ymin mismatch." severity error;
    assert to_integer(unsigned(fs_ymax_out)) = 4 report "Frame B: ymax mismatch." severity error;
    assert fs_centroid_valid = '1' report "Frame B: centroid_valid expected '1'." severity error;
    assert to_integer(unsigned(fs_centroid_x)) = 4 report "Frame B: centroid_x mismatch." severity error;
    assert to_integer(unsigned(fs_centroid_y)) = 2 report "Frame B: centroid_y mismatch." severity error;
    fs_vs_in <= '0';

    -- Frame C pixels: no fire, secondary-only
    fs_de_in <= '1';
    fs_fire_pix <= '0'; fs_secondary_pix <= '1';
    fs_x_pos <= std_logic_vector(to_unsigned(0, FRAME_X_BITS));
    fs_y_pos <= std_logic_vector(to_unsigned(0, FRAME_Y_BITS));
    wait until rising_edge(clk);
    assert to_integer(unsigned(fs_centroid_x)) = 4 report "Centroid should stay stable between frame updates (x)." severity error;
    assert to_integer(unsigned(fs_centroid_y)) = 2 report "Centroid should stay stable between frame updates (y)." severity error;
    assert fs_centroid_valid = '1' report "Centroid valid should stay stable between frame updates." severity error;

    fs_fire_pix <= '0'; fs_secondary_pix <= '1';
    fs_x_pos <= std_logic_vector(to_unsigned(1, FRAME_X_BITS));
    fs_y_pos <= std_logic_vector(to_unsigned(0, FRAME_Y_BITS));
    wait until rising_edge(clk);

    fs_fire_pix <= '0'; fs_secondary_pix <= '1';
    fs_x_pos <= std_logic_vector(to_unsigned(2, FRAME_X_BITS));
    fs_y_pos <= std_logic_vector(to_unsigned(1, FRAME_Y_BITS));
    wait until rising_edge(clk);

    fs_de_in <= '0';
    fs_secondary_pix <= '0';

    -- Start Frame D: latches Frame C results (no-fire case)
    wait until rising_edge(clk);
    fs_vs_in <= '1';
    wait until rising_edge(clk);
    wait until falling_edge(clk);
    assert fs_frame_done = '1' report "Frame C: frame_done expected '1'." severity error;
    assert to_integer(unsigned(fs_fire_count)) = 0 report "Frame C: fire_count mismatch." severity error;
    assert to_integer(unsigned(fs_secondary_count)) = 3 report "Frame C: secondary_count mismatch." severity error;
    assert to_integer(unsigned(fs_sum_x_fire)) = 0 report "Frame C: sum_x_fire mismatch." severity error;
    assert to_integer(unsigned(fs_sum_y_fire)) = 0 report "Frame C: sum_y_fire mismatch." severity error;
    assert fs_bbox_valid_out = '0' report "Frame C: bbox_valid_out expected '0'." severity error;
    assert to_integer(unsigned(fs_xmin_out)) = 0 report "Frame C: xmin should be 0 for no-fire frame." severity error;
    assert to_integer(unsigned(fs_xmax_out)) = 0 report "Frame C: xmax should be 0 for no-fire frame." severity error;
    assert to_integer(unsigned(fs_ymin_out)) = 0 report "Frame C: ymin should be 0 for no-fire frame." severity error;
    assert to_integer(unsigned(fs_ymax_out)) = 0 report "Frame C: ymax should be 0 for no-fire frame." severity error;
    assert fs_centroid_valid = '0' report "Frame C: centroid_valid expected '0'." severity error;
    assert to_integer(unsigned(fs_centroid_x)) = 0 report "Frame C: centroid_x should be 0 for no-fire frame." severity error;
    assert to_integer(unsigned(fs_centroid_y)) = 0 report "Frame C: centroid_y should be 0 for no-fire frame." severity error;
    fs_vs_in <= '0';

    frame_stats_checks_done <= frame_stats_checks_done + 1;
    wait;
  end process;

end architecture;
