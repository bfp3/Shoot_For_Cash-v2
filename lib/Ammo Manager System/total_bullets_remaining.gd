extends Control

@onready var bullets_container = $PanelContainer
@onready var shuffle_button = $ShuffleButton

@onready var bullet_scene: Panel = $ammo_unit
var original_positions := []

func setup(bullet_count: int):
	bullets_container.get_children().clear()
	original_positions.clear()
	for i in range(bullet_count):
		var bullet = bullet_scene.duplicate()
		bullets_container.add_child(bullet)
		original_positions.append(bullet.position)
		bullet.connect("drag_stopped", _on_bullet_drag_stopped)

func _on_bullet_drag_stopped(bullet):
	if !bullet.was_dropped_successfully():
		var tween = create_tween()
		tween.tween_property(bullet, "position", original_positions[bullet.get_index() - 1], 0.2)

func _ready():
	shuffle_button.pressed.connect(_on_shuffle_pressed)

func _on_shuffle_pressed():
	var bullets = bullets_container.get_children()
	var new_positions = original_positions.duplicate()
	new_positions.shuffle()
	for i in range(bullets.size()):
		var tween = create_tween()
		tween.tween_property(bullets[i], "position", new_positions[i], 0.25)
		original_positions[i] = new_positions[i]  # update tracked order
