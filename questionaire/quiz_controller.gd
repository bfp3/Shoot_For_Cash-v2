extends Node
## Challenge 6 quiz round driver. Questions come from the level script via Parser.
## Correct answers pay into the cash pool — reach WIN_CASH to clear the round.
## Wrong answers trigger a 10s rock-red-attacker dodge swarm.
class_name QuizController

const QUIZ_HUD_SCENE := preload("res://questionaire/quiz_hud.tscn")
const CANTINA_SFX := "res://sfx/star_wars_cantina.ogg"
const ELEVATOR_SFX := "res://sfx/elevator_going_up.wav"
const ANSWER_REVEAL_DELAY_SEC := 0.25
const CORRECT_NEXT_DELAY_SEC := 0.5
const SWARM_DURATION_SEC := 10.0
const SWARM_SPAWN_INTERVAL_SEC := 0.42
const WIN_CASH := 1000

@export_group("Audio")
## Cantina bed while the quiz runs (AudioStreamPlayer volume_db).
@export_range(-40.0, 6.0, 0.5) var cantina_volume_db := -4.0
## Elevator sting between questions / after hold-out (AudioStreamPlayer volume_db).
@export_range(-40.0, 6.0, 0.5) var elevator_volume_db := -2.0

const ANSWER_CELLS := [
	Vector2i(1, 1), # A1
	Vector2i(1, 8), # A8
	Vector2i(3, 1), # C1
	Vector2i(3, 8), # C8
]
## Red-attacker legal cells (cols 1/2/7/8 × rows A/B).
const SWARM_CELLS := [
	Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 7), Vector2i(1, 8),
	Vector2i(2, 1), Vector2i(2, 2), Vector2i(2, 7), Vector2i(2, 8),
]

var _round_manager: Node = null
var _rocks_container: Node = null
var _hud: QuizHud = null
var _active := false
var _ending := false
var _in_swarm := false
var _questions: Array = []
var _question_index := 0
var _wrong_count := 0
var _correct_count := 0
var _prize_start := 100
var _prize_step := 100
var _quiz_earned := 0
var _timer_sec := 60.0
var _time_left := 60.0
var _awaiting_answer := false
var _answer_rocks: Array = []
var _cantina_player: AudioStreamPlayer = null
var _sfx_player: AudioStreamPlayer = null
var _run_token := 0


func is_active() -> bool:
	return _active and not _ending


func begin(round_manager: Node, rocks_container: Node, round_data: Dictionary) -> void:
	stop()
	_round_manager = round_manager
	_rocks_container = rocks_container
	_questions = _normalize_questions(round_data.get("quiz_questions", []))
	_questions.shuffle()
	_prize_start = maxi(int(round_data.get("quiz_prize_start", 100)), 0)
	_prize_step = maxi(int(round_data.get("quiz_prize_step", 100)), 0)
	_timer_sec = float(maxi(int(round_data.get("quiz_timer_sec", 60)), 1))
	_time_left = _timer_sec
	_question_index = 0
	_wrong_count = 0
	_correct_count = 0
	_quiz_earned = 0
	_ending = false
	_in_swarm = false
	_awaiting_answer = false
	_answer_rocks.clear()
	_run_token += 1
	var token := _run_token

	if _questions.is_empty():
		push_warning("QuizController: no questions in round script")
		_finish(false)
		return

	_ensure_hud()
	_ensure_audio()
	_active = true
	if _round_manager and _round_manager.has_method("set_quiz_active"):
		_round_manager.set_quiz_active(true)
	if _rocks_container and _rocks_container.has_method("set_quiz_hold"):
		_rocks_container.set_quiz_hold(true)
	_set_quiz_no_lives(true)

	_hud.bind_world(_rocks_container)
	_hud.show_hud()
	_hud.set_goal_progress(_quiz_earned, WIN_CASH)
	_hud.set_timer(_time_left)
	_hud.set_status("Earn $%d to win!" % WIN_CASH)
	_play_cantina()

	await _run_quiz_loop(token)


