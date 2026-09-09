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
## Used when the script says `bird` / `birds` with no speed word.
@export var speed_default := 1.0
@export var speed_slow := 0.55
@export var speed_fast := 1.8

var flight_timer := 0.0

var	shrink_tween : Tween


func _ready() -> void:
	hide()
	set_process(false)
	path_follow_3d.progress = 0.0
	await get_tree().create_timer(5.0, false).timeout
	start_birds() 

func start_birds(speed_mode: String = "default") -> void:
	var mode := speed_mode.strip_edges().to_lower()
	match mode:
		"slow":
			speed_multiplier = speed_slow
		"fast":
			speed_multiplier = speed_fast
		_:
			speed_multiplier = speed_default

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
