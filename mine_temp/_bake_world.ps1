$ErrorActionPreference = "Stop"
[System.Globalization.CultureInfo]::CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture
$outPath = Join-Path $PSScriptRoot "scenes\mine_world.tscn"

function Hash01([int]$x, [int]$z, [int]$salt) {
    $n = [int64]$x * 374761393 + [int64]$z * 668265263 + [int64]$salt * 1274126177
    $n = $n -band 0x7FFFFFFF
    return $n / 2147483647.0
}
function Smoothstep([double]$e0, [double]$e1, [double]$x) {
    $t = [Math]::Max(0.0, [Math]::Min(1.0, ($x - $e0) / ($e1 - $e0)))
    return $t * $t * (3.0 - 2.0 * $t)
}
function InPond([int]$x, [int]$z) { return ($x -ge -5 -and $x -le 4 -and $z -ge 16 -and $z -le 24) }
function PondRim([int]$x, [int]$z) {
    if ($x -ge -6 -and $x -le 5 -and $z -ge 15 -and $z -le 25) { return -not (InPond $x $z) }
    return $false
}
function TowerFoot([int]$x, [int]$z) {
    if ([Math]::Abs($x + 16) -le 2 -and [Math]::Abs($z - 11) -le 2) { return -1 }
    if ([Math]::Abs($x - 16) -le 2 -and [Math]::Abs($z - 11) -le 2) { return 1 }
    return 0
}
function GroundH([int]$x, [int]$z) {
    $h = 0
    if ($x -gt 5 -and $z -gt 16) {
        $dx = [Math]::Max(0.0, [Math]::Min(1.0, ($x - 5) / 24.0))
        $dz = [Math]::Max(0.0, [Math]::Min(1.0, ($z - 16) / 42.0))
        $ridge = $dx * 13.0 * (Smoothstep 0.0 1.0 ($dz * 1.15))
        $ridge += ((Hash01 $x $z 3) - 0.5) * 2.4
        $ridge += [Math]::Sin($x * 0.35) * 0.8 + [Math]::Sin($z * 0.22) * 1.1
        $h = [Math]::Max(0, [int][Math]::Round($ridge))
    }
    if ((Hash01 $x $z 9) -gt 0.97 -and $h -eq 0) { $h = 1 }
    return $h
}

$cells = @{} # "x,y,z" -> @{kind=; group=; gid=}
function SetCell([int]$x, [int]$y, [int]$z, [string]$kind, [string]$group, [string]$gid) {
    $cells["$x,$y,$z"] = @{ kind = $kind; group = $group; gid = $gid; x = $x; y = $y; z = $z }
}
function HasCell([int]$x, [int]$y, [int]$z) { return $cells.ContainsKey("$x,$y,$z") }
function EraseCell([int]$x, [int]$y, [int]$z) { $cells.Remove("$x,$y,$z") }
function FillBox([int]$x0,[int]$y0,[int]$z0,[int]$x1,[int]$y1,[int]$z1,[string]$kind,[string]$group,[string]$gid) {
    $xa=[Math]::Min($x0,$x1); $xb=[Math]::Max($x0,$x1)
    $ya=[Math]::Min($y0,$y1); $yb=[Math]::Max($y0,$y1)
    $za=[Math]::Min($z0,$z1); $zb=[Math]::Max($z0,$z1)
    for ($x=$xa; $x -le $xb; $x++) {
        for ($y=$ya; $y -le $yb; $y++) {
            for ($z=$za; $z -le $zb; $z++) { SetCell $x $y $z $kind $group $gid }
        }
    }
}

