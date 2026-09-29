----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Wrapper for the MiSTer core that runs exclusively in the core's clock domanin
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_modes_pkg.all;
use work.globals.all;
library work;
use work.video_modes_pkg.all;
library xpm;
use xpm.vcomponents.all;

entity main is
   generic (
      G_VDNUM                 : natural                     -- amount of virtual drives
   );
   port (
      clk_main_i              : in  std_logic;
      clk_24_i                : in std_logic;
      reset_soft_i            : in  std_logic;
      reset_hard_i            : in  std_logic;
      pause_i                 : in  std_logic;

      -- MiSTer core main clock speed:
      -- Make sure you pass very exact numbers here, because they are used for avoiding clock drift at derived clocks
      clk_main_speed_i        : in  natural;

      -- Video output
      video_ce_o              : out std_logic;
      video_ce_ovl_o          : out std_logic;
      video_red_o             : out std_logic_vector(3 downto 0);
      video_green_o           : out std_logic_vector(3 downto 0);
      video_blue_o            : out std_logic_vector(3 downto 0);
      video_vs_o              : out std_logic;
      video_hs_o              : out std_logic;
      video_hblank_o          : out std_logic;
      video_vblank_o          : out std_logic;

      -- Audio output (Signed PCM)
      audio_left_o            : out signed(15 downto 0);
      audio_right_o           : out signed(15 downto 0);

      -- M2M Keyboard interface
      kb_key_num_i            : in  integer range 0 to 79;    -- cycles through all MEGA65 keys
      kb_key_pressed_n_i      : in  std_logic;                -- low active: debounced feedback: is kb_key_num_i pressed right now?

      -- MEGA65 joysticks and paddles/mouse/potentiometers
      joy_1_up_n_i            : in  std_logic;
      joy_1_down_n_i          : in  std_logic;
      joy_1_left_n_i          : in  std_logic;
      joy_1_right_n_i         : in  std_logic;
      joy_1_fire_n_i          : in  std_logic;

      joy_2_up_n_i            : in  std_logic;
      joy_2_down_n_i          : in  std_logic;
      joy_2_left_n_i          : in  std_logic;
      joy_2_right_n_i         : in  std_logic;
      joy_2_fire_n_i          : in  std_logic;

      pot1_x_i                : in  std_logic_vector(7 downto 0);
      pot1_y_i                : in  std_logic_vector(7 downto 0);
      pot2_x_i                : in  std_logic_vector(7 downto 0);
      pot2_y_i                : in  std_logic_vector(7 downto 0);

      -- ROM download bus from QNICE
      dn_clk_i                : in  std_logic;
      dn_addr_i               : in  std_logic_vector(24 downto 0);
      dn_data_i               : in  std_logic_vector(7 downto 0);
      dn_wr_i                 : in  std_logic;
      
      osm_control_i           : in  std_logic_vector(255 downto 0)
   );
end entity main;

architecture synthesis of main is

-- @TODO: Remove these demo core signals
signal keyboard_n          : std_logic_vector(79 downto 0);

---------------------------------------------------------------------------
-- Black Tiger
---------------------------------------------------------------------------

signal bt_pxl2_cen      : std_logic;
signal bt_debug_view    : std_logic_vector(7 downto 0);

-- Black Tiger ROM interfaces
signal bt_main_addr     : std_logic_vector(18 downto 0);
signal bt_main_cs       : std_logic;
signal bt_main_data     : std_logic_vector(7 downto 0);
signal bt_main_lo_data  : std_logic_vector(7 downto 0);
signal bt_main_hi_data  : std_logic_vector(7 downto 0);

signal bt_snd_addr      : std_logic_vector(14 downto 0);
signal bt_snd_cs        : std_logic;
signal bt_snd_data      : std_logic_vector(7 downto 0);

signal bt_char_addr     : std_logic_vector(14 downto 1);
signal bt_char_data     : std_logic_vector(15 downto 0);
signal bt_scr_addr      : std_logic_vector(17 downto 1);
signal bt_scr_data      : std_logic_vector(15 downto 0);
signal bt_obj_addr      : std_logic_vector(17 downto 1);
signal bt_obj_data      : std_logic_vector(15 downto 0);
signal bt_mcu_addr      : std_logic_vector(11 downto 0);
signal bt_mcu_data      : std_logic_vector(7 downto 0);
signal bt_mcu_cen       : std_logic;
signal dn_mcu_we        : std_logic;


