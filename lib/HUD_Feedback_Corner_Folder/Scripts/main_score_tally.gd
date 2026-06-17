extends Control

const SCORE_TALLY_SFX_REVERSE = preload("res://sfx/score_tally_sfx_reverse_2.wav")
const HUD_ON_CLICK = preload("res://sfx/HUD on click.wav")

@onready var scale_control: Control = $Scale_control
@onready var hud_light_control: Control = $Round_tally
@onready var score_per_shot_total: Label = $Control/Score_per_shot_total
@onready var progress_bar_texture: TextureProgressBar = $Progress_bar_texture

var tween_label: Tween = null
var tween_red_flash: Tween = null
var tween_special_flash: Tween = null
var fading_score := false


# ────────────────────────────────
# Initialization
# ────────────────────────────────

func _ready() -> void:
	score_per_shot_total.modulate = Color('FFFFFF00')
	scale_control.modulate = Color('FFFFFF00')


func on_startup() -> void:
	var tween = create_tween()
	tween.tween_property(scale_control, "modulate", Color('FFFFFF'), 0.8)
	tween.tween_callback(pulse_ring)
	tween.tween_interval(0.25)
	tween.tween_property(scale_control, "modulate", Color('FFFFFF15'), 1.25)
	tween.parallel().tween_callback(play_off_sound)


# ────────────────────────────────
# Basic HUD Feedback
# ────────────────────────────────

func turn_on() -> void:
	var tween = create_tween()
	tween.tween_property(scale_control, "modulate", Color('FFFFFF'), 0.4)
	tween.tween_interval(0.5)
	tween.tween_callback(pulse_ring)
	tween.tween_interval(0.25)
	tween.tween_property(scale_control, "modulate", Color('FFFFFF15'), 1.25)
	tween.parallel().tween_callback(play_off_sound)


func play_off_sound() -> void:
	CommonCode.play_sound_instance_delay_time(SCORE_TALLY_SFX_REVERSE, -15.0, 0.0, 0.35)


func blink_HUD_light() -> void:
	var tween = create_tween()
	tween.tween_property(scale_control, "modulate", Color('FFFFFF'), 0.4)
	tween.tween_interval(0.25)
	tween.tween_property(scale_control, "modulate", Color('FFFFFF15'), 1.25)


func shot_hit_something_blink() -> void:
	var tween = create_tween()
	tween.tween_property(scale_control, "modulate", Color('FFFFFF'), 0.4)
	tween.tween_property(scale_control, "modulate", Color('FFFFFF15'), 1.25)
	await tween.finished


func game_won_blink() -> void:
	var tween = create_tween()
	tween.tween_property(scale_control, "modulate", Color('FFFFFF'), 0.4)


# ────────────────────────────────
# Flash / Blink Effects
# ────────────────────────────────

func main_score_red_blink() -> void:
	if tween_red_flash:
		tween_red_flash.kill()

	tween_red_flash = create_tween()
	tween_red_flash.tween_interval(0.4)
	tween_red_flash.tween_property(scale_control, "modulate", Color('FF0000'), 0.4)
	tween_red_flash.parallel().tween_callback(pulse_ring)
	tween_red_flash.tween_interval(0.25)
	tween_red_flash.tween_property(scale_control, "modulate", Color('FFFFFF15'), 1.25)
	await tween_red_flash.finished


func main_score_special_flash() -> void:
	if tween_special_flash:
		tween_special_flash.kill()

	tween_special_flash = create_tween()
	tween_special_flash.tween_interval(0.5)
	tween_special_flash.tween_property(scale_control, "modulate", Color('ffa32b'), 0.2)
	tween_special_flash.parallel().tween_callback(pulse_ring)
	tween_special_flash.tween_interval(0.5)
	tween_special_flash.parallel().tween_callback(pulse_ring_2)
	tween_special_flash.tween_interval(0.25)
	tween_special_flash.tween_property(scale_control, "modulate", Color('FFFFFF15'), 1.25)
	await tween_special_flash.finished


# ────────────────────────────────
# Score Display & Animation
# ────────────────────────────────

func pull_up_score() -> void:
	var score_label = $"../Current_total_score_tally/Coins_tracker"
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_callback(pulse_ring).set_delay(0.15)
	tween.parallel().tween_property(scale_control, "modulate", Color('FFFFFF'), 1.25)
	tween.parallel().tween_property(score_label, "modulate", Color('FFFFFF'), 1.25)
	await tween.finished


func fade_out_score() -> void:
	var score_label = $"../Current_total_score_tally/Coins_tracker"

	CommonCode.play_sound_instance_delay_time(SCORE_TALLY_SFX_REVERSE, -15.0, 0.0, 0.0)

	if not GameManager.player_has_winning_score:
		var tween = create_tween().set_ease(Tween.EASE_OUT)
		#tween.tween_property(scale_control, "modulate", Color('FFFFFF15'), 0.5)
		tween.parallel().tween_property(score_label, "modulate", Color('FFFFFF99'), 0.5)
		await tween.finished


