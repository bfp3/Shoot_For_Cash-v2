extends StaticBody3D
class_name Poppers

@onready var player : Player = get_tree().get_first_node_in_group('Player')
@onready var egg: Egg_Cage = get_tree().get_first_node_in_group('Egg_Cage')
@onready var rigidbody_doppleganger: RigidBody3D = $Rigidbody_doppleganger

@export var first_appearing_time_dur := 5.5

var rigid_body_copy : RigidBody3D

enum State { IDLE, PEEKING, THROWING, STUNNED, WALKING, JUMPING, DUCKING }
var state := State.IDLE

var walk_speed := 1.5
var bob_amount := 0.2
var bob_speed := 3.0

#@export_group('Popping Up variables', "")
var up_dist := 0.65
var first_up_dist := 0.585
var second_up_dist := 0.05

var trans_popping_up : Tween.TransitionType = Tween.TRANS_LINEAR
var ease_popping_up : Tween.EaseType = Tween.EASE_IN
var spotter_reveal_dur := 1.0

var peeking_timer : float = 0.0
var peeking_timer_threshold : float = 0.0

var throwing_projectiles := false

var being_courageous := false
var health := 2
var start_pos : Vector3
var orig_pos : Vector3

var currently_peeking := false

var current_marker : Marker3D = null
var dying := false

var going_through_first_sequence := true

var duck_down_counter := 0
var ducked_down_threshold := 3
var ready_to_duck_down := false

var thrown_counter := 0
var thrown_threshold := 3

var taken_cover := true
var can_throw_projectiles := false
var stunned := false
var permanently_stunned_bool := false

var walkies := false


var crosshair_touching_me := false
var first_time_crosshair_touching_me := true


# STUN JUMP Variables
var is_jumping := false
var jump_velocity := Vector3.ZERO
var gravity := -9.8
var current_air_time := 0.0
var jump_duration := 1.5
var start_position := Vector3.ZERO
var target_rotation := Vector3.ZERO
var start_rotation := Vector3.ZERO

var projectile_throw_cancelled := false
var fail_safing := true

# TWEENS
var tween_popping_up : Tween = null
var tween_ducking : Tween = null
var tween_rotate_head : Tween = null
var tween_throwing : Tween = null
var walk_tween : Tween = null
var bob_tween : Tween = null


var duplicate_node := false

func _ready() -> void:
	set_process(false)
	set_physics_process(false)
	#duck_behind_wall()
	await get_tree().create_timer(0.1).timeout #Buffer so that the birds can be counted
	attach_self_to_nearest_marker()
	
	EventBus.instance.enemy_present.emit()
	EventBus.instance.egg_pulsed.connect(stop_throwing_tween)
	EventBus.instance.egg_pulsed.connect(jumping_shocked_tween)
	#EventBus.instance.egg_pulsed.connect(stunned_by_egg_pulse)

	start_pos = global_position
	%First_appearance_sequence.first_appearance()
	
func spare() -> void:
	await get_tree().create_timer(first_appearing_time_dur).timeout
	
	peeking_over_wall_sequence()
	await get_tree().create_timer(1.0).timeout
	head_look_away_tween()
	

func _physics_process(delta: float) -> void:
	if currently_peeking && !stunned:
		peeking_timer += delta
		if peeking_timer > peeking_timer_threshold:
			set_physics_process(false)
			peeking_timer_threshold = 1.0
			peeking_timer = 0.0
			throw_rock_at_the_egg()
	
	else:
		peeking_timer = 0.0

#func _process(delta: float) -> void:
	#if rigid_body_copy:
		#global_position.y = rigid_body_copy.global_position.y
		#rotation_degrees = rigid_body_copy.rotation_degrees
	#
	#
	##if is_jumping:
		##current_air_time += delta
	##
	#var new_y = start_position.y + jump_velocity.y * current_air_time + 0.5 * gravity * pow(current_air_time, 2)
	##global_position.y = new_y
##
	##rotation_degrees = start_rotation.lerp(target_rotation, min(current_air_time / (jump_duration / 2), 1.0))
	##
	###if current_air_time > jump_duration / 2:
		###$Mesh.rotation_degrees = target_rotation.lerp(start_rotation, min((current_air_time - jump_duration / 2) / (jump_duration / 2), 1.0))
#
	##if new_y <= start_position.y:
	#if is_jumping && global_position.y <= start_position.y + 0.5:
		#
		#set_process(false)
		#global_position = start_position
		#rotation_degrees = start_rotation
		#is_jumping = false
		#_on_jump_finished()