-- Download chip selects. The incoming address is the packed JTFRAME ROM map.
signal dn_main_lo_we    : std_logic;
signal dn_main_hi_we    : std_logic;
signal dn_snd_we        : std_logic;
signal dn_char_lo_we    : std_logic;
signal dn_char_hi_we    : std_logic;
signal dn_scr_lo_we     : std_logic;
signal dn_scr_hi_we     : std_logic;
signal dn_obj_lo_we     : std_logic;
signal dn_obj_hi_we     : std_logic;
signal dn_prom_we       : std_logic;
signal dn_scr_addr      : unsigned(17 downto 0);
signal dn_obj_addr      : unsigned(17 downto 0);
signal bt_prior_addr    : std_logic_vector(7 downto 0);
signal bt_prior_cen     : std_logic;
signal bt_prior_data    : std_logic_vector(3 downto 0);
signal bt_prior_data8   : std_logic_vector(7 downto 0);

signal dn_prior_we    : std_logic;

-- Audio - unused for now
signal bt_fm0           : signed(15 downto 0);
signal bt_fm1           : signed(15 downto 0);
signal bt_psg0          : signed(15 downto 0);
signal bt_psg1          : signed(15 downto 0);


signal bt_audio         : signed(15 downto 0);
signal bt_audio_peak    : std_logic;

-- Dip Switches
signal bt_dipsw_a       : std_logic_vector(7 downto 0);
signal bt_dipsw_b       : std_logic_vector(7 downto 0);
signal bt_dipsw         : std_logic_vector(31 downto 0);

signal bt_joystick1     : std_logic_vector(5 downto 0);
signal bt_joystick2     : std_logic_vector(5 downto 0);
signal shoot2_button1_n : std_logic := '1';
signal shoot2_button2_n : std_logic := '1';
signal pot1_val         : std_logic_vector(7 downto 0);
signal pot2_val         : std_logic_vector(7 downto 0);
signal potxy_sw         : std_logic;
signal pot_pol1_sw      : std_logic;
signal pot_pol2_sw      : std_logic;
signal bt_coin          : std_logic_vector(3 downto 0);
signal bt_cab_1p        : std_logic_vector(3 downto 0);


-- Game player inputs
constant m65_1          : integer := 56; --Player 1 Start
constant m65_2          : integer := 59; --Player 2 Start
constant m65_5          : integer := 16; --Insert coin 1
constant m65_6          : integer := 19; --Insert coin 2

-- Offer some keyboard controls in addition to Joy 1 Controls
constant m65_up_crsr    : integer := 73; --Player up
constant m65_vert_crsr  : integer := 7;  --Player down
constant m65_left_crsr  : integer := 74; --Player left
constant m65_horz_crsr  : integer := 2;  --Player right
constant m65_z          : integer := 12; --Fire 1
constant m65_x          : integer := 23; --Fire 2
constant m65_9          : integer := 32; --Service button
constant m65_p          : integer := 41; --Pause

signal reset_async      : std_logic;
signal reset_48         : std_logic;
signal reset_24         : std_logic;

