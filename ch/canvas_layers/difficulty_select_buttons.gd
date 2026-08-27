extends HBoxContainer

signal level_chosen(place: String, stage_title: String)

@onready var beginner: DifficultyBadge = $Beginner
@onready var advanced: DifficultyBadge = $Advanced
@onready var expert: DifficultyBadge = $Expert
@onready var mystery: DifficultyBadge = $Mystery


func _ready() -> void:
	for badge in [beginner, advanced, expert, mystery]:
		if badge:
			badge.pressed.connect(_on_badge_pressed.bind(badge))
	refresh_unlocks()


func refresh_unlocks() -> void:
	for badge in [beginner, advanced, expert, mystery]:
		if badge and badge.has_method("refresh_unlock_state"):
			badge.refresh_unlock_state()


func _on_badge_pressed(badge: DifficultyBadge) -> void:
	if badge == null:
		return
	var place := String(badge.travel_place).strip_edges().to_lower()
	if place.is_empty():
		return
	var stage_title := String(badge.title).strip_edges().to_upper()
	stage_title = stage_title.replace("[WAVE]", "").replace("[/WAVE]", "")
	if stage_title.is_empty():
		stage_title = "BEGINNER"
	level_chosen.emit(place, stage_title)
