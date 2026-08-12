extends Control

@export var circle_radius := 50.0:
	set(value):
		circle_radius = value
		queue_redraw()

@export var circle_color := Color.WHITE:
	set(value):
		circle_color = value
		queue_redraw()

@export var circle_outline_width := 3.0:
	set(value):
		circle_outline_width = value
		queue_redraw()

@export var circle_points := 32:
	set(value):
		circle_points = value
		queue_redraw()

func _draw() -> void:
	draw_arc(
		size / 2.0,
		circle_radius,
		0.0,
		TAU,
		circle_points,
		circle_color,
		circle_outline_width
	)
