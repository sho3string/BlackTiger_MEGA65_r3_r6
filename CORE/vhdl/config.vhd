----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Configuration data for the Shell
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2023 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity config is
port (
   clk_i       : in std_logic;

   -- bits 27 .. 12:    select configuration data block; called "Selector" hereafter
   -- bits 11 downto 0: address the up to 4k the configuration data
   address_i   : in std_logic_vector(27 downto 0);

   -- config data
   data_o      : out std_logic_vector(15 downto 0)
);
end entity config;

architecture beh of config is

--------------------------------------------------------------------------------------------------------------------
-- String and character constants (specific for the Anikki-16x16 font)
--------------------------------------------------------------------------------------------------------------------

-- !!! DO NOT TOUCH !!!
constant CHR_LINE_1  : character := character'val(196);
constant CHR_LINE_5  : string := CHR_LINE_1 & CHR_LINE_1 & CHR_LINE_1 & CHR_LINE_1 & CHR_LINE_1;
constant CHR_LINE_10 : string := CHR_LINE_5 & CHR_LINE_5;
constant CHR_LINE_50 : string := CHR_LINE_10 & CHR_LINE_10 & CHR_LINE_10 & CHR_LINE_10 & CHR_LINE_10;

--------------------------------------------------------------------------------------------------------------------
-- Welcome and Help Screens (Selectors 0x1000 .. 0x1FFF)
--------------------------------------------------------------------------------------------------------------------

-- define the amount of WHS array elements: between 1 and 16
constant WHS_RECORDS   : natural := 2;

-- define the maximum amount of pages per WHS array element: between 1 and 256
-- (this is necessary because Vivado does not support unconstrained arrays in a record)
constant WHS_MAX_PAGES : natural := 3;

 -- !!! DO NOT TOUCH !!!
constant SEL_WHS           : std_logic_vector(15 downto 0) := x"1000";
type WHS_INDEX_TYPE is array (0 to WHS_MAX_PAGES - 1) of natural;
type WHS_RECORD_TYPE is record
   page_count  : natural;
   page_start  : WHS_INDEX_TYPE;
   page_length : WHS_INDEX_TYPE;
end record;
type WHS_RECORD_ARRAY_TYPE is array (0 to WHS_RECORDS - 1) of WHS_RECORD_TYPE;

-- START YOUR CONFIGURATION BELOW THIS LINE

-- Define all your screens as string constants. They will be synthesized as ROMs.
-- You can name these string constants as you want to, as long as you make them part of the WHS array (see below).
--
-- WHS array position 0 is defined as the "Welcome Screen" as controled by WELCOME_ACTIVE and WELCOME_AT_RESET.
-- If you are not using a Welcome Screen but only Help menu items, then you need to leave WHS array pos. 0 empty.
--
-- WHS array position 1 and onwards is for all the Option Menu items tagged as "Help": The first one in the
-- Options menu is WHS array pos. 1, the second one in the menu is WHS array pos. 2 and so on.
--
-- Maximum 16 WHS array positions: The selector's bits 11 downto 8 select the WHS array position; 0=Welcome Screen
-- That means a maximum of 15 menu items in the Options menu can be tagged as "Help"
-- The selector's bits 7 downto 0 are selecting the page within the WHS array, so maximum 256 pages per Welcome Screen or Help menu item
--
-- Within a selector's address range, address 0 is the beginning of the string itself, while address 0xFFF of the 4k
-- window contains the amount of pages, so each zero-terminated string can be up to 4095 bytes = 4094 characters long.

constant SCR_WELCOME : string :=

   "Black Tiger V0.5.0\n" &
   "------------------\n" &
   "\n" &
   "Jotego port by Muse 2026\n\n" &

   -- We are not insisting. But it would be nice if you gave us credit for MiSTer2MEGA65 by leaving these lines in
   "Powered by MiSTer2MEGA65\n"   &
   "By sy2002 and MJoergen\n"     &
   "\n\n"                                 &
   "Credits  : Press '5' or '6'\n"        & 
   "Start    : Press '1' or '2'\n"        &
   "Pause    : Press 'CAPS-LOCK'\n"       &
   "Controls : Joy - arrows & z+x\n"      &
   "\n\n    Press Space to continue.\n"; 