func attach_self_to_nearest_marker() -> void:
	var marker = %Choose_available_marker_logic.get_available_marker(true)
	if marker == null:
		return
	marker.is_occupied = true
	current_marker = marker


func stop_throwing_tween() -> void:
	if tween_throwing and tween_throwing.is_running():
		tween_throwing.kill()
		rotation_degrees.x = 0.0
		%Rock.visible = false  # Optional: hide the rock if mid-animation
		fail_safing = true

func stop_animations() -> void:
	%facials_anim_player.stop()
	%bobble_animations.stop()
	%body_movement.stop()
	return
	
	
func change_facial_expression(expression: String) -> void:
	var face_nodes := {
		"standard": %Standard_face,
		"blinking": %Blinking_face,
		"scared": %Scared_face
	}
	
	for key in face_nodes.keys():
		if key == expression:
			face_nodes[key].show()
		else:
			face_nodes[key].hide()

	
func jumping_shocked_tween() -> void:
	projectile_throw_cancelled = true
	
	if stunned:
		return

	#$Rigidbody_doppleganger.full_range()


	await kill_all_current_tweens()
	await stop_animations()
	stop_throwing_tween()
	%Throwing_patterns.stop_throwing()

	currently_peeking = true
	stunned = true
	%facials_anim_player.play("scared")
	change_facial_expression('scared')
	
	$Mesh.hide()
	%the_bird.hide()
	await get_tree().create_timer(0.5).timeout
	is_jumping = true
	



func _on_jump_finished() -> void:
	$Mesh.show()

	await get_tree().create_timer(1.0).timeout
	%the_bird.show()
	%bobble_animations.play('wobble')
	%facials_anim_player.play('blinking_twice')
	stunned = false
	change_facial_expression('standard')
	flip_the_bird(2.0)
	
	#duck_behind_wall()


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
		await kill_all_current_tweens()
		await stop_animations()
		currently_peeking = true
		stunned = true
		%facials_anim_player.play("scared")
		change_facial_expression('blinking')
		var orig_rot : Vector3 = rotation_degrees
		self.rotation_degrees = Vector3(45, 45, 45)
		
		var _stunned_time = randf_range(3.0, 6.0)
		await get_tree().create_timer(_stunned_time).timeout
		if permanently_stunned_bool:
			return
		
		%facials_anim_player.play('blinking_twice')
		stunned = false
		self.rotation_degrees = orig_rot
		change_facial_expression('standard')
		
		duck_behind_wall()

	
func peeking_over_wall_sequence() -> void:
	if currently_peeking || walkies:
		return

	if tween_popping_up:
		tween_popping_up.kill()
		rotation_degrees = Vector3.ZERO
	
	taken_cover = false
	currently_peeking = true
	
	look_at(egg.global_position, Vector3.UP, false)
	orig_pos = global_position
	
	var random_dur : float = randf_range(0.1, 1.0)
	tween_popping_up = create_tween()
	tween_popping_up.tween_property(self, "global_position:y", first_up_dist, spotter_reveal_dur / 4).as_relative().set_trans(trans_popping_up).set_ease(ease_popping_up)
	tween_popping_up.tween_property(self, "global_position:y", second_up_dist, spotter_reveal_dur).as_relative().set_trans(trans_popping_up).set_ease(ease_popping_up)
	tween_popping_up.tween_interval(random_dur)
	await tween_popping_up.finished

	set_physics_process(true)
	%body_movement.play('moving_around')



func check_duck_down() -> void:
	duck_down_counter += 1
	if duck_down_counter >= ducked_down_threshold:
		duck_down_counter = 0
		ready_to_duck_down = true
	else:
		pass
		
func check_throw_counter() -> void:
	thrown_counter += 1
	if thrown_counter >= thrown_threshold:
		thrown_counter = 0
		ready_to_duck_down = true
	else:
		pass


func being_shot_at() -> void:
	being_courageous = false
	crosshair_touching_me = false
	change_facial_expression('scared')
	crosshair_spotted_me()

func crosshair_spotted_me() -> void:
	if crosshair_touching_me || being_courageous:
		return
	
	if tween_throwing:
		tween_throwing.kill()
	
	going_through_first_sequence = false
	currently_peeking = false
	being_courageous = false
	crosshair_touching_me = true
	check_duck_down()
	peeking_timer = 0.0
	
	if first_time_crosshair_touching_me:
		first_time_crosshair_touching_me = false
		change_facial_expression('scared')
	else:
		change_facial_expression('blinking')
		
	$SFX/duck_sfx.pitch_scale = randf_range(0.9,1.15)
	$SFX/duck_sfx.play()
	$Mesh/throw_arm.stop_tween()
	look_at(player.global_position, Vector3.UP, false)
	await get_tree().create_timer(0.2).timeout
	
	var rand_chance_for_courage = randi_range(0,20)
	if rand_chance_for_courage > 15: # 19
		being_courageous = true
	
	duck_behind_wall()
	