func stop() -> void:
	_run_token += 1
	_active = false
	_ending = false
	_in_swarm = false
	_awaiting_answer = false
	_clear_answer_rocks()
	_clear_swarm_rocks()
	if _cantina_player and _cantina_player.playing:
		_cantina_player.stop()
	if _sfx_player and _sfx_player.playing:
		_sfx_player.stop()
	if _hud:
		_hud.hide_hud()
	if _rocks_container and _rocks_container.has_method("set_quiz_hold"):
		_rocks_container.set_quiz_hold(false)
	if _round_manager and _round_manager.has_method("set_quiz_active"):
		_round_manager.set_quiz_active(false)


func _process(delta: float) -> void:
	if not _active or _ending or _in_swarm:
		return
	_time_left = maxf(_time_left - delta, 0.0)
	if _hud:
		_hud.set_timer(_time_left)
	if _time_left <= 0.0:
		## Time's up — bank whatever they earned; only strikeout is a hard fail.
		_finish(true)


func _run_quiz_loop(token: int) -> void:
	while _active and not _ending and token == _run_token:
		if _quiz_earned >= WIN_CASH:
			_finish(true)
			return
		if _time_left <= 0.0:
			_finish(true)
			return
		if _question_index >= _questions.size():
			_questions.shuffle()
			_question_index = 0
		await _play_question(token)
		if token != _run_token or _ending:
			return
		_question_index += 1


func _play_question(token: int) -> void:
	var q: Dictionary = _questions[_question_index]
	var shuffled := _shuffle_answers(q.get("answers", []), int(q.get("correct_index", -1)))
	var answers: Array = shuffled.get("answers", [])
	var correct_index := int(shuffled.get("correct_index", -1))
	var prize := _prize_start + _correct_count * _prize_step

	_hud.set_question(String(q.get("text", "")))
	_hud.set_prize(prize)
	_hud.set_goal_progress(_quiz_earned, WIN_CASH)
	_hud.set_status("Get ready…")
	_hud.clear_answers()
	_clear_answer_rocks()
	_set_quiz_no_lives(true)

	await get_tree().create_timer(ANSWER_REVEAL_DELAY_SEC, false).timeout
	if token != _run_token or _ending or not _active:
		return

	_hud.set_status("Shoot your answer!")
	_hud.show_answers(answers)
	await _spawn_answer_rocks(answers.size())
	if token != _run_token or _ending or not _active:
		return

	_awaiting_answer = true
	var selected := await _wait_for_answer_shot(token)
	_awaiting_answer = false
	if token != _run_token or _ending or not _active:
		return
	if selected < 0:
		return

	_hud.hide_answer_except(selected)
	_clear_answer_rocks_except(selected)
	var correct := selected == correct_index and correct_index >= 0
	_hud.mark_answer(selected, correct)

	if correct:
		_hud.set_status("Correct!")
		_hud.play_confetti()
		_quiz_earned += prize
		_correct_count += 1
		if gl_PlayerState and gl_PlayerState.has_method("add_to_cash_pool"):
			gl_PlayerState.add_to_cash_pool(prize)
		_hud.set_goal_progress(_quiz_earned, WIN_CASH)
		await get_tree().create_timer(CORRECT_NEXT_DELAY_SEC, false).timeout
		if _quiz_earned >= WIN_CASH:
			_hud.clear_answers()
			_clear_answer_rocks()
			_finish(true)
			return
		_play_elevator()
	else:
		_wrong_count += 1
		_hud.clear_answers()
		_clear_answer_rocks()
		_hud.set_hold_out(SWARM_DURATION_SEC)
		_hud.set_status("")
		await get_tree().create_timer(0.45, false).timeout
		if token != _run_token or _ending or not _active:
			return
		await _run_dodge_swarm(token)
		if token != _run_token or _ending or not _active:
			return
		_play_elevator()
		await _hud.fade_question_out(0.4)

	_hud.clear_answers()
	_clear_answer_rocks()
	await get_tree().create_timer(0.05, false).timeout


