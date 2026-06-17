extends CharacterBody3D
class_name Standard_Cannonball
const BOMBS_LANDING_IN_THE_DISTANCE = preload('uid://disfcwr18xhfw')
const RED_TAKEN_OUT_SFX = preload("res://sfx/pineapple_sound_3.wav")
const ARROW_AREA_3D = preload("res://ch/weapons/bullet_area3D.tscn")

@onready var new_feedback = get_tree().get_first_node_in_group("HUD_feedback_corner")

@export var rotate_faster := false
@export var spotter_projectile := false
@export var smokebomb := false
var hit_by_bullet := false

@export_group('Curves', '')
@export var flight_speed_curve : Curve
@export var lateral_curve : Curve
@export var scale_curve : Curve

@export var base_flight_time: float = 1.5
@export var lateral_amplitude : float = 0.0  # Max distance to swing left/right
@export var scale_multiplier: float = 1.0  # Optional: to control overall size
@export var travel_speed: float = 10.67  # units per second


@export_group('Export vars', '')
var waypoints: Array[Vector3] = [] # List of positions
var durations: Array[float] = []   # Duration for each movement segment


var target_hit := false
var cannonball_hit_ground := false
var smokescreen := false

var target_position: Vector3
@export var arc_strength: float = 0.5 # Controls height of the arc

var spawned_arrows: Array[Area3D] = []

var tween_moving_to_marker: Tween = null

var num_points: int = 50

var moving := true

var slow_travel_time : float
var fast_travel_time : float

var special_bomb := false
var special_bomb_health :=1 #6

var spawned_my_own_arrow := false
var target_is_going_to_hit_cage := false
var new_arrow : Node3D = null

signal target_destroyed
signal bomb_destroyed

var was_hit := false


var will_hit_cage := false

@onready var bomb_mesh: Node3D = $Mesh/Bomb_mesh
@onready var particles: GPUParticles3D = $Trails

@export var probability_of_special_bomb := 1.0

var arc_start_time := 0.0
var arc_duration := 0.0


func _ready() -> void:
	
	var cms : CMS = get_tree().get_first_node_in_group('CMS')
	if cms:
		connect("bomb_destroyed", cms._on_cannonball_destroyed)
		cms._on_cannonball_created()
	
	#EventBus.instance.egg_pulsed.connect(was_hit_tween)
	
	create_smoke_screen_timer()
	setup_direction_look_timer()
	tumbling_tween()
	check_if_bomb_is_special_bonus_one()
	#scale_tween()
	if $Mesh/Missile_mesh:
		var rand_time = randf_range(8.0,10.0)
		await get_tree().create_timer(rand_time).timeout
		recalculate_arc_path()

func recalculate_arc_path() -> void:
	# Stop any previous movement
	if tween_moving_to_marker:
		tween_moving_to_marker.stop()

	# Reset data
	waypoints.clear()
	durations.clear()

	# Start from current position
	var start_pos: Vector3 = global_position

	# How high the missile should go before moving to target
	var vertical_lift_distance: float = 5.0
	var lift_duration: float = 0.4
	var pause_duration: float = 0.15

	# Peak position after vertical lift
	var peak_pos: Vector3 = start_pos + Vector3.UP * vertical_lift_distance

	# Distance from peak to target for straight flight
	var distance_to_target: float = peak_pos.distance_to(target_position)
	var fly_duration: float = distance_to_target / travel_speed

	# For visual direction alignment
	$Mesh.look_at(peak_pos, Vector3.UP)

	# Setup and play the tween
	tween_moving_to_marker = create_tween()
	tween_moving_to_marker.set_trans(Tween.TRANS_BACK)
	tween_moving_to_marker.set_ease(Tween.EASE_IN)

	#tween_moving_to_marker.tween_property(self, "global_position", peak_pos, lift_duration)

	tween_moving_to_marker.tween_interval(pause_duration)

	tween_moving_to_marker.tween_callback(func(): $Mesh.look_at(target_position, Vector3.UP))  # Optional: reorient before diving
	tween_moving_to_marker.tween_property(self, "global_position", target_position, fly_duration)

	tween_moving_to_marker.tween_callback(Callable(self, "cannonball_hit_the_ground"))

	arc_start_time = Time.get_ticks_msec() / 1000.0
	arc_duration = lift_duration + pause_duration + fly_duration