func duck_behind_wall() -> void:
	#if stunned || taken_cover:
		#return
	if stunned: return
	
	taken_cover = true
	$Mesh/throw_arm.stop_tween()
	
	if tween_popping_up:
		tween_popping_up.stop()
		tween_popping_up.kill()
		
	if tween_ducking:
		tween_ducking.kill()

	tween_ducking = create_tween()
	tween_ducking.tween_property(self, "global_position:y", orig_pos.y, 0.2).set_trans(Tween.TRANS_BACK)
	await tween_ducking.finished
	
	if going_through_first_sequence:
		$Mesh.rotation_degrees.y = 0.0
		change_facial_expression('standard')
		currently_peeking = false
		crosshair_touching_me = false
		being_courageous = false
		throwing_projectiles = false
		return
		
	
	$Mesh.rotation_degrees.y = 0.0
	
	%fail_safe_timer.start(4.0)
	
	while throwing_projectiles:
		await get_tree().create_timer(0.15).timeout

	%fail_safe_timer.stop()
	change_facial_expression('standard')
	
	currently_peeking = false
	crosshair_touching_me = false
	being_courageous = false
	throwing_projectiles = false
	set_physics_process(true)
	
	var rand_timer_dur : float = randf_range(0.5,2.0)
	if ready_to_duck_down:
		ready_to_duck_down = false
		flip_the_bird(rand_timer_dur)
		
	else:
		await get_tree().create_timer(0.25).timeout
		peeking_over_wall_sequence()


func flip_the_bird(rand_timer_dur : float) -> void:
	var tween = create_tween()
	tween.tween_property(%the_bird, "visible", true, 0.05)
	tween.parallel().tween_property(%the_bird, "position:y", 0.65, 0.2).as_relative()
	tween.tween_interval(rand_timer_dur / 2)
	tween.tween_property(%the_bird, "position:y", -0.65, 0.15).as_relative()
	tween.tween_property(%the_bird, "visible", false, 0.05)
	tween.tween_interval(rand_timer_dur/4)
	await tween.finished
	
	%the_bird.position = Vector3.ZERO
	%Throwing_patterns.throw_distraction_rocks()
	await get_tree().create_timer(0.7).timeout
	walk_to_position()


func throw_rock_at_the_egg_tween() -> void:

	tween_throwing = create_tween()

	tween_throwing.tween_property($Mesh, "rotation_degrees:x", -45.0, 0.2)
	tween_throwing.parallel().tween_property(self, "global_position:y", -0.2, 0.2).as_relative().set_ease(Tween.EASE_OUT_IN)
	
	tween_throwing.tween_interval(0.25)
	tween_throwing.parallel().tween_property($Mesh, "rotation_degrees:x", 45.0, 0.175)
	tween_throwing.parallel().tween_property(self, "global_position:y", 0.25, 0.175).as_relative().set_ease(Tween.EASE_IN_OUT)
	tween_throwing.tween_callback(throwing_part_2)
	
	tween_throwing.tween_property(self, "global_position:y", -0.1, 0.1).as_relative().set_ease(Tween.EASE_OUT_IN)
	tween_throwing.parallel().tween_property($Mesh, "rotation_degrees:x", 0.0, 0.1)
	tween_throwing.tween_interval(0.1)
	await tween_throwing.finished
	
	duck_behind_wall()


func throw_rock_at_the_egg() -> void:
	if !can_throw_projectiles || throwing_projectiles:
		return
	
	fail_safing = false
	throwing_projectiles = true
	projectile_throw_cancelled = false
	throw_rock_at_the_egg_tween()
	
func throwing_part_2() -> void:

	if projectile_throw_cancelled:
		return
	
	%Throwing_patterns.pick_throwing_pattern()
	

func throwing_finished() -> void:
	if going_through_first_sequence:
		%First_appearance_sequence.finished_first_throw()
		check_throw_counter()
		return
		
	check_throw_counter()
	throwing_projectiles = false
	fail_safing = true
	set_physics_process(true)

