#@tool
extends StaticBody3D

#@export_tool_button('Testing Rotation', "") var rotation_tween = look_towards_center

const ARROW_AREA_3D = preload("res://200_characters/weapons/bullet_area3D.tscn")

@export var in_actual_level := false
@export var arrow_speed := 40.0

@onready var player : Player = get_tree().get_first_node_in_group('Player')
@onready var anim: AnimationPlayer = $Mesh/AnimationPlayer
@onready var anim_wobble: AnimationPlayer = $Mesh/AnimationPlayer2

var spawned_arrows: Array[Area3D] = []
var hit_able := false
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
@export var z_movement := -0.6

@export var z_dur := 0.35
@export var trans_popping_up : Tween.TransitionType = Tween.TRANS_LINEAR
@export var ease_popping_up : Tween.EaseType = Tween.EASE_IN
@export var spotter_reveal_dur := 1.0
@export var spotter_exposed_time := 1.25
@export var staying_around_time := 0.4
@export var spotter_hiding_dur := 0.5

var taken_cover := true
var going_to_get_hit := false
var can_throw_projectiles := false
var stunned := false

@export var peeking_timer : float = 0.0
@export var peeking_timer_threshold : float = 1.5

@export_group('Crosshair variables', "")
@export var crosshair_touching_me_threshold := 0.02
@export var crosshair_timer_allowance := 0.25
var crosshair_on_me_count := 0.0
var crosshair_touching_me := false

#@export var stunned_time := 6.0
var projectile_throw_cancelled := false


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

	

func _ready() -> void:
	await get_tree().create_timer(0.1).timeout
	attach_self_to_nearest_marker()
	#EventBus.instance.settle_phase_started.connect(peeking_over_wall_sequence)
	#EventBus.instance.player_shot_weapon.connect(take_cover_behind_wall)
	
	EventBus.instance.egg_pulsed.connect(stop_tween)
	EventBus.instance.egg_pulsed.connect(stunned_by_egg_pulse)
	EventBus.instance.enemy_present.emit()

	#EventBus.instance.settle_phase_started.connect(peeking_over_wall_sequence)
	start_pos = global_position
	
	if !in_actual_level:
		peeking_over_wall_sequence()
	
	else:
		pass
	
	await get_tree().create_timer(5.0).timeout
	
	can_throw_projectiles = true
	#peeking_over_wall_sequence()
	#if !Engine.is_editor_hint():
		#walk_to_position()

func stop_tween() -> void:
	if throwing_tween and throwing_tween.is_running():
		throwing_tween.kill()
		rotation_degrees.x = 0.0
		%Rock.visible = false  # Optional: hide the rock if mid-animation


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

		anim_wobble.play('wobble')
		anim.play('blinking_twice')
		stunned = false
		self.rotation_degrees = orig_rot
		$Mesh/Standard_face.show()
		$Mesh/Blinking_face.hide()
		$Mesh/Scared_face.hide()
		
		take_cover_behind_wall()




func add_unique_marker(pos: Vector3) -> void:
	$Mesh/Unique_marker.global_position = pos

func spawn_my_arrow() -> void:
	if !hit_able:
		take_cover_behind_wall()
		
		var new_arrow = ARROW_AREA_3D.instantiate()
		var player_gun = get_tree().get_first_node_in_group("player_gun")
		
		new_arrow.global_position = player_gun.get_barrel_position()
		get_tree().get_current_scene().add_child(new_arrow)
		
		spawned_arrows.append(new_arrow)
		return
	
	for i in range(2):
		var new_arrow = ARROW_AREA_3D.instantiate()
		var player_gun = get_tree().get_first_node_in_group("player_gun")
		
		
		get_tree().get_current_scene().add_child(new_arrow)
		new_arrow.global_position = player_gun.get_barrel_position()
		going_to_get_hit = true
		spawned_arrows.append(new_arrow)
		await get_tree().create_timer(0.15).timeout
	
	
func start_hide_timer() -> void:
	var rand : float = randf_range(2, 5)
	await get_tree().create_timer(rand).timeout
	take_cover_behind_wall()

func peeking_over_wall_sequence() -> void:
	if currently_peeking:
		return
	
	if in_actual_level:
		start_hide_timer()
	
	if tween_peaking_head:
		tween_peaking_head.kill()
		#global_position = start_pos
		rotation_degrees.y = 0

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
	
	taken_cover = false
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
	
	#tween_peaking_head.tween_property(self, "hit_able", true, 0.05)
	tween_peaking_head.tween_callback(_on_timer_timeout)
	tween_peaking_head.tween_interval(staying_around_time)
	#tween_peaking_head.tween_callback(take_cover_behind_wall)
	await tween_peaking_head.finished