# Terrain
for ($x = -30; $x -le 32; $x++) {
    for ($z = -8; $z -le 68; $z++) {
        if (InPond $x $z) {
            SetCell $x -1 $z "dirt" "terrain" "field"
            SetCell $x -2 $z "stone" "terrain" "field"
            continue
        }
        if (PondRim $x $z) {
            SetCell $x 0 $z "cobble" "terrain" "pond_rim"
            SetCell $x -1 $z "stone" "terrain" "pond_rim"
            continue
        }
        if ((TowerFoot $x $z) -ne 0) { continue }
        $h = GroundH $x $z
        for ($y = -2; $y -lt $h; $y++) {
            $kind = "dirt"
            if ($y -lt -1 -or ($h -ge 3 -and $y -lt $h - 2)) { $kind = "stone" }
            if ($y -eq $h - 1 -and $h -gt 0) {
                if ((Hash01 $x $z 21) -lt 0.72) { $kind = "grass" } else { $kind = "stone" }
            }
            SetCell $x $y $z $kind "terrain" "field"
        }
        if ($h -eq 0) {
            $top = "grass"
            if ((Hash01 $x $z 44) -gt 0.92) { $top = "stone" }
            elseif ((Hash01 $x $z 51) -gt 0.96) { $top = "dirt" }
            SetCell $x 0 $z $top "terrain" "field"
            SetCell $x -1 $z "dirt" "terrain" "field"
            if ((Hash01 $x $z 17) -gt 0.7) { SetCell $x -2 $z "stone" "terrain" "field" }
        } else {
            $cap = "grass"
            if ((Hash01 $x $z 7) -gt 0.55) { $cap = "stone" }
            SetCell $x $h $z $cap "terrain" "field"
        }
    }
}
for ($x = -5; $x -le 4; $x++) {
    for ($z = 16; $z -le 24; $z++) { SetCell $x -1 $z "stone" "terrain" "pond_floor" }
}

# Towers
foreach ($side in @(-1, 1)) {
    $cx = 16 * $side; $cz = 11
    $gid = $(if ($side -lt 0) { "left" } else { "right" })
    FillBox ($cx-2) 0 ($cz-2) ($cx+2) 2 ($cz+2) "cobble" "tower" $gid
    FillBox ($cx-2) -2 ($cz-2) ($cx+2) -1 ($cz+2) "stone" "tower" $gid
    FillBox ($cx-1) 3 ($cz-1) ($cx+1) 10 ($cz+1) "cobble" "tower" $gid
    for ($y = 8; $y -le 10; $y++) { EraseCell $cx $y $cz }
    FillBox $cx 11 $cz $cx 16 $cz "black" "tower" $gid
    SetCell $cx 17 $cz "iron" "tower" $gid
    $lx = $cx - $side
    SetCell $lx 6 $cz "cobble" "tower" $gid
    SetCell $lx 6 ($cz+1) "cobble" "tower" $gid
}

# Waterfall + cave
for ($i = 0; $i -le 11; $i++) {
    $y = 10 - $i
    $wz = 34 + [int]($i / 2)
    if ($y -lt 1) { $y = 1 }
    SetCell 18 $y $wz "water" "terrain" "waterfall"
    SetCell 19 $y $wz "water" "terrain" "waterfall"
}
for ($x = 24; $x -le 28; $x++) {
    for ($y = 1; $y -le 4; $y++) {
        for ($z = 42; $z -le 46; $z++) { EraseCell $x $y $z }
    }
    for ($z = 42; $z -le 46; $z++) { SetCell $x 0 $z "stone" "terrain" "cave" }
}
SetCell 24 3 43 "gold" "props" "torch"
SetCell 28 3 45 "gold" "props" "torch"

# Trees
$spots = @(
    @(-11,5,11),@(-20,6,18),@(-9,5,30),@(-22,5,6),@(-16,6,38),@(-6,5,46),
    @(5,5,12),@(8,6,34),@(22,6,20),@(12,5,48),@(26,7,30),@(4,5,40),
    @(-24,5,26),@(20,6,52),@(-3,5,8)
)
$treeIndex = 0
foreach ($s in $spots) {
    $tx = $s[0]; $trunk = $s[1]; $tz = $s[2]
    if ((InPond $tx $tz) -or ((TowerFoot $tx $tz) -ne 0)) { continue }
    $gid = "t$treeIndex"
    $treeIndex++
    $base = GroundH $tx $tz
    for ($y = $base + 1; $y -le $base + $trunk; $y++) {
        SetCell $tx $y $tz "log" "tree" $gid
    }
    $top = $base + $trunk
    for ($dx = -2; $dx -le 2; $dx++) {
        for ($dy = -1; $dy -le 2; $dy++) {
            for ($dz = -2; $dz -le 2; $dz++) {
                if ([Math]::Abs($dx) -eq 2 -and [Math]::Abs($dz) -eq 2 -and $dy -ne 0) { continue }
                if ($dy -eq 2 -and ([Math]::Abs($dx) + [Math]::Abs($dz) -gt 2)) { continue }
                if ($dx -eq 0 -and $dz -eq 0 -and $dy -le 0) { continue }
                if ((Hash01 ($tx+$dx) ($tz+$dz+$dy) 12) -lt 0.12) { continue }
                SetCell ($tx+$dx) ($top+$dy) ($tz+$dz) "leaves" "tree" $gid
            }
        }
    }
}