func setup_direction_look_timer():
	var timer = Timer.new()
	timer.wait_time = 0.05
	timer.one_shot = false
	timer.autostart = true
	timer.timeout.connect(update_mesh_facing)
	add_child(timer)

func update_mesh_facing():
	if !moving or waypoints.size() < 2:
		return

	var current_pos = global_position

	# Look ahead to the next waypoint
	var next_index = 0
	var min_dist = INF
	for i in range(waypoints.size()):
		var d = global_position.distance_to(waypoints[i])
		if d < min_dist:
			min_dist = d
			next_index = i
		else:
			break

	if next_index >= waypoints.size() - 1:
		return

	var next_pos = waypoints[next_index + 1]
	var direction = (next_pos - current_pos).normalized()

	# Optional: restrict rotation to Y axis only
	var look_target = Vector3(current_pos.x + direction.x, current_pos.y, current_pos.z + direction.z)
	$Mesh.look_at(look_target, Vector3.UP)

	
#func scale_tween() -> void:
	#
	#scale = Vector3.ONE / 10
#
	#var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	#tween.tween_property(self, "scale", Vector3.ONE, 0.15)
	#await tween.finished

	
func create_smoke_screen_timer() -> void:
	if smokescreen:
		var timer = Timer.new()
		add_child(timer)
		timer.timeout.connect(_on_timer_timeout)
		timer.wait_time = randf_range(2.25, 3.0) #randf_range(5.0, 6.0)
		timer.start()

func _on_timer_timeout() -> void:
	was_hit_tween()
	
func check_if_bomb_is_special_bonus_one() -> void:
	var rand_chance = randf_range(0.0, 1.0)
	if rand_chance >= probability_of_special_bomb:
		special_bomb = true
	else:
		special_bomb = false
		
	if special_bomb:
		$CollisionShape3D.shape.radius = 0.42
		$Mesh/Special_mesh.show()
		$Mesh/Bomb_mesh.hide()
		
	
func tumbling_tween() -> void:
	
	if !$Mesh/Missile_mesh:
		var dur : float = 3.0
		if rotate_faster:
			dur = 1.5
		$Mesh.look_at(target_position, Vector3.UP, true)
		var tween = create_tween().set_loops()
		tween.tween_property($Mesh, "rotation_degrees:x", -360.0, dur).as_relative().set_trans(Tween.TRANS_SINE)
		await tween.finished
	
	else:
		var dur : float = 1.0
		$Mesh.look_at(target_position, Vector3.UP, true)
		var tween = create_tween().set_loops()
		tween.tween_property($Mesh, "rotation_degrees:z", -360.0, dur).as_relative()
		await tween.finished

#func calculate_base_flight_time(start_pos: Vector3, end_pos: Vector3) -> float:
	#var distance = start_pos.distance_to(end_pos)
	#var time_per_unit := 1.0 / 6.0  # 1 sec per 6 units
	#var time = distance * time_per_unit
	#return base_flight_time + (distance * 0.6) # time
	##clamp(time, 0.5, 1.5)  # Clamp to min 0.5s, max 5.0s
#


func calculate_base_flight_time(start_pos: Vector3, end_pos: Vector3) -> float:
	
	#Control the travel speed here
	
	var distance = start_pos.distance_to(end_pos)
	var distance_speed = distance / travel_speed
	#distance_speed = clamp(distance_speed, 0.4, 2.4) #1.4
	#return distance / travel_speed
	return distance_speed

func spawn_my_arrow() -> void:
	#if new_arrow:
		#return
	
	new_arrow = ARROW_AREA_3D.instantiate()
	#add_child(new_arrow)
	get_tree().get_current_scene().add_child(new_arrow)
	var player_gun = get_tree().get_first_node_in_group('player_gun')
	
	new_arrow.global_position = player_gun.get_barrel_position()
	#spawned_my_own_arrow = true
		
	spawned_arrows.append(new_arrow)


		
		
