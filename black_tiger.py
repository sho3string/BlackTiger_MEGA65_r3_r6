#!/usr/bin/env python3

import sys
import zipfile
from pathlib import Path


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def read_rom(zf, name, expected_size):
    try:
        data = zf.read(name)
    except KeyError:
        raise RuntimeError(f"Missing ROM: {name}")

    if len(data) != expected_size:
        raise RuntimeError(
            f"{name}: expected 0x{expected_size:X} bytes, "
            f"got 0x{len(data):X}"
        )

    print(f"  {name:<14} 0x{len(data):05X}")
    return data


def write_rom(outdir, name, data):
    path = outdir / name
    path.write_bytes(data)
    print(f"Wrote {path}  (0x{len(data):X} bytes)")


def interleave16_map01_map10(a, b):
    """
    JTFRAME:

        <interleave output="16">
            <part ... map="01"/>
            <part ... map="10"/>
        </interleave>

    Produces one 16-bit word from one byte of each source ROM.
    """

    if len(a) != len(b):
        raise RuntimeError("16-bit interleave ROM sizes differ")

    out = bytearray(len(a) * 2)

    for i in range(len(a)):
        out[i * 2 + 0] = a[i]
        out[i * 2 + 1] = b[i]

    return bytes(out)


def map12_single(data):
    """
    JTFRAME:

        <interleave output="16">
            <part ... map="12"/>
        </interleave>

    A single 8-bit ROM is consumed as 16-bit words with its two bytes
    reversed within each word.
    """

    if len(data) & 1:
        raise RuntimeError("map=12 source must have an even size")

    out = bytearray(len(data))

    for i in range(0, len(data), 2):
        out[i + 0] = data[i + 1]
        out[i + 1] = data[i + 0]

    return bytes(out)


# ---------------------------------------------------------------------------
# Black Tiger
# ---------------------------------------------------------------------------

def build(zip_path, outdir):
    outdir.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(zip_path, "r") as zf:

        print("\nReading Black Tiger ROMs:")

        # ------------------------------------------------------------------
        # Main CPU
        #
        # Jotego MRA:
        #
        # bdu-02a.6e
        # bdu-03a.8e
        # bd-04.9e
        # bd-05.10e
        # bdu-01a.5e
        #
        # Total = $48000
        # ------------------------------------------------------------------

        main = b"".join([
            read_rom(zf, "bdu-02a.6e", 0x10000),
            read_rom(zf, "bdu-03a.8e", 0x10000),
            read_rom(zf, "bd-04.9e",   0x10000),
            read_rom(zf, "bd-05.10e",  0x10000),
            read_rom(zf, "bdu-01a.5e", 0x08000),
        ])

        # ------------------------------------------------------------------
        # Sound CPU
        # ------------------------------------------------------------------

        sound = read_rom(zf, "bd-06.1l", 0x08000)

        # ------------------------------------------------------------------
        # Characters
        #
        # MRA:
        #
        # <interleave output="16">
        #     <part name="bd-15.2n" map="12"/>
        # </interleave>
        # ------------------------------------------------------------------

        chars_raw = read_rom(zf, "bd-15.2n", 0x08000)
        chars = map12_single(chars_raw)

        # ------------------------------------------------------------------
        # Tiles
        #
        # $58000-$77fff:
        #   bd-14.9b map=01
        #   bd-12.5b map=10
        #
        # $78000-$97fff:
        #   bd-13.8b map=01
        #   bd-11.4b map=10
        # ------------------------------------------------------------------

        tile_14 = read_rom(zf, "bd-14.9b", 0x10000)
        tile_12 = read_rom(zf, "bd-12.5b", 0x10000)
        tile_13 = read_rom(zf, "bd-13.8b", 0x10000)
        tile_11 = read_rom(zf, "bd-11.4b", 0x10000)

        tiles = (
            interleave16_map01_map10(tile_14, tile_12) +
            interleave16_map01_map10(tile_13, tile_11)
        )

        # ------------------------------------------------------------------
        # Sprites
        #
        # $98000-$b7fff:
        #   bd-10.9a map=01
        #   bd-08.5a map=10
        #
        # $b8000-$d7fff:
        #   bd-09.8a map=01
        #   bd-07.4a map=10
        # ------------------------------------------------------------------

        obj_10 = read_rom(zf, "bd-10.9a", 0x10000)
        obj_08 = read_rom(zf, "bd-08.5a", 0x10000)
        obj_09 = read_rom(zf, "bd-09.8a", 0x10000)
        obj_07 = read_rom(zf, "bd-07.4a", 0x10000)

        objects = (
            interleave16_map01_map10(obj_10, obj_08) +
            interleave16_map01_map10(obj_09, obj_07)
        )

        # ------------------------------------------------------------------
        # 8751 MCU
        # ------------------------------------------------------------------

        mcu = read_rom(zf, "bd.6k", 0x01000)

        # ------------------------------------------------------------------
        # PROMs
        # ------------------------------------------------------------------

        proms = b"".join([
            read_rom(zf, "bd01.8j",  0x100),
            read_rom(zf, "bd02.9j",  0x100),
            read_rom(zf, "bd03.11k", 0x100),
            read_rom(zf, "bd04.11l", 0x100),
        ])

    # Sanity checks against Jotego's MRA
    assert len(main)    == 0x48000
    assert len(sound)   == 0x08000
    assert len(chars)   == 0x08000
    assert len(tiles)   == 0x40000
    assert len(objects) == 0x40000
    assert len(mcu)     == 0x01000
    assert len(proms)   == 0x00400

    print("\nWriting MEGA65 ROM images:")

    write_rom(outdir, "btiger_main.rom",  main)
    write_rom(outdir, "btiger_sound.rom", sound)
    write_rom(outdir, "btiger_char.rom",  chars)
    write_rom(outdir, "btiger_tiles.rom", tiles)
    write_rom(outdir, "btiger_obj.rom",   objects)
    write_rom(outdir, "btiger_mcu.rom",   mcu)
    write_rom(outdir, "btiger_prom.rom",  proms)

    print("\nDone.")
    print("Expected total payload: 0xD9400 bytes")


if __name__ == "__main__":
    if len(sys.argv) not in (2, 3):
        print(f"Usage: {sys.argv[0]} blktiger.zip [output-directory]")
        sys.exit(1)

    zip_path = Path(sys.argv[1])
    outdir = Path(sys.argv[2]) if len(sys.argv) == 3 else Path("btiger_roms")

    if not zip_path.exists():
        print(f"ERROR: {zip_path} does not exist")
        sys.exit(1)

    try:
        build(zip_path, outdir)
    except Exception as e:
        print(f"\nERROR: {e}")
        sys.exit(1)