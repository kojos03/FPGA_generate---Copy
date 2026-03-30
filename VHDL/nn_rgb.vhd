-- nn_rgb_generate.vhd

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.CONFIG.ALL;


entity nn_rgb is
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
  port (clk                : in  std_logic;                      -- input clock 74.25 MHz, video 720p
        reset_n            : in  std_logic;                      -- reset (invoked during configuration)
        enable_in          : in  std_logic_vector(2 downto 0);   -- three slide switches
        -- video in
        vs_in              : in  std_logic;                      -- vertical sync
        hs_in              : in  std_logic;                      -- horizontal sync
        de_in              : in  std_logic;                      -- data enable is '1' for valid pixel
        r_in               : in  std_logic_vector(7 downto 0);   -- red component of pixel
        g_in               : in  std_logic_vector(7 downto 0);   -- green component of pixel
        b_in               : in  std_logic_vector(7 downto 0);   -- blue component of pixel
        -- video out
        vs_out             : out std_logic;                      -- corresponding to video-in
        hs_out             : out std_logic;
        de_out             : out std_logic;
        r_out              : out std_logic_vector(7 downto 0);
        g_out              : out std_logic_vector(7 downto 0);
        b_out              : out std_logic_vector(7 downto 0);
        -- frame-level wildfire metadata
        fire_pixel         : out std_logic;
        frame_stats_valid  : out std_logic;
        frame_fire_detected: out std_logic;
        frame_fire_count   : out std_logic_vector(FIRE_COUNT_BITS-1 downto 0);
        frame_bbox_valid   : out std_logic;
        frame_min_x        : out std_logic_vector(FRAME_X_BITS-1 downto 0);
        frame_max_x        : out std_logic_vector(FRAME_X_BITS-1 downto 0);
        frame_min_y        : out std_logic_vector(FRAME_Y_BITS-1 downto 0);
        frame_max_y        : out std_logic_vector(FRAME_Y_BITS-1 downto 0);
        -- step-3 frame statistics
        frame_done         : out std_logic;
        fire_count         : out std_logic_vector(FIRE_COUNT_BITS-1 downto 0);
        secondary_count    : out std_logic_vector(FIRE_COUNT_BITS-1 downto 0);
        sum_x_fire         : out std_logic_vector(FIRE_SUM_X_BITS-1 downto 0);
        sum_y_fire         : out std_logic_vector(FIRE_SUM_Y_BITS-1 downto 0);
        xmin_out           : out std_logic_vector(FRAME_X_BITS-1 downto 0);
        xmax_out           : out std_logic_vector(FRAME_X_BITS-1 downto 0);
        ymin_out           : out std_logic_vector(FRAME_Y_BITS-1 downto 0);
        ymax_out           : out std_logic_vector(FRAME_Y_BITS-1 downto 0);
        bbox_valid_out     : out std_logic;
        -- frame centroid from frame statistics
        centroid_x           : out std_logic_vector(FRAME_X_BITS-1 downto 0);
        centroid_y           : out std_logic_vector(FRAME_Y_BITS-1 downto 0);
        centroid_valid       : out std_logic;
        -- temporal wildfire behavior indicators
        temporal_stats_valid : out std_logic;
        temporal_valid       : out std_logic;
        fire_growing         : out std_logic;
        fire_shrinking       : out std_logic;
        fire_count_delta     : out std_logic_vector(FIRE_COUNT_BITS downto 0);
        delta_x              : out std_logic_vector(FRAME_X_BITS downto 0);
        delta_y              : out std_logic_vector(FRAME_Y_BITS downto 0);
        move_left            : out std_logic;
        move_right           : out std_logic;
        move_up              : out std_logic;
        move_down            : out std_logic;
        move_dir_code        : out std_logic_vector(3 downto 0);
        bbox_width_growing   : out std_logic;
        bbox_height_growing  : out std_logic;
        spread_detected      : out std_logic;
        -- decision-layer outputs
        fire_present         : out std_logic;
        persistent_fire      : out std_logic;
        growth_alert         : out std_logic;
        movement_alert       : out std_logic;
        risk_level           : out std_logic_vector(1 downto 0);
        decision_valid       : out std_logic;
        --
        clk_o              : out std_logic;
        led                : out std_logic_vector(2 downto 0));
