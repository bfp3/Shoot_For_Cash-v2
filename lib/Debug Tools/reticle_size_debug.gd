extends Control

var radius := 0.0
@export var circle_color := Color("ff000071")
@export var follow_live_radius := true

func _draw() -> void:
	var center = size / 2.0
	draw_circle(center, radius, circle_color)

func _process(_delta: float) -> void:
	var next_radius := _resolve_radius()
	if not is_equal_approx(next_radius, radius):
		radius = next_radius
		queue_redraw()


func _resolve_radius() -> float:
	if follow_live_radius:
		var player := get_tree().get_first_node_in_group("Player") as Player
		if player and player.weapon_shooting:
			return player.weapon_shooting.power_target_circle

	return gl_DataSet.dataset_float.power_target_circle[
		gl_PlayerState.dataset.power_target_circle
	]


func draw_radius(_player_radius: float) -> void:
	radius = _player_radius
	hide()
	await get_tree().create_timer(0.25).timeout
	queue_redraw()
	show()
