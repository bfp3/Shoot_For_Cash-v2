extends Node3D

#@onready var camera_3d: Camera3D = $Camera3D
#
## Breathing parameters
#@export var amplitude: float = 0.008  # Maximum movement distance
#@export var frequency: float = 0.4 # Breaths per second (0.25 = one full cycle every 4 seconds)
#@export var mod_amount := 5
#@export var cam_rotation_speed: float = 4.0
#@export var cam_rotation_amount: float = 0.15
#@export var wait_dur := 0.0
#
#var _time_passed := 0.0
#var _original_position := Vector3.ZERO
#
#func _ready() -> void:
	#_original_position = position
	##tween()
#
#func _physics_process(delta: float) -> void:
	#
	##var current_frame = Engine.get_physics_frames()
	#_time_passed += delta
	#
	##if current_frame % mod_amount == 0:
		#
		## Breathing motion using sine waves for smooth oscillation
	#var offset_y = sin(_time_passed * TAU * frequency) * amplitude
	#var offset_x = cos(_time_passed * TAU * frequency * 0.5) * amplitude * 0.5
	#
	#position = _original_position + Vector3(offset_x, offset_y, 0)
	#
