extends Node3D

var dying := false
signal finished

func start(parent : CharacterBody3D) -> void:
	die(parent)

func _on_finished() -> void:
	finished.emit()

func cancel() -> void:
	pass

func die(parent : CharacterBody3D) -> void:
	#In case it gets called more than once
	if dying:
		return
	dying = true
	

	if %Rigidbody_doppleganger:
		%Rigidbody_doppleganger.queue_free()
	
	smoke_particles()
	white_particles()
	
	var dur : float = 0.25
	var tween := parent.create_tween()
	tween.tween_property(parent, "scale", Vector3.ONE / 8, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await tween.finished
	
	%Mesh.hide()
	CommonCode.play_sound_duplicate_instance(%Pop_sound, 0.0, %Pop_sound.volume_db - 7.0)
	parent.ev_HasDied()

	#await get_tree().create_timer(0.1).timeout
	print('dying now')
	parent.queue_free()

func smoke_particles() -> void:
	var smoke = %Smoke_quick.duplicate()
	smoke.show()
	get_tree().get_current_scene().add_child(smoke)
	smoke.global_position = global_position
	smoke.duplicate_particles = true
	smoke.emitting = true

func white_particles() -> void:
	var smoke = %Special_particles.duplicate()
	smoke.show()
	get_tree().get_current_scene().add_child(smoke)
	smoke.global_position = global_position
	smoke.duplicate_particles = true
	smoke.emitting = true