# Clouds
function AddCloud([int]$cx,[int]$cy,[int]$cz,[int]$w,[int]$d,[string]$gid) {
    for ($x = $cx; $x -lt $cx+$w; $x++) {
        for ($z = $cz; $z -lt $cz+$d; $z++) {
            if ((Hash01 $x $z 77) -lt 0.18) { continue }
            SetCell $x $cy $z "cloud" "cloud" $gid
            if ((Hash01 $x $z 78) -gt 0.72) { SetCell $x ($cy+1) $z "cloud" "cloud" $gid }
        }
    }
}
AddCloud -22 22 12 7 4 "c0"
AddCloud 4 24 28 9 5 "c1"
AddCloud 18 21 8 6 3 "c2"
AddCloud -8 26 40 8 4 "c3"
AddCloud 10 23 50 7 3 "c4"

# Props
SetCell 9 1 14 "ammo" "props" "ammo"
function Pyramid([int]$x,[int]$y,[int]$z,[string]$kind,[string]$gid) {
    SetCell $x $y $z $kind "props" $gid
    SetCell ($x+1) $y $z $kind "props" $gid
    SetCell $x $y ($z+1) $kind "props" $gid
    SetCell ($x+1) $y ($z+1) $kind "props" $gid
    SetCell $x ($y+1) $z $kind "props" $gid
}
Pyramid -6 1 15 "red" "pyr0"
Pyramid 5 1 15 "black" "pyr1"
Pyramid -6 1 25 "black" "pyr2"
Pyramid 5 1 25 "red" "pyr3"

function Buried($c) {
    $x=$c.x; $y=$c.y; $z=$c.z
    return (HasCell ($x+1) $y $z) -and (HasCell ($x-1) $y $z) -and
           (HasCell $x ($y+1) $z) -and (HasCell $x ($y-1) $z) -and
           (HasCell $x $y ($z+1)) -and (HasCell $x $y ($z-1))
}
function WorldPos($c) {
    return [pscustomobject]@{ x = $c.x + 0.5; y = $c.y + 0.5; z = $c.z + 0.5 }
}

$visible = @()
foreach ($c in $cells.Values) {
    if (-not (Buried $c)) { $visible += $c }
}

$mat = @{
    grass = "res://mine_temp/materials/mat_grass.tres"
    dirt = "res://mine_temp/materials/mat_dirt.tres"
    stone = "res://mine_temp/materials/mat_stone.tres"
    cobble = "res://mine_temp/materials/mat_cobble.tres"
    log = "res://mine_temp/materials/mat_log.tres"
    leaves = "res://mine_temp/materials/mat_leaves.tres"
    cloud = "res://mine_temp/materials/mat_cloud.tres"
    black = "res://mine_temp/materials/mat_black.tres"
    red = "res://mine_temp/materials/mat_red.tres"
    ammo = "res://mine_temp/materials/mat_ammo.tres"
    gold = "res://mine_temp/materials/mat_gold.tres"
    iron = "res://mine_temp/materials/mat_iron.tres"
    water = "res://mine_temp/materials/mat_water.tres"
}

function F([double]$n) { return ([string]::Format([System.Globalization.CultureInfo]::InvariantCulture, "{0:G9}", $n)) }