end nn_rgb;

architecture behave of nn_rgb is

  -- input FFs
  signal reset          : std_logic := '1';
  signal enable         : std_logic_vector(2 downto 0) := (others => '0');
  signal vs_0, hs_0, de_0 : std_logic := '0';

  -- delayed control (aligned to NN pipeline)
  signal vs_1, hs_1, de_1 : std_logic := '0';

  -- output color decision pipeline
  signal result_r, result_g, result_b : std_logic_vector(7 downto 0) := (others => '0');
  signal fire_pix_class               : std_logic := '0';
  signal secondary_pix_class          : std_logic := '0';
  signal bg_pix_class                 : std_logic := '0';

  -- registered outgoing stream (kept internal for clean module boundaries)
  signal vs_2, hs_2, de_2 : std_logic := '0';
  signal r_2, g_2, b_2    : std_logic_vector(7 downto 0) := (others => '0');
  signal fire_pix_2         : std_logic := '0';
  signal secondary_pix_2    : std_logic := '0';
  signal bg_pix_2           : std_logic := '0';

  -- output-aligned pixel coordinates (aligned with class flags and output video)
  signal vs_2_prev          : std_logic := '0';
  signal de_2_prev          : std_logic := '0';
  signal x_pos_s            : unsigned(FRAME_X_BITS-1 downto 0) := (others => '0');
  signal y_pos_s            : unsigned(FRAME_Y_BITS-1 downto 0) := (others => '0');
  signal line_seen_s        : std_logic := '0';

  constant X_POS_ALL_ONES   : unsigned(FRAME_X_BITS-1 downto 0) := (others => '1');
  constant Y_POS_ALL_ONES   : unsigned(FRAME_Y_BITS-1 downto 0) := (others => '1');
  constant OVERLAY_CROSS_HALF_X_C : unsigned(FRAME_X_BITS-1 downto 0) := to_unsigned(2, FRAME_X_BITS);
  constant OVERLAY_CROSS_HALF_Y_C : unsigned(FRAME_Y_BITS-1 downto 0) := to_unsigned(2, FRAME_Y_BITS);
  constant STATUS_BOX_W_C         : unsigned(FRAME_X_BITS-1 downto 0) := to_unsigned(16, FRAME_X_BITS);
  constant STATUS_BOX_H_C         : unsigned(FRAME_Y_BITS-1 downto 0) := to_unsigned(16, FRAME_Y_BITS);
  constant OVERLAY_BBOX_R_C       : std_logic_vector(7 downto 0) := x"00";
  constant OVERLAY_BBOX_G_C       : std_logic_vector(7 downto 0) := x"FF";
  constant OVERLAY_BBOX_B_C       : std_logic_vector(7 downto 0) := x"00";
  constant OVERLAY_CENTROID_R_C   : std_logic_vector(7 downto 0) := x"FF";
  constant OVERLAY_CENTROID_G_C   : std_logic_vector(7 downto 0) := x"00";
  constant OVERLAY_CENTROID_B_C   : std_logic_vector(7 downto 0) := x"FF";
  constant OVERLAY_RISK_NONE_R_C  : std_logic_vector(7 downto 0) := x"30";
  constant OVERLAY_RISK_NONE_G_C  : std_logic_vector(7 downto 0) := x"30";
  constant OVERLAY_RISK_NONE_B_C  : std_logic_vector(7 downto 0) := x"30";
  constant OVERLAY_RISK_LOW_R_C   : std_logic_vector(7 downto 0) := x"FF";
  constant OVERLAY_RISK_LOW_G_C   : std_logic_vector(7 downto 0) := x"FF";
  constant OVERLAY_RISK_LOW_B_C   : std_logic_vector(7 downto 0) := x"00";
  constant OVERLAY_RISK_MED_R_C   : std_logic_vector(7 downto 0) := x"FF";
  constant OVERLAY_RISK_MED_G_C   : std_logic_vector(7 downto 0) := x"A0";
  constant OVERLAY_RISK_MED_B_C   : std_logic_vector(7 downto 0) := x"00";
  constant OVERLAY_RISK_HIGH_R_C  : std_logic_vector(7 downto 0) := x"FF";
  constant OVERLAY_RISK_HIGH_G_C  : std_logic_vector(7 downto 0) := x"00";
  constant OVERLAY_RISK_HIGH_B_C  : std_logic_vector(7 downto 0) := x"00";

  -- frame-level metadata signals from aggregator
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
  signal frame_centroid_x_s    : std_logic_vector(FRAME_X_BITS-1 downto 0);
  signal frame_centroid_y_s    : std_logic_vector(FRAME_Y_BITS-1 downto 0);
  signal centroid_valid_s      : std_logic;
  signal xmin_out_s            : std_logic_vector(FRAME_X_BITS-1 downto 0);
  signal xmax_out_s            : std_logic_vector(FRAME_X_BITS-1 downto 0);
  signal ymin_out_s            : std_logic_vector(FRAME_Y_BITS-1 downto 0);
  signal ymax_out_s            : std_logic_vector(FRAME_Y_BITS-1 downto 0);
  signal bbox_valid_out_s      : std_logic;

  -- temporal metadata signals
  signal temporal_stats_valid_s : std_logic;
  signal temporal_valid_s       : std_logic;
  signal fire_growing_s         : std_logic;
  signal fire_shrinking_s       : std_logic;
  signal fire_count_delta_s     : std_logic_vector(FIRE_COUNT_BITS downto 0);
  signal temporal_centroid_x_s  : std_logic_vector(FRAME_X_BITS-1 downto 0);
  signal temporal_centroid_y_s  : std_logic_vector(FRAME_Y_BITS-1 downto 0);
  signal delta_x_s              : std_logic_vector(FRAME_X_BITS downto 0);
  signal delta_y_s              : std_logic_vector(FRAME_Y_BITS downto 0);
  signal move_left_s            : std_logic;
  signal move_right_s           : std_logic;
  signal move_up_s              : std_logic;
  signal move_down_s            : std_logic;
  signal move_dir_code_s        : std_logic_vector(3 downto 0);
  signal bbox_width_growing_s   : std_logic;
  signal bbox_height_growing_s  : std_logic;
  signal spread_detected_s      : std_logic;

  -- decision-layer metadata signals
  signal fire_present_s         : std_logic;
  signal persistent_fire_s      : std_logic;
  signal growth_alert_s         : std_logic;
  signal movement_alert_s       : std_logic;
  signal risk_level_s           : std_logic_vector(1 downto 0);
  signal decision_valid_s       : std_logic;

  type   y_array is array (0 to 10) of std_logic_vector(7 downto 0);
  signal y : y_array;

  -- moved from CONFIG package for Vivado synthesis compatibility
  signal connection : INPUT (11 downto 0);
