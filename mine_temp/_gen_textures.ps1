$ErrorActionPreference = "Stop"
$outDir = Join-Path $PSScriptRoot "textures"

function Hash([int]$x, [int]$y, [int]$s) {
    $n = [int64]$x * 374761393 + [int64]$y * 668265263 + [int64]$s * 1274126177
    $n = $n -band 0x7FFFFFFF
    return $n / 2147483647.0
}

function Mix([byte[]]$a, [byte[]]$b, [double]$t) {
    $t = [Math]::Max(0.0, [Math]::Min(1.0, $t))
    return [byte[]]@(
        [byte]([int]$a[0] + ([int]$b[0] - [int]$a[0]) * $t),
        [byte]([int]$a[1] + ([int]$b[1] - [int]$a[1]) * $t),
        [byte]([int]$a[2] + ([int]$b[2] - [int]$a[2]) * $t),
        [byte]([int]$a[3] + ([int]$b[3] - [int]$a[3]) * $t)
    )
}

function Write-Bmp([string]$name, [int]$w, [int]$h, $pixelFn) {
    $rowStride = $w * 4
    $pixelBytes = $rowStride * $h
    $fileSize = 54 + $pixelBytes
    $buf = New-Object byte[] $fileSize
    # BITMAPFILEHEADER
    $buf[0] = 0x42; $buf[1] = 0x4D
    [BitConverter]::GetBytes([int32]$fileSize).CopyTo($buf, 2)
    [BitConverter]::GetBytes([int32]54).CopyTo($buf, 10)
    # BITMAPINFOHEADER
    [BitConverter]::GetBytes([int32]40).CopyTo($buf, 14)
    [BitConverter]::GetBytes([int32]$w).CopyTo($buf, 18)
    [BitConverter]::GetBytes([int32]$h).CopyTo($buf, 22)
    [BitConverter]::GetBytes([int16]1).CopyTo($buf, 26)
    [BitConverter]::GetBytes([int16]32).CopyTo($buf, 28)
    $off = 54
    for ($y = 0; $y -lt $h; $y++) {
        for ($x = 0; $x -lt $w; $x++) {
            $c = & $pixelFn $x ($h - 1 - $y)
            $i = $off + ($y * $rowStride) + ($x * 4)
            $buf[$i]     = $c[2]
            $buf[$i + 1] = $c[1]
            $buf[$i + 2] = $c[0]
            $buf[$i + 3] = $c[3]
        }
    }
    $path = Join-Path $outDir "$name.bmp"
    [System.IO.File]::WriteAllBytes($path, $buf)
}

$dirtA = [byte[]]@(121, 85, 58, 255)
$dirtB = [byte[]]@(96, 64, 40, 255)
$grassA = [byte[]]@(79, 154, 54, 255)
$grassB = [byte[]]@(56, 122, 38, 255)
$grassC = [byte[]]@(102, 176, 62, 255)
$stoneA = [byte[]]@(132, 132, 132, 255)
$stoneB = [byte[]]@(108, 108, 108, 255)
$stoneC = [byte[]]@(156, 156, 154, 255)
$cobbleA = [byte[]]@(127, 127, 127, 255)
$logA = [byte[]]@(102, 76, 51, 255)
$logB = [byte[]]@(70, 50, 32, 255)
$logTopA = [byte[]]@(158, 116, 67, 255)
$leafA = [byte[]]@(48, 116, 32, 255)
$leafB = [byte[]]@(36, 92, 24, 255)
$waterA = [byte[]]@(38, 92, 198, 210)
$cloudA = [byte[]]@(245, 245, 250, 255)
$blackA = [byte[]]@(28, 28, 32, 255)
$redA = [byte[]]@(148, 18, 22, 255)
$goldA = [byte[]]@(232, 186, 64, 255)
$orangeA = [byte[]]@(214, 92, 18, 255)
$ironA = [byte[]]@(64, 64, 70, 255)

Write-Bmp "dirt" 16 16 {
    param($x,$y)
    $n = Hash $x $y 11
    Mix $dirtA $dirtB $n
}