# Terrain multimesshes by kind
$terrainByKind = @{}
$instanceCubes = @() # MeshInstance3D groups
foreach ($c in $visible) {
    if ($c.group -eq "terrain") {
        if (-not $terrainByKind.ContainsKey($c.kind)) { $terrainByKind[$c.kind] = New-Object System.Collections.Generic.List[object] }
        $terrainByKind[$c.kind].Add($c)
    } else {
        $instanceCubes += $c
    }
}

$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('[gd_scene format=3 uid="uid://dfxc6a3q1bcf5"]')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('[ext_resource type="Environment" path="res://mine_temp/mine_sunset_env.tres" id="1_env"]')
[void]$sb.AppendLine('[ext_resource type="PackedScene" path="res://mine_temp/scenes/mine_brazier.tscn" id="2_brazier"]')
[void]$sb.AppendLine('[ext_resource type="Material" path="res://mine_temp/materials/mat_banner.tres" id="3_banner"]')
[void]$sb.AppendLine('[ext_resource type="Material" path="res://mine_temp/materials/mat_sun.tres" id="4_sun"]')
[void]$sb.AppendLine('[ext_resource type="Material" path="res://mine_temp/materials/mat_water.tres" id="5_water"]')
[void]$sb.AppendLine('[ext_resource type="Texture2D" path="res://mine_temp/textures/flower_yellow.bmp" id="6_fy"]')
[void]$sb.AppendLine('[ext_resource type="Texture2D" path="res://mine_temp/textures/flower_red.bmp" id="7_fr"]')
$matIds = @{}
$mid = 8
foreach ($k in $mat.Keys) {
    $matIds[$k] = $mid
    [void]$sb.AppendLine("[ext_resource type=`"Material`" path=`"$($mat[$k])`" id=`"$mid`"]")
    $mid++
}
[void]$sb.AppendLine('')
[void]$sb.AppendLine('[sub_resource type="BoxMesh" id="BoxMesh_block"]')
[void]$sb.AppendLine('size = Vector3(1, 1, 1)')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('[sub_resource type="BoxMesh" id="BoxMesh_water"]')
[void]$sb.AppendLine('size = Vector3(10, 0.55, 9)')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('[sub_resource type="BoxMesh" id="BoxMesh_sun"]')
[void]$sb.AppendLine('size = Vector3(7, 7, 0.4)')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('[sub_resource type="QuadMesh" id="QuadMesh_banner"]')
[void]$sb.AppendLine('size = Vector2(1.6, 3.2)')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('[sub_resource type="BoxShape3D" id="BoxShape_ground"]')
[void]$sb.AppendLine('size = Vector3(72, 1, 88)')
[void]$sb.AppendLine('')

