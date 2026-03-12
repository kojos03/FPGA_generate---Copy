library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.CONFIG.ALL;

-- Lightweight frame-level decision logic from tracked wildfire features.
-- Converts frame statistics and temporal deltas into interpretable
-- decision-support outputs suitable for hardware integration.
entity decision_layer is
  generic (
    X_BITS                 : natural := FRAME_X_BITS;
    Y_BITS                 : natural := FRAME_Y_BITS;
    COUNT_BITS             : natural := FIRE_COUNT_BITS;
    FIRE_PRESENT_THRESHOLD_G : natural := FIRE_PRESENT_THRESHOLD;
    GROWTH_THRESHOLD_G     : natural := GROWTH_THRESHOLD;
    MOVEMENT_THRESHOLD_G   : natural := MOVEMENT_THRESHOLD;
    PERSISTENCE_FRAMES_G   : natural := PERSISTENCE_FRAMES
  );
  port (
    clk               : in  std_logic;
    reset             : in  std_logic;

    -- Frame-complete timing and feature inputs.
    frame_done        : in  std_logic;
    fire_count        : in  std_logic_vector(COUNT_BITS-1 downto 0);
    centroid_valid    : in  std_logic;
    centroid_x        : in  std_logic_vector(X_BITS-1 downto 0);
    centroid_y        : in  std_logic_vector(Y_BITS-1 downto 0);
    dx                : in  std_logic_vector(X_BITS downto 0);
    dy                : in  std_logic_vector(Y_BITS downto 0);
    dA                : in  std_logic_vector(COUNT_BITS downto 0);
    temporal_valid    : in  std_logic;

    -- Decision outputs.
    fire_present      : out std_logic;
    persistent_fire   : out std_logic;
    growth_alert      : out std_logic;
    movement_alert    : out std_logic;
    risk_level        : out std_logic_vector(1 downto 0);
    decision_valid    : out std_logic
  );
end entity;

architecture rtl of decision_layer is
  signal frame_done_d      : std_logic := '0';

  signal fire_count_u      : unsigned(COUNT_BITS-1 downto 0);
  signal dA_s              : signed(COUNT_BITS downto 0);
  signal dx_s              : signed(X_BITS downto 0);
  signal dy_s              : signed(Y_BITS downto 0);

  signal fire_present_s    : std_logic;
  signal growth_cond_s     : std_logic;
  signal movement_cond_s   : std_logic;

  signal persistence_count_r : integer range 0 to PERSISTENCE_FRAMES_G := 0;

  signal fire_present_r    : std_logic := '0';
  signal persistent_fire_r : std_logic := '0';
  signal growth_alert_r    : std_logic := '0';
  signal movement_alert_r  : std_logic := '0';
  signal risk_level_r      : std_logic_vector(1 downto 0) := (others => '0');
  signal decision_valid_r  : std_logic := '0';

  constant FIRE_PRESENT_TH_U : unsigned(COUNT_BITS-1 downto 0) := to_unsigned(FIRE_PRESENT_THRESHOLD_G, COUNT_BITS);
  constant GROWTH_TH_S       : signed(COUNT_BITS downto 0) := to_signed(GROWTH_THRESHOLD_G, COUNT_BITS+1);
  constant MOVE_TH_X_S       : signed(X_BITS downto 0) := to_signed(MOVEMENT_THRESHOLD_G, X_BITS+1);
  constant MOVE_TH_Y_S       : signed(Y_BITS downto 0) := to_signed(MOVEMENT_THRESHOLD_G, Y_BITS+1);

  constant RISK_NONE         : std_logic_vector(1 downto 0) := "00";
  constant RISK_LOW          : std_logic_vector(1 downto 0) := "01";
  constant RISK_MED          : std_logic_vector(1 downto 0) := "10";
  constant RISK_HIGH         : std_logic_vector(1 downto 0) := "11";
begin
  fire_count_u <= unsigned(fire_count);
  dA_s <= signed(dA);
  dx_s <= signed(dx);
  dy_s <= signed(dy);

  -- meaningful fire in current frame
  fire_present_s <= '1' when (fire_count_u > FIRE_PRESENT_TH_U) and (centroid_valid = '1') else '0';

  -- temporal growth indication from signed area delta
  growth_cond_s <= '1' when (temporal_valid = '1') and (dA_s > GROWTH_TH_S) else '0';

  -- movement indication from signed dx/dy without abs() arithmetic
  movement_cond_s <= '1' when
      (temporal_valid = '1') and (
        (dx_s > MOVE_TH_X_S) or (dx_s < -MOVE_TH_X_S) or
        (dy_s > MOVE_TH_Y_S) or (dy_s < -MOVE_TH_Y_S)
      ) else '0';

  process
  begin
    wait until rising_edge(clk);

    if reset = '1' then
      frame_done_d <= '0';
      persistence_count_r <= 0;
      fire_present_r <= '0';
      persistent_fire_r <= '0';
      growth_alert_r <= '0';
      movement_alert_r <= '0';
      risk_level_r <= RISK_NONE;
      decision_valid_r <= '0';
    else
      frame_done_d <= frame_done;
      decision_valid_r <= '0';

      -- one-cycle delayed frame_done aligns with temporal outputs from tracker
      if frame_done_d = '1' then
        decision_valid_r <= '1';
        fire_present_r <= fire_present_s;
        growth_alert_r <= growth_cond_s;
        movement_alert_r <= movement_cond_s;

        if fire_present_s = '1' then
          if persistence_count_r < PERSISTENCE_FRAMES_G then
            persistence_count_r <= persistence_count_r + 1;
          end if;

          if (persistence_count_r + 1) >= PERSISTENCE_FRAMES_G then
            persistent_fire_r <= '1';
          else
            persistent_fire_r <= '0';
          end if;
        else
          persistence_count_r <= 0;
          persistent_fire_r <= '0';
        end if;

        -- risk encoding:
        -- 00 no risk, 01 low, 10 medium, 11 high
        if fire_present_s = '0' then
          risk_level_r <= RISK_NONE;
        else
          if ((persistence_count_r + 1) >= PERSISTENCE_FRAMES_G) and
             ((growth_cond_s = '1') or (movement_cond_s = '1')) then
            risk_level_r <= RISK_HIGH;
          elsif ((persistence_count_r + 1) >= PERSISTENCE_FRAMES_G) or
                (growth_cond_s = '1') then
            risk_level_r <= RISK_MED;
          else
            risk_level_r <= RISK_LOW;
          end if;
        end if;
      end if;
    end if;
  end process;

  fire_present <= fire_present_r;
  persistent_fire <= persistent_fire_r;
  growth_alert <= growth_alert_r;
  movement_alert <= movement_alert_r;
  risk_level <= risk_level_r;
  decision_valid <= decision_valid_r;
end architecture;