begin


--generate the neural network with the parameters from config.vhd
--the outer loops creates the layers and the inner loop the neurons within the layer
--input Layer is assgined later
gen : FOR i IN 1 TO networkStructure'length - 1 GENERATE --layers
    gen2: FOR j IN 0 TO networkStructure(i) - 1 GENERATE --neurons within the Layers
     begin
        knot: entity work.neuron
             generic map ( weightsIn => weights(positions(j+1,i)-1 downto positions(j,i)))
             port map (  clk      => clk,
                         inputsIn => (connection(connnectionRange(i)-1 downto connnectionRange(i-1))),
                         output   => connection(connnectionRange(i)+j));
    END GENERATE;
END GENERATE;

--delay the control signals for the time of the processing
control: entity work.control
    generic map (delay => 9)
    port map (  clk      => clk,
                reset    => reset,
                vs_in    => vs_0,
                hs_in    => hs_0,
                de_in    => de_0,
                vs_out   => vs_1,
                hs_out   => hs_1,
                de_out   => de_1);

process
begin
   wait until rising_edge(clk);

   -- input FFs for control
   reset <= not reset_n;
   enable <= enable_in;
    -- input FFs for video signal
   vs_0  <= vs_in;
   hs_0  <= hs_in;
   de_0  <= de_in;

   --assign values of the input layer
   connection(0) <= to_integer(unsigned(r_in));
   connection(1) <= to_integer(unsigned(g_in));
   connection(2) <= to_integer(unsigned(b_in));

   -- convert RGB to luminance: Y (5*R + 9*G + 2*B)
   y(0) <= std_logic_vector(to_unsigned(
          (5*connection(0) + 9*connection(1) + 2*connection(2))/16,8));
   for i in 1 to 10 loop
      y(i) <= y(i-1);
   end loop;
   