$mmIndex = 0
$mmNames = @{}
foreach ($kind in $terrainByKind.Keys) {
    $pts = $terrainByKind[$kind]
    if ($pts.Count -eq 0) { continue }
    $id = "MultiMesh_$kind"
    $mmNames[$kind] = $id
    $buf = New-Object System.Text.StringBuilder
    $first = $true
    foreach ($c in $pts) {
        $p = WorldPos $c
        if (-not $first) { [void]$buf.Append(", ") }
        $first = $false
        [void]$buf.Append("1, 0, 0, $(F $p.x), 0, 1, 0, $(F $p.y), 0, 0, 1, $(F $p.z)")
    }
    [void]$sb.AppendLine("[sub_resource type=`"MultiMesh`" id=`"$id`"]")
    [void]$sb.AppendLine("transform_format = 1")
    [void]$sb.AppendLine("instance_count = $($pts.Count)")
    [void]$sb.AppendLine("mesh = SubResource(`"BoxMesh_block`")")
    [void]$sb.AppendLine("buffer = PackedFloat32Array($($buf.ToString()))")
    [void]$sb.AppendLine('')
    $mmIndex++
}

function Xform([double]$x,[double]$y,[double]$z) {
    return "transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, $(F $x), $(F $y), $(F $z))"
}
function XformS([double]$s,[double]$x,[double]$y,[double]$z) {
    return "transform = Transform3D($(F $s), 0, 0, 0, $(F $s), 0, 0, 0, $(F $s), $(F $x), $(F $y), $(F $z))"
}

[void]$sb.AppendLine('[node name="MineWorld" type="Node3D"]')
[void]$sb.AppendLine('transform = Transform3D(1, 0, 0, 0, 1, 0, 0, 0, 1, 0, -4, 0)')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('[node name="WorldEnvironment" type="WorldEnvironment" parent="."]')
[void]$sb.AppendLine('environment = ExtResource("1_env")')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('[node name="Lighting" type="Node3D" parent="."]')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('[node name="FillLight" type="OmniLight3D" parent="Lighting"]')
[void]$sb.AppendLine($(Xform -6 8 10))
[void]$sb.AppendLine('light_color = Color(1, 0.72, 0.42, 1)')
[void]$sb.AppendLine('light_energy = 0.85')
[void]$sb.AppendLine('light_volumetric_fog_energy = 0.5')
[void]$sb.AppendLine('omni_range = 42.0')
[void]$sb.AppendLine('omni_attenuation = 0.35')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('[node name="CaveLight" type="OmniLight3D" parent="Lighting"]')
[void]$sb.AppendLine($(Xform 26 3.2 44))
[void]$sb.AppendLine('light_color = Color(1, 0.55, 0.18, 1)')
[void]$sb.AppendLine('light_energy = 3.2')
[void]$sb.AppendLine('light_volumetric_fog_energy = 1.6')
[void]$sb.AppendLine('omni_range = 9.0')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('[node name="WaterfallLight" type="OmniLight3D" parent="Lighting"]')
[void]$sb.AppendLine($(Xform 18.5 6 36))
[void]$sb.AppendLine('light_color = Color(1, 0.4, 0.1, 1)')
[void]$sb.AppendLine('light_energy = 1.4')
[void]$sb.AppendLine('omni_range = 6.0')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('[node name="SquareSun" type="MeshInstance3D" parent="."]')
[void]$sb.AppendLine($(Xform -48 16 22))
[void]$sb.AppendLine('material_override = ExtResource("4_sun")')
[void]$sb.AppendLine('cast_shadow = 0')
[void]$sb.AppendLine('mesh = SubResource("BoxMesh_sun")')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('[node name="Terrain" type="Node3D" parent="."]')
[void]$sb.AppendLine('')

foreach ($kind in $terrainByKind.Keys) {
    if (-not $mmNames.ContainsKey($kind)) { continue }
    $nodeName = "Blocks_$kind"
    [void]$sb.AppendLine("[node name=`"$nodeName`" type=`"MultiMeshInstance3D`" parent=`"Terrain`"]")
    [void]$sb.AppendLine("material_override = ExtResource(`"$($matIds[$kind])`")")
    [void]$sb.AppendLine("multimesh = SubResource(`"$($mmNames[$kind])`")")
    [void]$sb.AppendLine('')
}

[void]$sb.AppendLine('[node name="Pond" type="Node3D" parent="."]')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('[node name="Water" type="MeshInstance3D" parent="Pond"]')
[void]$sb.AppendLine($(Xform -0.5 0.28 20))
[void]$sb.AppendLine('material_override = ExtResource("5_water")')
[void]$sb.AppendLine('cast_shadow = 0')
[void]$sb.AppendLine('mesh = SubResource("BoxMesh_water")')
[void]$sb.AppendLine('')

# Group instance cubes so each tree/tower/cloud/prop is a Node3D you can move in the editor.
$parentsMade = @{}
$groupOrigin = @{}
function EnsureParent([string]$path, [string]$name, [string]$parentPath) {
    $key = "$parentPath/$name"
    if ($parentsMade.ContainsKey($key)) { return }
    [void]$sb.AppendLine("[node name=`"$name`" type=`"Node3D`" parent=`"$parentPath`"]")
    if ($groupOrigin.ContainsKey($path)) {
        $o = $groupOrigin[$path]
        [void]$sb.AppendLine($(Xform $o.x $o.y $o.z))
    }
    [void]$sb.AppendLine('')
    $parentsMade[$key] = $true
}
function GroupPath($c) {
    if ($c.group -eq "tower") {
        $folder = $(if ($c.gid -eq "left") { "TowerLeft" } else { "TowerRight" })
        return [pscustomobject]@{ folder = $folder; parent = "Towers/$folder"; root = "Towers" }
    }
    if ($c.group -eq "tree") {
        $folder = "Tree_$($c.gid)"
        return [pscustomobject]@{ folder = $folder; parent = "Trees/$folder"; root = "Trees" }
    }
    if ($c.group -eq "cloud") {
        $folder = "Cloud_$($c.gid)"
        return [pscustomobject]@{ folder = $folder; parent = "Clouds/$folder"; root = "Clouds" }
    }
    $folder = $c.gid
    return [pscustomobject]@{ folder = $folder; parent = "Props/$folder"; root = "Props" }
}

$cubesByGroup = @{}
foreach ($c in $instanceCubes) {
    $g = GroupPath $c
    if (-not $cubesByGroup.ContainsKey($g.parent)) { $cubesByGroup[$g.parent] = New-Object System.Collections.Generic.List[object] }
    $cubesByGroup[$g.parent].Add($c)
}
foreach ($gpath in $cubesByGroup.Keys) {
    $list = $cubesByGroup[$gpath]
    $ox = 0.0; $oy = 0.0; $oz = 0.0
    foreach ($c in $list) {
        $p = WorldPos $c
        $ox += $p.x; $oy += $p.y; $oz += $p.z
    }
    $n = [double]$list.Count
    $groupOrigin[$gpath] = [pscustomobject]@{ x = $ox / $n; y = $oy / $n; z = $oz / $n }
}

EnsureParent "Towers" "Towers" "."
EnsureParent "Trees" "Trees" "."
EnsureParent "Clouds" "Clouds" "."
EnsureParent "Props" "Props" "."

$cubeCount = 0
foreach ($gpath in ($cubesByGroup.Keys | Sort-Object)) {
    $g0 = GroupPath $cubesByGroup[$gpath][0]
    EnsureParent $gpath $g0.folder $g0.root
    $o = $groupOrigin[$gpath]
    foreach ($c in $cubesByGroup[$gpath]) {
        $p = WorldPos $c
        $n = "Cube_$($c.x)_$($c.y)_$($c.z)"
        [void]$sb.AppendLine("[node name=`"$n`" type=`"MeshInstance3D`" parent=`"$gpath`"]")
        [void]$sb.AppendLine($(Xform ($p.x - $o.x) ($p.y - $o.y) ($p.z - $o.z)))
        [void]$sb.AppendLine("material_override = ExtResource(`"$($matIds[$c.kind])`")")
        [void]$sb.AppendLine('mesh = SubResource("BoxMesh_block")')
        [void]$sb.AppendLine('')
        $cubeCount++
    }
}

