extends RigidBody3D
#
#const BOMBS_LANDING_IN_THE_DISTANCE = preload("res://400_sounds/00_sfx/bombs_landing_in_the_distance.tscn")
#const RED_TAKEN_OUT_SFX = preload("res://400_sounds/SFX_pineapple_intro/pineapple_sound_3.wav")
#const SMOKE_LINGERING = preload("res://800_3D_materials/Particles/Smoke_particles/Smoke_lingering.tscn")
#const ARROW_AREA_3D = preload("res://200_characters/weapons/bullet_area3D.tscn")
#
#var respawn_time := 0.5
#
#var waypoints: Array[Vector3] = [] # List of positions
#var durations: Array[float] = []   # Duration for each movement segment
#var current_index: int = 0         # The index of the current segment
#var elapsed_time: float = 0.0      # Time spent in current segment
#var tween_duration: float = 0.0    # Total duration of current segment
#
#var target_hit := false
#var move_points = []
#var start_time = 0.0
#var travel_times = []
#var travel_directions = []
#var current_speed = 0.0
#
#var smokescreen := false
#
#var target_position: Vector3
#@export var travel_time: float = 2.0  # How long the arc should last
#@export var arc_strength: float = 0.5 # Controls height of the arc
#var destroy_siblings_mode := false
#
#var start_position: Vector3
#var tween_moving_to_marker: Tween = null
#var points: Array = []
#var num_points: int = 50
#
#var has_target_position := false
#
#var dying := false
#var moving := true
#
#var slow_travel_time : float
#var fast_travel_time : float
#
#var special_bomb_undetected_on_radar := false
#
#
#@export var split_odds: float = 0.5  # Probability of splitting into 3
#var has_been_split := false
#var spawned_my_own_arrow := false
#var target_is_going_to_hit_cage := false
#var new_arrow : Node3D = null
#@export var arrow_speed := 20.0  # Adjust speed as needed := 0.1
#
#signal target_destroyed
#signal bomb_destroyed
#
#var was_hit := false
#
#var target_node : Node3D
#var will_hit_cage := false
#
#@onready var particles: GPUParticles3D = $Particles/Trails
#
#func _ready() -> void:
	#$Timer.start()
	#
#func _on_timer_timeout() -> void:
	#var pineapple_sequence : PineappleEndingSeqeunceManager = get_tree().get_first_node_in_group('pineapple_ending_seqeunce_manager')
	#pineapple_sequence.wrap_up_pineapples()
	#destroy_self()
	#
#func destroy_self() -> void:
	#var crash_sound = BOMBS_LANDING_IN_THE_DISTANCE.instantiate()
	#crash_sound.volume_db = -80.0
	#get_tree().get_current_scene().add_child(crash_sound)
	#crash_sound.play_sound_gently()
	#var tween = create_tween()
	#tween.tween_property($Mesh, "scale", Vector3.ONE / 9, 0.25)
	#tween.parallel().tween_callback(smoke_particles).set_delay(0.1)
	#await tween.finished
	#if self != null:
		#self.queue_free()
		#
#func smoke_particles() -> void:
	#var new_particles = $Particles/Smoke_quick #.duplicate()
	#if new_particles:
		#new_particles.emitting = true
		#new_particles.duplicate_particles = true
		#new_particles.show()
		#new_particles.reparent(get_tree().get_current_scene(), true)
		#new_particles.global_position = global_position
