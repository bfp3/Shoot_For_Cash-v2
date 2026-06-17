extends Node

@onready var turn_left: AudioStreamPlayer = $Turn_left
@onready var turn_right: AudioStreamPlayer = $Turn_right
@onready var turn_up: AudioStreamPlayer = $Turn_up
@onready var turn_down: AudioStreamPlayer = $Turn_down
@onready var stop_timer: Timer = $StopTimer # Add a Timer node to your scene and reference it here

var last_mouse_motion_x = 0.0
var last_mouse_motion_y = 0.0
var threshold := 20

func _ready() -> void:
	stop_timer.wait_time = 0.1 # Adjust this value to change how frequently the timer checks for mouse movement
	stop_timer.start()


func mute() -> void:
	turn_left.volume_db = -80
	turn_right.volume_db = -80
	turn_up.volume_db = -80
	turn_down.volume_db = -80
	
func unmute() -> void:
	turn_left.volume_db = -44
	turn_right.volume_db = -44
	turn_up.volume_db = -44
	turn_down.volume_db = -44


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		last_mouse_motion_x = event.relative.x
		last_mouse_motion_y = event.relative.y

		# Handle left/right movement (x-axis)
		var turning_left = last_mouse_motion_x < -threshold
		var turning_right = last_mouse_motion_x > threshold

		# Handle up/down movement (y-axis)
		var turning_up = last_mouse_motion_y < -threshold
		var turning_down = last_mouse_motion_y > threshold
		
		if turning_left:
			if not turn_left.playing:
				turn_left.play()
			#turn_right.stop()

		elif turning_right:
			if not turn_right.playing:
				turn_right.play(0.5)
			#turn_left.stop()

		# Play sound for up movement
		if turning_up:
			if not turn_up.playing:
				turn_up.play()
			#turn_down.stop()

		# Play sound for down movement
		elif turning_down:
			if not turn_down.playing:
				turn_down.play(0.5)
			#turn_up.stop()

func _on_stop_timer_timeout() -> void:
	turn_left.stop()
	turn_right.stop()
	turn_up.stop()
	turn_down.stop()

	last_mouse_motion_x = 0.0
	last_mouse_motion_y = 0.0
	
	
	
	
	
	