signal bt_main_addr_d   : std_logic_vector(bt_main_addr'range);
signal bt_snd_addr_d    : std_logic_vector(bt_snd_addr'range);
signal bt_char_addr_d   : std_logic_vector(bt_char_addr'range);
signal bt_scr_addr_d    : std_logic_vector(bt_scr_addr'range);
signal bt_obj_addr_d    : std_logic_vector(bt_obj_addr'range);

signal bt_main_ok       : std_logic;
signal bt_snd_ok        : std_logic;
signal bt_char_ok       : std_logic;
signal bt_scr_ok        : std_logic;
signal bt_obj_ok        : std_logic;



component dualport_2clk_ram
   generic (
      FALLING_A  : boolean := false;
      FALLING_B  : boolean := false;
      ADDR_WIDTH : integer := 8
   );
   port (
      clock_a   : in  std_logic;
      clen_a    : in  std_logic := '1';
      address_a : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      q_a       : out std_logic_vector(7 downto 0);
      clock_b   : in  std_logic;
      clen_b    : in  std_logic := '1';
      address_b : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      data_b    : in  std_logic_vector(7 downto 0);
      wren_b    : in  std_logic
   );
end component;

component jtbtiger_game
   port (
      rst         : in  std_logic;
      clk         : in  std_logic;
      rst24       : in  std_logic;
      clk24       : in  std_logic;

      pxl2_cen    : out std_logic;
      pxl_cen     : out std_logic;

      red         : out std_logic_vector(3 downto 0);
      green       : out std_logic_vector(3 downto 0);
      blue        : out std_logic_vector(3 downto 0);

      LHBL        : out std_logic;
      LVBL        : out std_logic;
      HS          : out std_logic;
      VS          : out std_logic;

      cab_1p      : in  std_logic_vector(3 downto 0);
      coin        : in  std_logic_vector(3 downto 0);
      joystick1   : in  std_logic_vector(5 downto 0);
      joystick2   : in  std_logic_vector(5 downto 0);

      dipsw       : in  std_logic_vector(31 downto 0);
      dip_pause   : in  std_logic;
      service     : in  std_logic;
      dip_flip    : out std_logic;

      gfx_en      : in  std_logic_vector(3 downto 0);

      debug_bus   : in  std_logic_vector(7 downto 0);
      debug_view  : out std_logic_vector(7 downto 0);

      main_addr   : out std_logic_vector(18 downto 0);
      main_cs     : out std_logic;
      main_ok     : in  std_logic;
      main_data   : in  std_logic_vector(7 downto 0);

      snd_addr    : out std_logic_vector(14 downto 0);
      snd_cs      : out std_logic;
      snd_ok      : in  std_logic;
      snd_data    : in  std_logic_vector(7 downto 0);

      char_addr   : out std_logic_vector(14 downto 1);
      char_ok     : in  std_logic;
      char_data   : in  std_logic_vector(15 downto 0);

      scr_addr    : out std_logic_vector(17 downto 1);
      scr_ok      : in  std_logic;
      scr_data    : in  std_logic_vector(15 downto 0);

      obj_addr    : out std_logic_vector(17 downto 1);
      obj_ok      : in  std_logic;
      obj_data    : in  std_logic_vector(15 downto 0);

      ioctl_addr  : in  std_logic_vector(25 downto 0);
      prog_addr   : in  std_logic_vector(24 downto 0);
      prog_data   : in  std_logic_vector(15 downto 0);
      prom_we     : in  std_logic;

      fm0         : out signed(15 downto 0);
      fm1         : out signed(15 downto 0);
      psg0        : out signed(15 downto 0);
      psg1        : out signed(15 downto 0);
      
 
      mcu_rom_addr: out std_logic_vector(11 downto 0);
      mcu_rom_cen : out std_logic;
      mcu_rom_data: out std_logic_vector(7 downto 0);
      
      -- Priority PROM
      prior_rom_addr : out std_logic_vector(7 downto 0);
      prior_rom_cen  : out std_logic;
      prior_rom_data : in  std_logic_vector(3 downto 0)
   
   );
end component;

component jtframe_mixer
   generic (
      W0   : integer := 16;
      W1   : integer := 16;
      W2   : integer := 16;
      W3   : integer := 16;
      WOUT : integer := 16
   );
   port (
      rst   : in  std_logic;
      clk   : in  std_logic;
      cen   : in  std_logic;

      ch0   : in  signed(W0-1 downto 0);
      ch1   : in  signed(W1-1 downto 0);
      ch2   : in  signed(W2-1 downto 0);
      ch3   : in  signed(W3-1 downto 0);

      gain0 : in  std_logic_vector(7 downto 0);
      gain1 : in  std_logic_vector(7 downto 0);
      gain2 : in  std_logic_vector(7 downto 0);
      gain3 : in  std_logic_vector(7 downto 0);

      mixed : out signed(WOUT-1 downto 0);
      peak  : out std_logic
   );
end component;

begin

    ---------------------------------------------------------------------------
    -- Black Tiger 
    ---------------------------------------------------------------------------
    
    -- Packed download map:
    --   $00000-$47FFF main CPU
    --   $48000-$4FFFF sound CPU
    --   $50000-$57FFF chars
    --   $58000-$97FFF tiles
    --   $98000-$D7FFF objects
    --   $D8000-$D8FFF MCU
    --   $D9000-$D93FF PROMs
    --
    -- Port A is the running core. Port B is QNICE and therefore uses FALLING_B,
    -- matching the M2M dual-clock ROM convention.
    
    dn_main_lo_we <= dn_wr_i when unsigned(dn_addr_i) < 16#40000# else '0';
    dn_main_hi_we <= dn_wr_i when unsigned(dn_addr_i) >= 16#40000# and unsigned(dn_addr_i) < 16#48000# else '0';
    dn_snd_we     <= dn_wr_i when unsigned(dn_addr_i) >= 16#48000# and unsigned(dn_addr_i) < 16#50000# else '0';
    
    -- 16-bit graphics ROMs are stored as two byte-wide BRAMs.  The generated
    -- files are already interleaved, so dn_addr_i(0) selects the byte lane.
    dn_char_lo_we <= dn_wr_i when unsigned(dn_addr_i) >= 16#50000# and unsigned(dn_addr_i) < 16#58000# and dn_addr_i(0) = '0' else '0';
    dn_char_hi_we <= dn_wr_i when unsigned(dn_addr_i) >= 16#50000# and unsigned(dn_addr_i) < 16#58000# and dn_addr_i(0) = '1' else '0';
    dn_scr_lo_we  <= dn_wr_i when unsigned(dn_addr_i) >= 16#58000# and unsigned(dn_addr_i) < 16#98000# and dn_addr_i(0) = '0' else '0';
    dn_scr_hi_we  <= dn_wr_i when unsigned(dn_addr_i) >= 16#58000# and unsigned(dn_addr_i) < 16#98000# and dn_addr_i(0) = '1' else '0';
    dn_obj_lo_we  <= dn_wr_i when unsigned(dn_addr_i) >= 16#98000# and unsigned(dn_addr_i) < 16#D8000# and dn_addr_i(0) = '0' else '0';
    dn_obj_hi_we  <= dn_wr_i when unsigned(dn_addr_i) >= 16#98000# and unsigned(dn_addr_i) < 16#D8000# and dn_addr_i(0) = '1' else '0';

    --dn_prom_we    <= dn_wr_i when unsigned(dn_addr_i) >= 16#D8000# and unsigned(dn_addr_i) < 16#D9400# else '0';
    dn_mcu_we <= dn_wr_i when unsigned(dn_addr_i) >= 16#D8000# and unsigned(dn_addr_i) <  16#D9000# else '0';
    dn_prom_we <= dn_wr_i when unsigned(dn_addr_i) >= 16#D9000# and unsigned(dn_addr_i) <  16#D9400# else '0';
    
    -- Black Tiger priority PROM bd01.8j
    -- $D9000-$D90FF
    dn_prior_we <= '1' when
       dn_wr_i = '1' and
       unsigned(dn_addr_i) >= to_unsigned(16#D9000#, dn_addr_i'length) and
       unsigned(dn_addr_i) <  to_unsigned(16#D9100#, dn_addr_i'length)
       else '0';
    
    dn_scr_addr <= resize(unsigned(dn_addr_i) - to_unsigned(16#58000#, dn_addr_i'length),dn_scr_addr'length);
    dn_obj_addr <= resize(unsigned(dn_addr_i) - to_unsigned(16#98000#, dn_addr_i'length),dn_obj_addr'length);

    audio_left_o  <= bt_audio;
    audio_right_o <= bt_audio;

    -- Black Tiger DIP switches
    --
    -- dipsw[15:8] = SW1
    -- dipsw[ 7:0] = SW2
    --
    -- MAME defaults:
    --   Coin A         1 Coin / 1 Credit
    --   Coin B         1 Coin / 1 Credit
    --   Flip Screen    Off
    --   Test           Off
    --   Lives          3
    --   Difficulty     5 (Normal)
    --   Demo Sounds    On
    --   Allow Continue Yes
    --   Cabinet        Upright
    --   Freeze         Off

    -- SW1
    bt_dipsw_a <= not (
    osm_control_i(C_MENU_SW1_0) &
    osm_control_i(C_MENU_SW1_1) &
    osm_control_i(C_MENU_SW1_2) &
    osm_control_i(C_MENU_SW1_3) &
    osm_control_i(C_MENU_SW1_4) &
    osm_control_i(C_MENU_SW1_5) &
    osm_control_i(C_MENU_SW1_6) &
    osm_control_i(C_MENU_SW1_7));

    bt_dipsw_b <= not (
    osm_control_i(C_MENU_SW2_0) &
    osm_control_i(C_MENU_SW2_1) &
    osm_control_i(C_MENU_SW2_2) &
    osm_control_i(C_MENU_SW2_3) &
    osm_control_i(C_MENU_SW2_4) &
    osm_control_i(C_MENU_SW2_5) &
    osm_control_i(C_MENU_SW2_6) &
    osm_control_i(C_MENU_SW2_7));

    -- JTFRAME Black Tiger consumes dipsw[15:0]:
    -- [15:8] = SW1, [7:0] = SW2
    bt_dipsw <= x"0000" & bt_dipsw_b & bt_dipsw_a;
    
    bt_joystick1(0) <= joy_1_right_n_i and keyboard_n(m65_horz_crsr);
    bt_joystick1(1) <= joy_1_left_n_i  and keyboard_n(m65_left_crsr);
    bt_joystick1(2) <= joy_1_down_n_i  and keyboard_n(m65_vert_crsr);
    bt_joystick1(3) <= joy_1_up_n_i    and keyboard_n(m65_up_crsr);
    
    -- Button 1
    bt_joystick1(4) <= joy_1_fire_n_i and keyboard_n(m65_z);
    
    -- Button 2
    bt_joystick1(5) <= keyboard_n(m65_x); --shoot2_button1_n and 
    
    
    bt_joystick2(0) <= joy_2_right_n_i;
    bt_joystick2(1) <= joy_2_left_n_i;
    bt_joystick2(2) <= joy_2_down_n_i;
    bt_joystick2(3) <= joy_2_up_n_i;
    
    -- Button 1
    bt_joystick2(4) <= joy_2_fire_n_i and keyboard_n(m65_z);
    
    -- Button 2
    bt_joystick2(5) <= keyboard_n(m65_x); --shoot2_button2_n;
 
    
    potxy_sw    <= osm_control_i(C_MENU_SECOND_FIRE); -- 0 = POTX, 1 = POTY
    pot_pol1_sw <= osm_control_i(C_MENU_POTPOL);      -- P1: 1 = active-low, 0 = active-high
    pot_pol2_sw <= osm_control_i(C_MENU_P2_POTPOL);   -- P2: 1 = active-low, 0 = active-high
    
    bt_coin(0) <= keyboard_n(m65_6);  -- Coin 1
    bt_coin(1) <= keyboard_n(m65_5);  -- Coin 2
    bt_coin(2) <= '1'; -- test with 0 tomorrow
    bt_coin(3) <= '1'; -- test with 0 tomorrow
    
    bt_cab_1p(0) <= keyboard_n(m65_1);  -- 1P Start
    bt_cab_1p(1) <= keyboard_n(m65_2);  -- 2P Start
    bt_cab_1p(2) <= '1';
    bt_cab_1p(3) <= '1';
    
    -- rst synchronizers
    
    i_reset_48 : xpm_cdc_async_rst
    generic map (
       RST_ACTIVE_HIGH => 1,
       DEST_SYNC_FF    => 6
    )
    port map (
       src_arst  => reset_async,
       dest_clk  => clk_main_i,
       dest_arst => reset_48
    );
    i_reset_24 : xpm_cdc_async_rst
    generic map (
       RST_ACTIVE_HIGH => 1,
       DEST_SYNC_FF    => 6
    )
    port map (
       src_arst  => reset_async,
       dest_clk  => clk_24_i,
       dest_arst => reset_24
    );
    reset_async <= reset_hard_i or reset_soft_i;
    
  
    
    second_button_proc : process(all)
    begin
    
       ------------------------------------------------------------------------
       -- Select POTX/POTY for both joystick ports
       ------------------------------------------------------------------------
       if potxy_sw = '0' then
          pot1_val <= pot1_x_i;
          pot2_val <= pot2_x_i;
       else
          pot1_val <= pot1_y_i;
          pot2_val <= pot2_y_i;
       end if;
    
       ------------------------------------------------------------------------
       -- Player 1 second fire
       ------------------------------------------------------------------------
       if pot_pol1_sw = '1' then
    
          -- Active-low POT button
          if unsigned(pot1_val) < unsigned'(x"80") then
             shoot2_button1_n <= '0';
          else
             shoot2_button1_n <= '1';
          end if;
       else
          -- Active-high POT button
          if unsigned(pot1_val) >= unsigned'(x"80") then
             shoot2_button1_n <= '0';
          else
             shoot2_button1_n <= '1';
          end if;
       end if;
    
    
       ------------------------------------------------------------------------
       -- Player 2 second fire
       ------------------------------------------------------------------------
       if pot_pol2_sw = '1' then
          -- Active-low POT button
          if unsigned(pot2_val) < unsigned'(x"80") then
             shoot2_button2_n <= '0';
          else
             shoot2_button2_n <= '1';
          end if;
       else
          -- Active-high POT button
          if unsigned(pot2_val) >= unsigned'(x"80") then
             shoot2_button2_n <= '0';
          else
             shoot2_button2_n <= '1';
          end if;
       end if;
    end process;
    
    

-- Main CPU ROM is 288 KiB, so split it into 256 KiB + 32 KiB instead of
-- wasting a 512 KiB power-of-two BRAM allocation.
   i_main_rom_lo : dualport_2clk_ram
   generic map (FALLING_B => true, ADDR_WIDTH => 18)
   port map (
      clock_a   => clk_main_i,
      address_a => bt_main_addr(17 downto 0),
      q_a       => bt_main_lo_data,
      clock_b   => dn_clk_i,
      address_b => dn_addr_i(17 downto 0),
      data_b    => dn_data_i,
      wren_b    => dn_main_lo_we
   );

   i_main_rom_hi : dualport_2clk_ram
   generic map (FALLING_B => true, ADDR_WIDTH => 15)
   port map (
      clock_a   => clk_main_i,
      address_a => bt_main_addr(14 downto 0),
      q_a       => bt_main_hi_data,
      clock_b   => dn_clk_i,
      address_b => dn_addr_i(14 downto 0),
      data_b    => dn_data_i,
      wren_b    => dn_main_hi_we
   );

   bt_main_data <= bt_main_hi_data when bt_main_addr(18) = '1' else bt_main_lo_data;

   i_sound_rom : dualport_2clk_ram
   generic map (FALLING_B => true, ADDR_WIDTH => 15)
   port map (
      clock_a   => clk_main_i,
      address_a => bt_snd_addr,
      q_a       => bt_snd_data,
      clock_b   => dn_clk_i,
      address_b => dn_addr_i(14 downto 0),
      data_b    => dn_data_i,
      wren_b    => dn_snd_we
   );

   i_char_rom_lo : dualport_2clk_ram
   generic map (FALLING_B => true, ADDR_WIDTH => 14)
   port map (
      clock_a   => clk_main_i,
      address_a => bt_char_addr(14 downto 1),
      q_a       => bt_char_data(7 downto 0),
      clock_b   => dn_clk_i,
      address_b => dn_addr_i(14 downto 1),
      data_b    => dn_data_i,
      wren_b    => dn_char_lo_we
   );

   i_char_rom_hi : dualport_2clk_ram
   generic map (FALLING_B => true, ADDR_WIDTH => 14)
   port map (
      clock_a   => clk_main_i,
      address_a => bt_char_addr(14 downto 1),
      q_a       => bt_char_data(15 downto 8),
      clock_b   => dn_clk_i,
      address_b => dn_addr_i(14 downto 1),
      data_b    => dn_data_i,
      wren_b    => dn_char_hi_we
   );

   i_scroll_rom_lo : dualport_2clk_ram
   generic map (FALLING_B => true, ADDR_WIDTH => 17)
   port map (
      clock_a   => clk_main_i,
      address_a => bt_scr_addr(17 downto 1),
      q_a       => bt_scr_data(7 downto 0),
      clock_b   => dn_clk_i,
      address_b => std_logic_vector(dn_scr_addr(17 downto 1)),
      data_b    => dn_data_i,
      wren_b    => dn_scr_lo_we
   );

   i_scroll_rom_hi : dualport_2clk_ram
   generic map (FALLING_B => true, ADDR_WIDTH => 17)
   port map (
      clock_a   => clk_main_i,
      address_a => bt_scr_addr(17 downto 1),
      q_a       => bt_scr_data(15 downto 8),
      clock_b   => dn_clk_i,
      address_b => std_logic_vector(dn_scr_addr(17 downto 1)),
      data_b    => dn_data_i,
      wren_b    => dn_scr_hi_we
   );

   i_object_rom_lo : dualport_2clk_ram
   generic map (FALLING_B => true, ADDR_WIDTH => 17)
   port map (
       clock_a   => clk_main_i,
       address_a => bt_obj_addr(17 downto 1),
       q_a       => bt_obj_data(7 downto 0),
       clock_b   => dn_clk_i,
       address_b => std_logic_vector(dn_obj_addr(17 downto 1)),
       data_b    => dn_data_i,
       wren_b    => dn_obj_lo_we
    );

    i_object_rom_hi : dualport_2clk_ram
    generic map (FALLING_B => true, ADDR_WIDTH => 17)
    port map (
       clock_a   => clk_main_i,
       address_a => bt_obj_addr(17 downto 1),
       q_a       => bt_obj_data(15 downto 8),
       clock_b   => dn_clk_i,
       address_b => std_logic_vector(dn_obj_addr(17 downto 1)),
       data_b    => dn_data_i,
       wren_b    => dn_obj_hi_we
    );
    
    i_mcu_rom : dualport_2clk_ram
    generic map (FALLING_B  => true,ADDR_WIDTH => 12)
    port map (
      -- MCU read side
      clock_a   => clk_24_i,
      clen_a    => bt_mcu_cen,
      address_a => bt_mcu_addr,
      q_a       => bt_mcu_data,

      -- QNICE programming side
      clock_b   => dn_clk_i,
      address_b => dn_addr_i(11 downto 0),
      data_b    => dn_data_i,
      wren_b    => dn_mcu_we
    );
    
    i_priority_rom : dualport_2clk_ram
    generic map (
       FALLING_B  => true,
       ADDR_WIDTH => 8
    )
    port map (
       -- Black Tiger runtime read port
       clock_a   => clk_main_i,
       clen_a    => bt_prior_cen,
       address_a => bt_prior_addr,
       q_a       => bt_prior_data8,
    
       -- QNICE download port
       clock_b   => dn_clk_i,
       clen_b    => '1',
       address_b => dn_addr_i(7 downto 0),
       data_b    => dn_data_i,
       wren_b    => dn_prior_we
    );

bt_prior_data <= bt_prior_data8(3 downto 0);
   

   i_black_tiger : jtbtiger_game
   port map (
      -- Clocks
      rst         => reset_48,
      clk         => clk_main_i,       -- 48 MHz
      rst24       => reset_24,         -- synchronized to 24 MHz
      clk24       => clk_24_i,         -- 24 MHz

      -- Pixel enables
      pxl2_cen    => bt_pxl2_cen,      -- 12 MHz
      pxl_cen     => video_ce_o,       -- 6 MHz

      -- Video
      red         => video_red_o,
      green       => video_green_o,
      blue        => video_blue_o,
      LHBL        => video_hblank_o,
      LVBL        => video_vblank_o,
      HS          => video_hs_o,
      VS          => video_vs_o,

      -- Controls - temporary
      cab_1p      => bt_cab_1p,
      coin        => bt_coin,
      
      joystick1   => bt_joystick1,
      joystick2   => bt_joystick2,

      dipsw       => bt_dipsw,--(others => '0'), --
      dip_pause   => keyboard_n(m65_p),-- '1',     -- pause is active low, active high run
      service     => keyboard_n(m65_9), 
      dip_flip    => open,

      gfx_en      => "1111",

      debug_bus   => (others => '0'),
      debug_view  => bt_debug_view,

      -- ROM interfaces
      main_addr   => bt_main_addr,
      main_cs     => bt_main_cs,
      main_ok     => bt_main_ok,
      main_data   => bt_main_data,
    
      snd_addr    => bt_snd_addr,
      snd_cs      => bt_snd_cs,
      snd_ok      => bt_snd_ok,
      snd_data    => bt_snd_data,
    
      char_addr   => bt_char_addr,
      char_ok     => bt_char_ok,
      char_data   => bt_char_data,
    
      scr_addr    => bt_scr_addr,
      scr_ok      => bt_scr_ok,
      scr_data    => bt_scr_data,
    
      obj_addr    => bt_obj_addr,
      obj_ok      => bt_obj_ok,
      obj_data    => bt_obj_data,

      -- MCU + PROM programming.  jtbtiger_game decodes $D8000-$D8FFF as
      -- MCU and $D9000-$D93FF as the four 256-byte PROMs.
      
      ioctl_addr  => '0' & dn_addr_i,
      prog_addr   => dn_addr_i,
      prog_data   => x"00" & dn_data_i,
      prom_we     => dn_prom_we,
      
      mcu_rom_addr => bt_mcu_addr,
      mcu_rom_cen  => bt_mcu_cen,
      mcu_rom_data => bt_mcu_data,
      
      -- Priority PROM
      prior_rom_addr => bt_prior_addr,
      prior_rom_cen  => bt_prior_cen,
      prior_rom_data => bt_prior_data,
      
      -- Audio
      fm0         => bt_fm0,
      fm1         => bt_fm1,
      psg0        => bt_psg0,
      psg1        => bt_psg1
   );
   
   process(clk_main_i)
    begin
       if rising_edge(clk_main_i) then
    
          -- Main ROM
          bt_main_addr_d <= bt_main_addr;
          if bt_main_addr = bt_main_addr_d then
             bt_main_ok <= '1';
          else
             bt_main_ok <= '0';
          end if;
    
          -- Sound ROM
          bt_snd_addr_d <= bt_snd_addr;
          if bt_snd_addr = bt_snd_addr_d then
             bt_snd_ok <= '1';
          else
             bt_snd_ok <= '0';
          end if;
    
          -- Character ROM
          bt_char_addr_d <= bt_char_addr;
          if bt_char_addr = bt_char_addr_d then
             bt_char_ok <= '1';
          else
             bt_char_ok <= '0';
          end if;
    
          -- Scroll ROM
          bt_scr_addr_d <= bt_scr_addr;
          if bt_scr_addr = bt_scr_addr_d then
             bt_scr_ok <= '1';
          else
             bt_scr_ok <= '0';
          end if;
    
          -- Object ROM
          bt_obj_addr_d <= bt_obj_addr;
          if bt_obj_addr = bt_obj_addr_d then
             bt_obj_ok <= '1';
          else
             bt_obj_ok <= '0';
          end if;
    
       end if;
    end process;
   
   i_bt_audio_mixer : jtframe_mixer
   generic map (
      W0   => 16,
      W1   => 16,
      W2   => 16,
      W3   => 16,
      WOUT => 16
   )
   port map (
      rst   => reset_hard_i,
      clk   => clk_main_i,
      cen   => '1',
      
      ch0   => bt_psg0,
      ch1   => bt_psg1,
      ch2   => bt_fm0,
      ch3   => bt_fm1,

      gain0 => x"17",
      gain1 => x"17",
      gain2 => x"17",
      gain3 => x"17",

      mixed => bt_audio,
      peak  => bt_audio_peak
   );
   
   i_keyboard : entity work.keyboard
      port map (
         clk_main_i           => clk_main_i,

         -- Interface to the MEGA65 keyboard
         key_num_i            => kb_key_num_i,
         key_pressed_n_i      => kb_key_pressed_n_i,

         -- @TODO: Create the kind of keyboard output that your core needs
         -- "example_n_o" is a low active register and used by the demo core:
         --    bit 0: Space
         --    bit 1: Return
         --    bit 2: Run/Stop
         example_n_o          => keyboard_n
      ); -- i_keyboard

end architecture synthesis;

