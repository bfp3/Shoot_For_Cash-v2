#@tool
extends StaticBody3D
class_name Spotters

#@export_tool_button('Testing Rotation', "") var rotation_tween = look_towards_center

const ARROW_AREA_3D = preload("res://200_characters/weapons/bullet_area3D.tscn")

@export var arrow_speed := 40.0
@export var randf := 1.0

@onready var anim: AnimationPlayer = $Mesh/AnimationPlayer
@onready var anim_wobble: AnimationPlayer = $Mesh/AnimationPlayer2



var spawned_arrows: Array[Area3D] = []
var hit_able := false
var health := 1
var material : CompressedTexture2D
var start_pos : Vector3
var orig_pos : Vector3

var tween_peaking_head : Tween = null
var tween_ducking_cover : Tween = null
var tween_corner : Tween = null
var tween_rotate_head : Tween = null

var currently_peeking := false

@export var walk_speed := 3.0
@export var bob_amount := 0.2
@export var bob_speed := 8.0


@export var peeker := false
@export var dev_mode := false
@export_range(0.0, 1.0, 0.01)
var full_sequence_chance := 0.5  # 0.0 = never, 1.0 = always do full sequence


@export_group('Popping Up variables', "")
@export var up_dist := 1.0
@export var first_up_dist := 0.8
@export var second_up_dist := 0.2
@export var z_movement := 5.0

@export var z_dur := 0.25
@export var trans_popping_up : Tween.TransitionType
@export var ease_popping_up : Tween.EaseType 
@export var spotter_reveal_dur := 0.5
@export var spotter_exposed_time := 1.0
@export var staying_around_time := 0.4
@export var spotter_hiding_dur := 0.5


@export_group('Going_around_corner variables', "")

@export var lateral_movement := 0.5
@export var rotation_amount := 1.0
@export var trans_rotate_up : Tween.TransitionType
@export var ease_rotate_up : Tween.EaseType 
@export var spotter_rotate_dur := 0.5
@export var spotter_rotateexposed_time := 1.0
@export var spotter_back_dur := 0.5



func _ready() -> void:
	EventBus.instance.enemy_present.emit()
	#EventBus.instance.settle_phase_started.connect(peeking_over_wall_sequence)
	EventBus.instance.player_shot_weapon.connect(take_cover_behind_wall)
	EventBus.instance.egg_pulsed.connect(hit_by_egg_pulse)
	
	start_pos = global_position
	#peeking_over_wall_sequence()
	if !Engine.is_editor_hint():
		walk_to_position()



func hit_by_egg_pulse() -> void:
	if currently_peeking:
		# Interrupt current peek tweens
		if tween_peaking_head:
			tween_peaking_head.kill()
		if tween_ducking_cover:
			tween_ducking_cover.kill()

		currently_peeking = false
		hit_able = false  # Optional: stunned state may make the spotter invulnerable

		# Play stunned animation or visual feedback
		anim.play("scared")  # Use a stunned-specific animation if available
		$Mesh/Standard_face.hide()
		$Mesh/Blinking_face.show()

		# Wait for 3 seconds (while _physics_process continues to work)
		await get_tree().create_timer(3.0).timeout

		# Return to normal state
		$Mesh/Standard_face.show()
		$Mesh/Blinking_face.hide()

		take_cover_behind_wall()


func _input(event: InputEvent) -> void:
	if Input.is_key_label_pressed(KEY_A):
		if peeker:
			peeking_over_wall_sequence()
	
		#else:
			#tween_around_corner()
	
	#if Input.is_key_label_pressed(KEY_S):
		#if !peeker:
			#tween_around_corner()

		
func add_unique_marker(pos: Vector3) -> void:
	$Unique_marker.global_position = pos