constant HELP_1 : string :=

   "\n Demo Core for MEGA65 Version 1\n\n" &

   " MiSTer port 2022 by YOU\n" &
   " Powered by MiSTer2MEGA65\n\n\n" &

   " Lorem ipsum dolor sit amet, consetetur\n" &
   " sadipscing elitr, sed diam nonumy eirmod\n" &
   " Mpor invidunt ut labore et dolore magna\n" &
   " aliquyam erat, sed diam voluptua. At vero\n" &
   " eos et accusam et justo duo.\n\n" &

   " Dolores et ea rebum. Stet clita kasd gube\n" &
   " gren, no sea takimata sanctus est Lorem ip\n" &
   " Sed diam nonumy eirmod tempor invidunt ut\n" &
   " labore et dolore magna aliquyam era\n\n" &

   " Cursor right to learn more.       (1 of 3)\n" &
   " Press Space to close the help screen.";

constant HELP_2 : string :=

   "\n Demo Core for MEGA65 Version 1\n\n" &

   " XYZ ABCDEFGH:\n\n" &

   " 1. ABCD EFGH\n" &
   " 2. IJK LM NOPQ RSTUVWXYZ\n" &
   " 3. 10 20 30 40 50\n\n" &

   " a) Dolores et ea rebum\n" &
   " b) Takimata sanctus est\n" &
   " c) Tempor Invidunt ut\n" &
   " d) Sed Diam Nonumy eirmod te\n" &
   " e) Awesome\n\n" &

   " Ut wisi enim ad minim veniam, quis nostru\n" &
   " exerci tation ullamcorper suscipit lobor\n" &
   " tis nisl ut aliquip ex ea commodo.\n\n" &

   " Crsr left: Prev  Crsr right: Next (2 of 3)\n" &
   " Press Space to close the help screen.";

constant HELP_3 : string :=

   "\n Help Screens\n\n" &

   " You can have 255 screens per help topic.\n\n" &

   " 15 topics overall.\n" &
   " 1 menu item per topic.\n\n\n\n" &

   " Cursor left to go back.           (3 of 3)\n" &
   " Press Space to close the help screen.";

-- Concatenate all your Welcome and Help screens into one large string, so that during synthesis one large string ROM can be build.
constant WHS_DATA : string := SCR_WELCOME & HELP_1 & HELP_2 & HELP_3;

-- The WHS array needs the start address of each page. As a best practice: Just define some constants, that you can name for example
-- just like you named the string constants and then add _START. Use the 'length attribute of VHDL to add up all previous strings
-- so that the Synthesis tool can calculate the start addresses: Your first string starts at zero, your next one at the address which
-- is equal to the length of the first one, your next one at the address which is equal to the sum of the previous ones, and so on.
constant SCR_WELCOME_START : natural := 0;
constant HELP_1_START      : natural := SCR_WELCOME'length;
constant HELP_2_START      : natural := HELP_1_START + HELP_1'length;
constant HELP_3_START      : natural := HELP_2_START + HELP_2'length;

