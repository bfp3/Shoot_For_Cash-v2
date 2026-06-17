extends Node3D

@onready var player = get_tree().get_first_node_in_group('player_gun')

var start_pos : Vector3
var running_speed := 0.05

func _ready() -> void:
	start_pos = global_position
	
func _process(delta: float) -> void:
	var target_pos : Vector3 = player.global_position
	#look_at(target_pos, Vector3.UP, false)
	global_position.y = -2.0
	global_position.x = move_toward(global_position.x, player.global_position.x, running_speed)
	global_position.z= move_toward(global_position.z, player.global_position.z, running_speed)
