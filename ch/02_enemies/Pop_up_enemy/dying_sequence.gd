extends Node

var parent: Node = null

func _ready():
	parent = get_parent().get_parent()


func die() -> void:
	if parent.dying:
		return
	
	parent.dying = true
	
	await parent.kill_all_current_tweens() 

	if parent.current_marker:
		parent.current_marker.is_occupied = false
		parent.current_marker = null

	
	parent.stop_animations()
	%facials_anim_player.play('scared')

	got_hit_tween()


func got_hit_tween() -> void:
	var player := parent.get_tree().get_first_node_in_group("Player")
	if player == null:
		print("Player not found")
		return

	smoke_particles()
	white_particles()

	var tween := parent.create_tween()
	tween.tween_property(parent, "scale", Vector3.ONE / 8, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await tween.finished
	%Mesh.hide()
	const ES_BALLOON_POP = preload("res://400_sounds/00_sfx/ES_sound_effects/ES_Balloon Pop 2 - SFX Producer.wav")
	CommonCode.play_sound_duplicate_instance(parent.get_node('SFX/Pop_sound'), 0.0, parent.get_node('SFX/Pop_sound').volume_db - 7.0)
	EventBus.instance.enemy_popper_shot.emit()

	await get_tree().create_timer(0.05).timeout
	spawn_new_self()


func spawn_new_self() -> void:
	#var rand_number : int = randi_range(1,3)
	var rand_number : int = 2
	if parent.duplicate_node:
		#await parent.get_tree().create_timer(0.1).timeout
		await parent.get_tree().create_timer(1.0).timeout
		parent.queue_free()
		return
		
	for i in range(rand_number):
		#var markers_parent := parent.get_tree().get_first_node_in_group("spotter_marker_3d")
		#var marker_list := []
		#for child in markers_parent.get_children():
			#if child is Marker3D and !child.is_occupied:
				#marker_list.append(child)
#
		#if marker_list.is_empty():
			#print("No available markers found.")
			#parent.queue_free()
			#return
		#%Choose_available_marker_logic
		#var closest_marker: Marker3D = marker_list.pick_random()
		#closest_marker.is_occupied = true

		#var SPOTTERS = preload("res://200_characters/02_enemies/Pop_up_enemy/Poppers_v2.tscn")
		var SPOTTERS = preload('res://200_characters/02_enemies/Pop_up_enemy/Popper_camp_ver.tscn')
		var new_spotter = SPOTTERS.instantiate()
		new_spotter.going_through_first_sequence = false
		new_spotter.stunned = false
		parent.get_parent().add_child(new_spotter)
		new_spotter.attach_self_to_nearest_marker()
		#new_spotter.current_marker = closest_marker
		#new_spotter.global_position = closest_marker.global_position
		#new_spotter.start_pos = closest_marker.global_position
		new_spotter.duplicate_node = true

	#await parent.get_tree().create_timer(0.10).timeout
	await parent.get_tree().create_timer(1.0).timeout
	parent.queue_free()


func smoke_particles() -> void:
	var smoke = %Smoke_quick.duplicate()
	smoke.show()
	parent.get_tree().get_current_scene().add_child(smoke)
	smoke.global_position = parent.global_position
	smoke.duplicate_particles = true
	smoke.emitting = true


func white_particles() -> void:
	var smoke = %Special_particles.duplicate()
	smoke.show()
	parent.get_tree().get_current_scene().add_child(smoke)
	smoke.global_position = parent.global_position
	smoke.duplicate_particles = true
	smoke.emitting = true
