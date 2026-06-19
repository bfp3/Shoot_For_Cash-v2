extends Node3D

@export var flight_speed_curve: Curve
@export var flight_duration: float = 25.0
@onready var path_follow_3d: PathFollow3D = $'..'

#
#@onready var trails_built_in: MeshInstance3D = $body/bird/Trails_built_in
#@onready var trails_built_in_2: MeshInstance3D = $body/bird/Trails_built_in2
#@onready var trails_built_in_3: MeshInstance3D = $body/bird2/Trails_built_in
#@onready var trails_built_in_4: MeshInstance3D = $body/bird2/Trails_built_in2

@export var speed_multiplier := 1.0  # < 1 = slower, > 1 = faster

var flight_timer := 0.0

var	shrink_tween : Tween


func _ready() -> void:
	hide()
	set_process(false)
	path_follow_3d.progress = 0.0


func start_birds() -> void:

	path_follow_3d.progress = 0.0

	show()
	#trails_built_in._trailEnabled = true
	#trails_built_in_2._trailEnabled = true
	#trails_built_in_3._trailEnabled = true
	#trails_built_in_4._trailEnabled = true
	flight_timer = 0.0
	set_process(true)


func _process(delta: float) -> void:
		
	flight_timer += delta
	var t = clamp(flight_timer / flight_duration, 0.0, 1.0)
	path_follow_3d.progress += flight_speed_curve.sample(t) * speed_multiplier * delta
	
	if path_follow_3d.progress_ratio >= 1.0:

		_shrink_and_hide()


func _shrink_and_hide() -> void:
	if shrink_tween:
		shrink_tween.kill()

	#trails_built_in._trailEnabled = false
	#trails_built_in_2._trailEnabled = false
	#trails_built_in_3._trailEnabled = false
	#trails_built_in_4._trailEnabled = false
	set_process(false)
