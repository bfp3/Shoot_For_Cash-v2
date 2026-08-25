extends HBoxContainer

signal level_chosen(place: String)

@onready var beginner: DifficultyBadge = $Beginner
@onready var advanced: DifficultyBadge = $Advanced
@onready var expert: DifficultyBadge = $Expert
@onready var mystery: DifficultyBadge = $Mystery


func _ready() -> void:
	for badge in [beginner, advanced, expert, mystery]:
		if badge:
			badge.pressed.connect(_on_badge_pressed.bind(badge))


func _on_badge_pressed(badge: DifficultyBadge) -> void:
	if badge == null or badge.locked:
		return
	var place := String(badge.travel_place).strip_edges().to_lower()
	if place.is_empty():
		return
	level_chosen.emit(place)
