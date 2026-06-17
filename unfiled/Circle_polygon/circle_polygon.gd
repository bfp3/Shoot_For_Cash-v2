@tool
extends Polygon2D

@export var radius := 62
@export var thickness := 10
@export var segments := 40

@export var ring_shape := true

func _ready() -> void:
	if !ring_shape:
		_draw_circle(segments, radius)
	else:
		draw_ring(segments, radius, thickness)


func _draw_circle(_num_points: int, _radius: float) -> void:
	var outer_points = PackedVector2Array()
	
	for i in range(_num_points + 1):
		var angle = deg_to_rad(i * 360.0 / _num_points - 90)
		var dir = Vector2(cos(angle), sin(angle))
		outer_points.push_back(dir * _radius)

	var ring_points = PackedVector2Array()
	ring_points.append_array(outer_points)

	self.polygon = ring_points

func draw_ring(num_points: int, outer_radius: float, ring_thickness: float) -> void:
	var inner_radius = outer_radius - ring_thickness
	var outer_points = PackedVector2Array()
	var inner_points = PackedVector2Array()
	
	for i in range(num_points + 1):
		var angle = deg_to_rad(i * 360.0 / num_points - 90)
		var dir = Vector2(cos(angle), sin(angle))
		outer_points.push_back(dir * outer_radius)
		inner_points.push_back(dir * inner_radius)

	inner_points.reverse()  # To preserve correct triangle winding

	var ring_points = PackedVector2Array()
	ring_points.append_array(outer_points)
	ring_points.append_array(inner_points)

	self.polygon = ring_points

func _process(_delta: float) -> void:
	
	if !ring_shape:
		_draw_circle(segments, radius)
	else:
		draw_ring(segments, radius, thickness)
