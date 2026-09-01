extends DifficultyBadge
class_name LevelSelectBadgeUnlocked

## Numbered level-select badge. Visuals live in this scene so difficulty_badge.tscn can stay as the title-row original.

@onready var _stars: Control = get_node_or_null("Stars") as Control


func _ready() -> void:
	hide_icons = true
	hide_subtitle = true
	hide_banners = true
	blink_lock_instead_of_flip = true
	super._ready()
	_refresh_stars()


func configure_as_level(number: int, place: String, unlocked: bool, boss: bool, armored: bool = false, stage: String = "BEGINNER") -> void:
	super.configure_as_level(number, place, unlocked, boss, armored, stage)
	_refresh_stars()


func _refresh_stars() -> void:
	if _stars == null:
		_stars = get_node_or_null("Stars") as Control
	if _stars:
		_stars.visible = not locked and not _showing_back
		_stars.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _apply_visuals() -> void:
	super._apply_visuals()
	_refresh_stars()


func _set_face(back: bool, blank_back: bool = false) -> void:
	super._set_face(back, blank_back)
	_refresh_stars()
