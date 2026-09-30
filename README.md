# Black Tiger - for MEGA65

Black Tiger is Capcom's 1987 arcade action-platform game. The player
takes control of a barbarian warrior and fights through vertically
scrolling stages filled with enemies, traps, treasure and hidden areas.

This project ports the Black Tiger FPGA core from **Jotego's JTCORES
project** to the MEGA65.

The upstream Black Tiger core used as the basis of this port is:

[Jotego JTCORES - Black
Tiger](https://github.com/jotego/jtcores/tree/90bab1b9dc7a6f190f78b6b51b54ba59476d3c53/cores/btiger)

The original Black Tiger FPGA implementation, JTFRAME infrastructure and
associated supporting cores are the work of **Jotego and the JTCORES
contributors**.


The MEGA65 port uses the
[MiSTer2MEGA65](https://github.com/sy2002/MiSTer2MEGA65) framework and
[QNICE-FPGA](https://github.com/sy2002/QNICE-FPGA) for integration with
the MEGA65, including FAT32 ROM loading and the on-screen menu.

## Credits

Black Tiger was originally developed and released by **Capcom** in 1987.

This MEGA65 core would not exist without the work of **Jotego and the
JTCORES contributors**. The MEGA65 version is based on the JTCORES Black
Tiger implementation at the revision linked above.

Additional credit goes to **sy2002, MJoergen and the MiSTer2MEGA65
contributors** for the MiSTer2MEGA65 framework and QNICE-FPGA
integration used by this port.

## How to install the core

### 1. Obtain the Black Tiger ROM set

You need the MAME **Black Tiger** ROM set:

`blktiger.zip`

ROM files are **not included** with this repository.

The ROM conversion scripts expect the ZIP to contain the following
files:

``` text
bdu-02a.6e
bdu-03a.8e
bd-04.9e
bd-05.10e
bdu-01a.5e
bd-06.1l
bd-15.2n
bd-14.9b
bd-12.5b
bd-13.8b
bd-11.4b
bd-10.9a
bd-08.5a
bd-09.8a
bd-07.4a
bd.6k
bd01.8j
bd02.9j
bd03.11k
bd04.11l
```

The conversion will stop with an error if one of the required ROMs is
missing or has an unexpected size.

### 2. Generate the MEGA65 ROM images

Two ROM conversion scripts are provided:

-   `black_tiger.ps1` - Windows PowerShell
-   `black_tiger.sh` - Linux/macOS shell

The scripts read the files directly from `blktiger.zip`; you do **not**
need to extract the MAME ZIP first.

They also perform the transformations required by the MEGA65 port,
including the JTFRAME ROM interleaving and the object ROM address
reordering used by the sprite implementation.

#### Windows / PowerShell

Place `black_tiger.ps1` and `blktiger.zip` in the same directory and
run:

``` powershell
.\black_tiger.ps1 blktiger.zip
```

If Windows marks the downloaded PowerShell script as coming from the
Internet, you can unblock it with:

``` powershell
Unblock-File .\black_tiger.ps1
```

#### Linux / macOS

Place `black_tiger.sh` and `blktiger.zip` in the same directory.

Make the script executable if necessary:

``` bash
chmod +x black_tiger.sh
```

Then run:

``` bash
./black_tiger.sh blktiger.zip
```

The shell version requires `bash`, `unzip` and `perl`.

### 3. Generated ROM files

By default the scripts create a directory named:

``` text
btiger_roms
```

containing:

``` text
btiger_main.rom
btiger_sound.rom
btiger_char.rom
btiger_tiles.rom
btiger_obj.rom
btiger_mcu.rom
btiger_prom.rom
```

The expected sizes are:

  File                        Size
  -------------------- -----------
  `btiger_main.rom`      `0x48000`
  `btiger_sound.rom`     `0x08000`
  `btiger_char.rom`      `0x08000`
  `btiger_tiles.rom`     `0x40000`
  `btiger_obj.rom`       `0x40000`
  `btiger_mcu.rom`       `0x01000`
  `btiger_prom.rom`      `0x00400`

The complete generated ROM payload is `0xD9400` bytes.

You can optionally specify another output directory.

PowerShell:

``` powershell
.\black_tiger.ps1 blktiger.zip my_roms
```

Linux/macOS:

``` bash
./black_tiger.sh blktiger.zip my_roms
```

### 4. Copy the ROMs to the MEGA65 SD card

Copy the generated Black Tiger ROM files to the directory expected by
the Black Tiger core on your MEGA65 SD card.

The folder where the ROMs reside must be /blktiger

Both the bottom SD card slot and the rear SD card slot can be used. As
with other MEGA65 cores, the rear SD card takes precedence when both are
present.

Install the Black Tiger `.cor` file using the normal MEGA65 core
installation procedure.

## Game setup

Press the **HELP** key while the core is running to open the
MiSTer2MEGA65 on-screen menu.

The menu provides display, audio, control and DIP-switch settings for
the core.

### Video output

The core supports the MiSTer2MEGA65 digital video modes as well as
analog/VGA output modes.

The VGA menu provides:

-   Standard output
-   Retro 15 kHz mode with separate HS/VS
-   Retro 15 kHz mode with CSYNC

### Controls

The MEGA65 joystick ports are used for the arcade controls.

The menu also contains configuration for the second fire button using
the MEGA65 POT lines, including POTX/POTY selection and polarity
settings for the joystick port 1.

If Black Tiger jumps on its own when the game starts, simply alternate the polarity.  

Keyboard controls are recommended if you don't use an arcade style fight stick.  

Cocktail mode is not supported by this core, leave the game in Upright mode.
In this mode, 2 player games share the single joystick in port 1.

### DIP switches

The original Black Tiger arcade DIP switches can be configured from the
on-screen menu.

The DIP-switch menus expose the individual SW1 and SW2 settings so the
arcade configuration can be adjusted from the MEGA65.

## Upstream projects

This port builds upon the work of several open-source FPGA projects:

-   [Jotego JTCORES](https://github.com/jotego/jtcores)
-   [Black Tiger core in JTCORES - pinned upstream
    revision](https://github.com/jotego/jtcores/tree/90bab1b9dc7a6f190f78b6b51b54ba59476d3c53/cores/btiger)
-   [MiSTer2MEGA65](https://github.com/sy2002/MiSTer2MEGA65)
  
Please support the upstream projects and developers whose work made this
MEGA65 port possible.

## Status

This is an initial MEGA65 release of the Black Tiger core.

Please report MEGA65-specific problems through the Black Tiger MEGA65
project rather than to the upstream JTCORES project unless the problem
has also been reproduced on the original upstream implementation.
