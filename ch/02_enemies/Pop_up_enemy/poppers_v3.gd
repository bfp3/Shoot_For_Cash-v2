extends StaticBody3D
const ARROW_AREA_3D = preload("res://200_characters/weapons/bullet_area3D.tscn")

@export var amount_of_rocks := 10
@export var time_between_each_rock = 0.5
@export var staying_around_time := 2.0
@onready var player : Player = get_tree().get_first_node_in_group('Player')
@onready var egg: Egg_Cage = get_tree().get_first_node_in_group('Egg_Cage')
@onready var anim: AnimationPlayer = $Mesh/AnimationPlayer
@onready var anim_wobble: AnimationPlayer = $Mesh/AnimationPlayer2

var throwing_projectiles := false

var hit_able := false
var being_courageous := false
var health := 2
var material : CompressedTexture2D
var start_pos : Vector3
var orig_pos : Vector3

var tween_peaking_head : Tween = null
var tween_ducking_cover : Tween = null
var tween_corner : Tween = null
var tween_rotate_head : Tween = null
var throwing_tween : Tween = null

var currently_peeking := false
var laser_touched_me := false

var current_marker : Marker3D = null
var dying := false

@export var walk_speed := 1.5
@export var bob_amount := 0.2
@export var bob_speed := 3.0

@export var dev_mode := false
@export_range(0.0, 1.0, 0.01) var full_sequence_chance := 1.0

@export_group('Popping Up variables', "")
@export var up_dist := 0.65
@export var first_up_dist := 0.585
@export var second_up_dist := 0.05

@export var z_dur := 0.35
@export var trans_popping_up : Tween.TransitionType = Tween.TRANS_LINEAR
@export var ease_popping_up : Tween.EaseType = Tween.EASE_IN
@export var spotter_reveal_dur := 1.0
@export var spotter_exposed_time := 1.25
@export var spotter_hiding_dur := 0.5

var taken_cover := true
var going_to_get_hit := false
var can_throw_projectiles := false
var stunned := false
var permanently_stunned_bool := false

var walkies := false

@export var peeking_timer : float = 0.0
@export var peeking_timer_threshold : float = 0.0

var crosshair_touching_me := false

var projectile_throw_cancelled := false
var fail_safing := true

func _ready() -> void:
	duck_behind_wall()
	await get_tree().create_timer(0.1).timeout #Buffer so that the birds can be counted
	attach_self_to_nearest_marker()
	fail_safe_loop() # starts a background check loop
	
	EventBus.instance.enemy_present.emit()
	EventBus.instance.egg_pulsed.connect(stop_throwing_tween)
	EventBus.instance.egg_pulsed.connect(jumping_shocked_tween)
	#EventBus.instance.egg_pulsed.connect(stunned_by_egg_pulse)

	set_physics_process(false)
	start_pos = global_position
	

	
	await get_tree().create_timer(5.5).timeout
	
	peeking_over_wall_sequence()
	await get_tree().create_timer(1.0).timeout
	head_look_away_tween()
	
	#await get_tree().create_timer(1.5).timeout


func fail_safe_loop() -> void:
	await get_tree().process_frame # optional 1-frame delay after ready
	while fail_safing:
		await get_tree().create_timer(5.0).timeout
		throwing_projectiles = false
		if !dying and !stunned and !walkies:
		#if taken_cover and !currently_peeking and !dying and !stunned:
			print("Failsafe activated: resetting stuck enemy")
			taken_cover = false
			throwing_projectiles = false
			crosshair_touching_me = false
			hit_able = false
			peeking_timer = 0.0
			set_physics_process(true)
			peeking_over_wall_sequence()



func attach_self_to_nearest_marker() -> void:
	var markers_parent := get_tree().get_first_node_in_group("spotter_marker_3d")
	if markers_parent == null:
		print("No marker group found.")
		return
	
	var marker_list := []
	for child in markers_parent.get_children():
		if child is Marker3D and !child.is_occupied:
			marker_list.append(child)
	
	if marker_list.is_empty():
		print("No available markers found.")
		return
	
	# Sort by distance to this spotter
	marker_list.sort_custom(func(a, b):
		return global_position.distance_squared_to(a.global_position) < global_position.distance_squared_to(b.global_position)
	)

	var closest_marker: Marker3D = marker_list[0]
	closest_marker.is_occupied = true
	current_marker = closest_marker



