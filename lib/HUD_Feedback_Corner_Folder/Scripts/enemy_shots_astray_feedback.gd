extends Control

const HUD_ON_CLICK = preload("res://sfx/HUD on click.wav")

#@onready var hud_light_control: Control = $HUD_Light_Control
@onready var hud_light_control: Control = $Round_tally
@onready var label: Label = $Score_counter

var tween_label : Tween = null
var tween_pulse : Tween = null
var fading_score := false

var orig_start_pos : Vector2
var orig_start_pos_label : Vector2
var orig_scale : Vector2 = Vector2.ONE

func _ready() -> void:
	orig_start_pos = hud_light_control.position
	orig_start_pos_label = label.position
	orig_scale = hud_light_control.scale
	hud_light_control.modulate = Color('FFFFFF00')

	
func on_startup() -> void:
	if tween_pulse:
		tween_pulse.kill()
	
	tween_pulse = create_tween()
	tween_pulse.tween_property(hud_light_control, "modulate", Color('FFFFFF'), 0.1 * 2)
	tween_pulse.tween_property(hud_light_control, "modulate", Color('FFFFFF15'), 0.125 * 4)
	#await tween.finished

func hit_the_ground_flash() -> void:
	
	if tween_pulse:
		tween_pulse.kill()
	
	tween_pulse = create_tween()
	tween_pulse.tween_property(hud_light_control, "modulate", Color('FFFFFF'), 0.1 * 2)
	tween_pulse.parallel().tween_callback(pulse_ring)
	tween_pulse.tween_interval(0.25)
	tween_pulse.tween_property(hud_light_control, "modulate", Color('FFFFFF15'), 0.125 * 8)
	#await tween.finished

func points_added_blink_feedback() -> void:
	if tween_pulse:
		tween_pulse.kill()
	tween_pulse = create_tween()
	tween_pulse.tween_property(hud_light_control, "modulate", Color('FFFFFF'), 0.1 * 2)
	tween_pulse.parallel().tween_callback(pulse_ring)
	tween_pulse.parallel().tween_property(hud_light_control, "scale", Vector2.ONE * 1.1, 0.5).set_trans(Tween.TRANS_ELASTIC) #.as_relative()
	tween_pulse.parallel().tween_property(hud_light_control, "position", Vector2(-5,0), 0.25).as_relative().set_trans(Tween.TRANS_BOUNCE)
	tween_pulse.parallel().tween_property(label, "position", Vector2(-5,0), 0.25).as_relative().set_trans(Tween.TRANS_BOUNCE)
	
	tween_pulse.tween_interval(0.25)
	tween_pulse.tween_property(hud_light_control, "modulate", Color('FFFFFF15'), 0.125 * 8)

	
func hud_missed_pineapple_feedback() -> void:
	
	if tween_pulse:
		tween_pulse.kill()
	
	tween_pulse = create_tween()
	tween_pulse.tween_property(hud_light_control, "modulate", Color('FFFF00'), 0.1 * 2)
	tween_pulse.parallel().tween_callback(pulse_ring)
	tween_pulse.tween_interval(0.25)
	tween_pulse.tween_callback(pulse_ring_2)
	tween_pulse.tween_property(hud_light_control, "modulate", Color('FFFFFF15'), 0.125 * 8)

func pulse_ring() -> void:
	var new_pulse = $Round_tally/Light2.duplicate()
	$Round_tally.add_child(new_pulse)
	new_pulse.modulate = Color('FFFFFF8a')
	
	var tween = create_tween().set_ease(Tween.EASE_IN)
	tween.tween_property(new_pulse, "modulate", Color('FFFFFF00'), 1.5)
	tween.parallel().tween_property(new_pulse, "scale", Vector2.ONE * 0.3, 2.5)
	tween.tween_callback(new_pulse.queue_free)
	
	
func pulse_ring_2() -> void:
	var new_pulse = $Round_tally/Light2.duplicate()
	$Round_tally.add_child(new_pulse)
	new_pulse.modulate = Color('FFFFFF8a')
	var tween = create_tween().set_ease(Tween.EASE_IN)
	tween.tween_property(new_pulse, "modulate", Color('FFFFFF00'), 1.5)
	tween.parallel().tween_property(new_pulse, "scale", Vector2.ONE * 0.3, 2.5)
	tween.tween_callback(new_pulse.queue_free)

func fade_in_score_dials_one_by_one() -> void:
	var counter = $Score_counter
	counter.text = str(GameManager.shots_missed_during_round)
	var tween = create_tween().set_ease(Tween.EASE_IN)
	tween.tween_property(counter, "modulate", Color('FFFFFF'), 1.5)
	
func show_points_label(amount_of_points : int) -> void:
	var counter = $Score_counter
	if tween_label:
		tween_label.kill()
		counter.modulate = Color('FFFFFF00')
	
	counter.text = str(amount_of_points)
	#counter.text = str(GameManager.shots_missed_during_round)
	tween_label = create_tween().set_ease(Tween.EASE_IN)
	tween_label.tween_interval(0.25)
	tween_label.tween_property(counter, "modulate", Color('FFFFFF'), 0.75)
	tween_label.tween_interval(0.25)
	tween_label.tween_property(counter, "modulate", Color('FFFFFF00'), 0.75)
	await tween_label.finished
	


func fade_out_score_dials_one_by_one() -> void:
	#reset_score_and_fade_out()
	#return
	
	if fading_score:
		return
	fading_score = true

	var counter = $Score_counter
	var count := GameManager.shots_missed_during_round
	counter.text = str(count)

	while count > 0:
		count -= 1
		GameManager.shots_missed_during_round = count
		counter.text = str(count)
		await get_tree().create_timer(0.03).timeout

	var tween = create_tween().set_ease(Tween.EASE_IN)
	tween.tween_interval(0.25)
	tween.tween_property(counter, "modulate", Color.TRANSPARENT, 1.5)

	await tween.finished
	fading_score = false


func reset_score_and_fade_out() -> void:
	if fading_score:
		return
	fading_score = true

	var counter = $Score_counter
	GameManager.shots_missed_during_round = 0
	counter.text = "00"

	var tween = create_tween().set_ease(Tween.EASE_IN)
	tween.tween_interval(0.25)
	tween.tween_property(counter, "modulate", Color.TRANSPARENT, 1.5)

	await tween.finished
	fading_score = false


func hud_feedback_return_to_normal() -> void:
	var tween = create_tween()
	tween.tween_interval(0.25)
	tween.tween_property(hud_light_control, "modulate", Color('FFFFFF15'), 1.0)
	tween.parallel().tween_property(hud_light_control, "scale", orig_scale, 0.25)
	tween.parallel().tween_property(hud_light_control, "position", orig_start_pos, 0.25).set_trans(Tween.TRANS_BOUNCE)
	tween.parallel().tween_property(label, "position", orig_start_pos_label, 0.25).set_trans(Tween.TRANS_BOUNCE)

func player_won() -> void:
	var tween = create_tween()
	tween.tween_property($Round_tally/Light, "modulate", Color.GOLD, 0.25)
