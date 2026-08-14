extends Control

#@onready var color_rect: ColorRect = $ColorRect
#@onready var cherry_control: Control = $Cherry_control
#@onready var circle_polygon: Polygon2D = $Cherry_control/Circle_polygon
#@onready var animation_player: AnimationPlayer = $Cherry_control/Circle_polygon/AnimationPlayer
#@onready var smoke_sprite: AnimatedSprite2D = $Cherry_control/Smoke_sprite
#@onready var cherry_text: TextureRect = $Cherry_control/Cherry_texture
#@onready var incidental_music: AudioStreamPlayer 
#
#func _ready() -> void:
	##incidental_music = GlobalMusic.incidental_music
	##incidental_music.play_incidental_music()
#
	#circle_polygon.scale = Vector2.ZERO
	#cherry_text.scale = Vector2.ZERO
	#smoke_sprite.hide()
	#circle_polygon.modulate = Color.TRANSPARENT
	#await get_tree().create_timer(1.1).timeout
	#start_sequence()
	#heart_beat_cherry()
	#await get_tree().create_timer(3.0).timeout
	#
	##incidental_music.stop_incidental_music()
	#$Fuji_control.fade_out()
	#end_sequence()
#
#func start_sequence() -> void:
	##smoke_sequence()
	#$SFX/Panel_fade_in2.play()
	#var dur : float = 0.6
	#
	#var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	#tween.tween_interval(0.1)
	#tween.tween_property(circle_polygon, "scale", Vector2.ONE, dur)
	#tween.parallel().tween_property(cherry_text, "scale", Vector2.ONE, dur)
	#tween.parallel().tween_property(circle_polygon, "modulate", Color.WHITE, dur * 8)
#
	#await tween.finished
	#
	#
#func heart_beat_cherry() -> void:
	#$SFX/Cherry_heart.play()
	#$SFX/Cherry_heart2.play()
	#
	## Pulse the cherry scale with a bounce + slight squash
	#var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	#tween.tween_interval(1.0)
	#tween.tween_property(cherry_text, "scale", Vector2(1.1, 0.95), 0.15)
	#tween.tween_property(cherry_text, "scale", Vector2.ONE, 0.15)
	#tween.tween_interval(1.0)
	#tween.tween_property(cherry_text, "scale", Vector2(1.1, 0.95), 0.15)
	#tween.tween_property(cherry_text, "scale", Vector2.ONE, 0.15)
	#tween.tween_property(cherry_text, "scale", Vector2(1.1, 0.95), 0.15)
	#tween.tween_property(cherry_text, "scale", Vector2.ONE, 0.15)
	##tween.tween_interval(0.2)
	#await tween.finished
	#start_fading_circle()
	#
	#
#func start_fading_circle() -> void:
	#var dur : float = 1.5
	#var tween = create_tween().set_ease(Tween.EASE_OUT)
	#tween.parallel().tween_property(cherry_text, "modulate", Color('b8000000'), 0.5).set_trans(Tween.TRANS_LINEAR)
	#await tween.finished
	#circle_polygon.hide()
	#
	#
#func end_sequence() -> void:
	#var dur : float = 1.5
	#var tween = create_tween().set_ease(Tween.EASE_OUT)
	#tween.tween_property(circle_polygon, "scale", Vector2.ZERO, dur)
	#tween.parallel().tween_property(cherry_text, "scale", Vector2.ZERO, dur)
	#tween.parallel().tween_property(circle_polygon, "modulate", Color.TRANSPARENT, 0.75).set_trans(Tween.TRANS_LINEAR)
	#
	#tween.parallel().tween_callback(smoke_sequence).set_delay(0.5)
	#await tween.finished
	#prepare_for_transition()
	#
#func prepare_for_transition() -> void:
	#BackgroundForTransition.fade_in()
	#var choose_retry_world : String = GameManager.choose_retry_world()
	#
	#await get_tree().create_timer(0.15).timeout
	#get_tree().change_scene_to_file(choose_retry_world)
#
#func smoke_sequence() -> void:
	#smoke_sprite.show()
	#
	#smoke_sprite.play("default")
	#$SFX/Smoke_sound.play()
	#var tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_BACK)
	#tween.tween_property(smoke_sprite, "modulate", Color.TRANSPARENT, 1.0).set_trans(Tween.TRANS_LINEAR)
	#await tween.finished
	#smoke_sprite.modulate = Color.WHITE
	#smoke_sprite.hide()
