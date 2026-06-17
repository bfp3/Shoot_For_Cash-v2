extends Control
#class_name HUD_feedback_corner

@onready var main_score_tally: Control = $Corner_Container/Main_score_Tally
@onready var enemy_shots_astray_feedback: Control = $Corner_Container/Enemy_shots_astray_feedback
@onready var cage_damage_feedback: Control = $Corner_Container/Cage_damage_feedback
@onready var pineapple_module: Control = $Corner_Container/Pineapple_module


func _ready() -> void:
	pass


# ────────────────────────────────
# Startup Sequence
# ────────────────────────────────

func bootup_sequence() -> void:
	enemy_shots_astray_feedback.on_startup()
	cage_damage_feedback.on_startup()
	await get_tree().create_timer(2.0).timeout
	main_score_tally.on_startup()


# ────────────────────────────────
# Main Score Effects
# ────────────────────────────────

func feedback_on_a_hundred() -> void:
	main_score_tally.shot_hit_something_blink()
	
	
func main_score_GREY_flash() -> void:
	main_score_tally.shot_hit_something_blink()

func main_score_RED_flash() -> void:
	main_score_tally.main_score_red_blink()

func main_score_SPECIAL_flash() -> void:
	main_score_tally.main_score_special_flash()

func pull_up_score_tally() -> void:
	main_score_tally.pull_up_score()

func fade_out_score() -> void:
	if GameManager.player_has_winning_score:
		await $Corner_Container/Game_won_tally.display_tally()
		main_score_tally.hide()
	else:
		main_score_tally.fade_out_score()

func fade_out_score_dials_one_by_one() -> void:
	if GameManager.player_has_winning_score:
		main_score_tally.fade_out_score_dials_one_by_one()

func main_score_update(amount_of_points: float) -> void:
	# Placeholder or intentionally left empty
	return
	# main_score_tally.fade_in_score_label(amount_of_points)


# ────────────────────────────────
# Enemy Shots & Feedback
# ────────────────────────────────

func hud_missed_shot_feedback() -> void:
	enemy_shots_astray_feedback.hit_the_ground_flash()

func points_added_blink_feedback(amount_of_points: int) -> void:
	enemy_shots_astray_feedback.points_added_blink_feedback()
	enemy_shots_astray_feedback.show_points_label(amount_of_points)

func hud_missed_pineapple_feedback() -> void:
	enemy_shots_astray_feedback.hud_missed_pineapple_feedback()

func red_damage_hud_feedback_return_to_normal() -> void:
	cage_damage_feedback.red_damage_hud_feedback_return_to_normal()
	enemy_shots_astray_feedback.hud_feedback_return_to_normal()


# ────────────────────────────────
# Cage & Pineapple Feedback
# ────────────────────────────────

func cage_taken_damage() -> void:
	cage_damage_feedback.blink_HUD_light()

func fade_out_damage_counters() -> void:
	cage_damage_feedback.fade_out_damage_counters()

func hit_pineapple() -> void:
	pineapple_module.hit_pineapple()

func fade_out_pineapple() -> void:
	pineapple_module.fade_out_pineapple()


# ────────────────────────────────
# Endgame Feedback
# ────────────────────────────────

func player_has_reached_winning_score() -> void:
	main_score_tally.player_won()
	rotation_tween_quick()
	var container = $Corner_Container
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)

	tween.tween_property(container, "scale", container.scale * Vector2(1.25, 1.25), 0.5)
	tween.tween_property(enemy_shots_astray_feedback, "modulate", Color.TRANSPARENT, 0.5)
	tween.parallel().tween_property(cage_damage_feedback, "modulate", Color.TRANSPARENT, 0.5).set_delay(0.25)
	tween.tween_interval(0.5)
	tween.tween_property(container, "scale", Vector2.ONE, 1.0)

	await tween.finished
	enemy_shots_astray_feedback.hide()
	cage_damage_feedback.hide()

	await get_tree().create_timer(0.5).timeout
	$Corner_Container/Player_won.start_sequence()

func game_lost() -> void:
	rotation_tween()
	modulate_tween()

func rotation_tween() -> void:
	var dur := 0.2
	var container := $Corner_Container

	for i in range(5):
		var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(container, "rotation", -0.1, dur)
		tween.tween_property(container, "rotation", 0.1, dur)
		await tween.finished
		
func rotation_tween_quick() -> void:
	var dur := 0.1
	var container := $Corner_Container

	for i in range(5):
		var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		tween.tween_property(container, "rotation", -0.1, dur)
		tween.tween_property(container, "rotation", 0.1, dur)
		await tween.finished

func modulate_tween() -> void:
	
	var container := $Corner_Container
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(container, "modulate", Color.TRANSPARENT, 2.0)
	await tween.finished


# ────────────────────────────────
# Debug Key Input
# ────────────────────────────────

func _input(event: InputEvent) -> void:
	if Input.is_key_label_pressed(KEY_SPACE):
		player_has_reached_winning_score()