func walk_to_position() -> void:
	print('Walkies 1')
	%fail_safe_timer.start(4.0)
	
	if walkies:
		return
		
	print('Walkies 2')
	walkies = true
	throwing_projectiles = false  # reset this before walking

	if current_marker:
		current_marker.is_occupied = false
		current_marker = null

	var chosen_marker = %Choose_available_marker_logic.get_available_marker(true)
	if chosen_marker == null:
		return

	var target_pos : Vector3 = chosen_marker.global_position

	if global_position == target_pos:
		chosen_marker = %Choose_available_marker_logic.get_available_marker(false)
		if chosen_marker == null:
			return
		target_pos = chosen_marker.global_position
 
	chosen_marker.is_occupied = true
	await get_tree().create_timer(0.1).timeout

	var distance := start_pos.distance_to(target_pos)
	var duration := distance / walk_speed

	look_at(target_pos, Vector3.UP, false)

	if walk_tween:
		walk_tween.stop()
		bob_tween.kill()
		walk_tween.kill()
		bob_tween.kill()

	walk_tween = create_tween()
	walk_tween.tween_property(self, "global_position", target_pos, duration).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN_OUT)

	bob_tween = create_tween()
	var bob_cycles := int(duration * bob_speed)
	for i in range(bob_cycles):
		var up_down_time := duration / (bob_cycles * 2.0)
		bob_tween.tween_property(self, "global_position:y", bob_amount, up_down_time).as_relative()
		bob_tween.tween_property(self, "global_position:y", orig_pos.y, up_down_time)
	bob_tween.tween_property(self, "global_position:y", global_position.y, 0.1)

	await walk_tween.finished
	
	print('Walkies 3')
	%fail_safe_timer.stop()
	
	
	walkies = false
	global_position.y = target_pos.y
	current_marker = chosen_marker
	peeking_over_wall_sequence()


func head_look_away_tween() -> void:
	var target_rot : Vector3 = await pick_turn_rot()
	var orig_rot : Vector3 = rotation_degrees
	var rand_duration : float = 0.2
	#%facials_anim_player.play('blinking_once')

	tween_rotate_head = create_tween()
	tween_rotate_head.tween_property(self, "rotation_degrees:y", -target_rot.y / 10, 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CIRC)
	tween_rotate_head.tween_property(self, "rotation_degrees:y", target_rot.y, 0.1).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK) #.set_trans(Tween.TRANS_CIRC)
	tween_rotate_head.tween_interval(rand_duration)
	tween_rotate_head.tween_property(self, "rotation_degrees", orig_rot, 0.15).set_ease(Tween.EASE_OUT).set_delay(0.5).set_trans(Tween.TRANS_SPRING)
	
	await tween_rotate_head.finished
	can_throw_projectiles = true
	if first_time_crosshair_touching_me:
		set_physics_process(true)
	
func pick_turn_rot() -> Vector3:
	if global_position.x > 0:
		return Vector3(0,45.0,0)
	else:
		return Vector3(0,-45.0,0)
		
	#return %Head_turn_original.pick_turn_rot()


func play_sound() -> void:
	$SFX/Poking_sfx.play()

	
func kill_all_current_tweens() -> void:
	if tween_popping_up:
		tween_popping_up.kill()
		
	if tween_ducking:
		tween_ducking.kill()

	if tween_rotate_head:
		tween_rotate_head.kill()
		
	if tween_throwing:
		tween_throwing.kill()

	return


func _on_area_3d_area_entered(area: Area3D) -> void:
	if area.is_in_group('bullet') && stunned && !dying:
		var _pitch = randf_range(0.9,1.15)
		$SFX/duck_sfx.pitch_scale
		CommonCode.play_sound_duplicate_instance($SFX/duck_sfx, 0.0, $SFX/duck_sfx.volume_db + 5.0)
		await get_tree().create_timer(0.15).timeout
		%Dying_sequence.die()

	#if area.is_in_group('spotter_throw_area') && walkies && !dying && !null:
	if is_instance_valid(area) and area.is_in_group('spotter_throw_area') and walkies and not dying:

		print('triggered the wall')
		var throw_chance := randi_range(1,2)
		if throw_chance > 0:
			if walkies and !throwing_projectiles:
				throwing_projectiles = true
				%Throwing_patterns.throw_single()
				print('threw something')

func _on_fail_safe_timer_timeout() -> void:
	
	
	
	#print(throwing_projectiles, " Throw Project")
	#print(stunned, " Stunned")
	#print(walkies, " Walkies")
	#print(taken_cover, " Taken_cover")
	#print(crosshair_touching_me, " crosshair_touching_me")
	
	if !is_jumping:
		print('this may be causing issues in the future')
		stunned = false

	if !dying and !stunned:
		
		taken_cover = false
		throwing_projectiles = false
		crosshair_touching_me = false
		peeking_timer = 0.0
		set_physics_process(true)
		#peeking_over_wall_sequence()
		walkies = false
		walk_to_position()
