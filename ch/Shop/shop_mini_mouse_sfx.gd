extends Node
## Mini-game copy of mouse turning SFX — only active while the shop mini-game is open.

@onready var turn_left: AudioStreamPlayer = $Turn_left
@onready var turn_right: AudioStreamPlayer = $Turn_right
@onready var turn_up: AudioStreamPlayer = $Turn_up
@onready var turn_down: AudioStreamPlayer = $Turn_down
@onready var stop_timer: Timer = $StopTimer

var active := false
var last_mouse_motion_x := 0.0
var last_mouse_motion_y := 0.0
var threshold := 20.0


func _ready() -> void:
	stop_timer.wait_time = 0.1
	stop_timer.timeout.connect(_on_stop_timer_timeout)
	stop_timer.start()
	mute()


func set_active(value: bool) -> void:
	active = value
	if value:
		unmute()
	else:
		mute()
		_stop_all()


func mute() -> void:
	turn_left.volume_db = -80.0
	turn_right.volume_db = -80.0
	turn_up.volume_db = -80.0
	turn_down.volume_db = -80.0


func unmute() -> void:
	turn_left.volume_db = -44.0
	turn_right.volume_db = -44.0
	turn_up.volume_db = -44.0
	turn_down.volume_db = -44.0


func _input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseMotion:
		last_mouse_motion_x = event.relative.x
		last_mouse_motion_y = event.relative.y

		var turning_left := last_mouse_motion_x < -threshold
		var turning_right := last_mouse_motion_x > threshold
		var turning_up := last_mouse_motion_y < -threshold
		var turning_down := last_mouse_motion_y > threshold

		if turning_left:
			if not turn_left.playing:
				turn_left.play()
		elif turning_right:
			if not turn_right.playing:
				turn_right.play(0.5)

		if turning_up:
			if not turn_up.playing:
				turn_up.play()
		elif turning_down:
			if not turn_down.playing:
				turn_down.play(0.5)


func _on_stop_timer_timeout() -> void:
	if not active:
		return
	_stop_all()
	last_mouse_motion_x = 0.0
	last_mouse_motion_y = 0.0


func _stop_all() -> void:
	turn_left.stop()
	turn_right.stop()
	turn_up.stop()
	turn_down.stop()