end process;

process
  variable overlay_r_v       : std_logic_vector(7 downto 0);
  variable overlay_g_v       : std_logic_vector(7 downto 0);
  variable overlay_b_v       : std_logic_vector(7 downto 0);
  variable x_now_v           : unsigned(FRAME_X_BITS-1 downto 0);
  variable y_now_v           : unsigned(FRAME_Y_BITS-1 downto 0);
  variable xmin_v            : unsigned(FRAME_X_BITS-1 downto 0);
  variable xmax_v            : unsigned(FRAME_X_BITS-1 downto 0);
  variable ymin_v            : unsigned(FRAME_Y_BITS-1 downto 0);
  variable ymax_v            : unsigned(FRAME_Y_BITS-1 downto 0);
  variable centroid_x_v      : unsigned(FRAME_X_BITS-1 downto 0);
  variable centroid_y_v      : unsigned(FRAME_Y_BITS-1 downto 0);
  variable centroid_x_min_v  : unsigned(FRAME_X_BITS-1 downto 0);
  variable centroid_x_max_v  : unsigned(FRAME_X_BITS-1 downto 0);
  variable centroid_y_min_v  : unsigned(FRAME_Y_BITS-1 downto 0);
  variable centroid_y_max_v  : unsigned(FRAME_Y_BITS-1 downto 0);
  variable bbox_hit_v        : boolean;
  variable centroid_hit_v    : boolean;
  variable status_hit_v      : boolean;
begin

  wait until rising_edge(clk);
