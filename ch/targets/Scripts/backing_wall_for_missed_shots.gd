extends StaticBody3D

const ARROW_AREA_3D = preload("res://200_characters/weapons/bullet_area3D.tscn")

@export var arrow_speed := 40.0

var spawned_arrows: Array[Area3D] = []
var target_pos : Vector3

func _ready() -> void:
	add_to_group('Target')
	add_to_group('backing_wall')

func add_unique_marker(pos: Vector3) -> void:
	#$Unique_marker.global_position = pos
	target_pos = pos

func spawn_my_arrow() -> void:
	for i in range(2):
		var new_arrow = ARROW_AREA_3D.instantiate()
		var player_gun = get_tree().get_first_node_in_group("player_gun")
		
		get_tree().get_current_scene().add_child(new_arrow)
		new_arrow.global_position = player_gun.get_barrel_position()
		spawned_arrows.append(new_arrow)
		await get_tree().create_timer(0.15).timeout
	
func _physics_process(delta: float) -> void:
	#var target = $Unique_marker.global_position

	for arrow in spawned_arrows.duplicate():
		if !is_instance_valid(arrow):
			if spawned_arrows.has(arrow):
				spawned_arrows.erase(arrow)
			continue

		var direction = (target_pos - arrow.global_position).normalized()
		arrow.global_position += direction * arrow_speed * delta
		arrow.look_at(target_pos, Vector3.UP, true)

		if arrow.global_position.distance_to(target_pos) < 0.1:
			arrow.cleanUp()
			if spawned_arrows.has(arrow):
				spawned_arrows.erase(arrow)