func crosshair_spotted_me() -> void:
	if crosshair_touching_me:
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
	
	var rand_chance_for_glasses = randi_range(0,20)
	if rand_chance_for_glasses > 1: # 19
		crosshair_touching_me = true
		#%Binoculars.visible = true
	
	take_cover_behind_wall()


func take_cover_behind_wall() -> void:
	if stunned:
		return
	
	if taken_cover:
		return
	
	taken_cover = true
	
	#if %Binoculars.visible:
		#%Binoculars.hide()
	
	$Mesh/throw_arm.stop_tween()
	$Timer.stop()
	
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
	#tween_ducking_cover.tween_property(self, "hit_able", false, 0.05)
	tween_ducking_cover.tween_property(self, "global_position", orig_pos, 0.2)
	await tween_ducking_cover.finished
	
	%Scared_face.hide()
	%Standard_face.show()
	
	
	hit_able = false
	currently_peeking = false
	
	var rand_chance : int = randi_range(0,10)
	var rand_timer_dur : float = randf_range(0.5,2.0)
	if rand_chance >= 9:
		var tween = create_tween()
		tween.tween_interval(rand_timer_dur /2 )
		tween.tween_property($Sprite3D, "visible", true, 0.05)
		tween.parallel().tween_property($Sprite3D, "position:y", 0.65, 0.2).as_relative()
		tween.tween_interval(rand_timer_dur)
		tween.tween_property($Sprite3D, "position:y", -0.65, 0.15).as_relative()
		tween.tween_property($Sprite3D, "visible", false, 0.05)
		tween.tween_interval(rand_timer_dur)
		await tween.finished
		$Sprite3D.position = Vector3.ZERO
		
		walk_to_position()
		crosshair_touching_me = false
		#peeking_over_wall_sequence()
		
	else:
		await get_tree().create_timer(rand_timer_dur).timeout
		peeking_over_wall_sequence()
	
	#walk_to_position()
	#var rand_timer_dur : float = randf_range(0.5,2.0)
	#await get_tree().create_timer(rand_timer_dur).timeout
		
		
func throw_projectile() -> void:

	var rock : MeshInstance3D = %Rock
	throwing_tween = create_tween()
	throwing_tween.tween_property(self, "rotation_degrees", Vector3(0,0,0), 0.15)
	throwing_tween.tween_property(self, "rotation_degrees:x", -45.0, 0.2)
	throwing_tween.parallel().tween_property(self, "global_position:y", -0.2, 0.2).as_relative().set_ease(Tween.EASE_OUT_IN)
	
	throwing_tween.tween_interval(0.25)
	throwing_tween.tween_property(rock, "visible", true, 0.01)
	throwing_tween.parallel().tween_property(self, "rotation_degrees:x", 45.0, 0.2)
	throwing_tween.parallel().tween_property(self, "global_position:y", 0.25, 0.2).as_relative().set_ease(Tween.EASE_IN_OUT)
	#throwing_tween.tween_interval(0.1)
	throwing_tween.tween_callback(throwing_part_2)
	throwing_tween.tween_interval(0.2)
	
	throwing_tween.tween_property(self, "global_position:y", -0.1, 0.2).as_relative().set_ease(Tween.EASE_OUT_IN)
	throwing_tween.parallel().tween_property(self, "rotation_degrees:x", 0.0, 0.2)
	throwing_tween.tween_property(rock, "visible", false, 0.01)
	await throwing_tween.finished
	await get_tree().create_timer(0.5).timeout

	take_cover_behind_wall()
	peeking_timer_threshold = 1.5


func throw_rock_at_the_egg() -> void:
	if !can_throw_projectiles:
		return

	projectile_throw_cancelled = false
	$Timer.stop()
	
	throw_projectile()
	
func throwing_part_2() -> void:
	$SFX/EnemyPopperThrowRock.play()
	#await $Mesh/throw_arm.throw_projectile()
	if projectile_throw_cancelled:
		return

	var SPOTTER_PROJECTILE = preload('res://500_sequences/Cannonball_System/Cannonballs/Spotter_projectiles.tscn')
	var new_projectile : Standard_Cannonball = SPOTTER_PROJECTILE.instantiate()
	new_projectile.arc_strength = randf_range(0.1, 0.2)
	new_projectile.probability_of_special_bomb = 1.0
	get_tree().get_current_scene().add_child(new_projectile)
	new_projectile.global_position = %spawn_projectile_marker.global_position

	var target : Egg_Cage = get_tree().get_first_node_in_group('Egg_Cage')
	var target_pos = target.global_position
	new_projectile.target_position = target_pos

	var rand_targ : int = randi_range(0, 10)
	var targ_colour : String = 'GREY'
	if rand_targ >= 8:
		targ_colour = 'RED'
	new_projectile.target_launcher_fire(targ_colour)

	#await get_tree().create_timer(0.5).timeout
#
	#if projectile_throw_cancelled:
		#return
