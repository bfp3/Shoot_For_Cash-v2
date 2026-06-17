extends Control

@onready var ring_duplicate: Control = $Ring_duplicate

@onready var pineapples := [
	$PanelContainer/MarginContainer/HBoxContainer/Pineapple/PanelContainer/MarginContainer/TextureRect,
	$PanelContainer/MarginContainer/HBoxContainer/Pineapple2/PanelContainer/MarginContainer/TextureRect,
	$PanelContainer/MarginContainer/HBoxContainer/Pineapple3/PanelContainer/MarginContainer/TextureRect
]

@onready var pineapple_panels := [
	$PanelContainer/MarginContainer/HBoxContainer/Pineapple/PanelContainer,
	$PanelContainer/MarginContainer/HBoxContainer/Pineapple2/PanelContainer,
	$PanelContainer/MarginContainer/HBoxContainer/Pineapple3/PanelContainer
]

@onready var smoke_sprites := [$Smoke_sprite, $Smoke_sprite2, $Smoke_sprite3]

@onready var color_rect: ColorRect = $ColorRect
@onready var text_box: Control = $Text_box

@export var colour_bronze = Color('854505e6')
@export var colour_silver = Color('bdbdbd99') 
@export var colour_gold = Color('f5d50a') 
@export var time_until_pineapples_disappear := 1.5

signal finished_display

var amount_of_pineapples := 0

func _ready() -> void:
	amount_of_pineapples = GameManager.pineapples_available_within_level
	EventBus.instance.wrapping_up_a_level.connect(_fade_out)
	for i in range(3):
		smoke_sprites[i].hide()
		pineapples[i].modulate = Color('FFFFFF00')
		pineapple_panels[i].modulate = Color('FFFFFF00')


		


func _fade_out() -> void:
	var tween = create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 0.5)
	await tween.finished

func first_phase() -> void:
	amount_of_pineapples = GameManager.pineapples_available_within_level

	for i in range(3):
		smoke_sprites[i].hide()
		pineapples[i].modulate = Color('FFFFFF00')
		pineapple_panels[i].modulate = Color('FFFFFF00')

	$PanelContainer.modulate = Color('FFFFFF00')
	
	$Dots_phase.start_dots_phase()
	second_phase()

func second_phase() -> void:
	var tween = create_tween().set_ease(Tween.EASE_IN)
	tween.tween_property($PanelContainer, "modulate", Color('FFFFFF'), 1.0)
	tween.parallel().tween_property($SFX/Panel_fade_in, "playing", true, 0.01)
	third_phase()

func third_phase() -> void:
	for i in range(amount_of_pineapples):
		shake_pineapple(pineapples[i])

	make_dots_pulse()

func make_dots_pulse() -> void:
	var dur := 1.0
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_loops()
	for dot in [$Dots_phase/Dot, $Dots_phase/Dot2, $Dots_phase/Dot3]:
		tween.parallel().tween_property(dot, "scale", Vector2.ONE * 1.1, dur)
	tween.tween_property($Dots_phase/Dot, "scale", Vector2.ONE, dur)
	tween.parallel().tween_property($Dots_phase/Dot2, "scale", Vector2.ONE, dur)
	tween.parallel().tween_property($Dots_phase/Dot3, "scale", Vector2.ONE, dur)
	await tween.finished

func shake_pineapple(target_pineapple: TextureRect) -> void:
	var scale_control := target_pineapple.get_parent().get_parent()
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)

	tween.tween_property($SFX/Pine_shake_1, "playing", true, 0.01).set_delay(0.25)
	tween.tween_callback(change_modulate.bind(target_pineapple))

	tween.tween_property(scale_control, "rotation", -0.1, 0.1)
	tween.tween_property(scale_control, "rotation", 0.1, 0.1)
	tween.tween_property(scale_control, "rotation", -0.1, 0.12)
	tween.tween_property(scale_control, "rotation", 0.1, 0.15)
	tween.tween_property(scale_control, "rotation", -0.1, 0.12)
	tween.tween_property(scale_control, "rotation", 0.0, 0.15)

	await tween.finished

func change_modulate(target_pineapple: TextureRect) -> void:
	var dur := 0.25
	var scale_control := target_pineapple.get_parent().get_parent()
	scale_control.scale = Vector2.ZERO

	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property(target_pineapple, "modulate", Color('FFFFFF'), dur)
	tween.parallel().tween_property(scale_control, "modulate", Color('FFFFFF'), dur)
	tween.parallel().tween_property(scale_control, "scale", Vector2.ONE, 0.5)
	tween.tween_interval(dur)
	await tween.finished

func hide_pineapples() -> void:
	# Placeholder in case needed later
	pass

func smoke_particles() -> void:
	for i in range(amount_of_pineapples):
		smoke_sprites[i].show()
		smoke_sprites[i].play("default")

	await smoke_sprites[amount_of_pineapples - 1].animation_finished

	for i in range(amount_of_pineapples):
		var tween = create_tween()
		tween.tween_property(smoke_sprites[i], "modulate", Color('FFFFFF00'), 0.25).set_ease(Tween.EASE_OUT)

func emit_finished() -> void:
	finished_display.emit()

func show_next_pineapple(count: int) -> void:
	if count < 1 or count > 3:
		return

	$SFX/Telegraph_sound.play()

	var index := 3 - count  # Reverse order: 1 → 2, 2 → 1, 3 → 0
	var pineapple = pineapples[index]
	var smoke_sprite = smoke_sprites[index]
	var scale_control = pineapple.get_parent().get_parent()

	var original_position = scale_control.position

	smoke_sprite.show()
	smoke_sprite.play("default")

	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(scale_control, "scale", Vector2.ZERO, 0.25)
	tween.parallel().tween_property(pineapple, "position", scale_control.position, 0.25)
	tween.parallel().tween_property(smoke_sprite, "modulate", Color.TRANSPARENT, 1.0)
	tween.tween_callback(func(): pineapple.visible = false)

	await tween.finished

	smoke_sprite.hide()
	smoke_sprite.modulate = Color.WHITE
	scale_control.position = original_position
	scale_control.scale = Vector2.ONE
	scale_control.set_pivot_offset(Vector2.ZERO)
