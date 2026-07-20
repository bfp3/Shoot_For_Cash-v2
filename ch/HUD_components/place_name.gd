extends Control

@onready var place_label: RichTextLabel = $PlaceLabel

func _ready() -> void:
	update_place_name()

func update_place_name() -> void:
	var current_place : String = gl_PlayerState.dataset.level_name
	show()
	if current_place == 'start':
		hide()
		return
		
	var tween = create_tween()
	tween.tween_property(place_label, 'modulate', Color.TRANSPARENT, 1.0)
	tween.tween_interval(1.0)
	await tween.finished

	place_label.text = "[b]" + current_place.to_upper()
	
	var tween2 = create_tween()
	tween2.tween_property(place_label, 'modulate', Color.WHITE, 1.0)