func stop_throwing_tween() -> void:
	if throwing_tween and throwing_tween.is_running():
		throwing_tween.kill()
		rotation_degrees.x = 0.0
		%Rock.visible = false  # Optional: hide the rock if mid-animation
		fail_safing = true

func stop_animations() -> void:
	$Mesh/AnimationPlayer.stop()
	$Mesh/AnimationPlayer2.stop()
	$Mesh/AnimationPlayer3.stop()
	return
	
func jumping_shocked_tween() -> void:
	projectile_throw_cancelled = true
	if stunned:
		return
	#if currently_peeking:
	if tween_peaking_head:
		tween_peaking_head.kill()
	if tween_ducking_cover:
		tween_ducking_cover.kill()
	if tween_rotate_head:
		tween_rotate_head.kill()
	
	currently_peeking = true
	hit_able = true
	stunned = true
	await stop_animations()
	anim.play("scared")
	
	%Standard_face.hide()
	%Blinking_face.hide()
	%Scared_face.show()
	
	var _orig_pos : Vector3 = global_position
	var orig_rot : Vector3 = $Mesh.rotation_degrees
	
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "global_position:y", randf_range(3.0,5.0), 0.5).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property($Mesh, "rotation_degrees",  Vector3(45, 45, 45), 0.5).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position:y", 0.5, 2.0).as_relative().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "global_position:y", -0.25, 1.0).as_relative().set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", _orig_pos, 2.0).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property($Mesh, "rotation_degrees", orig_rot, 2.0)
	await tween.finished

	
	anim_wobble.play('wobble')
	anim.play('blinking_twice')
	stunned = false
	$Mesh.rotation_degrees = orig_rot
	$Mesh/Standard_face.show()
	$Mesh/Blinking_face.hide()
	$Mesh/Scared_face.hide()
	
	duck_behind_wall()


func jump_to_next_point(_target_pos: Vector3, _chosen_marker: Marker3D, _duration: float) -> void:
	stop_animations()
	var orig_pos: Vector3 = global_position
	var mid_pos: Vector3 = orig_pos.lerp(_target_pos, 0.5)
	mid_pos.y += 1.5  # Peak of the jump arc

	_duration = clamp(_duration, 0.5, 1.0)

	var tween = create_tween().set_trans(Tween.TRANS_LINEAR)

	# Jump to the peak (arc midpoint)
	tween.tween_property(self, "global_position", mid_pos, _duration)
	tween.tween_property(self, "global_position", _target_pos, _duration)

	await tween.finished

	# Snap cleanly
	walkies = false
	current_marker = _chosen_marker
	global_position = _target_pos

	peeking_over_wall_sequence()


	
func stunned_by_egg_pulse() -> void:
	projectile_throw_cancelled = true  # Cancel any active projectile throw
	
	if currently_peeking:
		if tween_peaking_head:
			tween_peaking_head.kill()
		if tween_ducking_cover:
			tween_ducking_cover.kill()
		if tween_rotate_head:
			tween_rotate_head.kill()
		
		currently_peeking = true
		hit_able = true
		stunned = true
		anim.stop()
		anim_wobble.stop()
		anim.play("scared")
		$Mesh/Standard_face.hide()
		$Mesh/Blinking_face.show()
		var orig_rot : Vector3 = rotation_degrees
		self.rotation_degrees = Vector3(45, 45, 45)
		
		var _stunned_time = randf_range(3.0, 6.0)
		await get_tree().create_timer(_stunned_time).timeout
		if permanently_stunned_bool:
			return
		
		anim_wobble.play('wobble')
		anim.play('blinking_twice')
		stunned = false
		self.rotation_degrees = orig_rot
		$Mesh/Standard_face.show()
		$Mesh/Blinking_face.hide()
		$Mesh/Scared_face.hide()
		
		duck_behind_wall()

	
func peeking_over_wall_sequence() -> void:
	if currently_peeking:
		return
	
	if tween_peaking_head:
		tween_peaking_head.kill()
		rotation_degrees = Vector3.ZERO

	await peek_over_wall_phase_1()
	await peek_over_wall_phase_2()
	peek_over_wall_phase_3()



