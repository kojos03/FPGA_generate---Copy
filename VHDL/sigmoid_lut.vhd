-- sigmoid_lut.vhd  (Vivado + ISE friendly; no black box)
-- Entity matches what sigmoid_IP.vhd expects: clka, ena, addra, douta
-- Implements a smooth sigmoid-like S-curve using fixed-point math
-- (You can later swap with a 4096x8 ROM if you want a true logistic table.)

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sigmoid_lut is
  port (
    clka  : in  std_logic;
    ena   : in  std_logic;                       -- NEW: match instantiation
    addra : in  std_logic_vector(11 downto 0);   -- 0..4095
    douta : out std_logic_vector(7 downto 0)     -- 0..255
  );
end entity;

architecture rtl of sigmoid_lut is
  signal dout_r : std_logic_vector(7 downto 0);

  -- saturate integer to 0..255
  function sat8(x : integer) return std_logic_vector is
    variable v : integer := x;
  begin
    if v < 0 then v := 0; elsif v > 255 then v := 255; end if;
    return std_logic_vector(to_unsigned(v, 8));
  end function;
begin
  process(clka)
    variable addr_u     : unsigned(11 downto 0);
    variable t_signed   : integer;  -- [-2048..+2047]
    variable u_q15      : integer;  -- Q1.15
    variable u_sq_q15   : integer;  -- Q1.15
    variable u_cu_q15   : integer;  -- Q1.15
    variable y_q15      : integer;  -- Q1.15
    variable y255       : integer;  -- 0..255 approx
    variable y8         : std_logic_vector(7 downto 0);
  begin
    if rising_edge(clka) then
      if ena = '1' then
        addr_u   := unsigned(addra);
        t_signed := to_integer(addr_u) - 2048;
        -- u ≈ t/2048 in Q1.15  -> u_q15 = t * 16  (since 2^15/2048 = 16)
        u_q15    := t_signed * 16;
        -- u^2, u^3 in Q1.15
        u_sq_q15 := (u_q15 * u_q15) / 32768;    -- >>15
        u_cu_q15 := (u_sq_q15 * u_q15) / 32768; -- >>15
        -- y ≈ 0.5 + 0.75*u - 0.25*u^3  (Q1.15: 0.5=16384, 0.75=24576, 0.25=8192)
        y_q15 := 16384
                 + ((24576 * u_q15) / 32768)
                 - ((8192  * u_cu_q15) / 32768);
        -- scale to 0..255: round(255*y) with y in [0,1]
        y255 := (y_q15 * 255 + 16384) / 32768;  -- +0.5 for rounding
        y8   := sat8(y255);
        dout_r <= y8;
      else
        -- hold last value when disabled
        dout_r <= dout_r;
      end if;
    end if;
  end process;

  douta <= dout_r;
end architecture;
