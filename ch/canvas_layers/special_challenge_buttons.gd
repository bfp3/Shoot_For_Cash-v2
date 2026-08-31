extends HBoxContainer
## Bonus challenge badges under the difficulty row. Hidden until `challenges_unlocked`.

signal level_chosen(place: String, stage_title: String)

@onready var challenge_1: DifficultyBadge = $Challenge1
@onready var challenge_2: DifficultyBadge = $Challenge2
@onready var challenge_3: DifficultyBadge = $Challenge3
@onready var challenge_4: DifficultyBadge = $Challenge4
@onready var challenge_5: DifficultyBadge = $Challenge5

var _rest_position := Vector2.ZERO
var _rest_captured := false


func _challenge_badges() -> Array:
	return [challenge_1, challenge_2, challenge_3, challenge_4, challenge_5]


func _ready() -> void:
	add_to_group("special_challenge_buttons")
	_rest_position = position
	_rest_captured = true
	for badge in _challenge_badges():
		if badge:
			badge.pressed.connect(_on_badge_pressed.bind(badge))
	refresh_unlocks()


func reset_row_layout() -> void:
	top_level = false
	if _rest_captured:
		position = _rest_position
	for badge in _challenge_badges():
		if badge and badge.has_method("reset_selection_state"):
			badge.reset_selection_state()


func refresh_unlocks() -> void:
	if owner != null and String(owner.name) == "StartMenuLevelSelect":
		hide()
		return
	var show_row := false
	if gl_DataSet and gl_DataSet.has_method("are_challenges_visible"):
		show_row = bool(gl_DataSet.are_challenges_visible())
	elif gl_DataSet and "debug_everything_unlocked" in gl_DataSet and gl_DataSet.debug_everything_unlocked:
		show_row = true
	visible = show_row
	if not show_row:
		return
	for badge in _challenge_badges():
		if badge and badge.has_method("refresh_unlock_state"):
			badge.refresh_unlock_state()


## Slide this row up to match DifficultySelectButtons Y while a challenge badge centers.
func animate_align_to_difficulty_row(duration: float = 0.22) -> void:
	var difficulty_row := get_parent().get_node_or_null("DifficultySelectButtons") as Control
	if difficulty_row == null or not is_instance_valid(difficulty_row):
		return
	## Keep badges as children so they ride up with this row.
	var gp := global_position
	top_level = true
	global_position = gp
	var dest := gp
	dest.y = difficulty_row.global_position.y
	var tween := create_tween()
	tween.tween_property(self, "global_position", dest, duration)\
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished


func _on_badge_pressed(badge: DifficultyBadge) -> void:
	if badge == null:
		return
	var place := String(badge.travel_place).strip_edges().to_lower()
	if place.is_empty():
		return
	var stage_title := String(badge.title).strip_edges().to_upper()
	stage_title = stage_title.replace("[WAVE]", "").replace("[/WAVE]", "")
	if stage_title.is_empty():
		stage_title = "CHALLENGE 1"
	level_chosen.emit(place, stage_title)
