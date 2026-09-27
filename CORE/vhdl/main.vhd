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
      dn_wr_i                 : in  std_logic
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

-- Audio - unused for now
signal bt_fm0           : signed(15 downto 0);
signal bt_fm1           : signed(15 downto 0);
signal bt_psg0          : signed(15 downto 0);
signal bt_psg1          : signed(15 downto 0);

component dualport_2clk_ram
   generic (
      FALLING_A  : boolean := false;
      FALLING_B  : boolean := false;
      ADDR_WIDTH : integer := 8
   );
   port (
      clock_a   : in  std_logic;
      address_a : in  std_logic_vector(ADDR_WIDTH-1 downto 0);
      q_a       : out std_logic_vector(7 downto 0);
      clock_b   : in  std_logic;
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
      psg1        : out signed(15 downto 0)
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

dn_prom_we    <= dn_wr_i when unsigned(dn_addr_i) >= 16#D8000# and unsigned(dn_addr_i) < 16#D9400# else '0';

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
      address_b => dn_addr_i(17 downto 1),
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
      address_b => dn_addr_i(17 downto 1),
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
      address_b => dn_addr_i(17 downto 1),
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
      address_b => dn_addr_i(17 downto 1),
      data_b    => dn_data_i,
      wren_b    => dn_obj_hi_we
   );

i_black_tiger : jtbtiger_game
   port map (
      -- Clocks
      rst         => reset_hard_i,
      clk         => clk_main_i,       -- 48 MHz
      rst24       => reset_hard_i,     -- temporary: reset is synchronous to 48 MHz
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
      cab_1p      => (others => '1'),
      coin        => (others => '1'),
      joystick1   => (others => '1'),
      joystick2   => (others => '1'),

      dipsw       => (others => '0'), -- separate issue; DIP configuration
      dip_pause   => '1', -- pause is active low, active high run
      service     => '1', -- 1 = inactive not pressed
      dip_flip    => open,

      gfx_en      => "1111",

      debug_bus   => (others => '0'),
      debug_view  => bt_debug_view,

      -- ROM interfaces
      main_addr   => bt_main_addr,
      main_cs     => bt_main_cs,
      main_ok     => '1',
      main_data   => bt_main_data,

      snd_addr    => bt_snd_addr,
      snd_cs      => bt_snd_cs,
      snd_ok      => '1',
      snd_data    => bt_snd_data,

      char_addr   => bt_char_addr,
      char_ok     => '1',
      char_data   => bt_char_data,

      scr_addr    => bt_scr_addr,
      scr_ok      => '1',
      scr_data    => bt_scr_data,

      obj_addr    => bt_obj_addr,
      obj_ok      => '1',
      obj_data    => bt_obj_data,

      -- MCU + PROM programming.  jtbtiger_game decodes $D8000-$D8FFF as
      -- MCU and $D9000-$D93FF as the four 256-byte PROMs.
      ioctl_addr  => '0' & dn_addr_i,
      prog_addr   => dn_addr_i,
      prog_data   => x"00" & dn_data_i,
      prom_we     => dn_prom_we,

      -- Audio - later
      fm0         => bt_fm0,
      fm1         => bt_fm1,
      psg0        => bt_psg0,
      psg1        => bt_psg1
   );
   

    
    -- Audio later
    audio_left_o   <= (others => '0');
    audio_right_o  <= (others => '0');

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