func peek_over_wall_phase_1() -> void:
	if tween_peaking_head:
		tween_peaking_head.kill()
		#global_position = start_pos
		rotation_degrees.y = 0
	
	taken_cover = false
	currently_peeking = true
	
	#rotation_degrees.y = 0
	look_at(egg.global_position, Vector3.UP, false)
	orig_pos = global_position
	
	tween_peaking_head = create_tween()
	tween_peaking_head.tween_property(self, "global_position:y", first_up_dist, spotter_reveal_dur / 4).as_relative().set_trans(trans_popping_up).set_ease(ease_popping_up)
	tween_peaking_head.tween_property(self, "global_position:y", second_up_dist, spotter_reveal_dur).as_relative().set_trans(trans_popping_up).set_ease(ease_popping_up)
	await tween_peaking_head.finished

func peek_over_wall_phase_2() -> void:
	#var random_dur : float = randf_range(0.1, 5.0)
	var random_dur : float = randf_range(0.1, 1.0)
	if tween_peaking_head == null or !tween_peaking_head.is_valid():
		tween_peaking_head = create_tween()
	else:
		tween_peaking_head.kill()
		tween_peaking_head = create_tween()
	tween_peaking_head.tween_interval(random_dur)
	#tween_peaking_head.tween_property(self, "global_position:z", -0.6, random_dur).as_relative().set_trans(trans_popping_up).set_ease(ease_popping_up)
	await tween_peaking_head.finished


func peek_over_wall_phase_3() -> void:
	
	if tween_peaking_head == null or !tween_peaking_head.is_valid():
		tween_peaking_head = create_tween()
	else:
		tween_peaking_head.kill()
		tween_peaking_head = create_tween()
	
	tween_peaking_head.tween_interval(staying_around_time)
	await tween_peaking_head.finished


func crosshair_spotted_me() -> void:
	if crosshair_touching_me || being_courageous:
		return
	
	if throwing_tween:
		throwing_tween.kill()
		
	peeking_timer = 0.0
	%Scared_face.show()
	%Standard_face.hide()
	$SFX/duck_sfx.pitch_scale = randf_range(0.9,1.15)
	$SFX/duck_sfx.play()
	$Timer.stop()
	$Mesh/throw_arm.stop_tween()
	look_at(player.global_position, Vector3.UP, false)
	await get_tree().create_timer(0.2).timeout
	
	var rand_chance_for_courage = randi_range(0,20)
	if rand_chance_for_courage > 15: # 19
		being_courageous = true
	
	duck_behind_wall()


func duck_behind_wall() -> void:
	if stunned || taken_cover:
		return
	
	taken_cover = true
	$Mesh/throw_arm.stop_tween()
	$Timer.stop()
	
	if tween_peaking_head:
		tween_peaking_head.stop()
		tween_peaking_head.kill()

	tween_ducking_cover = create_tween()
	tween_ducking_cover.tween_property(self, "global_position", orig_pos, 0.2)
	await tween_ducking_cover.finished
	
	while throwing_projectiles:
		await get_tree().process_frame  # slight delay to separate batches (1 frame)
	
	%Scared_face.hide()
	%Standard_face.show()
	
	hit_able = false
	currently_peeking = false
	crosshair_touching_me = false
	being_courageous = false
	throwing_projectiles = false
	set_physics_process(true)
	
	var rand_chance : int = randi_range(0,10)
	var rand_timer_dur : float = randf_range(0.5,2.0)
	if rand_chance >= 9:
		flip_the_bird(rand_timer_dur)
		
	else:
		#await get_tree().create_timer(rand_timer_dur).timeout
		await get_tree().create_timer(0.25).timeout
		peeking_over_wall_sequence()

		
func flip_the_bird(rand_timer_dur : float) -> void:
	var tween = create_tween()
	#tween.tween_interval(0.1)
	tween.tween_property($Sprite3D, "visible", true, 0.05)
	tween.parallel().tween_property($Sprite3D, "position:y", 0.65, 0.2).as_relative()
	tween.tween_interval(rand_timer_dur / 2)
	tween.tween_property($Sprite3D, "position:y", -0.65, 0.15).as_relative()
	tween.tween_property($Sprite3D, "visible", false, 0.05)
	tween.tween_interval(rand_timer_dur/4)
	await tween.finished
	$Sprite3D.position = Vector3.ZERO
	%Throwing_patterns.throw_distraction_rocks()
	walk_to_position()
	crosshair_touching_me = false


