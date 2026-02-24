-- multiplier.vhd
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

library work;
use work.CONFIG.ALL;   -- <- make CONFIG visible (min/max ranges)

entity multiplier is
  generic (
    weight : integer := 0
  );
  port (
    clk    : in  std_logic;
    input  : in  integer range 0 to 255;                     -- CONFIG.INPUT element
    output : out integer range minMultRange to maxMultRange  -- from CONFIG
  );
end entity;

architecture behave of multiplier is
  signal prod_r : integer range minMultRange to maxMultRange := 0;
  -- Ensure multiplier maps efficiently to DSP48
  attribute use_dsp : string;
  attribute use_dsp of prod_r : signal is "yes";
begin
  process(clk)
  begin
    if rising_edge(clk) then
      prod_r <= input * weight;
    end if;
  end process;

  output <= prod_r;
end architecture;
