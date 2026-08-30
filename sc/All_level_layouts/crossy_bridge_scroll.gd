extends Node3D
## Per-layout forward scroll: on a successful shot of rock / rock-stay,
## smoothly slide this layout so it feels like travelling backwards.
## Attach to each level layout's root Node3D. Toggle with `enabled` — only active layouts scroll.

## When false, this layout never scrolls (default). Turn on per level that needs it.
@export var enabled := true
## World units to move the layout per successful shot.
@export var step_distance := 5.0
## Direction treated as "forward" for the layout (default +Z into the scene).
@export var forward_axis := Vector3(1, 0, 0)
@export var lerp_duration := 0.35
@export var lerp_trans := Tween.TRANS_CUBIC
@export var lerp_ease := Tween.EASE_OUT
## Smooth return to start when the shop opens (fail) or after a level transition.
@export var reset_lerp_duration := 0.55

## Dataset keys / rock_type_name values that trigger a step.
@export var trigger_items: PackedStringArray = PackedStringArray([
	"rock_type_1",
	"rock_type_stay",
])

var _base_position := Vector3.ZERO
var _target_offset := Vector3.ZERO
var _move_tween: Tween


func _ready() -> void:
	_base_position = position
	forward_axis = forward_axis.normalized()
	if forward_axis.length_squared() < 0.0001:
		forward_axis = Vector3.FORWARD
	if not enabled:
		return
	if EventBus.instance:
		if EventBus.instance.has_signal("rock_hit_logged"):
			EventBus.instance.rock_hit_logged.connect(_on_rock_hit_logged)
		## Fail → shop, and shop-after-travel arrival.
		if EventBus.instance.has_signal("open_shop"):
			EventBus.instance.open_shop.connect(_on_open_shop)
		## Fresh run / hard restart.
		if EventBus.instance.has_signal("level_restarted"):
			EventBus.instance.level_restarted.connect(_on_level_transition_reset)


func _exit_tree() -> void:
	if EventBus.instance == null:
		return
	if EventBus.instance.rock_hit_logged.is_connected(_on_rock_hit_logged):
		EventBus.instance.rock_hit_logged.disconnect(_on_rock_hit_logged)
	if EventBus.instance.open_shop.is_connected(_on_open_shop):
		EventBus.instance.open_shop.disconnect(_on_open_shop)
	if EventBus.instance.level_restarted.is_connected(_on_level_transition_reset):
		EventBus.instance.level_restarted.disconnect(_on_level_transition_reset)


func _on_rock_hit_logged(item: String, _item_type: String, value: int) -> void:
	if not enabled:
		return
	## Stay-timeout and other zero-cash fails don't count as a successful shot.
	if value <= 0:
		return
	if not _is_trigger_item(item):
		return
	advance_step()


func _on_open_shop() -> void:
	if not enabled:
		return
	reset_scroll_smooth()


func _on_level_transition_reset() -> void:
	if not enabled:
		return
	reset_scroll_smooth()


func _is_trigger_item(item: String) -> bool:
	for key in trigger_items:
		if item == key or item.contains(key):
			return true
	return false


func advance_step() -> void:
	if not enabled:
		return
	_target_offset += forward_axis * step_distance
	_tween_to_target(lerp_duration)


func reset_scroll() -> void:
	if _move_tween:
		_move_tween.kill()
		_move_tween = null
	_target_offset = Vector3.ZERO
	position = _base_position


func reset_scroll_smooth() -> void:
	if _target_offset.length_squared() < 0.0001 and position.distance_squared_to(_base_position) < 0.0001:
		return
	_target_offset = Vector3.ZERO
	_tween_to_target(reset_lerp_duration)


func _tween_to_target(duration: float) -> void:
	if _move_tween:
		_move_tween.kill()
	_move_tween = create_tween().set_trans(lerp_trans).set_ease(lerp_ease)
	_move_tween.tween_property(self, "position", _base_position + _target_offset, maxf(duration, 0.01))
