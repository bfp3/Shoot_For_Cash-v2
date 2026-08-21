extends "res://ch/Rocks/balloon.gd"
## Balloon-check: drifts up into centre, bobs in place, never leaves until shot.
## Shooting it saves this script cursor as the fail-resume point and clears strikes.

const REST_POS := Vector3(0.0, 3.5, 22.5)
const SPAWN_POS := Vector3(0.0, -12.0, 26.0)
## Seconds to rise from SPAWN_POS to REST_POS. Lower = faster.
const ARRIVE_DURATION := 1.0
const BOB_DISTANCE := 0.28
const BOB_DURATION := 1.35

var _bob_tween: Tween
var _arrived := false
var _consumed := false
var _rest_pos := REST_POS


func _ready() -> void:
	
	balloon_type = BalloonType.WHITE
	default_balloon_type = BalloonType.WHITE
	penalty_amount = 0
	original_penalty_amount = 0
	add_to_group("checkpoint")
	configure_balloon_colour()
	hide()
	disable_collision()
	set_process_input(false)
	

func arrive_from_below(rest: Vector3 = REST_POS) -> void:
	if transition_locked:
		return
	transition_locked = true
	_consumed = false
	_arrived = false
	_rest_pos = rest if rest.is_finite() else REST_POS
	var spawn := Vector3(_rest_pos.x, SPAWN_POS.y, SPAWN_POS.z)
	global_position = spawn
	start_pos = _rest_pos
	orig_start_pos = _rest_pos
	behind_player = false
	scale = Vector3.ONE * 1.7
	show()
	if has_node("Mesh"):
		$Mesh.show()
		$Mesh.scale = Vector3.ONE
	enter_state(State.ACTIVE)
	if has_node("AnimationPlayer"):
		$AnimationPlayer.stop()
	if has_node("balloon_blowing_up"):
		$balloon_blowing_up.play()
	if has_node("move_balloon"):
		$move_balloon.play()

	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "global_position", _rest_pos, ARRIVE_DURATION)
	await tween.finished
	if _consumed or not is_instance_valid(self):
		transition_locked = false
		return
	transition_locked = false
	_arrived = true
	_start_bob()
	if has_node("AnimationPlayer"):
		$AnimationPlayer.play("idle")


func _start_bob() -> void:
	_stop_bob()
	#$Checkpoint.play()
	_bob_tween = create_tween()
	_bob_tween.set_ease(Tween.EASE_IN_OUT)
	_bob_tween.set_trans(Tween.TRANS_SINE)
	_bob_tween.set_loops()
	_bob_tween.tween_property(self, "global_position:y", _rest_pos.y + BOB_DISTANCE, BOB_DURATION)
	_bob_tween.tween_property(self, "global_position:y", _rest_pos.y - BOB_DISTANCE, BOB_DURATION)


func _stop_bob() -> void:
	if _bob_tween and _bob_tween.is_valid():
		_bob_tween.kill()
	_bob_tween = null
	stop_gentle_pan()


func is_blocking_sky() -> bool:
	return not _consumed and rock_activated


func hit_by_player(damage: int, _screen_offset: Vector2 = Vector2.ZERO) -> void:
	if _consumed or not rock_activated:
		return
	if not visible and has_node("Mesh") and $Mesh.visible == false:
		return
	health -= damage
	_consume_by_player()


func rock_pop_balloon() -> void:
	## Rocks / pineapples must not clear a balloon-check — only a player shot does.
	return


func _on_area_3d_body_entered(_body: Node3D) -> void:
	return


func start_destroyed_process() -> void:
	## Ignore generic hazard destroy — balloon-check only pops from a player shot.
	smoke_particles()
	return


func _consume_by_player() -> void:
	if _consumed:
		return
	$Checkpoint.play()
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
	if EventBus.instance:
		EventBus.instance.checkpoint_shot.emit()
	var round_manager = get_tree().get_first_node_in_group("round_manager")
	if round_manager and round_manager.has_method("on_checkpoint_shot"):
		round_manager.on_checkpoint_shot()
	await was_hit_tween()
	if is_instance_valid(self):
		queue_free()


func _keep_playing_audio_after_free() -> void:
	var host := get_parent()
	if host == null:
		host = get_tree().current_scene
	if host == null:
		return
	var playing_audio: Array = []
	for child in get_children():
		if child is AudioStreamPlayer and child.playing:
			playing_audio.append(child)
	for player in playing_audio:
		player.reparent(host)
		if not player.finished.is_connected(player.queue_free):
			player.finished.connect(player.queue_free)


## Fail / abort / shop: remove without counting as a shot.
func dismiss_without_shot() -> void:
	if _consumed:
		return
	_consumed = true
	rock_activated = false
	_stop_bob()
	disable_collision()
	if is_in_group("Target"):
		remove_from_group("Target")
	queue_free()


func end_of_the_round_pop_balloon(_added_cash: int) -> void:
	dismiss_without_shot()