func throw_projectile_tween() -> void:

	var rock: MeshInstance3D = %Rock
	throwing_tween = create_tween()

	throwing_tween.tween_property($Mesh, "rotation_degrees:x", -45.0, 0.2)
	throwing_tween.parallel().tween_property(self, "global_position:y", -0.2, 0.2).as_relative().set_ease(Tween.EASE_OUT_IN)
	
	throwing_tween.tween_interval(0.25)
	# throwing_tween.tween_property(rock, "visible", true, 0.01)
	throwing_tween.parallel().tween_property($Mesh, "rotation_degrees:x", 45.0, 0.2)
	throwing_tween.parallel().tween_property(self, "global_position:y", 0.25, 0.2).as_relative().set_ease(Tween.EASE_IN_OUT)
	# throwing_tween.tween_interval(0.1)
	throwing_tween.tween_callback(throwing_part_2)
	throwing_tween.tween_interval(0.1)

	throwing_tween.tween_property(self, "global_position:y", -0.1, 0.1).as_relative().set_ease(Tween.EASE_OUT_IN)
	throwing_tween.parallel().tween_property($Mesh, "rotation_degrees:x", 0.0, 0.1)
	# throwing_tween.tween_property(rock, "visible", false, 0.01)

	await throwing_tween.finished
	$Mesh.rotation_degrees.y = 0.0
	
	duck_behind_wall()


func throw_rock_at_the_egg() -> void:
	if !can_throw_projectiles || throwing_projectiles:
		return
	
	
	fail_safing = false
	throwing_projectiles = true
	projectile_throw_cancelled = false
	
	$Timer.stop()
	
	throw_projectile_tween()
	
func throwing_part_2() -> void:
	
	#await $Mesh/throw_arm.throw_projectile()
	if projectile_throw_cancelled:
		return
	
	%Throwing_patterns.pick_throwing_pattern()
	

func throwing_finished() -> void:
	throwing_projectiles = false
	fail_safing = true
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	#if going_to_get_hit:
		#hit_able = true
	
	if currently_peeking && !stunned:
		peeking_timer += delta
		if peeking_timer > peeking_timer_threshold:
			peeking_timer_threshold = 1.0
			set_physics_process(false)
			peeking_timer = 0.0
			throw_rock_at_the_egg()
	
	else:
		peeking_timer = 0.0
	


func smoke_particles() -> void:
	var smoke = $Smoke_quick.duplicate()
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


func walk_to_position() -> void:
	if walkies:
		return
	walkies = true
	
	if current_marker:
		current_marker.is_occupied = false
		current_marker = null

	
	var markers_parent := get_tree().get_first_node_in_group("spotter_marker_3d")
	if markers_parent == null:
		print("No marker group found.")
		return
	
	var marker_list := []
	for child in markers_parent.get_children():
		if child is Marker3D and !child.is_occupied:
			marker_list.append(child)
	
	if marker_list.is_empty():
		print("No available markers found.")
		return
	
	var chosen_marker: Marker3D = marker_list.pick_random()
	chosen_marker.is_occupied = true  # Reserve the position
	
	var target_pos: Vector3 = chosen_marker.global_position
	
	# Avoid standing still at the same spot
	if global_position == target_pos and marker_list.size() > 1:
		marker_list.erase(chosen_marker)
		chosen_marker = marker_list.pick_random()
		target_pos = chosen_marker.global_position
		chosen_marker.is_occupied = true
	
	var start_height = global_position
	var distance := start_pos.distance_to(target_pos)
	var duration := distance / walk_speed

	await get_tree().create_timer(0.1).timeout

	look_at(target_pos, Vector3.UP, false)
	
	
	
	jump_to_next_point(target_pos, chosen_marker, duration)
	return
	
	# Create movement tween
	var walk_tween := create_tween()
	walk_tween.tween_property(self, "global_position", target_pos, duration).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

	# Bobbing up and down during movement
	var bob_tween := create_tween()
	var bob_cycles := int(duration * bob_speed)
	for i in range(bob_cycles):
		var up_down_time := duration / (bob_cycles * 2.0)
		bob_tween.tween_property(self, "global_position:y", bob_amount, up_down_time).as_relative()
		bob_tween.tween_property(self, "global_position:y", orig_pos.y, up_down_time)

	bob_tween.tween_property(self, "global_position:y", start_height.y, 0.1)

	await walk_tween.finished
	walkies = false
	
	global_position.y = target_pos.y

	# Optionally store the marker so you can release it later
	current_marker = chosen_marker
	peeking_over_wall_sequence()


#func _on_timer_timeout() -> void:
	#head_look_away_tween()
	

func play_bobble() -> void:
	anim_wobble.speed_scale = 0.75
	anim_wobble.play('nodding')
	await anim_wobble.animation_finished
	anim_wobble.speed_scale = 1.0