-- output processing
-- assign the pixel a value depending on the output of the neural network

      if(connection(11) > 127) then
      
            if(connection(11) > connection(10)) then
                -- yellow
                result_r <= '1' & y(8)(7 downto 1);
                result_g <= '1' & y(8)(7 downto 1);
                result_b <= '0' & y(8)(7 downto 1);
                fire_pix_class <= '1';
                secondary_pix_class <= '0';
                bg_pix_class <= '0';
            else
                -- blue
                result_r <= '0' & y(8)(7 downto 1);
                result_g <= '0' & y(8)(7 downto 1);
                result_b <= '1' & y(8)(7 downto 1);
                fire_pix_class <= '0';
                secondary_pix_class <= '1';
                bg_pix_class <= '0';
            end if;
      elsif (connection(10)>127) then
            -- blue
            result_r <= '0' & y(8)(7 downto 1);
            result_g <= '0' & y(8)(7 downto 1);
            result_b <= '1' & y(8)(7 downto 1);
            fire_pix_class <= '0';
            secondary_pix_class <= '1';
            bg_pix_class <= '0';

      else
            -- gray
            result_r <= y(8);
            result_g <= y(8);
            result_b <= y(8);
            fire_pix_class <= '0';
            secondary_pix_class <= '0';
            bg_pix_class <= '1';
      end if;

    -- overlay in output-aligned coordinate space
    overlay_r_v := result_r;
    overlay_g_v := result_g;
    overlay_b_v := result_b;
    x_now_v := x_pos_s;
    y_now_v := y_pos_s;
    bbox_hit_v := false;
    centroid_hit_v := false;
    status_hit_v := false;

    if de_1 = '1' then
      status_hit_v := (x_now_v < STATUS_BOX_W_C) and (y_now_v < STATUS_BOX_H_C);

      if centroid_valid_s = '1' then
        centroid_x_v := unsigned(frame_centroid_x_s);
        centroid_y_v := unsigned(frame_centroid_y_s);

        if centroid_x_v > OVERLAY_CROSS_HALF_X_C then
          centroid_x_min_v := centroid_x_v - OVERLAY_CROSS_HALF_X_C;
        else
          centroid_x_min_v := (others => '0');
        end if;

        if centroid_x_v < (X_POS_ALL_ONES - OVERLAY_CROSS_HALF_X_C) then
          centroid_x_max_v := centroid_x_v + OVERLAY_CROSS_HALF_X_C;
        else
          centroid_x_max_v := X_POS_ALL_ONES;
        end if;

        if centroid_y_v > OVERLAY_CROSS_HALF_Y_C then
          centroid_y_min_v := centroid_y_v - OVERLAY_CROSS_HALF_Y_C;
        else
          centroid_y_min_v := (others => '0');
        end if;

        if centroid_y_v < (Y_POS_ALL_ONES - OVERLAY_CROSS_HALF_Y_C) then
          centroid_y_max_v := centroid_y_v + OVERLAY_CROSS_HALF_Y_C;
        else
          centroid_y_max_v := Y_POS_ALL_ONES;
        end if;

        if ((x_now_v = centroid_x_v) and (y_now_v >= centroid_y_min_v) and (y_now_v <= centroid_y_max_v)) or
           ((y_now_v = centroid_y_v) and (x_now_v >= centroid_x_min_v) and (x_now_v <= centroid_x_max_v)) then
          centroid_hit_v := true;
        end if;
      end if;

      if bbox_valid_out_s = '1' then
        xmin_v := unsigned(xmin_out_s);
        xmax_v := unsigned(xmax_out_s);
        ymin_v := unsigned(ymin_out_s);
        ymax_v := unsigned(ymax_out_s);

        if (((x_now_v = xmin_v) or (x_now_v = xmax_v)) and (y_now_v >= ymin_v) and (y_now_v <= ymax_v)) or
           (((y_now_v = ymin_v) or (y_now_v = ymax_v)) and (x_now_v >= xmin_v) and (x_now_v <= xmax_v)) then
          bbox_hit_v := true;
        end if;
      end if;

      if centroid_hit_v then
        overlay_r_v := OVERLAY_CENTROID_R_C;
        overlay_g_v := OVERLAY_CENTROID_G_C;
        overlay_b_v := OVERLAY_CENTROID_B_C;
      elsif bbox_hit_v then
        overlay_r_v := OVERLAY_BBOX_R_C;
        overlay_g_v := OVERLAY_BBOX_G_C;
        overlay_b_v := OVERLAY_BBOX_B_C;
      elsif status_hit_v then
        case risk_level_s is
          when "01" =>
            overlay_r_v := OVERLAY_RISK_LOW_R_C;
            overlay_g_v := OVERLAY_RISK_LOW_G_C;
            overlay_b_v := OVERLAY_RISK_LOW_B_C;
          when "10" =>
            overlay_r_v := OVERLAY_RISK_MED_R_C;
            overlay_g_v := OVERLAY_RISK_MED_G_C;
            overlay_b_v := OVERLAY_RISK_MED_B_C;
          when "11" =>
            overlay_r_v := OVERLAY_RISK_HIGH_R_C;
            overlay_g_v := OVERLAY_RISK_HIGH_G_C;
            overlay_b_v := OVERLAY_RISK_HIGH_B_C;
          when others =>
            overlay_r_v := OVERLAY_RISK_NONE_R_C;
            overlay_g_v := OVERLAY_RISK_NONE_G_C;
            overlay_b_v := OVERLAY_RISK_NONE_B_C;
        end case;
      end if;
    end if;

    -- output FFs 
    vs_2       <= vs_1;
    hs_2       <= hs_1;
    de_2       <= de_1;
    r_2        <= overlay_r_v;
    g_2        <= overlay_g_v;
    b_2        <= overlay_b_v;
    fire_pix_2 <= fire_pix_class;
    secondary_pix_2 <= secondary_pix_class;
    bg_pix_2 <= bg_pix_class;

end process;

