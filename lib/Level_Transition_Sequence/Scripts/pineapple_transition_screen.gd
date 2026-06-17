extends Control

@onready var control: Control = $Circles/Control
#@onready var pineapple_texture: TextureRect = $Circles/Control/Circle_polygon/Pineapple_texture
@onready var circle_polygon: Polygon2D = $Pineapple_control/Circle_polygon
@onready var pineapple_texture: TextureRect = $Pineapple_control/pineapple_texture
@onready var pineapple_container: Control = $Pineapple_container
@onready var pineapple_unit: Control = $Pineapple_control
@onready var smoke_sprite: AnimatedSprite2D = $Pineapple_control/Smoke_sprite
@onready var pineapples_collected: Control = $Pineapples_collected
@onready var prize_allocation: Node = $Prize_allocation

@export var do_not_move_on := false

var amount_of_pineapples_collected := 0

#func allocate_pineapples_for_next_round() -> void:
	#var total_pineapples_up_for_grabs = prize_allocation.next_rounds_prize_allocation()
	#total_pineapples_up_for_grabs = clamp(total_pineapples_up_for_grabs, 0, ScoreGl.MAX_PINEAPPLES_PER_ROUND)
	#GameManager.pineapples_available_within_level = total_pineapples_up_for_grabs
	
func _ready() -> void:
	
	amount_of_pineapples_collected = GameManager.total_number_of_pineapples_collected
	
	#GlobalMusic.incidental_music.play_incidental_music()

	circle_polygon.scale = Vector2.ZERO
	#pineapple_texture.scale = Vector2.ZERO
	smoke_sprite.hide()
	circle_polygon.modulate = Color.TRANSPARENT
	await get_tree().create_timer(3.1).timeout

	#start_sequence()
	#heart_beat_cherry()
	$Fuji_control.fade_out()
	$Pineapples_collected.fade_out()
	await get_tree().create_timer(2.0).timeout
	if do_not_move_on:
		return
	#$Fuji_control.fade_out()
	#GlobalMusic.incidental_music.stop_incidental_music()
	prepare_for_transition()
	#end_sequence()
	
	
func start_sequence() -> void:
	#smoke_sequence()
	$SFX/Panel_fade_in2.play()
	var dur : float = 0.6
	
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_interval(0.1)
	tween.tween_property(circle_polygon, "scale", Vector2.ONE, dur)
	tween.parallel().tween_property(pineapple_texture, "scale", Vector2.ONE, dur)
	tween.parallel().tween_property(circle_polygon, "modulate", Color.WHITE, dur * 8)

	await tween.finished
	
func heart_beat_cherry() -> void:
	$SFX/Cherry_heart.play()
	$SFX/Cherry_heart2.play()
	
	# Pulse the cherry scale with a bounce + slight squash
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(1.0)
	tween.tween_property(pineapple_texture, "scale", Vector2(1.1, 0.95), 0.15)
	tween.tween_property(pineapple_texture, "scale", Vector2.ONE, 0.15)
	tween.tween_interval(1.0)
	tween.tween_property(pineapple_texture, "scale", Vector2(1.1, 0.95), 0.15)
	tween.tween_property(pineapple_texture, "scale", Vector2.ONE, 0.15)
	tween.tween_property(pineapple_texture, "scale", Vector2(1.1, 0.95), 0.15)
	tween.tween_property(pineapple_texture, "scale", Vector2.ONE, 0.15)
	#tween.tween_interval(0.2)
	await tween.finished
	start_fading_circle()
	
	
func start_fading_circle() -> void:
	var dur : float = 1.5
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(pineapple_texture, "modulate", Color('b8000000'), 0.5).set_trans(Tween.TRANS_LINEAR)
	await tween.finished
	circle_polygon.hide()
	
	
func end_sequence() -> void:
	var dur : float = 1.5
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property(circle_polygon, "scale", Vector2.ZERO, dur)
	tween.parallel().tween_property(pineapple_texture, "scale", Vector2.ZERO, dur)
	tween.parallel().tween_property(circle_polygon, "modulate", Color.TRANSPARENT, 0.75).set_trans(Tween.TRANS_LINEAR)
	
	tween.parallel().tween_callback(smoke_sequence).set_delay(0.5)
	await tween.finished
	prepare_for_transition()
	
func prepare_for_transition() -> void:
	BackgroundForTransition.fade_in()
	await get_tree().create_timer(0.15).timeout
	var next_scene = GameManager.next_level_directory()
	get_tree().change_scene_to_file(next_scene)

func smoke_sequence() -> void:
	smoke_sprite.show()
	
	smoke_sprite.play("default")
	$SFX/Smoke_sound.play()
	var tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	tween.tween_property(smoke_sprite, "modulate", Color.TRANSPARENT, 1.0).set_trans(Tween.TRANS_LINEAR)
	await tween.finished
	smoke_sprite.modulate = Color.WHITE
	smoke_sprite.hide()