func _physics_process(delta: float) -> void:
	
	if scale_curve == null or arc_duration == 0.0:
		return
	var current_time = Time.get_ticks_msec() / 1000.0
	var t = clamp((current_time - arc_start_time) / arc_duration, 0.0, 1.0)

	var scale_factor = scale_curve.sample(t) * scale_multiplier
	scale = Vector3.ONE * scale_factor

func target_launcher_fire(threat_type : String) -> void:
	var result = find_target_position(threat_type)
	target_position = result["position"]
	will_hit_cage = result["will_hit_cage"]
	
	base_flight_time = calculate_base_flight_time(global_position, target_position)
	generate_arc_path(global_position, target_position)
	start_arc_movement()
	set_meta("type", threat_type)
	
	
func find_target_position(threat_color: String) -> Dictionary:
	var marker_node
	if GameManager.in_retry_world:
		marker_node = get_tree().get_first_node_in_group("Cannonball_player_marker")
		if marker_node == null:
			marker_node = get_tree().get_first_node_in_group("Target_Markers_manager")
	else:
		marker_node = get_tree().get_first_node_in_group("Target_Markers_manager")
		
	if marker_node == null:
		push_error("No TargetMarkers node found")
		return {"position": global_position, "will_hit_cage": false}

	return marker_node._choose_marker(threat_color)


func generate_arc_path(start_pos: Vector3, end_pos: Vector3):
	waypoints.clear()

	var distance = start_pos.distance_to(end_pos)
	var h_max = distance * arc_strength

	for i in range(num_points + 1):
		var t = float(i) / num_points

		# Base arc path
		var x = lerp(start_pos.x, end_pos.x, t)
		var z = lerp(start_pos.z, end_pos.z, t)
		var y = lerp(start_pos.y, end_pos.y, t) + h_max * (1 - (2 * t - 1) ** 2)

		var base_pos = Vector3(x, y, z)

		# === Apply lateral offset ===
		if lateral_curve:
			var offset = lateral_curve.sample(t) * lateral_amplitude

			# Compute direction and perpendicular
			var forward_dir = (end_pos - start_pos).normalized()
			var left_dir = forward_dir.cross(Vector3.UP).normalized()

			base_pos += left_dir * offset

		waypoints.append(base_pos)


func start_arc_movement():

	if waypoints.is_empty() or not moving or flight_speed_curve == null:
		return

	tween_moving_to_marker = create_tween()
	tween_moving_to_marker.set_trans(Tween.TRANS_LINEAR)
	tween_moving_to_marker.set_ease(Tween.EASE_IN_OUT)


	var base_time := base_flight_time # Total travel time (you can export this as a tunable var)
	var step_count := waypoints.size()
	durations.clear()

	for i in range(step_count - 1):
		var t = float(i) / float(step_count - 1)  # Normalized 0-1
		var speed_scale = flight_speed_curve.sample(t)
		
		# Avoid zero or near-zero speed values
		speed_scale = max(speed_scale, 0.01)

		var segment_duration = (base_time / step_count) / speed_scale
		durations.append(segment_duration)
		
		arc_start_time = Time.get_ticks_msec() / 1000.0
		arc_duration = 0.0
		for d in durations:
			arc_duration += d
		

		tween_moving_to_marker.tween_property(self, "global_position", waypoints[i + 1], segment_duration)

	await tween_moving_to_marker.finished
	global_position = target_position
	cannonball_hit_the_ground()


func points_counter_trails() -> void:

	var new_points_particles : GPUParticles3D = $Points_particles.duplicate()
	get_tree().get_current_scene().add_child(new_points_particles)
	
	if will_hit_cage:
		new_points_particles.red = true
	new_points_particles.global_position = global_position
	new_points_particles.activate()