-- Fill the WHS array with page start addresses and the length of each page.
-- Make sure that array element 0 is always your Welcome page. If you don't use a welcome page, fill everything with zeros.
constant WHS : WHS_RECORD_ARRAY_TYPE := (
   --- Welcome Screen
   (page_count    => 1,
    page_start    => (SCR_WELCOME_START,  0, 0),
    page_length   => (SCR_WELCOME'length, 0, 0)),

   --- Help pages
   (page_count    => 3,
    page_start    => (HELP_1_START,  HELP_2_START,  HELP_3_START),
    page_length   => (HELP_1'length, HELP_2'length, HELP_3'length))
);

--------------------------------------------------------------------------------------------------------------------
-- Set start folder for file browser and specify config file for menu persistence (Selectors 0x0100 and 0x0101)
--------------------------------------------------------------------------------------------------------------------

-- !!! DO NOT TOUCH !!!
constant SEL_DIR_START     : std_logic_vector(15 downto 0) := x"0100";
constant SEL_CFG_FILE      : std_logic_vector(15 downto 0) := x"0101";

-- START YOUR CONFIGURATION BELOW THIS LINE

constant DIR_START         : string := "/arcade/blktiger";
constant CFG_FILE          : string := "/arcade/blktiger/btcfg";

--------------------------------------------------------------------------------------------------------------------
-- General configuration settings: Reset, Pause, OSD behavior, Ascal, etc. (Selector 0x0110)
--------------------------------------------------------------------------------------------------------------------

constant SEL_GENERAL       : std_logic_vector(15 downto 0) := x"0110";  -- !!! DO NOT TOUCH !!!

-- START YOUR CONFIGURATION BELOW THIS LINE

-- at a minimum, keep the reset line active for this amount of "QNICE loops" (see gencfg.asm).
-- "0" means: deactivate this feature
constant RESET_COUNTER     : natural := 100;

-- put the core in PAUSE state if any OSD opens
constant OPTM_PAUSE        : boolean := false;

-- show the welcome screen in general
constant WELCOME_ACTIVE    : boolean := true;

-- shall the welcome screen also be shown after the core is reset?
-- (only relevant if WELCOME_ACTIVE is true)
constant WELCOME_AT_RESET  : boolean := true;

-- keyboard and joystick connection during reset and OSD
constant KEYBOARD_AT_RESET : boolean := false;
constant JOY_1_AT_RESET    : boolean := false;
constant JOY_2_AT_RESET    : boolean := false;

constant KEYBOARD_AT_OSD   : boolean := false;
constant JOY_1_AT_OSD      : boolean := false;
constant JOY_2_AT_OSD      : boolean := false;

-- Avalon Scaler settings (see ascal.vhd, used for HDMI output only)
-- 0=set ascal mode (via QNICE's ascal_mode_o) to the value of the config.vhd constant ASCAL_MODE
-- 1=do nothing, leave ascal mode alone, custom QNICE assembly code can still change it via M2M$ASCAL_MODE
--               and QNICE's CSR will be set to not automatically sync ascal_mode_i
-- 2=keep ascal mode in sync with the QNICE input register ascal_mode_i:
--   use this if you want to control the ascal mode for example via the Options menu
--   where you would wire the output of certain options menu bits with ascal_mode_i
constant ASCAL_USAGE       : natural := 2;
constant ASCAL_MODE        : natural := 0;   -- see ascal.vhd for the meaning of this value

-- Save on-screen-display settings if the file specified by CFG_FILE exists and if it has
-- the length of OPTM_SIZE bytes. If the first byte of the file has the value 0xFF then it
-- is considered as "default", i.e. the menu items specified by OPTM_G_STDSEL are selected.
-- If the file does not exists, then settings are not saved and OPTM_G_STDSEL always denotes the standard settings.
constant SAVE_SETTINGS     : boolean := true;

-- Delay in ms between the last write request to a virtual drive from the core and the start of the
-- cache flushing (i.e. writing to the SD card). Since every new write from the core invalidates the cache,
-- and therefore leads to a completely new writing of the cache (flushing), this constant prevents thrashing.
-- The default is 2 seconds (2000 ms). Should be reasonable for many systems, but if you have a very fast
-- or very slow system, you might need to change this constant.
--
-- Constraint (@TODO): Currently we have only one constant for all virtual drives, i.e. the delay is
-- the same for all virtual drives. This might be absolutely OK; future will tell. If we need to have
-- more flexibility: vdrives.vhd already supports one delay per virtual drive. All what would need
-- to be done in such a case is: Enhance config.vhd to have more constants plus enhance the initialization
-- routine VD_INIT in vdrives.asm (tagged by @TODO) to store different values in the appropriate registers.
constant VD_ANTI_THRASHING_DELAY : natural := 2000;

-- Amount of bytes saved in one iteration of the background saving (buffer flushing) process
-- Constraint (@TODO): Similar constraint as in VD_ANTI_THRASHING_DELAY: Only one value for all drives.
-- shell.asm and shell_vars.asm already supports distinct values per drive; config.vhd and VD_INIT would
-- needs to be updated in case we would need this feature in future
constant VD_ITERATION_SIZE       : natural := 100;

--------------------------------------------------------------------------------------------------------------------
-- Name and version of the core  (Selector 0x0200)
--------------------------------------------------------------------------------------------------------------------

-- !!! DO NOT TOUCH !!!
constant SEL_CORENAME      : std_logic_vector(15 downto 0) := x"0200";

-- START YOUR CONFIGURATION BELOW THIS LINE

-- Currently this is only used in the debug console. Use the welcome screen and the
-- help system to display the name and version of your core to the end user
constant CORENAME          : string := "BlackTiger v0.5.0";

--------------------------------------------------------------------------------------------------------------------
-- "Help" menu / Options menu  (Selectors 0x0300 .. 0x0312): DO NOT TOUCH
--------------------------------------------------------------------------------------------------------------------

-- !!! DO NOT TOUCH !!! Selectors for accessing the menu configuration data
constant SEL_OPTM_ITEMS       : std_logic_vector(15 downto 0) := x"0300";
constant SEL_OPTM_GROUPS      : std_logic_vector(15 downto 0) := x"0301";
constant SEL_OPTM_STDSEL      : std_logic_vector(15 downto 0) := x"0302";
constant SEL_OPTM_LINES       : std_logic_vector(15 downto 0) := x"0303";
constant SEL_OPTM_START       : std_logic_vector(15 downto 0) := x"0304";
constant SEL_OPTM_ICOUNT      : std_logic_vector(15 downto 0) := x"0305";
constant SEL_OPTM_MOUNT_DRV   : std_logic_vector(15 downto 0) := x"0306";
constant SEL_OPTM_SINGLESEL   : std_logic_vector(15 downto 0) := x"0307";
constant SEL_OPTM_MOUNT_STR   : std_logic_vector(15 downto 0) := x"0308";
constant SEL_OPTM_DIMENSIONS  : std_logic_vector(15 downto 0) := x"0309";
constant SEL_OPTM_SAVING_STR  : std_logic_vector(15 downto 0) := x"030A";
constant SEL_OPTM_HELP        : std_logic_vector(15 downto 0) := x"0310";
constant SEL_OPTM_CRTROM      : std_logic_vector(15 downto 0) := x"0311";
constant SEL_OPTM_CRTROM_STR  : std_logic_vector(15 downto 0) := x"0312";

-- !!! DO NOT TOUCH !!! Configuration constants for OPTM_GROUPS (shell.asm and menu.asm expect them to be like this)
constant OPTM_G_TEXT       : integer := 16#00000#;         -- text that cannot be selected
constant OPTM_G_CLOSE      : integer := 16#000FF#;        -- menu items that closes menu
constant OPTM_G_STDSEL     : integer := 16#00100#;        -- item within a group that is selected by default
constant OPTM_G_LINE       : integer := 16#00200#;        -- draw a line at this position
constant OPTM_G_START      : integer := 16#00400#;        -- selector / cursor position after startup (only use once!)
                                                          -- 16#00800# is used in OPTM_G_MOUNT_DRV (OPTM_G_SINGLESEL)
constant OPTM_G_HEADLINE   : integer := 16#01000#;        -- like OPTM_G_TEXT but will be shown in a brigher color
                                                          -- 16#02000# is used in OPTM_G_HELP (plus OPTM_G_SINGLESEL)
                                                          -- 16#04000# is used in OPTM_G_SUBMENU
constant OPTM_G_SINGLESEL  : integer := 16#08000#;        -- single select item
constant OPTM_G_MOUNT_DRV  : integer := 16#08800#;        -- line item means: mount drive; first occurance = drive 0, second = drive 1, ...
constant OPTM_G_HELP       : integer := 16#0A000#;        -- line item means: help screen; first occurance = WHS(1), second = WHS(2), ...
constant OPTM_G_SUBMENU    : integer := 16#0C000#;        -- starts/ends a section that is treated as submenu
constant OPTM_G_LOAD_ROM   : integer := 16#18000#;        -- line item means: load ROM; first occurance = rom 0, second = rom 1, ...

constant OPTM_GTC          : natural := 17;                -- Amount of significant bits in OPTM_G_* constants

-- @TODO/REMINDER: If we added in future more configuration constants that are not meant to be saved in the
-- configuration file, such as OPTM_G_MOUNT_DRV and OPTM_G_LOAD_ROM, then we need to make sure that we
-- also extend _ROSMS_4A and _ROSMC_NEXTBIT in options.asm accordingly.
-- Also: Right now OPTM_G_SUBMENU cannot have a "selected" state (and therefore cannot be saved in the config file)
-- and therefore _ROSMS_4A and _ROSMC_NEXTBIT are not yet handling the situation. If we decided to change that in future,
-- we would need to define the right semantics everywhere.

--------------------------------------------------------------------------------------------------------------------
-- "Help" menu / Options menu: START YOUR CONFIGURATION BELOW THIS LINE
--------------------------------------------------------------------------------------------------------------------

-- Strings with which %s will be replaced in case the menu item is of type OPTM_G_MOUNT_DRV
--------------------------------------------------------------------------------------------------------------------
-- Options Menu
--------------------------------------------------------------------------------------------------------------------

-- Strings with which %s will be replaced in case the menu item is of type OPTM_G_MOUNT_DRV
constant OPTM_S_MOUNT      : string := "<Mount Drive>";
constant OPTM_S_CRTROM     : string := "<Load>";
constant OPTM_S_SAVING     : string := "<Saving>";

-- Size of menu and menu items
constant OPTM_SIZE         : natural := 68;

-- Net size of the Options menu on the screen in characters
constant OPTM_DX           : natural := 23;
constant OPTM_DY           : natural := 23;

constant OPTM_ITEMS        : string :=
           " Black Tiger - Capcom\n"    &  --  0
           "\n"                         &  --  1

           " Display Settings\n"        &  --  2
           "\n"                         &  --  3

           " HDMI: CRT emulation\n"     &  --  4

           " HDMI: %s\n"                &  --  5
           " HDMI Settings\n"           &  --  6
           "\n"                         &  --  7
           " 720p 50 Hz 16:9\n"         &  --  8
           " 720p 60 Hz 16:9\n"         &  --  9
           " 576p 50 Hz 4:3\n"          &  -- 10
           " 576p 50 Hz 5:4\n"          &  -- 11
           " 640x480 60 Hz\n"           &  -- 12
           " 720x480 59.94 Hz\n"        &  -- 13
           " 800x600 60 Hz\n"           &  -- 14
           "\n"                         &  -- 15
           " Back to main menu\n"       &  -- 16

           " VGA: %s\n"                 &  -- 17
           " VGA Display Mode\n"        &  -- 18
           "\n"                         &  -- 19
           " Standard\n"                &  -- 20
           "\n"                         &  -- 21
           " Retro 15 kHz mode\n"       &  -- 22
           "\n"                         &  -- 23
           " 15 kHz with HS/VS\n"       &  -- 24
           " 15 kHz with CSYNC\n"       &  -- 25
           "\n"                         &  -- 26
           " Back to main menu\n"       &  -- 27

           "\n"                         &  -- 28
           " Audio Settings\n"          &  -- 29
           "\n"                         &  -- 30

           " Audio improvements\n"      &  -- 31

           "\n"                         &  -- 32
           " Control Settings\n"        &  -- 33
           "\n"                         &  -- 34

           " Second Fire: POTX\n"       &  -- 35
           " Second Fire: POTY\n"       &  -- 36

           " P1 POT Polarity: High\n"   &  -- 37
           " P1 POT Polarity: Low\n"    &  -- 38

           "\n"                         &  -- 39

           " DIP SW1\n"                 &  -- 40
           " SW1 Settings\n"            &  -- 41
           "\n"                         &  -- 42
           " SW1-1 Coin A\n"            &  -- 43
           " SW1-2 Coin A\n"            &  -- 44
           " SW1-3 Coin A\n"            &  -- 45
           " SW1-4 Coin B\n"            &  -- 46
           " SW1-5 Coin B\n"            &  -- 47
           " SW1-6 Coin B\n"            &  -- 48
           " SW1-7 Flip Screen\n"       &  -- 49
           " SW1-8 Test\n"              &  -- 50
           "\n"                         &  -- 51
           " Back to main menu\n"       &  -- 52

           " DIP SW2\n"                 &  -- 53
           " SW2 Settings\n"            &  -- 54
           "\n"                         &  -- 55
           " SW2-1 Lives\n"             &  -- 56
           " SW2-2 Lives\n"             &  -- 57
           " SW2-3 Difficulty\n"        &  -- 58
           " SW2-4 Difficulty\n"        &  -- 59
           " SW2-5 Difficulty\n"        &  -- 60
           " SW2-6 Demo Sounds\n"       &  -- 61
           " SW2-7 Continue\n"          &  -- 62
           " SW2-8 Cabinet\n"           &  -- 63
           "\n"                         &  -- 64
           " Back to main menu\n"       &  -- 65

           "\n"                         &  -- 66
           " Close Menu\n";                -- 67
                

--------------------------------------------------------------------------------------------------------------------
-- Menu groups
--------------------------------------------------------------------------------------------------------------------

constant OPTM_G_Demo_A      : integer := 1;
constant OPTM_G_HDMI        : integer := 2;
constant OPTM_G_CRT         : integer := 3;
constant OPTM_G_Audio       : integer := 4;
constant OPTM_G_SECOND_FIRE : integer := 5;
constant OPTM_G_POTPOL      : integer := 6;   -- P1 polarity

-- Black Tiger DIP SW1
constant OPTM_G_SW1_0       : integer := 7;
constant OPTM_G_SW1_1       : integer := 8;
constant OPTM_G_SW1_2       : integer := 9;
constant OPTM_G_SW1_3       : integer := 10;
constant OPTM_G_SW1_4       : integer := 11;
constant OPTM_G_SW1_5       : integer := 12;
constant OPTM_G_SW1_6       : integer := 13;
constant OPTM_G_SW1_7       : integer := 14;

-- Black Tiger DIP SW2
constant OPTM_G_SW2_0       : integer := 15;
constant OPTM_G_SW2_1       : integer := 16;
constant OPTM_G_SW2_2       : integer := 17;
constant OPTM_G_SW2_3       : integer := 18;
constant OPTM_G_SW2_4       : integer := 19;
constant OPTM_G_SW2_5       : integer := 20;
constant OPTM_G_SW2_6       : integer := 21;
constant OPTM_G_SW2_7       : integer := 22;
-- VGA / analog output
constant OPTM_G_VGA_MODES   : integer := 24;


-- !!! DO NOT TOUCH !!!
type OPTM_GTYPE is array (0 to OPTM_SIZE - 1) of integer range 0 to 2**OPTM_GTC - 1;


constant OPTM_GROUPS : OPTM_GTYPE := (
                               -- Black Tiger
                               OPTM_G_TEXT + OPTM_G_HEADLINE,                       --  0 Black Tiger
                               OPTM_G_LINE,                                         --  1

                               -- Display
                               OPTM_G_TEXT + OPTM_G_HEADLINE,                       --  2 Display Settings
                               OPTM_G_LINE,                                         --  3

                               OPTM_G_CRT + OPTM_G_SINGLESEL + OPTM_G_START,        --  4 HDMI: CRT emulation

                               -- HDMI submenu
                               OPTM_G_SUBMENU,                                      --  5 HDMI: %s
                               OPTM_G_HEADLINE,                                     --  6 HDMI Settings
                               OPTM_G_LINE,                                         --  7

                               OPTM_G_HDMI + OPTM_G_STDSEL,                         --  8 720p 50 Hz 16:9
                               OPTM_G_HDMI,                                         --  9 720p 60 Hz 16:9
                               OPTM_G_HDMI,                                         -- 10 576p 50 Hz 4:3
                               OPTM_G_HDMI,                                         -- 11 576p 50 Hz 5:4
                               OPTM_G_HDMI,                                         -- 12 640x480 60 Hz
                               OPTM_G_HDMI,                                         -- 13 720x480 59.94 Hz
                               OPTM_G_HDMI,                                         -- 14 800x600 60 Hz

                               OPTM_G_LINE,                                         -- 15
                               OPTM_G_CLOSE + OPTM_G_SUBMENU,                       -- 16 Back to main menu

                               -- VGA submenu
                               OPTM_G_SUBMENU,                                      -- 17 VGA: %s
                               OPTM_G_HEADLINE,                                     -- 18 VGA Display Mode
                               OPTM_G_LINE,                                         -- 19

                               OPTM_G_VGA_MODES + OPTM_G_STDSEL,                    -- 20 Standard

                               OPTM_G_LINE,                                         -- 21
                               OPTM_G_TEXT,                                         -- 22 Retro 15 kHz mode
                               OPTM_G_LINE,                                         -- 23

                               OPTM_G_VGA_MODES,                                    -- 24 15 kHz with HS/VS
                               OPTM_G_VGA_MODES,                                    -- 25 15 kHz with CSYNC

                               OPTM_G_LINE,                                         -- 26
                               OPTM_G_CLOSE + OPTM_G_SUBMENU,                       -- 27 Back to main menu

                               -- Audio
                               OPTM_G_LINE,                                         -- 28
                               OPTM_G_TEXT + OPTM_G_HEADLINE,                       -- 29 Audio Settings
                               OPTM_G_LINE,                                         -- 30

                               OPTM_G_Audio + OPTM_G_SINGLESEL,                     -- 31 Audio improvements

                               -- Controls
                               OPTM_G_LINE,                                         -- 32
                               OPTM_G_TEXT + OPTM_G_HEADLINE,                       -- 33 Control Settings
                               OPTM_G_LINE,                                         -- 34

                               -- Second fire
                               OPTM_G_SECOND_FIRE + OPTM_G_STDSEL,                  -- 35 POTX
                               OPTM_G_SECOND_FIRE,                                  -- 36 POTY

                               -- Player 1 POT polarity
                               OPTM_G_POTPOL,                                       -- 37 High
                               OPTM_G_POTPOL + OPTM_G_STDSEL,                       -- 38 Low

                               OPTM_G_LINE,                                         -- 39

                               -- DIP SW1 submenu
                               OPTM_G_SUBMENU,                                      -- 40 DIP SW1
                               OPTM_G_HEADLINE,                                     -- 41 SW1 Settings
                               OPTM_G_LINE,                                         -- 42

                               OPTM_G_SW1_0 + OPTM_G_SINGLESEL,                     -- 43 SW1-1
                               OPTM_G_SW1_1 + OPTM_G_SINGLESEL,                     -- 44 SW1-2
                               OPTM_G_SW1_2 + OPTM_G_SINGLESEL,                     -- 45 SW1-3
                               OPTM_G_SW1_3 + OPTM_G_SINGLESEL,                     -- 46 SW1-4
                               OPTM_G_SW1_4 + OPTM_G_SINGLESEL,                     -- 47 SW1-5
                               OPTM_G_SW1_5 + OPTM_G_SINGLESEL,                     -- 48 SW1-6
                               OPTM_G_SW1_6 + OPTM_G_SINGLESEL,                     -- 49 SW1-7
                               OPTM_G_SW1_7 + OPTM_G_SINGLESEL,                     -- 50 SW1-8

                               OPTM_G_LINE,                                         -- 51
                               OPTM_G_CLOSE + OPTM_G_SUBMENU,                       -- 52 Back to main menu

                               -- DIP SW2 submenu
                               OPTM_G_SUBMENU,                                      -- 53 DIP SW2
                               OPTM_G_HEADLINE,                                     -- 54 SW2 Settings
                               OPTM_G_LINE,                                         -- 55

                               OPTM_G_SW2_0 + OPTM_G_SINGLESEL + OPTM_G_STDSEL,     -- 56 SW2-1
                               OPTM_G_SW2_1 + OPTM_G_SINGLESEL,                     -- 57 SW2-2
                               OPTM_G_SW2_2 + OPTM_G_SINGLESEL,                     -- 58 SW2-3
                               OPTM_G_SW2_3 + OPTM_G_SINGLESEL + OPTM_G_STDSEL,     -- 59 SW2-4
                               OPTM_G_SW2_4 + OPTM_G_SINGLESEL,                     -- 60 SW2-5
                               OPTM_G_SW2_5 + OPTM_G_SINGLESEL,                     -- 61 SW2-6
                               OPTM_G_SW2_6 + OPTM_G_SINGLESEL,                     -- 62 SW2-7
                               OPTM_G_SW2_7 + OPTM_G_SINGLESEL,                     -- 63 SW2-8

                               OPTM_G_LINE,                                         -- 64
                               OPTM_G_CLOSE + OPTM_G_SUBMENU,                       -- 65 Back to main menu

                               OPTM_G_LINE,                                         -- 66
                               OPTM_G_CLOSE                                         -- 67 Close Menu
);


--------------------------------------------------------------------------------------------------------------------
-- Address Decoding
--------------------------------------------------------------------------------------------------------------------

begin

addr_decode : process(clk_i)
   -- return ASCII value of given string at the position defined by index (zero-based)
   pure function str2data(str : string; index : integer) return std_logic_vector is
   variable strpos : integer;
   begin
      strpos := index + 1;
      if strpos <= str'length then
         return std_logic_vector(to_unsigned(character'pos(str(strpos)), 16));
      else
         return X"0000"; -- zero terminated strings
      end if;
   end function str2data;

   -- return the dimensions of the Options menu
   pure function getDXDY(dx, dy, index: natural) return std_logic_vector is
   begin
      case index is
         when 0 => return std_logic_vector(to_unsigned(dx + 2, 16));
         when 1 => return std_logic_vector(to_unsigned(dy + 2, 16));
         when others => return X"0000";
      end case;
   end function getDXDY;

   -- convert bool to std_logic_vector
   pure function bool2slv(b: boolean) return std_logic_vector is
   begin
      if b then
         return x"0001";
      else
         return x"0000";
      end if;
   end function bool2slv;

   -- return the General Configuration settings
   function getGenConf(index: natural) return std_logic_vector is
   begin
      case index is
         when 1      => return std_logic_vector(to_unsigned(RESET_COUNTER, 16));
         when 2      => return bool2slv(OPTM_PAUSE);
         when 3      => return bool2slv(WELCOME_ACTIVE);
         when 4      => return bool2slv(WELCOME_AT_RESET);
         when 5      => return bool2slv(KEYBOARD_AT_RESET);
         when 6      => return bool2slv(JOY_1_AT_RESET);
         when 7      => return bool2slv(JOY_2_AT_RESET);
         when 8      => return bool2slv(KEYBOARD_AT_OSD);
         when 9      => return bool2slv(JOY_1_AT_OSD);
         when 10     => return bool2slv(JOY_2_AT_OSD);
         when 11     => return std_logic_vector(to_unsigned(ASCAL_USAGE, 16));
         when 12     => return std_logic_vector(to_unsigned(ASCAL_MODE, 16));
         when 13     => return std_logic_vector(to_unsigned(VD_ANTI_THRASHING_DELAY, 16));
         when 14     => return std_logic_vector(to_unsigned(VD_ITERATION_SIZE, 16));
         when 15     => return bool2slv(SAVE_SETTINGS);
         when others => return x"0000";
      end case;
   end function getGenConf;

   variable index           : integer;
   variable whs_page_index  : integer;
   variable whs_array_index : integer;

begin

   if falling_edge(clk_i) then

      index := to_integer(unsigned(address_i(11 downto 0)));
      whs_page_index  := to_integer(unsigned(address_i(19 downto 12)));
      whs_array_index := to_integer(unsigned(address_i(23 downto 20)));

      data_o <= x"EEEE";

      -----------------------------------------------------------------------------------
      -- Welcome & Help System: upper 4 bits of address equal SEL_WHS' upper 4 bits
      -----------------------------------------------------------------------------------

      if address_i(27 downto 24) = SEL_WHS(15 downto 12) then

         if  whs_array_index < WHS_RECORDS then
            if index = 4095 then
               data_o <= std_logic_vector(to_unsigned(WHS(whs_array_index).page_count, 16));
            else
               if index < WHS(whs_array_index).page_length(whs_page_index) then
                  data_o <= str2data(WHS_DATA, WHS(whs_array_index).page_start(whs_page_index) + index);
               else
                  data_o <= (others => '0'); -- zero-terminated strings
               end if;
            end if;
         end if;

      -----------------------------------------------------------------------------------
      -- All other selectors, which are 16-bit values
      -----------------------------------------------------------------------------------

      else

         case address_i(27 downto 12) is
            when SEL_GENERAL           => data_o <= getGenConf(index);
            when SEL_DIR_START         => data_o <= str2data(DIR_START, index);
            when SEL_CFG_FILE          => data_o <= str2data(CFG_FILE, index);
            when SEL_CORENAME          => data_o <= str2data(CORENAME, index);
            when SEL_OPTM_ITEMS        => data_o <= str2data(OPTM_ITEMS, index);
            when SEL_OPTM_MOUNT_STR    => data_o <= str2data(OPTM_S_MOUNT, index);
            when SEL_OPTM_CRTROM_STR   => data_o <= str2data(OPTM_S_CRTROM, index);
            when SEL_OPTM_SAVING_STR   => data_o <= str2data(OPTM_S_SAVING, index);
            when SEL_OPTM_GROUPS       => data_o <= std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(15)) &
                                                    std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(14)) & "0" &
                                                    std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(12)) & "0000" &
                                                    std_logic_vector(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(7 downto 0));
            when SEL_OPTM_STDSEL       => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(8));
            when SEL_OPTM_LINES        => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(9));
            when SEL_OPTM_START        => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(10));
            when SEL_OPTM_MOUNT_DRV    => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(11));
            when SEL_OPTM_HELP         => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(13));
            when SEL_OPTM_SINGLESEL    => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(15));
            when SEL_OPTM_CRTROM       => data_o <= x"000" & "000" & std_logic(to_unsigned(OPTM_GROUPS(index), OPTM_GTC)(16));
            when SEL_OPTM_ICOUNT       => data_o <= x"00" & std_logic_vector(to_unsigned(OPTM_SIZE, 8));
            when SEL_OPTM_DIMENSIONS   => data_o <= getDXDY(OPTM_DX, OPTM_DY, index);

            when others                => null;
         end case;
      end if;
   end if;
end process;

end architecture beh;

