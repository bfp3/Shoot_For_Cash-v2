extends CanvasLayer
## Challenge 6 questionnaire HUD — question, prize, timer, answer labels over aim cells.
class_name QuizHud

signal answer_labels_ready

const ANSWER_CELLS := [
	Vector2i(1, 1), # A1
	Vector2i(1, 8), # A8
	Vector2i(3, 1), # C1
	Vector2i(3, 8), # C8
]

@onready var question_label: RichTextLabel = %QuestionLabel
@onready var prize_label: Label = %PrizeLabel
@onready var timer_label: Label = %TimerLabel
@onready var wrongs_label: Label = %WrongsLabel
@onready var status_label: Label = %StatusLabel
@onready var confetti: CPUParticles2D = %Confetti
@onready var answer_root: Control = %AnswerRoot

var _answer_labels: Array[Label] = []
var _rocks_container: Node = null
var _camera: Camera3D = null


func _ready() -> void:
	layer = 85
	visible = false
	_ensure_answer_labels()
	if confetti:
		confetti.emitting = false


func bind_world(rocks_container: Node, camera: Camera3D = null) -> void:
	_rocks_container = rocks_container
	_camera = camera


func show_hud() -> void:
	visible = true



func hide_hud() -> void:
	visible = false
	clear_answers()
	set_status("")


func set_question(text: String) -> void:
	if question_label:
		question_label.text = "[center]%s[/center]" % text
		question_label.modulate.a = 1.0
		question_label.show()


func set_hold_out(seconds_left: float) -> void:
	if question_label == null:
		return
	var secs := maxi(ceili(seconds_left), 0)
	question_label.text = "[center]HOLD OUT %d second%s[/center]" % [secs, "" if secs == 1 else "s"]
	question_label.modulate.a = 1.0
	question_label.show()


func set_prize(amount: int) -> void:
	if prize_label:
		prize_label.text = "$%d" % amount


func set_timer(seconds_left: float) -> void:
	if timer_label == null:
		return
	var secs := maxi(ceili(seconds_left), 0)
	timer_label.text = "%d:%02d" % [int(secs / 60.0), secs % 60]


func set_goal_progress(earned: int, goal: int) -> void:
	if wrongs_label:
		wrongs_label.text = "$%d / $%d" % [earned, goal]


func set_wrongs(wrong_count: int, wrong_limit: int) -> void:
	if wrongs_label:
		wrongs_label.text = "Wrong %d / %d" % [wrong_count, wrong_limit]


func set_status(text: String) -> void:
	if status_label:
		status_label.text = text


func clear_answers() -> void:
	for label in _answer_labels:
		if label:
			label.hide()
			label.text = ""
			label.modulate = Color.WHITE


func show_answers(answers: Array) -> void:
	_ensure_answer_labels()
	clear_answers()
	for i in mini(answers.size(), _answer_labels.size()):
		var label := _answer_labels[i]
		label.text = str(answers[i])
		label.modulate = Color.WHITE
		label.show()
	_update_answer_positions()
	answer_labels_ready.emit()


func hide_answer_except(keep_index: int) -> void:
	for i in _answer_labels.size():
		var label := _answer_labels[i]
		if label == null:
			continue
		if i == keep_index:
			label.show()
		else:
			label.hide()


func mark_answer(index: int, correct: bool) -> void:
	if index < 0 or index >= _answer_labels.size():
		return
	var label := _answer_labels[index]
	if label == null:
		return
	label.modulate = Color(0.35, 0.95, 0.45, 1.0) if correct else Color(0.95, 0.3, 0.3, 1.0)


func play_confetti() -> void:
	if confetti == null:
		return
	confetti.one_shot = true
	confetti.lifetime = 3.0
	confetti.restart()
	confetti.emitting = true
	var world_confetti := get_tree().get_first_node_in_group("confetti")
	if world_confetti and world_confetti.has_method("start_confetti"):
		world_confetti.start_confetti()


func fade_question_out(duration: float = 0.85) -> void:
	if question_label == null:
		return
	var tween := create_tween()
	tween.tween_property(question_label, "modulate:a", 0.0, duration)
	await tween.finished


func _process(_delta: float) -> void:
	if not visible:
		return
	_update_answer_positions()


func _ensure_answer_labels() -> void:
	if not _answer_labels.is_empty():
		return
	if answer_root == null:
		return
	for i in ANSWER_CELLS.size():
		var label := Label.new()
		label.name = "Answer%d" % (i + 1)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(520, 160)
		label.add_theme_font_size_override("font_size", 84)
		label.add_theme_color_override("font_color", Color(1, 0.95, 0.88, 1))
		label.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.08, 0.9))
		label.add_theme_constant_override("outline_size", 8)
		label.hide()
		answer_root.add_child(label)
		_answer_labels.append(label)


func _update_answer_positions() -> void:
	if _rocks_container == null or not _rocks_container.has_method("aim_cell_world_position"):
		return
	var cam := _camera
	if cam == null or not is_instance_valid(cam):
		cam = get_viewport().get_camera_3d()
	if cam == null:
		return
	for i in ANSWER_CELLS.size():
		if i >= _answer_labels.size():
			break
		var label := _answer_labels[i]
		if label == null or not label.visible:
			continue
		var cell: Vector2i = ANSWER_CELLS[i]
		var world: Vector3 = _rocks_container.aim_cell_world_position(cell.x, cell.y)
		var screen: Vector2 = cam.unproject_position(world)
		label.global_position = screen - label.size * 0.5
