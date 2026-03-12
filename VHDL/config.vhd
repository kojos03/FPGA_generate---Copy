library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package CONFIG is
	type INPUT is array (natural range <>) of integer range 0 to 255;
	-- NOTE: 'connection' moved to top-level (nn_rgb.vhd) for Vivado synthesis
	-- Declare in the architecture of the top-level as:
	--   signal connection : INPUT(11 downto 0);
	-- connection(2 downto 0) are NN inputs, connection(11 downto 10) are NN outputs

	-- Frame-level wildfire metadata configuration.
	-- These values define the numeric width of frame counters/coordinates
	-- and the threshold used for frame-level fire detection.
	constant FRAME_X_BITS          : natural := 12;   -- up to 4096 columns
	constant FRAME_Y_BITS          : natural := 12;   -- up to 4096 rows
	constant FIRE_COUNT_BITS       : natural := 24;   -- up to 16,777,216 pixels/frame
	constant FIRE_SUM_X_BITS       : natural := FRAME_X_BITS + FIRE_COUNT_BITS;
	constant FIRE_SUM_Y_BITS       : natural := FRAME_Y_BITS + FIRE_COUNT_BITS;
	constant FIRE_COUNT_THRESHOLD  : natural := 4096; -- tune per resolution/sensitivity

	-- Temporal comparison thresholds (frame-to-frame behavior estimation).
	-- Small thresholds suppress one-pixel/one-count jitter in trend decisions.
	constant TEMP_AREA_DELTA_TH    : natural := 16;
	constant TEMP_MOVE_DELTA_TH    : natural := 1;
	constant TEMP_SPREAD_DELTA_TH  : natural := 1;

	-- Decision-layer thresholds.
	-- These values map extracted frame/temporal features to coarse risk outputs.
	constant FIRE_PRESENT_THRESHOLD : natural := 64;
	constant GROWTH_THRESHOLD       : natural := 32;
	constant MOVEMENT_THRESHOLD     : natural := 2;
	constant PERSISTENCE_FRAMES     : natural := 3;

	-- int Arrays with Constants
	type constIntArray is ARRAY (natural range <>) of integer;
	constant networkStructure : constIntArray (2 downto 0) := (2,7,3);
	constant connnectionRange : constIntArray (3 downto 0) := (12,10,3,0);
	constant weights : constIntArray (43 downto 0) := (-2323,-148,31,-75,101,-126,34,-80,3508,84,-98,68,-112,94,-92,45,-6377,340,13,-176,14324,-223,84,197,-3886,160,-51,-165,2445,-277,95,260,-3630,267,-45,-196,13643,-217,87,189,2524,154,-26,-123);

	--mapping the 2D network to the 1D Array with the weights
	type KOORDINATES is array (0 to 7, 1 to 2) of natural;
	constant positions: KOORDINATES:=( 
				(0,28),
				(4,36),
				(8,44),
				(12,0),
				(16,0),
				(20,0),
				(24,0),
				(28,0));

	-- Ranges for the sum inside a neuron and the multiplication of an input signal with a weight
	constant maxSumRange: integer:=131071;
	constant minSumRange: integer:=-131072;
	constant maxMultRange: integer:=131071;
	constant minMultRange: integer:=-131072;

	-- -- Array for all multiplication results inside a neuron
	type multResults is ARRAY (natural range <>) of integer range minMultRange to maxMultRange;
end CONFIG;
