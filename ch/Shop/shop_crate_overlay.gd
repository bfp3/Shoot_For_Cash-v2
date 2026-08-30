extends SubViewportContainer
## Rotating 3D crate overlay for the shop panel.
## Visible only while the shop is open (driven by Shop_Main_Menu).
##
## Where to move it:
## - In Shop_Main_Menu.tscn, select node `ShopCrateOverlay` and change its
##   Position / Offsets (anchors are centered on the shop root).
## - Or tweak `display_offset` below (pixels: +X right, +Y down).

@export var display_offset := Vector2(0, -40)
@export var rotation_speed_deg := 38.0
@export var crate_tilt_deg := 18.0

@onready var _pivot: Node3D = $SubViewport/CratePivot
@onready var _viewport: SubViewport = $SubViewport

var _rest_position := Vector2.ZERO


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	stretch = true
	_rest_position = position
	_apply_layout()
	if _pivot:
		_pivot.rotation_degrees.x = crate_tilt_deg
	hide_overlay()


func _process(delta: float) -> void:
	if not visible or _pivot == null:
		return
	_pivot.rotate_y(deg_to_rad(rotation_speed_deg) * delta)


func show_overlay() -> void:
	_apply_layout()
	if _viewport:
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	show()
	set_process(true)


func hide_overlay() -> void:
	hide()
	set_process(false)
	if _viewport:
		_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED


func _apply_layout() -> void:
	position = _rest_position + display_offset