Write-Bmp "grass_top" 16 16 {
    param($x,$y)
    $n = Hash $x $y 3
    $m = Hash $x $y 19
    $c = Mix $grassA $grassB $n
    if ($m -gt 0.72) { $c = Mix $c $grassC 0.7 }
    $c
}

Write-Bmp "grass_side" 16 16 {
    param($x,$y)
    $n = Hash $x $y 7
    $c = Mix $dirtA $dirtB $n
    $edge = 4 + [int]((Hash $x 0 41) * 2)
    if ($y -le $edge) {
        $g = Mix $grassA $grassB (Hash $x $y 5)
        if ($y -eq $edge) { $c = Mix $g $c 0.45 } else { $c = $g }
    }
    $c
}

Write-Bmp "stone" 16 16 {
    param($x,$y)
    $n = Hash $x $y 21
    $c = Mix $stoneA $stoneB $n
    if ((Hash $x $y 8) -gt 0.82) { $c = Mix $c $stoneC 0.8 }
    $c
}

Write-Bmp "cobble" 16 16 {
    param($x,$y)
    $n = Hash $x $y 33
    $c = Mix $cobbleA $stoneB $n
    if ((($x + $y * 3) % 5) -eq 0) { $c = Mix $c $stoneA 0.5 }
    $c
}

Write-Bmp "log_side" 16 16 {
    param($x,$y)
    $n = Hash $x $y 14
    $c = Mix $logA $logB $n
    if (($x -eq 0) -or ($x -eq 15)) { $c = Mix $c $logB 0.7 }
    $c
}

Write-Bmp "log_top" 16 16 {
    param($x,$y)
    $dx = $x - 7.5; $dy = $y - 7.5
    $r = [Math]::Sqrt($dx*$dx + $dy*$dy)
    if ($r -gt 7.2) { Mix $logB $logA 0.3 }
    elseif ([Math]::Abs($r - [Math]::Floor($r)) -lt 0.35) { Mix $logA $logB 0.6 }
    else { Mix $logTopA $logA (Hash $x $y 2) }
}

Write-Bmp "leaves" 16 16 {
    param($x,$y)
    $n = Hash $x $y 9
    if ($n -lt 0.28) { [byte[]]@(0,0,0,0) }
    else { $c = Mix $leafA $leafB $n; $c }
}

Write-Bmp "water" 16 16 {
    param($x,$y)
    $n = Hash $x $y 4
    $hi = [byte[]]@(72, 140, 220, 200)
    Mix $waterA $hi $n
}

Write-Bmp "cloud" 16 16 {
    param($x,$y)
    $n = Hash $x $y 6
    $b = [byte[]]@(228, 230, 240, 255)
    Mix $cloudA $b $n
}

Write-Bmp "black_block" 16 16 {
    param($x,$y)
    Mix $blackA ([byte[]]@(48,48,52,255)) (Hash $x $y 12)
}

Write-Bmp "red_wool" 16 16 {
    param($x,$y)
    Mix $redA ([byte[]]@(176, 28, 32, 255)) (Hash $x $y 17)
}

Write-Bmp "gold" 16 16 {
    param($x,$y)
    Mix $goldA ([byte[]]@(196, 148, 36, 255)) (Hash $x $y 15)
}

Write-Bmp "orange_wool" 16 16 {
    param($x,$y)
    Mix $orangeA ([byte[]]@(236, 120, 28, 255)) (Hash $x $y 18)
}

Write-Bmp "iron" 16 16 {
    param($x,$y)
    Mix $ironA ([byte[]]@(90,90,98,255)) (Hash $x $y 22)
}

Write-Bmp "sand" 16 16 {
    param($x,$y)
    Mix ([byte[]]@(219, 207, 143, 255)) ([byte[]]@(196, 180, 118, 255)) (Hash $x $y 10)
}

