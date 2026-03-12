-- sim_nn_rgb.vhd
--
-- testbench for nn_rgb
-- reading and writing images in ppm-file format
--          ppm-file can be generated and viewed with IrfanView and probably other image viewers
--          verified with IrfanView version 4.54 - 64 bit and 4.44 - 64 bit

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;
use std.textio.all;
use ieee.std_logic_textio.all;
use work.CONFIG.ALL;

entity sim_nn_rgb is
end sim_nn_rgb;

architecture sim of sim_nn_rgb is

-- define constants for simulation
  constant stimuli_filename  : string  := "image_stimuli.ppm";
  constant response_filename : string  := "image_response.ppm";
  constant x_blank           : integer := 100;   -- horizontal blanking
  constant trail             : integer := 1000;  -- clock cycles after active image

-- signals of testbench
  signal clk       : std_logic := '0';
  signal reset_n   : std_logic;
  signal enable_in : std_logic_vector(2 downto 0);
  signal vs_in     : std_logic;
  signal hs_in     : std_logic;
  signal de_in     : std_logic;
  signal r_in      : std_logic_vector(7 downto 0);
  signal g_in      : std_logic_vector(7 downto 0);
  signal b_in      : std_logic_vector(7 downto 0);
  signal vs_out    : std_logic;
  signal hs_out    : std_logic;
  signal de_out    : std_logic;
  signal r_out     : std_logic_vector(7 downto 0);
  signal g_out     : std_logic_vector(7 downto 0);
  signal b_out     : std_logic_vector(7 downto 0);
  signal fire_pixel          : std_logic;
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
  signal centroid_valid      : std_logic;
  signal temporal_stats_valid : std_logic;
  signal temporal_valid       : std_logic;
  signal fire_growing         : std_logic;
  signal fire_shrinking       : std_logic;
  signal fire_count_delta     : std_logic_vector(FIRE_COUNT_BITS downto 0);
  signal centroid_x           : std_logic_vector(FRAME_X_BITS-1 downto 0);
  signal centroid_y           : std_logic_vector(FRAME_Y_BITS-1 downto 0);
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
  signal x_size, y_size      : integer;
  signal end_tb    : integer   := 0;
  signal mismatch  : integer   := 0;

begin

  -- clock generation
  clk <= not clk after 5 ns;

  -- instantiation of design-under-verification
  duv : entity work.nn_rgb
    port map (clk       => clk,
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
              led       => led);

  -- main process for stimuli
  stimuli_process : process

  -- variables for stimuli file
    file stimuli_file       : text;
    variable l              : line;
    variable stimuli_status : file_open_status;
    variable x, y      : integer;
    variable i, r_integer, g_integer, b_integer  : integer;

  begin

    -- read stimuli file
    file_open(stimuli_status, stimuli_file, stimuli_filename, read_mode);
    readline(stimuli_file, l);          -- read line 1 with magic number
    readline(stimuli_file, l);          -- read line 2 with comments
    readline(stimuli_file, l);          -- read line 3 with x, y size
    read(l, i); x_size <= i;
    read(l, i); y_size <= i;
    readline(stimuli_file, l);          -- read line 4 with maximum value
    readline(stimuli_file, l);          -- read first line of image data

    -- init
    reset_n   <= '0', '1' after 50 ns;  -- reset for 10 clock cycles
    enable_in <= "111";
    vs_in     <= '0';
    hs_in     <= '0';
    de_in     <= '0';
    r_in      <= "00000000";
    g_in      <= "00000000";
    b_in      <= "00000000";

    -- wait for reset
    wait for 100 ns;

    -- loop for one frame
    for y in 0 to y_size-1 loop
    
      -- set vertical sync
      if (y = 0) then
        vs_in <= '1';
      else
        vs_in <= '0';
      end if;

      -- set herizontal sync
      hs_in <= '1';
      for x in 0 to x_blank-1 loop
        wait until falling_edge(clk);
      end loop;  -- x, blanking
      hs_in <= '0';

      -- read one image line from file and give it to device under verification
      -- set de_in to '1' for active pixel
      de_in <= '1';
      for x in 0 to x_size-1 loop
      
        -- a ppm-file has several pixel per line
        -- check if the current line has characters to be processed
        -- if no character or only one  character is present, read new line (single character might be one blank)
        if l'length < 2 then readline(stimuli_file, l); end if;
        read(l, r_integer);
        read(l, g_integer);
        read(l, b_integer);
        -- convert integer values to std_logic
        r_in <= std_logic_vector(to_unsigned(r_integer,8));
        g_in <= std_logic_vector(to_unsigned(g_integer,8));
        b_in <= std_logic_vector(to_unsigned(b_integer,8));

        wait until falling_edge(clk);
      end loop;  -- x, active line
      de_in <= '0';
      r_in  <= "00000000";
      g_in  <= "00000000";
      b_in  <= "00000000";

    end loop;  -- y

-- simulation for trailing clock cycles
    for i in 0 to trail-1 loop
      wait until falling_edge(clk);
    end loop;

    end_tb <= 1;                        -- signal to close response_file
    file_close(stimuli_file);
    wait for 20 ns;

-- stop simulation
    assert false
      report "Simulation completed"
      severity failure;

  end process;

-- second process to handle DUT output
  response_process : process
-- variables for writing simulated response
    file response_file        : text;
    variable l_sim            : line;
    variable response_status  : file_open_status;
    variable r_sim, g_sim, b_sim        : integer;

  begin

    wait until (hs_out = '1');  -- wait until stimuli process is started


-- open file for output image
    file_open(response_status, response_file, response_filename, write_mode);
    write (l_sim, string'("P3"));       -- magic number
    writeline(response_file, l_sim);        
    write (l_sim, string'("# generated by VHDL testbench"));       -- comment
    writeline(response_file, l_sim);   
    write (l_sim, x_size);
    write (l_sim, string'(" "));
    write (l_sim, y_size);
    writeline(response_file, l_sim);        
    write (l_sim, string'("255"));       -- maximum value
    writeline(response_file, l_sim);        
    
    while (end_tb /= 1) loop
      wait until falling_edge(clk);
      if (de_out = '1') then

        -- get response and write to response file
          r_sim := to_integer(unsigned(r_out));
          g_sim := to_integer(unsigned(g_out));
          b_sim := to_integer(unsigned(b_out));
        write(l_sim, r_sim);
        write (l_sim, string'(" "));
        write(l_sim, g_sim);
        write (l_sim, string'(" "));
        write(l_sim, b_sim);
        writeline(response_file, l_sim);

      end if;
    end loop;

    file_close(response_file);
    wait until (end_tb = 2); -- wait forever, because end_tb will not become 2

  end process;

end sim;