func spawn_my_arrow() -> void:
	if !hit_able:
		take_cover_behind_wall()
		var new_arrow = ARROW_AREA_3D.instantiate()
		var player_gun = get_tree().get_first_node_in_group("player_gun")
		
		new_arrow.global_position = player_gun.get_barrel_position()
		get_tree().get_current_scene().add_child(new_arrow)
		
		spawned_arrows.append(new_arrow)
		return
	
	var new_arrow = ARROW_AREA_3D.instantiate()
	var player_gun = get_tree().get_first_node_in_group("player_gun")
	
	
	get_tree().get_current_scene().add_child(new_arrow)
	new_arrow.global_position = player_gun.get_barrel_position()
	
	spawned_arrows.append(new_arrow)
	
	

func peeking_over_wall_sequence() -> void:
	if tween_peaking_head:
		tween_peaking_head.kill()
		#global_position = start_pos
		rotation_degrees.y = 0

	# Randomly decide how far into the sequence to go
	var rand := randf()
	
	await peek_over_wall_phase_1()
	
	if rand < full_sequence_chance:
		await peek_over_wall_phase_2()
		peek_over_wall_phase_3()
	else:
		var mid_threshold := full_sequence_chance * 0.5
		if rand < mid_threshold:
			await peek_over_wall_phase_2()
			take_cover_behind_wall()
		else:
			take_cover_behind_wall()


func peek_over_wall_phase_1() -> void:
	if tween_peaking_head:
		tween_peaking_head.kill()
		#global_position = start_pos
		rotation_degrees.y = 0
	
	currently_peeking = true
	
	#rotation_degrees.y = 0
	var player : Player = get_tree().get_first_node_in_group('Player')
	look_at(player.global_position, Vector3.UP, false)
	orig_pos = global_position
	
	tween_peaking_head = create_tween()
	tween_peaking_head.tween_property(self, "global_position:y", first_up_dist, spotter_reveal_dur / 4).as_relative().set_trans(trans_popping_up).set_ease(ease_popping_up)
	tween_peaking_head.tween_property(self, "global_position:y", second_up_dist, spotter_reveal_dur).as_relative().set_trans(trans_popping_up).set_ease(ease_popping_up)
	await tween_peaking_head.finished

func peek_over_wall_phase_2() -> void:
	var random_dur : float = randf_range(0.1, 5.0)
	if tween_peaking_head == null or !tween_peaking_head.is_valid():
		tween_peaking_head = create_tween()
	else:
		tween_peaking_head.kill()
		tween_peaking_head = create_tween()
	
	tween_peaking_head.tween_property(self, "global_position:z", z_movement, random_dur).as_relative().set_trans(trans_popping_up).set_ease(ease_popping_up)
	await tween_peaking_head.finished

func peek_over_wall_phase_3() -> void:
	
	if tween_peaking_head == null or !tween_peaking_head.is_valid():
		tween_peaking_head = create_tween()
	else:
		tween_peaking_head.kill()
		tween_peaking_head = create_tween()
	
	tween_peaking_head.tween_property(self, "hit_able", true, 0.05)
	tween_peaking_head.tween_callback(_on_timer_timeout)
	tween_peaking_head.tween_interval(staying_around_time)
	#tween_peaking_head.tween_callback(take_cover_behind_wall)
	await tween_peaking_head.finished

func take_cover_behind_wall() -> void:

	
	if tween_peaking_head:
		tween_peaking_head.stop()
		tween_peaking_head.kill()
	#
	#if tween_ducking_cover == null or !tween_ducking_cover.is_valid():
		#tween_ducking_cover = create_tween()
	#else:
		##tween_peaking_head.kill()
		#tween_ducking_cover = create_tween()

	tween_ducking_cover = create_tween()
	tween_ducking_cover.tween_property(self, "hit_able", false, 0.05)
	tween_ducking_cover.tween_property(self, "global_position", orig_pos, 0.2)
	await tween_ducking_cover.finished
	
	currently_peeking = false
	
	walk_to_position()
	
	
	
	

