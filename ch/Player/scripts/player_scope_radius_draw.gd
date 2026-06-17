extends Control
#@onready var player: Player = $"../../.."
@export var player : Player
@onready var radius = player.power_target_circle
@onready var arc_radius = radius * 2
@export var circle_color := Color('ffffff80')
@export var test_radius := 60.0

#func _physics_process(delta: float) -> void:
	#if Engine.get_physics_frames() % 60 == 0:
		#var center = size / 2.0
		##_draw()
		#draw_radius(test_radius)
		#return

func display_circle() -> void:
	#var center = size / 2.0
	show()
	for i in range(3):
		draw_radius(test_radius)
		await get_tree().create_timer(1.0).timeout
	#return

	hide()

func _draw() -> void:
	var center = size / 2.0
	#draw_circle(center, radius, circle_color, true, false)
	draw_circle(center, radius, circle_color)
	
func draw_radius(_player_radius : float) -> void:
	radius = _player_radius

	hide()
	await get_tree().create_timer(0.25).timeout

	queue_redraw()   # ← replace _draw()

	show()