# Banner 16x32 — red field, gold ring + W
Write-Bmp "banner" 16 32 {
    param($x,$y)
    $c = Mix $redA ([byte[]]@(120, 12, 16, 255)) (Hash $x $y 1)
    # swallowtail: transparent lower V
    if ($y -gt 24) {
        $mid = 7.5
        $width = (32 - $y) * 1.6
        if ([Math]::Abs($x - $mid) -gt $width) { return [byte[]]@(0,0,0,0) }
    }
    $dx = $x - 7.5; $dy = $y - 10.0
    $r = [Math]::Sqrt($dx*$dx + $dy*$dy)
    if ($r -gt 5.1 -and $r -lt 6.4) { $c = $goldA }
    # W
    if ($y -ge 7 -and $y -le 14) {
        $onW = $false
        if ($x -eq 4 -or $x -eq 11) { $onW = $true }
        if ($x -eq 6 -and $y -ge 10) { $onW = $true }
        if ($x -eq 9 -and $y -ge 10) { $onW = $true }
        if ($x -eq 7 -and $y -ge 12) { $onW = $true }
        if ($x -eq 8 -and $y -ge 12) { $onW = $true }
        if ($onW) { $c = $goldA }
    }
    $c
}

# Ammo crate 16x16 with AMMO text
Write-Bmp "ammo" 16 16 {
    param($x,$y)
    $c = Mix $orangeA ([byte[]]@(180, 70, 12, 255)) (Hash $x $y 13)
    if ($x -eq 0 -or $x -eq 15 -or $y -eq 0 -or $y -eq 15) {
        $c = Mix $c ([byte[]]@(90, 40, 8, 255)) 0.6
    }
    $c
}

Write-Bmp "ammo_top" 16 16 {
    param($x,$y)
    $c = Mix ([byte[]]@(236, 120, 28, 255)) $orangeA (Hash $x $y 16)
    if ($x -eq 0 -or $x -eq 15 -or $y -eq 0 -or $y -eq 15) {
        $c = [byte[]]@(90, 40, 8, 255)
    }
    # AMMO 5-pixel font rows 5-10
    $glyph = @{
        5  = "1110101001010010"
        6  = "1010111001010010"
        7  = "1110101001010010"
        8  = "1010101001010010"
        9  = "1010101010101110"
        10 = "0000000000000000"
    }
    if ($glyph.ContainsKey($y)) {
        $row = $glyph[$y]
        if ($x -lt 16 -and $row[$x] -eq '1') {
            $c = [byte[]]@(255, 255, 255, 255)
        }
    }
    $c
}

Write-Bmp "fire" 16 16 {
    param($x,$y)
    $dx = ($x - 7.5) / 7.5
    $dy = (15.5 - $y) / 16.0
    $core = [Math]::Exp(-($dx*$dx)*3.2) * (1.0 - $dy * 0.15)
    $flick = 0.75 + 0.25 * [Math]::Sin(($x * 1.7 + $y * 2.3))
    $a = [Math]::Max(0.0, [Math]::Min(1.0, $core * $flick))
    if ($a -lt 0.08) { return [byte[]]@(0,0,0,0) }
    $r = [byte](255)
    $g = [byte][Math]::Min(255, 80 + $a * 180)
    $b = [byte][Math]::Min(255, 20 + $a * 40)
    [byte[]]@($r, $g, $b, [byte]($a * 255))
}

Write-Bmp "flower_yellow" 8 8 {
    param($x,$y)
    if ($x -eq 3 -or $x -eq 4) {
        if ($y -ge 3) { return [byte[]]@(48, 120, 32, 255) }
    }
    $dx = $x - 3.5; $dy = $y - 2.5
    if (($dx*$dx + $dy*$dy) -lt 4.2) { return [byte[]]@(236, 196, 48, 255) }
    [byte[]]@(0,0,0,0)
}

Write-Bmp "flower_red" 8 8 {
    param($x,$y)
    if ($x -eq 3 -or $x -eq 4) {
        if ($y -ge 3) { return [byte[]]@(48, 120, 32, 255) }
    }
    $dx = $x - 3.5; $dy = $y - 2.5
    if (($dx*$dx + $dy*$dy) -lt 4.2) { return [byte[]]@(196, 36, 36, 255) }
    [byte[]]@(0,0,0,0)
}

Write-Bmp "sun" 16 16 {
    param($x,$y)
    [byte[]]@(255, 236, 170, 255)
}

Write-Output "wrote textures"
Get-ChildItem $outDir | Select-Object Name, Length