func tween_around_corner() -> void:
	return
	if tween_corner:
		tween_corner.kill()
		global_position = start_pos + Vector3(0.8,0.8,0)
	
	_on_timer_timeout()
	
	global_position = start_pos + Vector3(0.8,0.8,0)
	rotation_degrees.y = 90
	var orig_pos : Vector3 = global_position
	tween_corner = create_tween()
	tween_corner.tween_property(self, "global_position:x", -lateral_movement, spotter_reveal_dur).as_relative().set_trans(trans_popping_up).set_ease(ease_popping_up)
	tween_corner.parallel().tween_property(self, "rotation_degrees:y", -rotation_amount, spotter_reveal_dur).as_relative().set_trans(trans_popping_up).set_ease(ease_popping_up)
	tween_corner.tween_property(self, "hit_able", true, 0.05)
	tween_corner.tween_interval(spotter_exposed_time)
	tween_corner.tween_property(self, "global_position:x", lateral_movement, spotter_hiding_dur).as_relative()
	tween_corner.parallel().tween_property(self, "rotation_degrees:y", rotation_amount, spotter_reveal_dur).as_relative().set_trans(trans_popping_up).set_ease(ease_popping_up)
	await tween_corner.finished
	hit_able = false


func _physics_process(delta: float) -> void:

	
	var target : Vector3
	if !hit_able:
		target = $Unique_marker.global_position + Vector3(0,0.5,5)
	else:
		target = $Unique_marker.global_position

	for arrow in spawned_arrows.duplicate():
		
		if tween_peaking_head && hit_able:
			tween_peaking_head.kill()
		
		if !is_instance_valid(arrow):
			if spawned_arrows.has(arrow):
				spawned_arrows.erase(arrow)
			continue
		
		
		var direction = (target - arrow.global_position).normalized()
		arrow.global_position += direction * arrow_speed * delta
		arrow.look_at(target, Vector3.UP, true)

		if arrow.global_position.distance_to(target) < 0.5:
			arrow.cleanUp()
			if spawned_arrows.has(arrow):
				health -= 1
				if health <= 0:
					die()
				spawned_arrows.erase(arrow)

func smoke_particles() -> void:
	var smoke = $Smoke_quick2.duplicate()
	smoke.show()
	get_tree().get_current_scene().add_child(smoke)
	smoke.global_position = global_position
	smoke.duplicate_particles = true
	smoke.emitting = true

func white_particles() -> void:
	var smoke = $Special_particles.duplicate()
	smoke.show()
	get_tree().get_current_scene().add_child(smoke)
	smoke.global_position = global_position
	smoke.duplicate_particles = true
	smoke.emitting = true
	

func die() -> void:
	if !hit_able:
		return
		
	anim.stop()
	anim_wobble.stop()
	anim.play('scared')
	#$MeshInstance3D2.material_override.albedo_texture = FACE_3_KO
	if tween_peaking_head:
		tween_peaking_head.kill()
		
	if tween_ducking_cover:
		tween_ducking_cover.kill()
	#smoke_particles()
	$SFX/Poking_sfx3.play()
	got_hit_tween()
	
func got_hit_tween() -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		print("Player not found")
		return
	
	var hit_direction = (global_position - player.global_position).normalized()
	var knockback_distance : float = 10.0
	var knockback_offset = hit_direction * knockback_distance + Vector3.UP * 2.0

	$Mesh/Standard_face.hide()
	$Mesh/Blinking_face.show()
	var dur: float = 0.75

	white_particles()

	var tween := create_tween()
	var global_target = global_position + knockback_offset

	tween.tween_property(self, "global_position", global_target, dur).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "rotation_degrees", rotation_degrees + Vector3(360, 720, 180), dur).set_ease(Tween.EASE_OUT)

	tween.parallel().tween_property($Mesh, "scale", Vector3.ONE / 100, 2.5).set_ease(Tween.EASE_IN)
	tween.tween_interval(0.1)

	await tween.finished
	EventBus.instance.enemy_popper_shot.emit()

	if !dev_mode:
		queue_free()
	else:
		reset_position()



		