func _run_dodge_swarm(token: int) -> void:
	_in_swarm = true
	_hud.set_hold_out(SWARM_DURATION_SEC)
	_hud.set_status("")
	_set_quiz_no_lives(false)
	var elapsed := 0.0
	var spawn_cd := 0.0
	while elapsed < SWARM_DURATION_SEC and token == _run_token and _active and not _ending:
		if _round_failed():
			_in_swarm = false
			_finish(false)
			return
		spawn_cd -= 0.05
		if spawn_cd <= 0.0:
			spawn_cd = SWARM_SPAWN_INTERVAL_SEC
			var cell: Vector2i = SWARM_CELLS[randi() % SWARM_CELLS.size()]
			if _rocks_container and _rocks_container.has_method("spawn_quiz_swarm_attacker"):
				_rocks_container.spawn_quiz_swarm_attacker(cell.x, cell.y)
		var step := 0.05
		await get_tree().create_timer(step, false).timeout
		elapsed += step
		var left := maxf(SWARM_DURATION_SEC - elapsed, 0.0)
		if _hud:
			_hud.set_hold_out(left)

	_clear_swarm_rocks()
	_set_quiz_no_lives(true)
	_in_swarm = false
	if _hud:
		_hud.set_status("")


func _round_failed() -> bool:
	if _round_manager == null:
		return false
	if bool(_round_manager.get("player_failed")):
		return true
	if bool(_round_manager.get("wave_ending")) and not bool(_round_manager.get("success")):
		return true
	return false


func _set_quiz_no_lives(enabled: bool) -> void:
	if _round_manager == null:
		return
	if "no_lives_this_round" in _round_manager:
		_round_manager.no_lives_this_round = enabled


## Fisher–Yates shuffle of answer slots (A1 / A8 / C1 / C8) each question.
func _shuffle_answers(answers: Array, correct_index: int) -> Dictionary:
	var order: Array = []
	for i in answers.size():
		order.append(i)
	order.shuffle()
	var shuffled: Array = []
	var new_correct := -1
	for slot in order.size():
		var old_i: int = int(order[slot])
		shuffled.append(answers[old_i])
		if old_i == correct_index:
			new_correct = slot
	return {
		"answers": shuffled,
		"correct_index": new_correct,
	}


func _spawn_answer_rocks(count: int) -> void:
	_answer_rocks.clear()
	if _rocks_container == null or not _rocks_container.has_method("spawn_quiz_answer_rock"):
		push_error("QuizController: rocks_container missing spawn_quiz_answer_rock")
		return
	for i in mini(count, ANSWER_CELLS.size()):
		var cell: Vector2i = ANSWER_CELLS[i]
		var rock = await _rocks_container.spawn_quiz_answer_rock(cell.x, cell.y, i)
		if rock != null:
			_answer_rocks.append(rock)
		await get_tree().create_timer(0.08, false).timeout


func _wait_for_answer_shot(token: int) -> int:
	while _active and not _ending and token == _run_token and _time_left > 0.0:
		for rock in _answer_rocks:
			if rock == null or not is_instance_valid(rock):
				continue
			var idx := int(rock.get_meta("quiz_answer_index", -1))
			if idx < 0:
				continue
			if not bool(rock.get("rock_activated")):
				return idx
			var state = rock.get("current_state")
			if state != null and (int(state) == RockInstance.State.HIT or int(state) == RockInstance.State.MISSED):
				return idx
		await get_tree().process_frame
	return -1


func _clear_answer_rocks_except(keep_index: int) -> void:
	for rock in _answer_rocks:
		if rock == null or not is_instance_valid(rock):
			continue
		var idx := int(rock.get_meta("quiz_answer_index", -1))
		if idx == keep_index:
			continue
		_expire_quiz_rock(rock)
	var kept: Array = []
	for rock in _answer_rocks:
		if rock != null and is_instance_valid(rock):
			var idx := int(rock.get_meta("quiz_answer_index", -1))
			if idx == keep_index:
				kept.append(rock)
	_answer_rocks = kept


func _clear_answer_rocks() -> void:
	for rock in _answer_rocks:
		_expire_quiz_rock(rock)
	_answer_rocks.clear()


func _clear_swarm_rocks() -> void:
	if _rocks_container == null:
		return
	for child in _rocks_container.get_children():
		if child == null or not is_instance_valid(child):
			continue
		if not (child is RockInstance):
			continue
		if child.rock_type != RockInstance.RockSize.RED_ATTACKER:
			continue
		if not bool(child.get_meta("quiz_swarm", false)) and not bool(child.get("rock_activated")):
			continue
		if child.has_method("_expire_red_attacker_lifetime"):
			child._expire_red_attacker_lifetime()


