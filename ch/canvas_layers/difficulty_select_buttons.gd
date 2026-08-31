extends HBoxContainer

signal difficulty_chosen(stage_title: String)
signal level_chosen(place: String, stage_title: String)

@onready var beginner: DifficultyBadge = $Beginner
@onready var advanced: DifficultyBadge = $Advanced
@onready var expert: DifficultyBadge = $Expert
@onready var mystery: DifficultyBadge = $Mystery


func _ready() -> void:
	for badge in [beginner, advanced, expert]:
		if badge:
			badge.selects_difficulty = true
			badge.pressed.connect(_on_badge_pressed.bind(badge))
	refresh_unlocks()


func refresh_unlocks() -> void:
	for badge in [beginner, advanced, expert]:
		if badge == null:
			continue
		if badge.has_method("reset_selection_state"):
			badge.reset_selection_state()
		if badge.has_method("refresh_unlock_state"):
			badge.refresh_unlock_state()


func _on_badge_pressed(badge: DifficultyBadge) -> void:
	if badge == null:
		return
	var stage_title := String(badge.title).strip_edges().to_upper()
	stage_title = stage_title.replace("[WAVE]", "").replace("[/WAVE]", "")
	if stage_title.is_empty() or stage_title == "???":
		stage_title = "BEGINNER"
	difficulty_chosen.emit(stage_title)
