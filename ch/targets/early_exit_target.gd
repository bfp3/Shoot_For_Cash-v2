extends StaticBody3D

## Shoot this to abort the current round and return to the shop (works with or without ammo).

@onready var main_col: CollisionShape3D = $main_col

var _triggered := false
var _rest_scale := Vector3.ONE


func _ready() -> void:
	_rest_scale = scale
	add_to_group('Target')
	add_to_group('early_exit_target')
	visible = true
	EventBus.instance.open_shop.connect(_reset_for_next_round)


func _reset_for_next_round() -> void:
	_triggered = false
	scale = _rest_scale
	if not is_in_group('Target'):
		add_to_group('Target')
	if not is_in_group('early_exit_target'):
		add_to_group('early_exit_target')
	show()


func start_bullet_to_target() -> void:
	pass


func hit_by_player(_damage: int, _screen_offset: Vector2 = Vector2.ZERO) -> void:
	if _triggered:
		return
	_triggered = true

	if is_in_group('Target'):
		remove_from_group('Target')

	_play_hit_feedback()

	var round_manager = get_tree().get_first_node_in_group('round_manager')
	if round_manager and round_manager.has_method('abort_round_to_shop'):
		round_manager.abort_round_to_shop()


func _play_hit_feedback() -> void:
	if has_node('hitSound'):
		$hitSound.play()
	
	var orig_scale = self.scale
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, 'scale', _rest_scale * 1.15, 0.08)
	tween.tween_property(self, 'scale', Vector3.ZERO, 0.2)
	tween.tween_interval(2.0)
	tween.tween_property(self, 'scale', orig_scale, 0.9)
	await tween.finished
	