func walk_to_position() -> void:
	var markers_parent := get_tree().get_first_node_in_group("spotter_marker_3d")
	if markers_parent == null:
		print("No marker group found.")
		return
	
	var marker_list := []
	for child in markers_parent.get_children():
		if child is Marker3D:
			marker_list.append(child)
	
	if marker_list.is_empty():
		print("No Marker3D nodes found.")
		return
	
	var chosen_marker: Marker3D = marker_list.pick_random()
	var target_pos: Vector3 = chosen_marker.global_position
	
	# Avoid standing still at the same spot
	if global_position == target_pos and marker_list.size() > 1:
		marker_list.erase(chosen_marker)
		chosen_marker = marker_list.pick_random()
		target_pos = chosen_marker.global_position
	
	var start_pos = global_position
	var distance := start_pos.distance_to(target_pos)
	var duration := distance / walk_speed

	await get_tree().create_timer(0.25).timeout

	look_at(target_pos, Vector3.UP, false)
	
	# Create movement tween
	var walk_tween := create_tween()
	walk_tween.tween_property(self, "global_position", target_pos, duration).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

	# Bobbing up and down during movement
	var bob_tween := create_tween()
	var bob_cycles := int(duration * bob_speed)
	for i in range(bob_cycles):
		var up_down_time := duration / (bob_cycles * 2.0)
		bob_tween.tween_property(self, "global_position:y", bob_amount, up_down_time).as_relative()
		bob_tween.tween_property(self, "global_position:y", -bob_amount, up_down_time).as_relative()

	# Reset final y position
	bob_tween.tween_property(self, "global_position:y", start_pos.y, 0.1)

	# Wait for main movement to finish
	await walk_tween.finished

	# Just in case: ensure final position is accurate and aligned
	global_position.y = target_pos.y

	peeking_over_wall_sequence()



func reset_position() -> void:
	global_position = start_pos
	hit_able = false
	
	$Mesh/Standard_face.show()
	$Mesh/Blinking_face.hide()
	
	
func _on_timer_timeout() -> void:
	play_sound()
	#anim_wobble.play('wobble')
	look_towards_center()
	
	var rand_i = randi_range(0,2)
	if rand_i > 1:
		anim.play('blinking_twice')
		await anim.animation_finished
		#$Timer.start(randf_range(1,5))
	else:
		anim.play('blinking_three_times')
		await anim.animation_finished
		#$Timer.start(randf_range(1,5))
		

func play_bobble() -> void:
	anim_wobble.speed_scale = 0.75
	anim_wobble.play('nodding')
	await anim_wobble.animation_finished
	anim_wobble.speed_scale = 1.0

func look_towards_center() -> void:
	var orig_rot : Vector3 = rotation_degrees
	var target_rot : float
	if global_position.x >= 0.5:
		target_rot = 45.0
	elif global_position.x <= -0.5:
		target_rot = -45.0
	else:
		target_rot = -45.0
	
	anim.play('blinking_twice')
	#anim_wobble.play('bobble')
	
	tween_rotate_head = create_tween()
	tween_rotate_head.tween_property(self, "rotation_degrees:y", -target_rot / 10, 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CIRC)
	tween_rotate_head.tween_property(self, "rotation_degrees:y", target_rot, 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK) #.set_trans(Tween.TRANS_CIRC)
	tween_rotate_head.tween_interval(1.0)
	#tween_rotate_head.parallel().tween_callback(play_bobble).set_delay(0.5)
	#tween_rotate_head.tween_property(self, "rotation_degrees:x", -15, 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CIRC)
	#tween_rotate_head.tween_property(self, "rotation_degrees:x", 15, 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CIRC)
	tween_rotate_head.tween_property(self, "rotation_degrees", orig_rot, 0.25).set_ease(Tween.EASE_OUT).set_delay(0.5).set_trans(Tween.TRANS_SPRING)
	
	await tween_rotate_head.finished
	anim.play('blinking_twice')
	if !Engine.is_editor_hint():
		take_cover_behind_wall()

func play_sound() -> void:
	$SFX/Poking_sfx.play()
	#$SFX/Poking_sfx2.play()
	#$SFX/Poking_sfx3.play()
