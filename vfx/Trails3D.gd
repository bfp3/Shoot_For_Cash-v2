#@tool
extends MeshInstance3D
#class_name Trail3D
var _active_points := []
var _active_widths := []
var _active_lifePoints := []

var _old_trails := [] # Stores finished trails to fade out naturally

@export var _trailEnabled : bool = true:
	set(value):
		if _trailEnabled != value:
			_trailEnabled = value
			if value:
				_start_new_trail()
			else:
				_finalize_current_trail()

@export var _fromWidth : float = 0.5
@export var _toWidth : float = 0.0
@export_range(0.5,1.5) var _scaleAcceleration : float = 1.0
@export var _motionDelta : float = 0.1
@export var _lifespan : float = 1.0
@export var _startColor : Color = Color(1.0,1.0,1.0,1.0)
@export var _endColor : Color = Color(1.0,1.0,1.0,1.0)

var _oldPos : Vector3


func _ready() -> void:
	_oldPos = get_global_transform().origin
	mesh = ImmediateMesh.new()


func _start_new_trail() -> void:
	_active_points.clear()
	_active_widths.clear()
	_active_lifePoints.clear()
	_oldPos = get_global_transform().origin


func _finalize_current_trail() -> void:
	if _active_points.size() > 1:
		_old_trails.append({
			"points": _active_points.duplicate(),
			"widths": _active_widths.duplicate(),
			"lifes": _active_lifePoints.duplicate()
		})
	_active_points.clear()
	_active_widths.clear()
	_active_lifePoints.clear()


func appendPoint() -> void:
	_active_points.append(get_global_transform().origin)
	_active_widths.append([
		get_global_transform().basis.x * _fromWidth,
		get_global_transform().basis.x * _fromWidth,
		- get_global_transform().basis.x * _toWidth,
	])
	_active_lifePoints.append(0.0)


func removePoint(arr_points, arr_widths, arr_lifes, i: int) -> void:
	arr_points.remove_at(i)
	arr_widths.remove_at(i)
	arr_lifes.remove_at(i)


func _process(delta: float) -> void:
	# Add new points if trail is active
	if _trailEnabled and (_oldPos - get_global_transform().origin).length() > _motionDelta:
		appendPoint()
		_oldPos = get_global_transform().origin

	# Update all trails
	_update_trail_data(_active_points, _active_widths, _active_lifePoints, delta)

	for old_trail in _old_trails:
		_update_trail_data(old_trail["points"], old_trail["widths"], old_trail["lifes"], delta)

	# Remove finished old trails
	_old_trails = _old_trails.filter(func(t): return t["points"].size() > 1)

	# Draw all trails
	mesh.clear_surfaces()
	_draw_trail(_active_points, _active_widths, _active_lifePoints)
	for old_trail in _old_trails:
		_draw_trail(old_trail["points"], old_trail["widths"], old_trail["lifes"])


func _update_trail_data(points, widths, lifes, delta: float) -> void:
	var p := 0
	var max_points = points.size()
	while p < max_points:
		lifes[p] += delta
		if lifes[p] > _lifespan:
			removePoint(points, widths, lifes, p)
			p -= 1
			if p < 0:
				p = 0
		max_points = points.size()
		p += 1


func _draw_trail(points, widths, lifes) -> void:
	if points.size() < 2:
		return

	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in range(points.size()):
		var t = float(i) / (points.size() - 1.0)
		var fade = 1.0 - (lifes[i] / _lifespan)
		var currColor := _startColor.lerp(_endColor, 1 - t)
		currColor.a *= fade  # fade out naturally

		mesh.surface_set_color(currColor)
		var currWidth = widths[i][0] - pow(1 - t, _scaleAcceleration) * widths[i][1]
		mesh.surface_set_uv(Vector2(i / float(points.size()), 0))
		mesh.surface_add_vertex(to_local(points[i] + currWidth))
		mesh.surface_set_uv(Vector2(i / float(points.size()), 1))
		mesh.surface_add_vertex(to_local(points[i] - currWidth))
	mesh.surface_end()
