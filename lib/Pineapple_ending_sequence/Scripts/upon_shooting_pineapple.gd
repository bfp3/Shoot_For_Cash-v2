extends Control

@onready var pineapple_1: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/Pineapple/PanelContainer/MarginContainer/TextureRect
@onready var pineapple_2: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/Pineapple2/PanelContainer/MarginContainer/TextureRect
@onready var pineapple_3: TextureRect = $PanelContainer/MarginContainer/HBoxContainer/Pineapple3/PanelContainer/MarginContainer/TextureRect

var wrap_up_started := false

func _ready() -> void:
	hide()
	EventBus.instance.wrapping_up_a_level.connect(_fade_out)


func _fade_out() -> void:
	var tween = create_tween()
	#tween.tween_interval(0.5)
	tween.tween_property(self, "modulate", Color.TRANSPARENT, 1.0)
	await tween.finished
	#pineapple_1.hide()
	#pineapple_2.hide()
	#pineapple_3.hide()
	#
func show_next_pineapple(count: int) -> void:
	pass
	#$SFX/Telegraph_sound.play()
#
	#var pineapple: TextureRect
	#var smoke_sprite: AnimatedSprite2D
#
	#match count:
		#1:
			#pineapple = pineapple_3
			#smoke_sprite = $Smoke_sprite3
		#2:
			#pineapple = pineapple_2
			#smoke_sprite = $Smoke_sprite2
		#3:
			#pineapple = pineapple_1
			#smoke_sprite = $Smoke_sprite
#
	#if !pineapple or !smoke_sprite:
		#return
#
	#smoke_sprite.show()
	#smoke_sprite.play("default")
#
	#var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	#tween.tween_property(pineapple, "visible", true, 0.01)
	#pineapple.scale = Vector2.ZERO
	#tween.parallel().tween_property(pineapple, "scale", Vector2.ONE * 1.25, 0.5)
	#tween.tween_property(pineapple, "scale", Vector2.ONE, 0.25)
	#tween.parallel().tween_property(smoke_sprite, "modulate", Color.TRANSPARENT, 1.0)
#
	#await tween.finished
	#smoke_sprite.hide()
	#smoke_sprite.modulate = Color.WHITE  # Reset smoke opacity for reuse
		#
#func wrap_up_sequence() -> void:
	#if wrap_up_started:
		#return
	#wrap_up_started = true
	#var pineapples = [pineapple_1, pineapple_2, pineapple_3]
	#var smoke_sprites = [$Smoke_sprite, $Smoke_sprite2, $Smoke_sprite3]
#
	#for i in range(3):
		#var pineapple = pineapples[i]
		#var smoke_sprite = smoke_sprites[i]
#
		#if !pineapple.visible:
			#continue  # Skip hidden pineapples
#
		## Prepare smoke
		#smoke_sprite.modulate = Color(1, 1, 1, 0)
		#smoke_sprite.show()
#
		#var tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
#
		#tween.tween_property(pineapple, "scale", Vector2.ONE * 1.05, 0.15)
		#tween.tween_property(pineapple, "scale", Vector2.ZERO, 0.25)
		#tween.parallel().tween_callback(smoke_sprite.play.bind("default"))
		#tween.parallel().tween_callback($SFX/Telegraph_sound.play)
		#tween.parallel().tween_property(smoke_sprite, "modulate", Color.WHITE, 0.15)
		#tween.tween_property(smoke_sprite, "modulate", Color.TRANSPARENT, 0.15)
#
		#await tween.finished
#
		#pineapple.hide()
		#smoke_sprite.hide()