-- Output-aligned pixel coordinates for classified stream.
process
begin
  wait until rising_edge(clk);

  if reset = '1' then
    vs_2_prev <= '0';
    de_2_prev <= '0';
    x_pos_s <= (others => '0');
    y_pos_s <= (others => '0');
    line_seen_s <= '0';
  else
    -- frame start reset
    if (vs_2_prev = '0') and (vs_2 = '1') then
      x_pos_s <= (others => '0');
      y_pos_s <= (others => '0');
      line_seen_s <= '0';
    end if;

    -- line/pixel progress inside active area
    if (de_2_prev = '0') and (de_2 = '1') then
      x_pos_s <= (others => '0');
      if line_seen_s = '0' then
        y_pos_s <= (others => '0');
        line_seen_s <= '1';
      elsif y_pos_s /= Y_POS_ALL_ONES then
        y_pos_s <= y_pos_s + 1;
      end if;
    elsif de_2 = '1' then
      if x_pos_s /= X_POS_ALL_ONES then
        x_pos_s <= x_pos_s + 1;
      end if;
    end if;

    vs_2_prev <= vs_2;
    de_2_prev <= de_2;
  end if;
end process;

-- Step-3 frame statistics from aligned class stream and coordinates.
frame_stats_u : entity work.frame_stats
  generic map (
    X_BITS     => FRAME_X_BITS,
    Y_BITS     => FRAME_Y_BITS,
    COUNT_BITS => FIRE_COUNT_BITS,
    SUM_X_BITS => FIRE_SUM_X_BITS,
    SUM_Y_BITS => FIRE_SUM_Y_BITS
  )
  port map (
    clk           => clk,
    reset         => reset,
    vs_in         => vs_2,
    de_in         => de_2,
    fire_pix      => fire_pix_2,
    secondary_pix => secondary_pix_2,
    x_pos         => std_logic_vector(x_pos_s),
    y_pos         => std_logic_vector(y_pos_s),
    frame_done      => frame_done_s,
    fire_count      => fire_count_s,
    secondary_count => secondary_count_s,
    sum_x_fire      => sum_x_fire_s,
    sum_y_fire      => sum_y_fire_s,
    xmin_out        => xmin_out_s,
    xmax_out        => xmax_out_s,
    ymin_out        => ymin_out_s,
    ymax_out        => ymax_out_s,
    bbox_valid_out  => bbox_valid_out_s,
    centroid_x      => frame_centroid_x_s,
    centroid_y      => frame_centroid_y_s,
    centroid_valid  => centroid_valid_s
  );

-- Frame-level wildfire statistics from pixel-level fire decisions.
frame_agg : entity work.fire_frame_aggregator
  generic map (
    X_BITS                 => FRAME_X_BITS,
    Y_BITS                 => FRAME_Y_BITS,
    COUNT_BITS             => FIRE_COUNT_BITS,
    FIRE_COUNT_THRESHOLD_G => FIRE_COUNT_THRESHOLD_G
  )
  port map (
    clk                 => clk,
    reset               => reset,
    vs_in               => vs_2,
    hs_in               => hs_2,
    de_in               => de_2,
    fire_pixel_in       => fire_pix_2,
    frame_stats_valid   => frame_stats_valid_s,
    frame_fire_detected => frame_fire_detected_s,
    frame_fire_count    => frame_fire_count_s,
    frame_bbox_valid    => frame_bbox_valid_s,
    frame_min_x         => frame_min_x_s,
    frame_max_x         => frame_max_x_s,
    frame_min_y         => frame_min_y_s,
    frame_max_y         => frame_max_y_s
  );

-- Temporal behavior estimation from consecutive frame metadata.
frame_temporal : entity work.temporal_tracker
  generic map (
    X_BITS            => FRAME_X_BITS,
    Y_BITS            => FRAME_Y_BITS,
    COUNT_BITS        => FIRE_COUNT_BITS
  )
  port map (
    clk                => clk,
    reset              => reset,
    frame_done         => frame_done_s,
    frame_bbox_valid   => bbox_valid_out_s,
    frame_fire_count   => fire_count_s,
    frame_min_x        => xmin_out_s,
    frame_max_x        => xmax_out_s,
    frame_min_y        => ymin_out_s,
    frame_max_y        => ymax_out_s,
    centroid_x_in      => frame_centroid_x_s,
    centroid_y_in      => frame_centroid_y_s,
    centroid_valid_in  => centroid_valid_s,
    temporal_stats_valid => temporal_stats_valid_s,
    temporal_valid       => temporal_valid_s,
    fire_growing         => fire_growing_s,
    fire_shrinking       => fire_shrinking_s,
    fire_count_delta     => fire_count_delta_s,
    centroid_x           => temporal_centroid_x_s,
    centroid_y           => temporal_centroid_y_s,
    delta_x              => delta_x_s,
    delta_y              => delta_y_s,
    move_left            => move_left_s,
    move_right           => move_right_s,
    move_up              => move_up_s,
    move_down            => move_down_s,
    move_dir_code        => move_dir_code_s,
    bbox_width_growing   => bbox_width_growing_s,
    bbox_height_growing  => bbox_height_growing_s,
    spread_detected      => spread_detected_s
  );

