extends Control

#const HUD_ON_CLICK = preload("res://400_sounds/HUD Sfx/HUD on click.wav")
#
#@onready var hud_light_control: Control = $Round_tally
#
#var tween_pulse : Tween = null
#var orig_start_pos : Vector2
#var orig_scale : Vector2
#
#func _ready() -> void:
	#orig_start_pos = global_position
	#orig_scale = scale
	#modulate = Color('FFFFFF00')
	##await get_tree().create_timer(0.4).timeout
	##blink_HUD_light()
#
#func on_startup() -> void:
	#var tween = create_tween()
	#tween.tween_property(self, "modulate", Color('FFDDDD'), 0.1 * 4)
	##tween.parallel().tween_callback(pulse_ring)
	##tween.tween_interval(0.25)
	#tween.tween_property(self, "modulate", Color('FFFFFF15'), 0.125 * 16)
	#await tween.finished
	##
	##
	##var tween = create_tween()
	##tween.tween_property(self, "modulate", Color('FFDDDD'), 0.1 * 8)
	##tween.parallel().tween_callback(pulse_ring)
	##tween.tween_interval(0.25)
	##tween.tween_property(self, "modulate", Color('FFFFFF15'), 0.125 * 16)
	##await tween.finished
#
#func blink_HUD_light() -> void:
	#if tween_pulse:
		#tween_pulse.kill()
		#
	#tween_pulse = create_tween()
	#
	#tween_pulse.tween_property(self, "modulate", Color('FFDDDD'), 0.1 * 8)
	#tween_pulse.parallel().tween_callback(pulse_ring)
	#tween_pulse.parallel().tween_property(self, "scale", scale * 1.2, 0.5).set_trans(Tween.TRANS_ELASTIC)
	#tween_pulse.parallel().tween_property(self, "global_position", Vector2(-10,-10), 0.25).as_relative().set_trans(Tween.TRANS_BOUNCE)
	#
#func red_damage_hud_feedback_return_to_normal() -> void:
	#var tween = create_tween()
	#tween.tween_interval(0.25)
	#tween.tween_property(self, "modulate", Color('FFFFFF15'), 1.0)
	#tween.parallel().tween_property(self, "scale", orig_scale, 0.5)
	#tween.parallel().tween_property(self, "global_position", orig_start_pos, 0.25).set_trans(Tween.TRANS_BOUNCE)
	#
#func pulse_ring() -> void:
	#var new_pulse = $Light2.duplicate()
	#add_child(new_pulse)
	#new_pulse.modulate = Color('FFEEEE')
	#
	#var tween = create_tween().set_ease(Tween.EASE_IN)
	#tween.tween_property(new_pulse, "modulate", Color('FFEEEE00'), 2.5)
	#tween.parallel().tween_property(new_pulse, "scale", Vector2.ONE * 2.0, 3.5)
	#tween.parallel().tween_callback(pulse_ring_2).set_delay(2.0)
	#tween.tween_callback(new_pulse.queue_free)
#
	##await tween.finished
	#
#func pulse_ring_2() -> void:
	#var new_pulse = $Light2.duplicate()
	#add_child(new_pulse)
	#new_pulse.modulate = Color('FFEEEE')
	#
	#var tween = create_tween().set_ease(Tween.EASE_IN)
	#tween.tween_property(new_pulse, "modulate", Color('FFEEEE00'), 2.5)
	#tween.parallel().tween_property(new_pulse, "scale", Vector2.ONE * 2.0, 3.5)
	#tween.tween_callback(new_pulse.queue_free)
#
#
#func fade_out_damage_counters() -> void:
	#var tween = create_tween()
	#tween.tween_property(self, "modulate", Color('FFFFFF15'), 0.1 * 4)
