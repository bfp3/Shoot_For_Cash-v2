class_name Points_receptor_UI
extends Control

@onready var ring_polygon: Polygon2D = $Ring_polygon

@onready var circle_polygon: Polygon2D = $Circle_polygon
@onready var total:          Label      = $Total       # shows current number of points

@export var circle_radius := 56.0
@export var number_of_points := 3               # this can become a float while animating!

var default_radius     : float
var default_num_points : int


func _ready() -> void:
	default_radius     = circle_radius
	default_num_points = number_of_points
	_display_points()


# ────────────────────────────────────────────────────────────────
# PUBLIC API
# ────────────────────────────────────────────────────────────────
func update_points_receptor() -> void:
	circle_radius    += 10.0
	number_of_points += 1
	_display_points()


func return_to_default() -> void:
	print("STILL BEING CALLED")
	return
	#var radius_speed := 25.0      # px per second
	#var points_speed := 1.0        # segments per second (≈ units / sec)
#
	#while abs(circle_radius - default_radius) > 0.5 \
	   #or abs(number_of_points - default_num_points) > 0.1:
#
		#var delta := get_process_delta_time()
#
		## — radius —
		#circle_radius = move_toward(circle_radius, default_radius,
									#radius_speed * delta)
#
		## — points —
		#number_of_points = move_toward(number_of_points, default_num_points,
									   #points_speed * delta)
#
		#_display_points()
		#await get_tree().process_frame   # wait 1 frame
#
	## make sure we end exactly on the defaults
	#circle_radius     = default_radius
	#number_of_points  = default_num_points
	#_display_points()


# ────────────────────────────────────────────────────────────────
# INTERNAL HELPERS
# ────────────────────────────────────────────────────────────────
func _display_points() -> void:
	circle_polygon.radius   = circle_radius
	circle_polygon.segments = int(round(number_of_points))
	
	ring_polygon.radius = circle_radius
	ring_polygon.segments = int(round(number_of_points))
	
	total.text = str(int(round(number_of_points - default_num_points)))   # update label