#
	#take_cover_behind_wall()
	#peeking_timer_threshold = 1.5
	#$Timer.start(3.0)


func reset_crosshair_on_me_timer() -> void:
	$Crosshair_timer.stop()
	$Crosshair_timer.start(crosshair_timer_allowance)


func _on_crosshair_timer_timeout() -> void:
	crosshair_touching_me = false


func _physics_process(delta: float) -> void:
#
	#if crosshair_touching_me:
		#crosshair_on_me_count += delta
		#if crosshair_on_me_count >= crosshair_touching_me_threshold:
			#take_cover_behind_wall()
			#crosshair_touching_me = false
			#crosshair_on_me_count = 0.0
	#else:
		#crosshair_on_me_count = 0.0
	
	if going_to_get_hit:
		hit_able = true
	
	if currently_peeking && !stunned:
		peeking_timer += delta
		if peeking_timer > peeking_timer_threshold:
			peeking_timer = 0.0
			peeking_timer_threshold = 6.0
			throw_rock_at_the_egg()
	
	else:
		peeking_timer = 0.0
	
	
	var target : Vector3
	if !hit_able:
		target = $Mesh/Unique_marker.global_position + Vector3(0,0.5,5)
	else:
		target = $Mesh/Unique_marker.global_position


	if !stunned:
		return
		
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
				else:
					CommonCode.play_sound_duplicate_instance($SFX/Poking_sfx2 , 0.0, -30.0)
				spawned_arrows.erase(arrow)

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
	
	var start_pos = global_position
	var distance := start_pos.distance_to(target_pos)
	var duration := distance / walk_speed

	await get_tree().create_timer(0.1).timeout

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

	bob_tween.tween_property(self, "global_position:y", start_pos.y, 0.1)

	await walk_tween.finished
	
	global_position.y = target_pos.y

	# Optionally store the marker so you can release it later
	current_marker = chosen_marker
	peeking_over_wall_sequence()



func reset_position() -> void:
	global_position = start_pos
	hit_able = false
	
	$Mesh/Standard_face.show()
	$Mesh/Blinking_face.hide()
	
	
func _on_timer_timeout() -> void:
	play_sound()
	head_look_away_tween()
	

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
	var rand_duration : float = randf_range(0.1,0.3)
	anim.play('blinking_once')
	#anim_wobble.play('bobble')
	hit_able = true
	tween_rotate_head = create_tween()
	tween_rotate_head.tween_property(self, "rotation_degrees", -target_rot / 10, 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CIRC)
	tween_rotate_head.tween_property(self, "rotation_degrees", target_rot, 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK) #.set_trans(Tween.TRANS_CIRC)
	tween_rotate_head.tween_interval(rand_duration)
	tween_rotate_head.tween_property(self, "rotation_degrees", orig_rot, 0.25).set_ease(Tween.EASE_OUT).set_delay(0.5).set_trans(Tween.TRANS_SPRING)
	tween_rotate_head.parallel().tween_property(self, "hit_able", false, 0.1).set_delay(0.1)
	
	await tween_rotate_head.finished
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
		return Vector3(45.0, 0.0, 0.0)
		
	elif rand_num == 2:
		return Vector3(45.0, 0.0, 0.0)
		
	elif rand_num == 3:
		return Vector3(0.0, 45.0, 0.0)
		
	elif rand_num == 4:
		return Vector3(0.0, -45.0, 0.0)
		
	else:
		return Vector3(0.0, 45.0, 0.0)
	
	

func play_sound() -> void:
	$SFX/Poking_sfx.play()


func die() -> void:
	if dying:
		return
		
	if !hit_able:
		return
	
	if current_marker:
		current_marker.is_occupied = false
		current_marker = null

	dying = true
	anim.stop()
	anim_wobble.stop()
	anim.play('scared')
	if tween_peaking_head:
		tween_peaking_head.kill()
		
	if tween_ducking_cover:
		tween_ducking_cover.kill()
	
	got_hit_tween()
	
	
func got_hit_tween() -> void:
	var player := get_tree().get_first_node_in_group("Player")
	if player == null:
		print("Player not found")
		return
	
	smoke_particles()
	white_particles()
	
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector3.ONE / 2, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	await tween.finished

	const ES_BALLOON_POP_2___SFX_PRODUCER = preload('res://400_sounds/00_sfx/ES_sound_effects/ES_Balloon Pop 2 - SFX Producer.wav')
	CommonCode.play_sound_duplicate_instance($SFX/Pop_sound, 0.0, $SFX/Pop_sound.volume_db - 5.0)

	EventBus.instance.enemy_popper_shot.emit()

	if !dev_mode:
		spawn_new_self()
		#self.queue_free()
	else:
		reset_position()


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
	await get_tree().create_timer(0.10).timeout
	self.queue_free()
