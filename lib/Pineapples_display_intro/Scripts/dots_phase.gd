extends Control

const SFX_DOT_1 = preload("res://sfx/sfx_dot_1.wav")
const SFX_DOT_2 = preload("res://sfx/sfx_dot_2.wav")
const SFX_DOT_3 = preload("res://sfx/sfx_dot_3.wav")

@onready var sfx: Node = $"../SFX"

@onready var dot: Control = $Dot
@onready var dot_2: Control = $Dot2
@onready var dot_3: Control = $Dot3

@export var colour_bronze = Color('854505e6')
@export var colour_silver = Color('bdbdbd99') 
@export var colour_gold = Color('f5d50a') 

func colour_outline() -> void:
	var colour = Color('f5e10a82')
	
	$Dot/Outline.modulate = colour_gold
	$Dot2/Outline.modulate = colour_gold
	$Dot3/Outline.modulate = colour_gold

func _ready() -> void:
	
	colour_outline()
	
	modulate = Color('FFFFFF00')
	dot.modulate = Color('FFFFFF00')
	dot_2.modulate = Color('FFFFFF00')
	dot_3.modulate = Color('FFFFFF00')
	
	dot.scale = Vector2.ZERO
	dot_2.scale = Vector2.ZERO
	dot_3.scale = Vector2.ZERO

func start_dots_phase() -> void:
	modulate = Color('FFFFFF')
	#await get_tree().create_timer(0.3).timeout
	fade_in_tween(dot)
	sfx.play_sound(SFX_DOT_1)
	#await get_tree().create_timer(0.1).timeout
	fade_in_tween(dot_2)
	#sfx.play_sound(SFX_DOT_2)
	#await get_tree().create_timer(0.1).timeout
	fade_in_tween(dot_3)
	#sfx.play_sound(SFX_DOT_3)
	
func fade_in_tween(current_dot : Control) -> void:
	var dur : float = 1.0
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC) #.set_trans(Tween.TRANS_BOUNCE)
	tween.tween_property(current_dot, "modulate", Color('FFFFFF'), 0.5)
	tween.parallel().tween_property(current_dot, "scale", Vector2.ONE * 1.1, dur)
	tween.tween_property(current_dot, "scale", Vector2.ONE, dur)

	tween.tween_property(current_dot, "scale", Vector2.ONE * 1.1, dur)
	#tween.tween_property(current_dot, "scale", Vector2.ONE, dur)
	#tween.tween_interval(0.5)
	await tween.finished

func fade_dots_phase() -> void:
	modulate = Color('FFFFFF')
	fade_out_tween(dot_3)
	sfx.play_sound(SFX_DOT_3)
	#await get_tree().create_timer(0.1).timeout
	fade_out_tween(dot_2)
	sfx.play_sound(SFX_DOT_2)
	#await get_tree().create_timer(0.1).timeout
	fade_out_tween(dot)
	sfx.play_sound(SFX_DOT_1)

func fade_out_tween(current_dot : Control) -> void:
	var dur : float = 0.5 #0.25
	var tween = create_tween().set_ease(Tween.EASE_IN)
	#tween.tween_property(current_dot, "scale", Vector2.ONE, 0.15)
	tween.tween_property(current_dot, "modulate", Color('FFFFFF00'), dur)
	tween.parallel().tween_property(self, "modulate", Color('FFFFFF00'), dur)
	tween.parallel().tween_property(current_dot, "scale", Vector2.ZERO, dur)
	await tween.finished
