extends StaticBody3D

## Shoot this to buy an ammo pack mid-round ($10). Works with or without ammo in the gun.
## After the flip tween finishes it becomes shootable again.

@export var reload_cost := 10
@export var flip_out_duration := 0.22
@export var flip_hold_duration := 0.35
@export var flip_back_duration := 0.28

@onready var main_col: CollisionShape3D = $main_col

var _busy := false
var _rest_rotation_y := 0.0
var _feedback_tween: Tween


func _ready() -> void:
	_rest_rotation_y = rotation.y
	add_to_group("Target")
	add_to_group("ammo_reload_target")
	visible = true
	EventBus.instance.open_shop.connect(_reset_for_next_round)


func _reset_for_next_round() -> void:
	_busy = false
	if _feedback_tween and _feedback_tween.is_valid():
		_feedback_tween.kill()
		_feedback_tween = null
	rotation.y = _rest_rotation_y
	if not is_in_group("Target"):
		add_to_group("Target")
	if not is_in_group("ammo_reload_target"):
		add_to_group("ammo_reload_target")
	show()


func start_bullet_to_target() -> void:
	pass


func hit_by_player(_damage: int, _screen_offset: Vector2 = Vector2.ZERO) -> void:
	if _busy:
		return
	_busy = true

	if is_in_group("Target"):
		remove_from_group("Target")

	_apply_ammo_reload()
	await _play_hit_feedback()
	_ready_to_shoot_again()


func _ready_to_shoot_again() -> void:
	rotation.y = _rest_rotation_y
	if not is_in_group("Target"):
		add_to_group("Target")
	if not is_in_group("ammo_reload_target"):
		add_to_group("ammo_reload_target")
	_busy = false


func _apply_ammo_reload() -> void:
	var player = get_tree().get_first_node_in_group("Player")
	if player == null:
		return

	var cost := reload_cost
	if cost > 0:
		if int(gl_PlayerState.dataset.cash) < cost:
			## Still allow the shot feedback; just skip the purchase if broke.
			return
		gl_PlayerState.dataset.cash = int(gl_PlayerState.dataset.cash) - cost
		if EventBus.instance.has_signal("purchase_made"):
			EventBus.instance.purchase_made.emit("ammo_reload_target")

	var pack := 12
	if player.has_method("get_ammo_pack_size"):
		pack = int(player.get_ammo_pack_size())
	if player.has_method("add_ammo"):
		player.add_ammo(pack, true)


func _play_hit_feedback() -> void:
	if has_node("hitSound"):
		$hitSound.play()

	if _feedback_tween and _feedback_tween.is_valid():
		_feedback_tween.kill()

	var flipped_y := _rest_rotation_y + PI
	_feedback_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_feedback_tween.tween_property(self, "rotation:y", flipped_y, flip_out_duration)
	_feedback_tween.tween_interval(flip_hold_duration)
	_feedback_tween.tween_property(self, "rotation:y", _rest_rotation_y, flip_back_duration)
	await _feedback_tween.finished
	_feedback_tween = null
