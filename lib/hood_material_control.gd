@tool
extends Node3D
class_name HoodsMaterialControl

@onready var alt_skin_1: Node3D = $Alt_Skin_1

# =========================
# BACKING VARIABLES
# =========================

var _different_colour := false
var _random_colour := false


# =========================
# EXPORTED SETTINGS
# =========================

@export var different_colour := false:
	get:
		return _different_colour
	set(value):
		_different_colour = value
		_refresh_colours()

@export var random_colour := false:
	get:
		return _random_colour
	set(value):
		_random_colour = value
		_refresh_colours()


# =========================
# DEFAULT COLOURS
# =========================

var orig_canopy_colour_head := Color("b06100")
var orig_canopy_colour_forehead := Color("383838")
var orig_scarf_colour := Color("1a1a1a")

var orig_rim_colour := Color("845e00")
var orig_rim_colour2 := Color("c1aa00")
var orig_rim_colour3 := Color("936700")
var orig_eye_colour := Color("ff2640")

# =========================
# EXPORTED COLOURS (LIVE)
# =========================

var _canopy_colour_head := Color("b06100")
var _canopy_colour_forehead := Color("383838")
var _scarf_colour := Color("1a1a1a")
var _rim_colour := Color("845e00")
var _rim_colour2 := Color("c1aa00")
var _rim_colour3 := Color("936700")
var _eye_colour := Color("ff2640")



@export var canopy_colour_head : Color:
	get: return _canopy_colour_head
	set(value):
		_canopy_colour_head = value
		_refresh_colours()

@export var canopy_colour_forehead : Color:
	get: return _canopy_colour_forehead
	set(value):
		_canopy_colour_forehead = value
		_refresh_colours()

@export var scarf_colour : Color:
	get: return _scarf_colour
	set(value):
		_scarf_colour = value
		_refresh_colours()

@export var rim_colour : Color:
	get: return _rim_colour
	set(value):
		_rim_colour = value
		_refresh_colours()

@export var rim_colour2 : Color:
	get: return _rim_colour2
	set(value):
		_rim_colour2 = value
		_refresh_colours()

@export var rim_colour3 : Color:
	get: return _rim_colour3
	set(value):
		_rim_colour3 = value
		_refresh_colours()

@export var eye_colour_torch : Color:
	get: return _eye_colour
	set(value):
		_eye_colour = value
		_refresh_colours()

# =========================
# MATERIALS
# =========================

var CANOPY_COLOUR_HEAD_MATERIAL = preload("uid://b0pb0iqautw7t")
var CANOPY_FOREHEAD_MATERIAL = preload("uid://wheaqvtk481p")
var SCARF_MATERIAL = preload("uid://4su0e7ekl1tt")
var RIM_BODY_MATERIAL = preload("uid://du6stho3eesie")
var RIM_BODY_2_MATERIAL = preload("uid://csum6kiahh4u8")
var RIM_BODY_3_MATERIAL = preload("uid://ig6l6depd7ao")
var HOOD_TORCH_EYE_OUTER_RIM_MAT = preload("uid://di2evm0u83yhd")



# =========================
# LIFECYCLE
# =========================

#func _enter_tree():
	#if Engine.is_editor_hint():
		#make_unique()


func _ready():
	if Engine.is_editor_hint():
		_refresh_colours()
	else:
		start()


# =========================
# LIVE REFRESH
# =========================

func _refresh_colours() -> void:
	if not Engine.is_editor_hint():
		return

	_update_default_colours_from_visible_skin()

	if _different_colour:
		if _random_colour:
			set_to_random_colours()
		else:
			set_to_exported_colours()
	else:
		reset_colours_to_defaults()



# =========================
# RUNTIME
# =========================

func start() -> void:
	_update_default_colours_from_visible_skin()

	reset_colours_to_defaults()

	if _different_colour:
		set_to_exported_colours()

	if _random_colour:
		set_to_random_colours()



# =========================
# COLOUR MODES
# =========================