func head_look_away_tween() -> void:
	if stunned:
		$Timer.start(3.0)
		return
		
	var target_rot : Vector3 = await pick_turn_rot()
	var orig_rot : Vector3 = rotation_degrees
	var rand_duration : float = randf_range(0.1,0.2)
	anim.play('blinking_once')
	#anim_wobble.play('bobble')

	tween_rotate_head = create_tween()
	tween_rotate_head.tween_property(self, "rotation_degrees:y", -target_rot.y / 10, 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CIRC)
	tween_rotate_head.tween_property(self, "rotation_degrees:y", target_rot.y, 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK) #.set_trans(Tween.TRANS_CIRC)
	tween_rotate_head.tween_interval(rand_duration)
	tween_rotate_head.tween_property(self, "rotation_degrees", orig_rot, 0.15).set_ease(Tween.EASE_OUT).set_delay(0.5).set_trans(Tween.TRANS_SPRING)
	
	await tween_rotate_head.finished
	can_throw_projectiles = true
	set_physics_process(true)
	#hit_able = false
	#anim.play('blinking_twice')

	#var rand_timer_dur : float = randf_range(0.5,2.0)
	#$Timer.start(rand_timer_dur)
	
func pick_turn_rot() -> Vector3:
	var orig_rot : Vector3 = rotation_degrees
	var target_rot : float
	var rand_num : int = randi_range(0,4)
	
	if rand_num == 0:
		return Vector3.ZERO
		
	elif rand_num == 1:
		#return Vector3(45.0, 0.0, 0.0)
		return Vector3(0.0, 45.0, 0.0)
		
	elif rand_num == 2:
		#return Vector3(45.0, 0.0, 0.0)
		return Vector3(0.0, -45.0, 0.0)
		
	elif rand_num == 3:
		return Vector3(0.0, 45.0, 0.0)
		
	elif rand_num == 4:
		return Vector3(0.0, -45.0, 0.0)
		
	else:
		return Vector3(0.0, 45.0, 0.0)
	
	

func play_sound() -> void:
	$SFX/Poking_sfx.play()


func die() -> void:
	if dying || !hit_able:
		return
	
	dying = true
	anim.stop()
	anim_wobble.stop()
	anim.play('scared')
	
	if tween_peaking_head:
		tween_peaking_head.kill()
		
	if tween_ducking_cover:
		tween_ducking_cover.kill()
	
	if current_marker:
		current_marker.is_occupied = false
		current_marker = null
	
	got_hit_tween()
	
	
func got_hit_tween() -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		print("Player not found")
		return
	
	smoke_particles()
	white_particles()
	
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE / 8, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await tween.finished
	
	$Mesh.hide()
	const ES_BALLOON_POP_2___SFX_PRODUCER = preload('res://400_sounds/00_sfx/ES_sound_effects/ES_Balloon Pop 2 - SFX Producer.wav')
	CommonCode.play_sound_duplicate_instance($SFX/Pop_sound, 0.0, $SFX/Pop_sound.volume_db - 5.0)

	EventBus.instance.enemy_popper_shot.emit()

	#if !dev_mode:
	await get_tree().create_timer(0.25).timeout
	spawn_new_self()
		#self.queue_free()


func spawn_new_self() -> void:
	for i in range(3):
		await get_tree().create_timer(0.5).timeout
		var markers_parent := get_tree().get_first_node_in_group("spotter_marker_3d")
		var marker_list := []
		for child in markers_parent.get_children():
			if child is Marker3D and !child.is_occupied:
				marker_list.append(child)
		
		if marker_list.is_empty():
			print("No available markers found.")
			self.queue_free()
			return

		var closest_marker: Marker3D = marker_list.pick_random()
		closest_marker.is_occupied = true
		
		var SPOTTERS = preload('res://200_characters/02_enemies/Pop_up_enemy/Poppers_v2.tscn')
		var new_spotter = SPOTTERS.instantiate()
		get_parent().add_child(new_spotter)
		new_spotter.current_marker = closest_marker
		new_spotter.global_position = closest_marker.global_position
		new_spotter.start_pos = closest_marker.global_position
	await get_tree().create_timer(0.15).timeout
	self.queue_free()





func _on_area_3d_area_entered(area: Area3D) -> void:
	if area.is_in_group('bullet') && stunned && !dying:
		CommonCode.play_sound_duplicate_instance($SFX/Poking_sfx2 , 0.0, -35.0)
		await get_tree().create_timer(0.15).timeout
		die()