func fade_in_score_label(amount_of_points: int) -> void:
	var counter = score_per_shot_total
	if tween_label:
		tween_label.kill()
		counter.modulate = Color('FFFFFF00')

	counter.text = str(amount_of_points).pad_zeros(2)

	tween_label = create_tween().set_ease(Tween.EASE_IN)
	tween_label.tween_interval(0.25)
	tween_label.tween_property(counter, "modulate", Color('FFFFFF'), 1.0)
	tween_label.tween_interval(0.25)
	tween_label.tween_property(counter, "modulate", Color('FFFFFF00'), 0.75)
	await tween_label.finished


func display_winning_score() -> void:
	var counter: Label = $Total_score_counter
	var bubble: Control = $Score_to_beat

	counter.text = str(GameManager.score_to_beat_for_the_level)

	var tween = create_tween().set_ease(Tween.EASE_IN)
	tween.tween_property(counter, "modulate", Color('FFFF00'), 1.5)
	tween.parallel().tween_property(bubble, "modulate", Color('FFFF00'), 1.5)
	tween.tween_interval(6.0)
	tween.tween_property(counter, "modulate", Color('FFFFFF00'), 1.5)
	tween.parallel().tween_property(bubble, "modulate", Color('FFFFFF00'), 1.5)


# ────────────────────────────────
# Visual Pulses
# ────────────────────────────────

func pulse_ring() -> void:
	var new_pulse = $Scale_control/Light2.duplicate()
	$Scale_control.add_child(new_pulse)
	new_pulse.modulate = Color('8a8a8a8a')

	var tween = create_tween().set_ease(Tween.EASE_IN)
	tween.tween_property(new_pulse, "modulate", Color('FFFFFF00'), 1.5)
	tween.parallel().tween_property(new_pulse, "scale", Vector2.ONE * 2.0, 2.5)
	await tween.finished

	if new_pulse:
		new_pulse.queue_free()


func pulse_ring_2() -> void:
	var new_pulse = $Scale_control/Light2.duplicate()
	$Scale_control.add_child(new_pulse)
	new_pulse.modulate = Color('8a8a8a8a')

	var tween = create_tween().set_ease(Tween.EASE_IN)
	tween.tween_property(new_pulse, "modulate", Color('FFFFFF00'), 1.5)
	tween.parallel().tween_property(new_pulse, "scale", Vector2.ONE * 2.0, 2.5)
	await tween.finished

	if new_pulse:
		new_pulse.queue_free()


func pulse_ring_inverse() -> void:
	var new_pulse = $Scale_control/Light2.duplicate()
	$Scale_control.add_child(new_pulse)
	new_pulse.modulate = Color('FFFFFF99')
	new_pulse.scale = Vector2.ONE

	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(new_pulse, "scale", Vector2.ONE * 1.5, 0.5).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(new_pulse, "modulate", Color('FFFFFF'), 0.25)
	tween.tween_interval(0.15)
	tween.tween_property(new_pulse, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(new_pulse, "modulate", Color('FFFFFF00'), 0.5)
	await tween.finished

	if new_pulse:
		new_pulse.queue_free()


# ────────────────────────────────
# Special Events
# ────────────────────────────────

func hit_pineapple() -> void:
	var tween = create_tween()
	tween.tween_interval(0.4)
	tween.tween_property(scale_control, "modulate", Color('FFFF00'), 0.4)
	tween.parallel().tween_callback(pulse_ring)
	tween.tween_interval(0.25)
	tween.tween_property(scale_control, "modulate", Color('FFFFFF15'), 1.25)
	await tween.finished


func fully_realised_score_indicator() -> void:
	var tween = create_tween()
	tween.tween_property(scale_control, "modulate", Color('FFFFFF50'), 0.1)
	tween.parallel().tween_property(score_per_shot_total, "scale", Vector2.ONE * 1.1, 0.1)
	tween.parallel().tween_callback(pulse_ring_inverse)
	tween.tween_property(scale_control, "modulate", Color('FFFFFF'), 0.2)
	tween.tween_interval(0.5)
	tween.tween_property(scale_control, "modulate", Color('FFFFFF15'), 1.25)
	tween.parallel().tween_property(score_per_shot_total, "scale", Vector2.ONE * 1.1, 0.1)
	await tween.finished


func player_won() -> void:
	var tween = create_tween()
	tween.tween_property($Scale_control/Light, "modulate", Color.GOLD, 0.25)
	tween.tween_property(self, "modulate", Color.GOLD, 0.25)
