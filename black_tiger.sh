#!/usr/bin/env bash
set -euo pipefail

usage() {
    echo "Usage: $0 blktiger.zip [output-directory]"
    exit 1
}

[[ $# -eq 1 || $# -eq 2 ]] || usage

ZIP_PATH=$1
OUTDIR=${2:-btiger_roms}

if [[ ! -f "$ZIP_PATH" ]]; then
    echo "ERROR: $ZIP_PATH does not exist" >&2
    exit 1
fi

for cmd in unzip perl cat wc; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: required command '$cmd' was not found" >&2
        exit 1
    fi
done

mkdir -p "$OUTDIR"
TMPDIR_BT=$(mktemp -d)
trap 'rm -rf "$TMPDIR_BT"' EXIT

read_rom() {
    local name=$1
    local expected=$2
    local output=$3

    if ! unzip -p "$ZIP_PATH" "$name" > "$output"; then
        echo "ERROR: Missing ROM: $name" >&2
        exit 1
    fi

    local size
    size=$(wc -c < "$output")
    if (( size != expected )); then
        printf 'ERROR: %s: expected 0x%X bytes, got 0x%X\n' \
            "$name" "$expected" "$size" >&2
        exit 1
    fi

    printf '  %-14s 0x%05X\n' "$name" "$size"
}

interleave16_map01_map10() {
    local a=$1
    local b=$2
    local output=$3

    perl -e '
        use strict;
        use warnings;

        my ($af, $bf, $outf) = @ARGV;

        open my $A, "<:raw", $af or die "$af: $!\n";
        open my $B, "<:raw", $bf or die "$bf: $!\n";
        open my $O, ">:raw", $outf or die "$outf: $!\n";

        local $/;
        my $a = <$A>;
        my $b = <$B>;

        die "16-bit interleave ROM sizes differ\n"
            unless length($a) == length($b);

        for (my $i = 0; $i < length($a); $i++) {
            print {$O} substr($a, $i, 1), substr($b, $i, 1);
        }
    ' "$a" "$b" "$output"
}

map12_single() {
    local input=$1
    local output=$2

    perl -e '
        use strict;
        use warnings;

        my ($inf, $outf) = @ARGV;

        open my $I, "<:raw", $inf or die "$inf: $!\n";
        open my $O, ">:raw", $outf or die "$outf: $!\n";

        local $/;
        my $data = <$I>;

        die "map=12 source must have an even size\n"
            if length($data) & 1;

        for (my $i = 0; $i < length($data); $i += 2) {
            print {$O} substr($data, $i + 1, 1), substr($data, $i, 1);
        }
    ' "$input" "$output"
}

sort_object_rom() {
    local input=$1
    local output=$2

    perl -e '
        use strict;
        use warnings;

        my ($inf, $outf) = @ARGV;

        open my $I, "<:raw", $inf or die "$inf: $!\n";
        open my $O, ">:raw", $outf or die "$outf: $!\n";

        local $/;
        my $data = <$I>;

        die sprintf(
            "Object ROM: expected 0x40000 bytes, got 0x%X\n",
            length($data)
        ) unless length($data) == 0x40000;

        my $out = "\0" x length($data);

        for (my $dst = 0; $dst < length($data); $dst++) {
            my $src =
                ($dst & ~0x7C) |
                (($dst & 0x04) << 4) |
                (($dst & 0x78) >> 1);

            substr($out, $dst, 1) = substr($data, $src, 1);
        }

        print {$O} $out;
    ' "$input" "$output"
}

check_size() {
    local file=$1
    local expected=$2
    local label=$3

    local size
    size=$(wc -c < "$file")

    if (( size != expected )); then
        printf 'ERROR: %s: expected 0x%X bytes, got 0x%X\n' \
            "$label" "$expected" "$size" >&2
        exit 1
    fi
}

write_rom() {
    local source=$1
    local name=$2
    local destination="$OUTDIR/$name"

    cp "$source" "$destination"

    local size
    size=$(wc -c < "$destination")
    printf 'Wrote %s  (0x%X bytes)\n' "$destination" "$size"
}

echo
echo "Reading Black Tiger ROMs:"

# Main CPU
read_rom "bdu-02a.6e" 0x10000 "$TMPDIR_BT/main_0"
read_rom "bdu-03a.8e" 0x10000 "$TMPDIR_BT/main_1"
read_rom "bd-04.9e"   0x10000 "$TMPDIR_BT/main_2"
read_rom "bd-05.10e"  0x10000 "$TMPDIR_BT/main_3"
read_rom "bdu-01a.5e" 0x08000 "$TMPDIR_BT/main_4"
cat "$TMPDIR_BT/main_0" "$TMPDIR_BT/main_1" "$TMPDIR_BT/main_2" \
    "$TMPDIR_BT/main_3" "$TMPDIR_BT/main_4" > "$TMPDIR_BT/main"

# Sound CPU
read_rom "bd-06.1l" 0x08000 "$TMPDIR_BT/sound"

# Characters: JTFRAME map="12"
read_rom "bd-15.2n" 0x08000 "$TMPDIR_BT/chars_raw"
map12_single "$TMPDIR_BT/chars_raw" "$TMPDIR_BT/chars"

# Tiles
read_rom "bd-14.9b" 0x10000 "$TMPDIR_BT/tile_14"
read_rom "bd-12.5b" 0x10000 "$TMPDIR_BT/tile_12"
read_rom "bd-13.8b" 0x10000 "$TMPDIR_BT/tile_13"
read_rom "bd-11.4b" 0x10000 "$TMPDIR_BT/tile_11"

interleave16_map01_map10 \
    "$TMPDIR_BT/tile_14" "$TMPDIR_BT/tile_12" "$TMPDIR_BT/tiles_0"
interleave16_map01_map10 \
    "$TMPDIR_BT/tile_13" "$TMPDIR_BT/tile_11" "$TMPDIR_BT/tiles_1"
cat "$TMPDIR_BT/tiles_0" "$TMPDIR_BT/tiles_1" > "$TMPDIR_BT/tiles"

# Sprites
read_rom "bd-10.9a" 0x10000 "$TMPDIR_BT/obj_10"
read_rom "bd-08.5a" 0x10000 "$TMPDIR_BT/obj_08"
read_rom "bd-09.8a" 0x10000 "$TMPDIR_BT/obj_09"
read_rom "bd-07.4a" 0x10000 "$TMPDIR_BT/obj_07"

interleave16_map01_map10 \
    "$TMPDIR_BT/obj_10" "$TMPDIR_BT/obj_08" "$TMPDIR_BT/objects_0"
interleave16_map01_map10 \
    "$TMPDIR_BT/obj_09" "$TMPDIR_BT/obj_07" "$TMPDIR_BT/objects_1"
cat "$TMPDIR_BT/objects_0" "$TMPDIR_BT/objects_1" > "$TMPDIR_BT/objects_raw"

# Restructure object ROM into the linear sprite layout expected by MEGA65.
sort_object_rom "$TMPDIR_BT/objects_raw" "$TMPDIR_BT/objects"

# 8751 MCU
read_rom "bd.6k" 0x01000 "$TMPDIR_BT/mcu"

# PROMs
read_rom "bd01.8j"  0x100 "$TMPDIR_BT/prom_0"
read_rom "bd02.9j"  0x100 "$TMPDIR_BT/prom_1"
read_rom "bd03.11k" 0x100 "$TMPDIR_BT/prom_2"
read_rom "bd04.11l" 0x100 "$TMPDIR_BT/prom_3"
cat "$TMPDIR_BT/prom_0" "$TMPDIR_BT/prom_1" \
    "$TMPDIR_BT/prom_2" "$TMPDIR_BT/prom_3" > "$TMPDIR_BT/proms"

# Sanity checks against Jotego's MRA
check_size "$TMPDIR_BT/main"    0x48000 "Main ROM"
check_size "$TMPDIR_BT/sound"   0x08000 "Sound ROM"
check_size "$TMPDIR_BT/chars"   0x08000 "Character ROM"
check_size "$TMPDIR_BT/tiles"   0x40000 "Tile ROM"
check_size "$TMPDIR_BT/objects" 0x40000 "Object ROM"
check_size "$TMPDIR_BT/mcu"     0x01000 "MCU ROM"
check_size "$TMPDIR_BT/proms"   0x00400 "PROM ROM"

echo
echo "Writing MEGA65 ROM images:"

write_rom "$TMPDIR_BT/main"    "btiger_main.rom"
write_rom "$TMPDIR_BT/sound"   "btiger_sound.rom"
write_rom "$TMPDIR_BT/chars"   "btiger_char.rom"
write_rom "$TMPDIR_BT/tiles"   "btiger_tiles.rom"
write_rom "$TMPDIR_BT/objects" "btiger_obj.rom"
write_rom "$TMPDIR_BT/mcu"     "btiger_mcu.rom"
write_rom "$TMPDIR_BT/proms"   "btiger_prom.rom"

echo
echo "Done."
echo "Expected total payload: 0xD9400 bytes"
