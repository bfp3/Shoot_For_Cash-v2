extends "res://ch/Rocks/checkpoint.gd"
## Scripted BANK CASH / +1 Multiplier balloon. Shooting one dismisses the other.

signal ladder_choice_taken(kind: String)

const BANK_REST_POS := Vector3(-2.8, 3.5, 22.5)
const MULT_REST_POS := Vector3(2.8, 3.5, 22.5)

@export var choice_kind := "bank"

var _choice_emitted := false


func default_rest_pos() -> Vector3:
	return MULT_REST_POS if choice_kind == "multiply" else BANK_REST_POS


func _ready() -> void:
	if choice_kind == "multiply":
		balloon_type = BalloonType.ORANGE
		default_balloon_type = BalloonType.ORANGE
	else:
		balloon_type = BalloonType.WHITE
		default_balloon_type = BalloonType.WHITE
	penalty_amount = 0
	original_penalty_amount = 0
	add_to_group("ladder_choice")
	configure_balloon_colour()
	_apply_choice_material()
	_add_choice_label()
	hide()
	disable_collision()
	set_process_input(false)


func _apply_choice_material() -> void:
	var balloon_mesh := get_node_or_null("Mesh/small_rock2") as MeshInstance3D
	if balloon_mesh == null:
		return
	if choice_kind == "multiply":
		balloon_mesh.material_override = BALLOON_MAT_MULTIPLIER_BALLOON
	else:
		balloon_mesh.material_override = BALLOON_MAT_BANK_BALLOON


func _add_choice_label() -> void:
	if has_node("ChoiceLabel"):
		return
	var label := Label3D.new()
	label.name = "ChoiceLabel"
	if choice_kind == "multiply":
		label.text = "+1 Multiplier"
		label.font_size = 64
		label.modulate = Color(1, 0.92, 0.55, 1)
	else:
		label.text = "BANK\nCASH"
		label.font_size = 80
		label.modulate = Color(0.95, 0.95, 0.9, 1)
	label.outline_size = 16
	label.position = Vector3(0, 1.35, 0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	add_child(label)


func _consume_by_player() -> void:
	if _consumed:
		return
	_consumed = true
	rock_activated = false
	_stop_bob()
	if has_node("AnimationPlayer"):
		$AnimationPlayer.stop()
	enter_state(State.HIT)
	disable_collision()
	if is_in_group("Target"):
		remove_from_group("Target")
	is_deactivated = true
	if has_node("pop_balloon"):
		$pop_balloon.pitch_scale = randf_range(0.95, 1.1)
		$pop_balloon.play()
	play_destroy_sfx()
	_keep_playing_audio_after_free()
	if not _choice_emitted:
		_choice_emitted = true
		ladder_choice_taken.emit(choice_kind)
		_dismiss_sibling_choices()
		var round_manager = get_tree().get_first_node_in_group("round_manager")
		if round_manager and round_manager.has_method("apply_ladder_choice"):
			round_manager.apply_ladder_choice(choice_kind)
	await was_hit_tween()
	if is_instance_valid(self):
		queue_free()


func _dismiss_sibling_choices() -> void:
	for other in get_tree().get_nodes_in_group("ladder_choice"):
		if other == self or not is_instance_valid(other):
			continue
		if other.has_method("dismiss_without_shot"):
			other.dismiss_without_shot()