-- Lightweight decision support from frame/temporal wildfire indicators.
frame_decision : entity work.decision_layer
  generic map (
    X_BITS                   => FRAME_X_BITS,
    Y_BITS                   => FRAME_Y_BITS,
    COUNT_BITS               => FIRE_COUNT_BITS,
    FIRE_PRESENT_THRESHOLD_G => DEC_FIRE_PRESENT_THRESHOLD_G,
    GROWTH_THRESHOLD_G       => DEC_GROWTH_THRESHOLD_G,
    MOVEMENT_THRESHOLD_G     => DEC_MOVEMENT_THRESHOLD_G,
    PERSISTENCE_FRAMES_G     => DEC_PERSISTENCE_FRAMES_G
  )
  port map (
    clk               => clk,
    reset             => reset,
    frame_done        => frame_done_s,
    fire_count        => fire_count_s,
    centroid_valid    => centroid_valid_s,
    centroid_x        => frame_centroid_x_s,
    centroid_y        => frame_centroid_y_s,
    dx                => delta_x_s,
    dy                => delta_y_s,
    dA                => fire_count_delta_s,
    temporal_valid    => temporal_valid_s,
    fire_present      => fire_present_s,
    persistent_fire   => persistent_fire_s,
    growth_alert      => growth_alert_s,
    movement_alert    => movement_alert_s,
    risk_level        => risk_level_s,
    decision_valid    => decision_valid_s
  );

-- output ports
vs_out              <= vs_2;
hs_out              <= hs_2;
de_out              <= de_2;
r_out               <= r_2;
g_out               <= g_2;
b_out               <= b_2;
fire_pixel          <= fire_pix_2;
frame_stats_valid   <= frame_stats_valid_s;
frame_fire_detected <= frame_fire_detected_s;
frame_fire_count    <= frame_fire_count_s;
frame_bbox_valid    <= frame_bbox_valid_s;
frame_min_x         <= frame_min_x_s;
frame_max_x         <= frame_max_x_s;
frame_min_y         <= frame_min_y_s;
frame_max_y         <= frame_max_y_s;
frame_done          <= frame_done_s;
fire_count          <= fire_count_s;
secondary_count     <= secondary_count_s;
sum_x_fire          <= sum_x_fire_s;
sum_y_fire          <= sum_y_fire_s;
xmin_out            <= xmin_out_s;
xmax_out            <= xmax_out_s;
ymin_out            <= ymin_out_s;
ymax_out            <= ymax_out_s;
bbox_valid_out      <= bbox_valid_out_s;
centroid_x          <= frame_centroid_x_s;
centroid_y          <= frame_centroid_y_s;
centroid_valid      <= centroid_valid_s;
temporal_stats_valid <= temporal_stats_valid_s;
temporal_valid       <= temporal_valid_s;
fire_growing         <= fire_growing_s;
fire_shrinking       <= fire_shrinking_s;
fire_count_delta     <= fire_count_delta_s;
delta_x              <= delta_x_s;
delta_y              <= delta_y_s;
move_left            <= move_left_s;
move_right           <= move_right_s;
move_up              <= move_up_s;
move_down            <= move_down_s;
move_dir_code        <= move_dir_code_s;
bbox_width_growing   <= bbox_width_growing_s;
bbox_height_growing  <= bbox_height_growing_s;
spread_detected      <= spread_detected_s;
fire_present         <= fire_present_s;
persistent_fire      <= persistent_fire_s;
growth_alert         <= growth_alert_s;
movement_alert       <= movement_alert_s;
risk_level           <= risk_level_s;
decision_valid       <= decision_valid_s;

clk_o <= clk;
led   <= "000";

end behave;
