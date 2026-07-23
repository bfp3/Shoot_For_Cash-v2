extends Control

var radius := 0
@export var circle_color := Color("ff000071")

func _draw() -> void:
	var _rad = gl_DataSet.dataset_float.power_target_circle[gl_PlayerState.dataset.power_target_circle]
	radius = _rad
	var center = size / 2.0
	draw_circle(center, radius, circle_color)

func _physics_process(delta: float) -> void:
	var current_frame = Engine.get_physics_frames()
	if current_frame % 120 == 0:
		_draw()
	return
		
	
	

func draw_radius(_player_radius : float) -> void:
	radius = _player_radius

	hide()
	await get_tree().create_timer(0.25).timeout

	queue_redraw()   # ← replace _draw()

	show()