func _expire_quiz_rock(rock) -> void:
	if rock == null or not is_instance_valid(rock):
		return
	if rock.has_method("_expire_rock_stay_lifetime"):
		rock.rock_stay_expire_gives_strike = false
		rock._expire_rock_stay_lifetime()
	elif rock.has_method("enter_state"):
		rock.rock_activated = false
		rock.enter_state(rock.State.MISSED)


func _finish(success: bool) -> void:
	if _ending:
		return
	_ending = true
	_awaiting_answer = false
	_in_swarm = false
	_clear_answer_rocks()
	_clear_swarm_rocks()
	if _hud:
		if success and _quiz_earned >= WIN_CASH:
			_hud.set_status("You won $%d!" % _quiz_earned)
			_hud.play_confetti()
		elif success:
			_hud.set_status("Time's up — $%d earned" % _quiz_earned)
		else:
			_hud.set_status("Struck out!")
	await get_tree().create_timer(1.1, false).timeout
	_stop_cantina_fade(0.5)
	if _hud:
		_hud.hide_hud()
	_active = false
	_set_quiz_no_lives(false)
	if _rocks_container and _rocks_container.has_method("set_quiz_hold"):
		_rocks_container.set_quiz_hold(false)
	if _round_manager and _round_manager.has_method("set_quiz_active"):
		_round_manager.set_quiz_active(false)
	if _round_manager == null:
		return
	if success:
		if _round_manager.has_method("successful_round"):
			_round_manager.successful_round()
	else:
		if _round_manager.has_method("unsuccessful_round_locked"):
			_round_manager.unsuccessful_round_locked()


func _normalize_questions(raw: Array) -> Array:
	var out: Array = []
	for item in raw:
		if not (item is Dictionary):
			continue
		var answers: Array = []
		for a in item.get("answers", []):
			answers.append(str(a))
		while answers.size() < 4:
			answers.append("—")
		if answers.size() > 4:
			answers = answers.slice(0, 4)
		var correct := int(item.get("correct_index", -1))
		if correct < 0 or correct >= answers.size():
			correct = 0
		out.append({
			"text": String(item.get("text", "")).strip_edges(),
			"answers": answers,
			"correct_index": correct,
		})
	return out


func _ensure_hud() -> void:
	if _hud != null and is_instance_valid(_hud):
		return
	_hud = QUIZ_HUD_SCENE.instantiate() as QuizHud
	var host := _round_manager if _round_manager else get_tree().current_scene
	host.add_child(_hud)


func _ensure_audio() -> void:
	if _cantina_player == null:
		_cantina_player = AudioStreamPlayer.new()
		_cantina_player.name = "QuizCantina"
		_cantina_player.bus = "Master"
		add_child(_cantina_player)
		var stream = load(CANTINA_SFX)
		if stream:
			if stream is AudioStream:
				stream.loop = true
			_cantina_player.stream = stream
	if _sfx_player == null:
		_sfx_player = AudioStreamPlayer.new()
		_sfx_player.name = "QuizSfx"
		_sfx_player.bus = "Master"
		add_child(_sfx_player)


func _play_cantina() -> void:
	if _cantina_player == null:
		return
	if _cantina_player.playing:
		return
	_cantina_player.volume_db = cantina_volume_db
	_cantina_player.play()


func _stop_cantina_fade(duration: float = 0.5) -> void:
	if _cantina_player == null or not _cantina_player.playing:
		return
	var tween := create_tween()
	tween.tween_property(_cantina_player, "volume_db", -40.0, duration)
	await tween.finished
	if _cantina_player:
		_cantina_player.stop()
		_cantina_player.volume_db = cantina_volume_db


func _play_elevator() -> void:
	if _sfx_player == null:
		return
	var stream = load(ELEVATOR_SFX)
	if stream:
		_sfx_player.stream = stream
	_sfx_player.stop()
	_sfx_player.volume_db = elevator_volume_db
	_sfx_player.play()
