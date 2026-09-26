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
      video_red_o             : out std_logic_vector(7 downto 0);
      video_green_o           : out std_logic_vector(7 downto 0);
      video_blue_o            : out std_logic_vector(7 downto 0);
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
      pot2_y_i                : in  std_logic_vector(7 downto 0)
   );
end entity main;

architecture synthesis of main is

-- @TODO: Remove these demo core signals
signal keyboard_n          : std_logic_vector(79 downto 0);

---------------------------------------------------------------------------
-- Black Tiger
---------------------------------------------------------------------------

signal bt_pxl_cen       : std_logic;
signal bt_pxl2_cen      : std_logic;

signal bt_red           : std_logic_vector(3 downto 0);
signal bt_green         : std_logic_vector(3 downto 0);
signal bt_blue          : std_logic_vector(3 downto 0);

signal bt_hs            : std_logic;
signal bt_vs            : std_logic;
signal bt_lhbl          : std_logic;
signal bt_lvbl          : std_logic;

signal bt_dip_flip      : std_logic;
signal bt_debug_view    : std_logic_vector(7 downto 0);

-- ROM interfaces - unused for now
signal bt_main_addr     : std_logic_vector(18 downto 0);
signal bt_main_cs       : std_logic;

signal bt_snd_addr      : std_logic_vector(14 downto 0);
signal bt_snd_cs        : std_logic;

signal bt_char_addr     : std_logic_vector(14 downto 1);
signal bt_scr_addr      : std_logic_vector(17 downto 1);
signal bt_obj_addr      : std_logic_vector(17 downto 1);

-- Audio - unused for now
signal bt_fm0           : signed(15 downto 0);
signal bt_fm1           : signed(15 downto 0);
signal bt_psg0          : signed(15 downto 0);
signal bt_psg1          : signed(15 downto 0);

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

i_black_tiger : jtbtiger_game
   port map (
      -- Clocks
      rst         => reset_hard_i,
      clk         => clk_main_i,       -- 48 MHz
      rst24       => reset_hard_i,     -- temporary: reset is synchronous to 48 MHz
      clk24       => clk_24_i,         -- 24 MHz

      -- Pixel enables
      pxl2_cen    => bt_pxl2_cen,      -- 12 MHz
      pxl_cen     => bt_pxl_cen,       -- 6 MHz

      -- Video
      red         => bt_red,
      green       => bt_green,
      blue        => bt_blue,
      LHBL        => bt_lhbl,
      LVBL        => bt_lvbl,
      HS          => bt_hs,
      VS          => bt_vs,

      -- Controls - temporary
      cab_1p      => (others => '0'),
      coin        => (others => '0'),
      joystick1   => (others => '0'),
      joystick2   => (others => '0'),

      dipsw       => (others => '0'),
      dip_pause   => '0',
      service     => '0',
      dip_flip    => bt_dip_flip,

      gfx_en      => "1111",

      debug_bus   => (others => '0'),
      debug_view  => bt_debug_view,

      -- ROM interfaces - temporary dummy data
      main_addr   => bt_main_addr,
      main_cs     => bt_main_cs,
      main_ok     => '1',
      main_data   => x"FF",

      snd_addr    => bt_snd_addr,
      snd_cs      => bt_snd_cs,
      snd_ok      => '1',
      snd_data    => x"FF",

      char_addr   => bt_char_addr,
      char_ok     => '1',
      char_data   => x"FFFF",

      scr_addr    => bt_scr_addr,
      scr_ok      => '1',
      scr_data    => x"FFFF",

      obj_addr    => bt_obj_addr,
      obj_ok      => '1',
      obj_data    => x"FFFF",

      -- PROM programming - later
      ioctl_addr  => (others => '0'),
      prog_addr   => (others => '0'),
      prog_data   => (others => '0'),
      prom_we     => '0',

      -- Audio - later
      fm0         => bt_fm0,
      fm1         => bt_fm1,
      psg0        => bt_psg0,
      psg1        => bt_psg1
   );
   
    ---------------------------------------------------------------------------
    -- Native Black Tiger video -> M2M
    ---------------------------------------------------------------------------
    
    video_ce_o     <= bt_pxl_cen;
    video_ce_ovl_o <= bt_pxl_cen;
    
    video_red_o    <= bt_red   & bt_red;
    video_green_o  <= bt_green & bt_green;
    video_blue_o   <= bt_blue  & bt_blue;
    
    video_hs_o     <= bt_hs;
    video_vs_o     <= bt_vs;
    
    video_hblank_o <= not bt_lhbl;
    video_vblank_o <= not bt_lvbl;
    
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

