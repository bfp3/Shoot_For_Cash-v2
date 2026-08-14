extends Control

#@onready var pineapple_unit: Control = $PineappleTemplate  # Template Control node
#
#@export var rot_speed := 0.1
#@export var dist_radius := 375.0
#@export var scale_factor := 0.4
#@export var collected_color: Color = Color("ffffff")
#@export var uncollected_color: Color = Color("ffffff30")
#@onready var new_container: Control = $New_container
#
#@onready var smoke_sfx := $Smoke_sound
#@onready var not_collected: AudioStreamPlayer = $Not_collected
#
#var collected_pineapple_ring_colour := Color('ffb900')
#var uncollected_pineapple_ring_colour := Color('737373')
#
#const PINEAPPLE_EMOJI = preload('res://700_2D_nodes_UI/Decal_placeholders/pineapple_emoji.png')
#const PINEAPPLE_OUTLINE = preload('res://700_2D_nodes_UI/Decal_placeholders/pineapple_emoji.png')
#
#@onready var pineapple_texture: TextureRect = $PineappleTemplate/pineapple_texture
#@onready var circle_polygon: Polygon2D = $PineappleTemplate/pineapple_texture/Circle_polygon
#
#var delay_time := 0.25
#var amount_of_pineapples_collected := 0  # Can be dynamically assigned from GameManager
#
#var time := 0.01
#
#func _ready() -> void:
	#amount_of_pineapples_collected = GameManager.total_number_of_pineapples_collected
	#create_pineapple_circle()
	#
	#if amount_of_pineapples_collected >= 10:
		#reveal_fuji()
		#
#func reveal_fuji() -> void:
	#var tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	#tween.tween_interval(2.5)
	#tween.tween_property($"../Fuji_control/Circle_polygon3/TextureRect", "self_modulate", Color('FFFFFF'), 0.75).set_ease(Tween.EASE_IN)
#
#
#func fade_out() -> void:
	#
	#
	#var tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_LINEAR)
	#tween.tween_interval(1.0)
	#tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.5)
#
#func create_pineapple_circle() -> void:
	#var total : int = 10 #ScoreGl.PINEAPPLES_AMOUNT_TO_COMPLETE
	#var radius := dist_radius
#
	#for i in range(total):
		#var angle = TAU * float(i) / float(total)
		#var pos = Vector2(cos(angle), sin(angle)) * -radius
#
		#var pineapple = pineapple_unit.duplicate() as Control
		#pineapple.show()
		#new_container.add_child(pineapple)
		#pineapple.position = pos
		#var target_scale = Vector2.ONE * scale_factor
		#pineapple.scale = Vector2.ZERO
		#
		#var tween = create_tween()
		#tween.tween_property(pineapple, "scale", target_scale, 0.5)
		#
		#var is_collected := i < amount_of_pineapples_collected
		#pineapple.get_child(0).collected = is_collected
		#pineapple.modulate = collected_color if is_collected else uncollected_color
#
		## Get references to texture and polygon
		#var texture_rect := pineapple.get_node("pineapple_texture") as TextureRect
		#var polygon := texture_rect.get_node("Circle_polygon") as Polygon2D
#
		#if is_collected:
			#texture_rect.texture = PINEAPPLE_EMOJI
			#polygon.modulate = collected_pineapple_ring_colour
			#smoke_sfx.play()
		#else:
			#polygon.modulate = uncollected_pineapple_ring_colour
			#not_collected.play()
#
		#await get_tree().create_timer(delay_time).timeout
		#delay_time = max(0.05, delay_time - 0.025)
#
#func _process(_delta: float) -> void:
	#
	#rotation += _delta * rot_speed
	#if time >= 0.5:
		#time = 0
		#_adjust_params()
#
#func _adjust_params() -> void:
	#
	#var total := new_container.get_child_count() - 1  # Exclude template
	#var index := 0
#
	#for child in new_container.get_children():
		##if child != Control:
			##return
		#if child == pineapple_unit:
			#continue
		#var angle := TAU * float(index) / float(total)
		#var pos := Vector2(cos(angle), sin(angle)) * -dist_radius
		#child.position = pos
		#child.scale = Vector2.ONE * scale_factor
#
		#var is_collected := index < amount_of_pineapples_collected
		#child.modulate = collected_color if is_collected else uncollected_color
#
		#index += 1
