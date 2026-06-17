extends Node3D

@onready var post: MeshInstance3D = $Post_mesh/Post

@export var start_flag := false
var flag_target_scale: Vector3 = Vector3(1.0, 1.0, 1.0)
var flag_raised := false
#signal flag_has_folded


func _ready():
	#hide()
	#rollout_flag()
	$Sprite3D.hide()


	#EventBus.instance.player_has_hit_winning_score.connect(_on_player_has_hit_winning_score)


func rollout_flag() -> void:
	if flag_raised:
		return
	flag_raised = true
	var flag_sfx : AudioStreamWAV = preload('res://sfx/pineapple_shake_1.wav')
	CommonCode.play_sound_instance_pitch_adjusted(flag_sfx, -35.0, 1.0)
	
	show()

	$Smoke_quick.smoke_particles()
	#CommonCode.play_sound_instance_delay_time(flag_sfx, -40.0, 0.0, 0.5)
	$hitSound.play()
	var new_tween = create_tween()

	#new_tween.parallel().tween_property(flag_mesh, "visible", true, 0.05).set_delay(0.15)
	#new_tween.parallel().tween_property(flag_holder, "visible", true, 0.05).set_delay(0.15)
	new_tween.parallel().tween_property($Sprite3D, "visible", true, 0.05).set_delay(0.15)
	new_tween.parallel().tween_property($Post_mesh, "visible", true, 0.05).set_delay(0.15)
	

	await new_tween.finished
	#$Mesh.queue_free()
	

	
func _on_player_has_hit_winning_score() -> void:
	await get_tree().create_timer(2.25).timeout
	rollout_flag()


#func _input(event: InputEvent) -> void:
	#if Input.is_key_label_pressed(KEY_SPACE):
		#rollout_flag()