function LocalXform([string]$gpath, [double]$wx, [double]$wy, [double]$wz) {
    $o = $groupOrigin[$gpath]
    return (Xform ($wx - $o.x) ($wy - $o.y) ($wz - $o.z))
}
function LocalXformS([string]$gpath, [double]$s, [double]$wx, [double]$wy, [double]$wz) {
    $o = $groupOrigin[$gpath]
    return (XformS $s ($wx - $o.x) ($wy - $o.y) ($wz - $o.z))
}

EnsureParent "Towers/TowerLeft" "TowerLeft" "Towers"
EnsureParent "Towers/TowerRight" "TowerRight" "Towers"

[void]$sb.AppendLine('[node name="Banner" type="MeshInstance3D" parent="Towers/TowerLeft"]')
$ol = $groupOrigin["Towers/TowerLeft"]
[void]$sb.AppendLine("transform = Transform3D(-4.37114e-08, 0, 1, 0, 1, 0, -1, 0, -4.37114e-08, $(F (-14.2 - $ol.x)), $(F (8.2 - $ol.y)), $(F (11 - $ol.z)))")
[void]$sb.AppendLine('material_override = ExtResource("3_banner")')
[void]$sb.AppendLine('mesh = SubResource("QuadMesh_banner")')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('[node name="Brazier" parent="Towers/TowerLeft" instance=ExtResource("2_brazier")]')
[void]$sb.AppendLine($(LocalXformS "Towers/TowerLeft" 0.55 -15 7 11))
[void]$sb.AppendLine('')
[void]$sb.AppendLine('[node name="Banner" type="MeshInstance3D" parent="Towers/TowerRight"]')
$or = $groupOrigin["Towers/TowerRight"]
[void]$sb.AppendLine("transform = Transform3D(-4.37114e-08, 0, -1, 0, 1, 0, 1, 0, -4.37114e-08, $(F (14.2 - $or.x)), $(F (8.2 - $or.y)), $(F (11 - $or.z)))")
[void]$sb.AppendLine('material_override = ExtResource("3_banner")')
[void]$sb.AppendLine('mesh = SubResource("QuadMesh_banner")')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('[node name="Brazier" parent="Towers/TowerRight" instance=ExtResource("2_brazier")]')
[void]$sb.AppendLine($(LocalXformS "Towers/TowerRight" 0.55 15 7 11))
[void]$sb.AppendLine('')