func reset_colours_to_defaults():
	_set_material_colour(CANOPY_COLOUR_HEAD_MATERIAL, orig_canopy_colour_head)
	_set_material_colour(CANOPY_FOREHEAD_MATERIAL, orig_canopy_colour_forehead)
	_set_material_colour(SCARF_MATERIAL, orig_scarf_colour)
	_set_material_colour(RIM_BODY_MATERIAL, orig_rim_colour)
	_set_material_colour(RIM_BODY_2_MATERIAL, orig_rim_colour2)
	_set_material_colour(RIM_BODY_3_MATERIAL, orig_rim_colour3)
	_set_material_colour(HOOD_TORCH_EYE_OUTER_RIM_MAT, orig_eye_colour)

func set_to_exported_colours():
	_set_material_colour(CANOPY_COLOUR_HEAD_MATERIAL, _canopy_colour_head)
	_set_material_colour(CANOPY_FOREHEAD_MATERIAL, _canopy_colour_forehead)
	_set_material_colour(SCARF_MATERIAL, _scarf_colour)
	_set_material_colour(RIM_BODY_MATERIAL, _rim_colour)
	_set_material_colour(RIM_BODY_2_MATERIAL, _rim_colour2)
	_set_material_colour(RIM_BODY_3_MATERIAL, _rim_colour3)	
	_set_material_colour(HOOD_TORCH_EYE_OUTER_RIM_MAT, eye_colour_torch)



func set_to_random_colours():
	_set_material_colour(CANOPY_COLOUR_HEAD_MATERIAL, _random_colour_func())
	_set_material_colour(CANOPY_FOREHEAD_MATERIAL, _random_colour_func())
	_set_material_colour(SCARF_MATERIAL, _random_colour_func())
	_set_material_colour(RIM_BODY_MATERIAL, _random_colour_func())
	_set_material_colour(RIM_BODY_2_MATERIAL, _random_colour_func())
	_set_material_colour(RIM_BODY_3_MATERIAL, _random_colour_func())
	_set_material_colour(HOOD_TORCH_EYE_OUTER_RIM_MAT, _random_colour_func())

# =========================
# HELPERS
# =========================

func _random_colour_func() -> Color:
	return Color.from_hsv(randf(), 0.8, 0.9)


func _set_material_colour(material: StandardMaterial3D, colour: Color):
	if material:
		material.albedo_color = colour


func make_unique():
	CANOPY_COLOUR_HEAD_MATERIAL = CANOPY_COLOUR_HEAD_MATERIAL.duplicate()
	CANOPY_FOREHEAD_MATERIAL = CANOPY_FOREHEAD_MATERIAL.duplicate()
	SCARF_MATERIAL = SCARF_MATERIAL.duplicate()
	RIM_BODY_MATERIAL = RIM_BODY_MATERIAL.duplicate()
	RIM_BODY_2_MATERIAL = RIM_BODY_2_MATERIAL.duplicate()
	RIM_BODY_3_MATERIAL = RIM_BODY_3_MATERIAL.duplicate()
	HOOD_TORCH_EYE_OUTER_RIM_MAT = HOOD_TORCH_EYE_OUTER_RIM_MAT.duplicate()

func _update_default_colours_from_visible_skin() -> void:

	# Reset to THIS skin defaults first
	orig_canopy_colour_head = Color("b06100")
	orig_canopy_colour_forehead = Color("383838")
	orig_scarf_colour = Color("1a1a1a")
	orig_rim_colour = Color("845e00")
	orig_rim_colour2 = Color("c1aa00")
	orig_rim_colour3 = Color("936700")
	orig_eye_colour = Color("ff2640")

	# If alt skin is visible — override defaults
	if alt_skin_1 and alt_skin_1.visible:
		#if alt_skin_1.has_variable("orig_canopy_colour_head"):
		orig_canopy_colour_head = alt_skin_1.orig_canopy_colour_head
		orig_canopy_colour_forehead = alt_skin_1.orig_canopy_colour_forehead
		orig_scarf_colour = alt_skin_1.orig_scarf_colour

		orig_rim_colour = alt_skin_1.orig_rim_colour
		orig_rim_colour2 = alt_skin_1.orig_rim_colour2
		orig_rim_colour3 = alt_skin_1.orig_rim_colour3
		orig_eye_colour = alt_skin_1.orig_eye_colour
