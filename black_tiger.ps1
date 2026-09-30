param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$ZipPath,

    [Parameter(Position=1)]
    [string]$OutputDirectory = "btiger_roms"
)

$ErrorActionPreference = "Stop"

function Read-Rom {
    param(
        [System.IO.Compression.ZipArchive]$Zip,
        [string]$Name,
        [int]$ExpectedSize
    )

    $entry = $Zip.GetEntry($Name)
    if ($null -eq $entry) {
        throw "Missing ROM: $Name"
    }

    $stream = $entry.Open()
    try {
        $ms = New-Object System.IO.MemoryStream
        $stream.CopyTo($ms)
        [byte[]]$data = $ms.ToArray()
    }
    finally {
        $stream.Dispose()
        if ($null -ne $ms) { $ms.Dispose() }
    }

    if ($data.Length -ne $ExpectedSize) {
        throw ("{0}: expected 0x{1:X} bytes, got 0x{2:X}" -f $Name, $ExpectedSize, $data.Length)
    }

    Write-Host ("  {0,-14} 0x{1:X5}" -f $Name, $data.Length)
    return ,$data
}

function Write-Rom {
    param(
        [string]$OutputDirectory,
        [string]$Name,
        [byte[]]$Data
    )

    $path = Join-Path $OutputDirectory $Name
    [System.IO.File]::WriteAllBytes($path, $Data)
    Write-Host ("Wrote {0}  (0x{1:X} bytes)" -f $path, $Data.Length)
}

function Join-ByteArrays {
    param([byte[][]]$Arrays)

    $length = 0
    foreach ($a in $Arrays) { $length += $a.Length }

    [byte[]]$out = New-Object byte[] $length
    $offset = 0
    foreach ($a in $Arrays) {
        [Array]::Copy($a, 0, $out, $offset, $a.Length)
        $offset += $a.Length
    }

    return ,$out
}

function Interleave16-Map01Map10 {
    param([byte[]]$A, [byte[]]$B)

    if ($A.Length -ne $B.Length) {
        throw "16-bit interleave ROM sizes differ"
    }

    [byte[]]$out = New-Object byte[] ($A.Length * 2)

    for ($i = 0; $i -lt $A.Length; $i++) {
        $out[$i * 2]     = $A[$i]
        $out[$i * 2 + 1] = $B[$i]
    }

    return ,$out
}

function Map12-Single {
    param([byte[]]$Data)

    if (($Data.Length -band 1) -ne 0) {
        throw "map=12 source must have an even size"
    }

    [byte[]]$out = New-Object byte[] $Data.Length

    for ($i = 0; $i -lt $Data.Length; $i += 2) {
        $out[$i]     = $Data[$i + 1]
        $out[$i + 1] = $Data[$i]
    }

    return ,$out
}

function Sort-ObjectRom {
    param([byte[]]$Data)

    if ($Data.Length -ne 0x40000) {
        throw ("Object ROM: expected 0x40000 bytes, got 0x{0:X}" -f $Data.Length)
    }

    [byte[]]$out = New-Object byte[] $Data.Length

    for ($dst = 0; $dst -lt $Data.Length; $dst++) {
        $src = (($dst -band (-bnot 0x7C)) -bor
                (($dst -band 0x04) -shl 4) -bor
                (($dst -band 0x78) -shr 1))
        $out[$dst] = $Data[$src]
    }

    return ,$out
}

if (-not (Test-Path -LiteralPath $ZipPath -PathType Leaf)) {
    Write-Error "ERROR: $ZipPath does not exist"
    exit 1
}

# Resolve output directory relative to where the script was launched
$OutputDirectory = [System.IO.Path]::GetFullPath(
    (Join-Path (Get-Location).Path $OutputDirectory)
)

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$zip = [System.IO.Compression.ZipFile]::OpenRead((Resolve-Path -LiteralPath $ZipPath))

try {
    Write-Host "`nReading Black Tiger ROMs:"

    # Main CPU
    $main = Join-ByteArrays @(
        (Read-Rom $zip "bdu-02a.6e" 0x10000),
        (Read-Rom $zip "bdu-03a.8e" 0x10000),
        (Read-Rom $zip "bd-04.9e"   0x10000),
        (Read-Rom $zip "bd-05.10e"  0x10000),
        (Read-Rom $zip "bdu-01a.5e" 0x08000)
    )

    # Sound CPU
    $sound = Read-Rom $zip "bd-06.1l" 0x08000

    # Characters: JTFRAME map="12"
    $charsRaw = Read-Rom $zip "bd-15.2n" 0x08000
    $chars = Map12-Single $charsRaw

    # Tiles
    $tile14 = Read-Rom $zip "bd-14.9b" 0x10000
    $tile12 = Read-Rom $zip "bd-12.5b" 0x10000
    $tile13 = Read-Rom $zip "bd-13.8b" 0x10000
    $tile11 = Read-Rom $zip "bd-11.4b" 0x10000

    $tiles = Join-ByteArrays @(
        (Interleave16-Map01Map10 $tile14 $tile12),
        (Interleave16-Map01Map10 $tile13 $tile11)
    )

    # Sprites
    $obj10 = Read-Rom $zip "bd-10.9a" 0x10000
    $obj08 = Read-Rom $zip "bd-08.5a" 0x10000
    $obj09 = Read-Rom $zip "bd-09.8a" 0x10000
    $obj07 = Read-Rom $zip "bd-07.4a" 0x10000

    $objectsRaw = Join-ByteArrays @(
        (Interleave16-Map01Map10 $obj10 $obj08),
        (Interleave16-Map01Map10 $obj09 $obj07)
    )

    # Restructure object ROM into the linear sprite layout expected by MEGA65.
    $objects = Sort-ObjectRom $objectsRaw

    # 8751 MCU
    $mcu = Read-Rom $zip "bd.6k" 0x01000

    # PROMs
    $proms = Join-ByteArrays @(
        (Read-Rom $zip "bd01.8j"  0x100),
        (Read-Rom $zip "bd02.9j"  0x100),
        (Read-Rom $zip "bd03.11k" 0x100),
        (Read-Rom $zip "bd04.11l" 0x100)
    )
}
finally {
    $zip.Dispose()
}

# Sanity checks
if ($main.Length    -ne 0x48000) { throw "Internal error: main ROM size" }
if ($sound.Length   -ne 0x08000) { throw "Internal error: sound ROM size" }
if ($chars.Length   -ne 0x08000) { throw "Internal error: char ROM size" }
if ($tiles.Length   -ne 0x40000) { throw "Internal error: tile ROM size" }
if ($objects.Length -ne 0x40000) { throw "Internal error: object ROM size" }
if ($mcu.Length     -ne 0x01000) { throw "Internal error: MCU ROM size" }
if ($proms.Length   -ne 0x00400) { throw "Internal error: PROM ROM size" }

Write-Host "`nWriting MEGA65 ROM images:"

Write-Rom $OutputDirectory "btiger_main.rom"  $main
Write-Rom $OutputDirectory "btiger_sound.rom" $sound
Write-Rom $OutputDirectory "btiger_char.rom"  $chars
Write-Rom $OutputDirectory "btiger_tiles.rom" $tiles
Write-Rom $OutputDirectory "btiger_obj.rom"   $objects
Write-Rom $OutputDirectory "btiger_mcu.rom"   $mcu
Write-Rom $OutputDirectory "btiger_prom.rom"  $proms

Write-Host "`nDone."
Write-Host "Expected total payload: 0xD9400 bytes"
