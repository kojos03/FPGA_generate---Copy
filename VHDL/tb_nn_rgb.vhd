--- Testbench for nn_rgb from Dionysiou

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.all;
use std.textio.all;
use ieee.std_logic_textio.all;

entity tb_nn_rgb is
end entity;

architecture sim of tb_nn_rgb is
  -- simulation config
  constant H_ACTIVE  : integer := 16;
  constant V_ACTIVE  : integer := 8;
  constant H_BLANK   : integer := 8;
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
  signal clk_o     : std_logic;
  signal led       : std_logic_vector(2 downto 0);

  -- response file
  constant response_filename : string := "tb_nn_rgb_response.ppm";
begin
  -- clock
  clk <= not clk after CLK_PER/2;

  -- DUT
  dut: entity work.nn_rgb
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
      clk_o     => clk_o,
      led       => led
    );

  -- stimulus
  stim: process
    variable x, y : integer;
  begin
    -- reset for ~20 cycles
    wait for 20*CLK_PER;
    reset_n <= '1';
    wait for 5*CLK_PER;

    for y in 0 to V_ACTIVE-1 loop
      -- vertical sync only on first line
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
        -- simple color pattern
        r_in <= std_logic_vector(to_unsigned((x*16) mod 256, 8));
        g_in <= std_logic_vector(to_unsigned((y*32) mod 256, 8));
        b_in <= std_logic_vector(to_unsigned((x*16 + y*32) mod 256, 8));
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

    -- trailing clocks then finish
    for x in 0 to 200 loop
      wait until rising_edge(clk);
    end loop;

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

end architecture;