func smokebomb_particles() -> void:
	
	var new_particles : GPUParticles3D
	if !hit_by_bullet:
		new_particles = %Smoke_quick
	else:
		new_particles = %Smoke_quick2
		
	if new_particles:
		new_particles.add_to_group("smoke_particles")
		new_particles.emitting = true
		new_particles.duplicate_particles = true
		new_particles.show()
		new_particles.reparent(get_tree().get_current_scene(), true)
		new_particles.global_position = global_position


func smoke_particles() -> void:
	if smokebomb:
		smokebomb_particles()
		return
	
	if special_bomb:
		special_particles()
		
	#if will_hit_cage:
		#red_particles_emit()
	
	var new_particles : GPUParticles3D
	if special_bomb:
		new_particles = $Special_smoke
	else:
		new_particles = $Smoke_quick #.duplicate()
		
	if new_particles:
		new_particles.add_to_group("smoke_particles")
		new_particles.emitting = true
		new_particles.duplicate_particles = true
		new_particles.show()
		new_particles.reparent(get_tree().get_current_scene(), true)
		#get_tree().get_current_scene().add_child(new_particles)
		new_particles.global_position = global_position


func red_particles_emit() -> void:
	var new_particles = $Red_particles
	if new_particles:
		
		new_particles.duplicate_particles = true
		new_particles.show()
		new_particles.reparent(get_tree().get_current_scene(), true)
		new_particles.global_position = global_position
		await get_tree().create_timer(0.1).timeout
		new_particles.emitting = true

func special_particles() -> void:
	var new_particles = $Special_particles #.duplicate()
	if new_particles:
		new_particles.add_to_group("smoke_particles")
		new_particles.emitting = true
		new_particles.duplicate_particles = true
		new_particles.show()
		new_particles.reparent(get_tree().get_current_scene(), true)
		#get_tree().get_current_scene().add_child(new_particles)
		new_particles.global_position = global_position

func remove_from_groups() -> void:
	remove_from_group('cannonball')
	remove_from_group('Moving_target')
	remove_from_group('Target')


func cannonball_hit_the_ground() -> void:
	cannonball_hit_ground = true
	instance_hud_missed_shot_feedback()
	was_hit_tween()
	points_counter_trails()
	
	


func was_hit_tween() -> void:
	remove_from_groups()
	trails_reparent()
	bomb_destroyed.emit()

	if tween_moving_to_marker:
		tween_moving_to_marker.stop()  # Stop the ongoing movement tween

	moving = false  # Prevent further movement

	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_callback(smoke_particles)
	tween.tween_property($Mesh, "scale", Vector3.ZERO, 0.10)
	await tween.finished

	destroy_self()


func play_red_hit_sfx() -> void:
	await get_tree().create_timer(0.5).timeout
	CommonCode.play_sound_instance_pitch_adjusted(RED_TAKEN_OUT_SFX, -25.0, 0.75)
	await get_tree().create_timer(0.1).timeout
	CommonCode.play_sound_instance_pitch_adjusted(RED_TAKEN_OUT_SFX, -25.0, 1.75)
	CommonCode.play_sound_instance_pitch_adjusted(RED_TAKEN_OUT_SFX, -25.0, 1.0)

func spotter_projectile_destroy() -> void:
	if tween_moving_to_marker:
		tween_moving_to_marker.stop()

	moving = false

	var bullet = null
	for area in $Area3D.get_overlapping_areas():
		if area.is_in_group('bullet'):
			bullet = area
			break

	if bullet == null:
		was_hit_tween()
		return

	# Always bounce in local -z direction (backward from facing direction)
	var local_backward = global_transform.basis.z.normalized()
	var bounce_target_pos = global_position + (local_backward * 2.0)

	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(self, "global_position", bounce_target_pos, 0.15)
	tween.parallel().tween_property($Mesh, "rotation_degrees:x", 360.0, 0.15).as_relative()
	tween.parallel().tween_property($Mesh, "rotation_degrees:y", 180.0, 0.15).as_relative()
	tween.parallel().tween_property($Mesh, "scale", $Mesh.scale / 2, 0.15)
	tween.tween_callback(was_hit_tween)



