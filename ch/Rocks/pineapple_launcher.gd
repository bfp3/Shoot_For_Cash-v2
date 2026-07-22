extends Node3D

@onready var pineapple : RigidBody3D  = $Pineapple
@onready var pineapple_2: RigidBody3D = $Pineapple2
@onready var pineapple_3: RigidBody3D = $Pineapple3

@export var left_marker: Marker3D
@export var right_marker: Marker3D

@export var round_manager : RoundManager

var x_positions : Array = [-7,-5,-3,-1,1,3,5,7]

func start_bonus_round() -> void:
	gl_PlayerState.dataset.power_bonus_round_pineapples = 0
	%PerfectParticles.emitting = true
	%PerfectParticles2.emitting = true
	
	await get_tree().create_timer(1.0).timeout
	
	await get_tree().create_timer(1.0).timeout
	launch_pineapple(pineapple)

	await get_tree().create_timer(2.0).timeout
	launch_pineapple(pineapple_2)

	await get_tree().create_timer(2.0).timeout
	launch_pineapple(pineapple_3)


func stop_pineapples() -> void:
	await get_tree().create_timer(2.0).timeout
	pineapple.reset_stats()
	pineapple_2.reset_stats()
	pineapple_3.reset_stats()


func launch_pineapple(body : RigidBody3D) -> void:
		
	body.update_active()
	#var sideways := true
	#if sideways:
	body.exit_side = body.ExitSide.TOP
	# Original vertical/sideways launch
	body.global_position.x = x_positions.pick_random()

	var x_variation = 0 #randf_range(-1.0, 1.0)
	var upward_force = randf_range(9.5, 10.0)

	var impulse = Vector3(
		x_variation,
		upward_force * body.force_multiplier,
		0.0
	) * body.pulse_magnitude

	body.apply_central_impulse(impulse)
	body.apply_torque_impulse(Vector3.RIGHT * 3000.0)
	body.start_timer()

	
	
	#extends Node3D
#
#@export var left_marker: Marker3D
#@export var right_marker: Marker3D
#@export var round_manager: RoundManager
#
#const ROW_SIZE := 8
#const DELAY_BETWEEN_ROWS := 2.0
#const DELAY_WITHIN_ROW := 0.0  # set > 0 if you want a stagger inside each row
#
#var pineapples: Array[RigidBody3D] = []
#
#func _ready() -> void:
	#_collect_pineapples()
#
#func _collect_pineapples() -> void:
	#pineapples.clear()
	#for child in get_children():
		#if child is RigidBody3D:
			#pineapples.append(child)
#
#func start_bonus_round() -> void:
	#gl_PlayerState.dataset.power_bonus_round_pineapples = 0
	#%PerfectParticles.emitting = true
	#%PerfectParticles2.emitting = true
#
	#await get_tree().create_timer(1.0).timeout
	#await get_tree().create_timer(1.0).timeout
#
	## Launch all children in rows of 8
	#for row_start in range(0, pineapples.size(), ROW_SIZE):
		#var row := pineapples.slice(row_start, min(row_start + ROW_SIZE, pineapples.size()))
		#for body in row:
			#launch_pineapple(body)
			#if DELAY_WITHIN_ROW > 0.0:
				#await get_tree().create_timer(DELAY_WITHIN_ROW).timeout
		#if row_start + ROW_SIZE < pineapples.size():
			#await get_tree().create_timer(DELAY_BETWEEN_ROWS).timeout
#
#func stop_pineapples() -> void:
	#await get_tree().create_timer(2.0).timeout
	#for body in pineapples:
		#body.reset_stats()
#
#func launch_pineapple(body: RigidBody3D) -> void:
	#body.update_active()
	#var sideways := true
	#if sideways:
		#body.exit_side = body.ExitSide.TOP
		#body.global_position.x = [-7, -5, -3, -1, 1, 3, 5, 7].pick_random()
		#var x_variation = 0
		#var upward_force = randf_range(9.5, 10.0)
		#var impulse = Vector3(
			#x_variation,
			#upward_force * body.force_multiplier,
			#0.0
		#) * body.pulse_magnitude
		#body.apply_central_impulse(impulse)
		#body.start_timer()
	#else:
		#var shoot_from_left := randf() < 0.5
		#var force = (
			#randf_range(9.5, 10.0)
			#* body.force_multiplier
			#* 1.5
			#* body.pulse_magnitude
		#)
		#if shoot_from_left:
			#body.exit_side = body.ExitSide.RIGHT
			#body.global_position = left_marker.global_position
			#body.apply_central_impulse(Vector3(-force, 0.0, 0.0))
			#body.start_timer()
		#else:
			#body.exit_side = body.ExitSide.LEFT
			#body.global_position = right_marker.global_position
			#body.apply_central_impulse(Vector3(force, 0.0, 0.0))
			#body.start_timer()


	#
#func XAlternative_version() -> void:
	#for i in range(3):
		#gl_PlayerState.dataset.total_pineapples_destroyed = 0
		#await get_tree().create_timer(1.0).timeout
		#launch_pineapple(pineapple)
#
		##await get_tree().create_timer(2.0).timeout
		#launch_pineapple(pineapple_2)
		#
		#
		#gl_PlayerState.dataset.total_pineapples_destroyed = 0
		##await get_tree().create_timer(2.0).timeout
		#launch_pineapple(pineapple_3)
		#
		#await get_tree().create_timer(5.0).timeout
		#pineapple.reset_stats()
		#pineapple_2.reset_stats()
		#pineapple_3.reset_stats()
		#await get_tree().create_timer(0.5).timeout
		#
	#gl_PlayerState.dataset.total_pineapples_destroyed = 3

#
#func sideways() -> void:
	#else:
		## 50/50 chance of left->right or right->left
		#var shoot_from_left := randf() < 0.5
#
		#var force = (
			#randf_range(9.5, 10.0)
			#* body.force_multiplier
			#* 1.5
			#* body.pulse_magnitude
		#)
#
		#if shoot_from_left:
			#body.exit_side = body.ExitSide.RIGHT
			#body.global_position = left_marker.global_position
			#body.apply_central_impulse(Vector3(-force, 0.0, 0.0))
			#body.start_timer()
		#else:
			#body.exit_side = body.ExitSide.LEFT
			#body.global_position = right_marker.global_position
			#body.apply_central_impulse(Vector3(force, 0.0, 0.0))
			#body.start_timer()