[void]$sb.AppendLine('[node name="AmmoLabel" type="Label3D" parent="Props/ammo"]')
[void]$sb.AppendLine($(LocalXform "Props/ammo" 9.5 1.72 14.5))
[void]$sb.AppendLine('billboard = 1')
[void]$sb.AppendLine('pixel_size = 0.012')
[void]$sb.AppendLine('text = "AMMO"')
[void]$sb.AppendLine('font_size = 48')
[void]$sb.AppendLine('outline_size = 8')
[void]$sb.AppendLine('outline_modulate = Color(0.25, 0.08, 0, 1)')
[void]$sb.AppendLine('')

[void]$sb.AppendLine('[node name="Cave" type="Node3D" parent="."]')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('[node name="TorchA" parent="Cave" instance=ExtResource("2_brazier")]')
[void]$sb.AppendLine($(XformS 0.35 24.5 3 43.5))
[void]$sb.AppendLine('')
[void]$sb.AppendLine('[node name="TorchB" parent="Cave" instance=ExtResource("2_brazier")]')
[void]$sb.AppendLine($(XformS 0.35 28.5 3 45.5))
[void]$sb.AppendLine('')

[void]$sb.AppendLine('[node name="Flowers" type="Node3D" parent="."]')
[void]$sb.AppendLine('')
$fi = 0
for ($i = 0; $i -le 21; $i++) {
    $x = [int][Math]::Round((-18) + (10 - -18) * (Hash01 $i 2 90))
    $z = [int][Math]::Round(4 + (28 - 4) * (Hash01 $i 4 91))
    if ((InPond $x $z) -or ((TowerFoot $x $z) -ne 0)) { continue }
    if ((GroundH $x $z) -gt 0) { continue }
    $red = (Hash01 $i 1 92) -gt 0.55
    $tex = $(if ($red) { "7_fr" } else { "6_fy" })
    [void]$sb.AppendLine("[node name=`"Flower_$fi`" type=`"Sprite3D`" parent=`"Flowers`"]")
    [void]$sb.AppendLine($(Xform ($x+0.5) 1.15 ($z+0.5)))
    [void]$sb.AppendLine('pixel_size = 0.085')
    [void]$sb.AppendLine('billboard = 1')
    [void]$sb.AppendLine('shaded = true')
    [void]$sb.AppendLine('alpha_cut = 1')
    [void]$sb.AppendLine('texture_filter = 0')
    [void]$sb.AppendLine("texture = ExtResource(`"$tex`")")
    [void]$sb.AppendLine('')
    $fi++
}

[void]$sb.AppendLine('[node name="GroundCollision" type="StaticBody3D" parent="."]')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('[node name="CollisionShape3D" parent="GroundCollision"]')
[void]$sb.AppendLine($(Xform 1 0 30))
[void]$sb.AppendLine('shape = SubResource("BoxShape_ground")')
[void]$sb.AppendLine('')

[System.IO.File]::WriteAllText($outPath, $sb.ToString())
Write-Output "Wrote $outPath"
Write-Output "Terrain kinds: $($terrainByKind.Keys -join ', ')"
Write-Output "Instance cubes: $cubeCount  Flowers: $fi  Visible cells: $($visible.Count)"