func _on_area_3d_area_entered(area: Area3D) -> void:
	
	if area.is_in_group('bullet') && !target_hit: # && special_bomb:
		if spotter_projectile:
			hit_by_bullet = true
			EventBus.instance.rock_destroyed.emit()
			#if area.has_method('cleanUp'):
				#area.cleanUp()
			#spotter_projectile_destroy()
			#return
		special_bomb_health -= 1
		
		#if tween_moving_to_marker:
			#tween_moving_to_marker.stop()
		#moving = false
		area.queue_free()
		#target_hit = true

		if area.has_method('cleanUp'):
			area.cleanUp()
			
		$reloading_sfx.play()
		
		if special_bomb_health <= 0:
			was_hit_tween()
			instance_hud_feedback()
			points_counter_trails()
			
		else:
			var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
			tween.tween_property($Mesh/Special_mesh, "scale", $Mesh/Special_mesh.scale * 1.5, 0.33)
			tween.parallel().tween_property($CollisionShape3D, "scale", $CollisionShape3D.scale * 1.5, 0.33)
			tween.parallel().tween_property($Area3D, "scale", $Area3D.scale * 1.5, 0.33)
			await tween.finished
			return
			
		return

	
	if area.is_in_group('bullet') && !target_hit:
		area.queue_free()
		target_hit = true

		if area.has_method('cleanUp'):
			area.cleanUp()
		
		$reloading_sfx.play()
		was_hit_tween()
		instance_hud_feedback()
		points_counter_trails()
		if !will_hit_cage:
			EventBus.instance.standard_cannonball_destroyed.emit()
		return

func instance_hud_feedback() -> void:

	if !new_feedback:
		return
		
	if special_bomb:
		GameManager.bombs_hit_by_player += ScoreGl.special_bonus_bomb
		new_feedback.main_score_SPECIAL_flash()
		new_feedback.main_score_update(ScoreGl.special_bonus_bomb)
		EventBus.instance.special_cannonball_destroyed_astray.emit()
		return

	elif will_hit_cage:
		GameManager.bombs_hit_by_player += ScoreGl.red_dots
		new_feedback.main_score_RED_flash()
		new_feedback.main_score_update(ScoreGl.red_dots)
		EventBus.instance.red_cannonball_destroyed.emit()
		
	else:
		GameManager.bombs_hit_by_player += ScoreGl.grey_dots
		new_feedback.main_score_GREY_flash()
		new_feedback.main_score_update(ScoreGl.grey_dots)
		EventBus.instance.standard_cannonball_destroyed_astray.emit()

func instance_hud_missed_shot_feedback() -> void:
	
	GameManager.shots_missed_during_round += ScoreGl.grey_dots_astray
	if new_feedback:
		if smokescreen:
			new_feedback.points_added_blink_feedback(ScoreGl.smokescreen_rounds)
			return

		else:
			new_feedback.points_added_blink_feedback(ScoreGl.grey_dots_astray)
			EventBus.instance.standard_cannonball_destroyed_astray.emit()

func destroy_self() -> void:
	$hitSound.play_sound()
	EventBus.instance.cannonball_destroyed.emit()
	target_destroyed.emit()
	shake_camera_on_impact()
	var crash_sound = BOMBS_LANDING_IN_THE_DISTANCE.instantiate()
	crash_sound.volume_db = -80.0
	get_tree().get_current_scene().add_child(crash_sound)
	crash_sound.play_sound_gently()
	
	if will_hit_cage:
		await play_red_hit_sfx()
		self.queue_free()
	else:
		self.queue_free()

func shake_camera_on_impact() -> void:
	var player_cam = get_tree().get_first_node_in_group('player_cam')
	var distance_from_player = global_position.distance_to(player_cam.global_position)
	player_cam.shake_camera_based_on_position(distance_from_player)

	
func trails_reparent() -> void:
	if $Trails:
		$Trails.connect_signal()
