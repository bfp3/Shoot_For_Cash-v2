extends StaticBody3D
## Distant shootable egg — always active, no rock-round activation needed.

var destroyed := false
@export var health := 1
@export var destroy_cleanup_delay := 2.2

@onready var main_col: CollisionShape3D = $main_col

func _ready() -> void:

	#freeze = true
	#gravity_scale = 0.0
	add_to_group("Target")
	if has_node("AoE"):
		$AoE.hide()

func start_bullet_to_target() -> void:
	print('empty thing ')

func hit_by_player(damage: int, _screen_offset: Vector2 = Vector2.ZERO) -> void:
	if destroyed:
		return
	health -= maxi(damage, 1)
	if health <= 0:
		start_destroyed_process()


func start_destroyed_process() -> void:
	if destroyed:
		return
	destroyed = true
	remove_from_group("Target")

	if has_node("Egg_shape"):
		$Egg_shape.hide()
	if has_node("Mesh"):
		$Mesh.hide()

	if has_node("main_col"):
		$main_col.disabled = true

	if has_node("hitSound") and $hitSound.has_method("play_sound"):
		$hitSound.play_sound()
	elif has_node("hitSound"):
		$hitSound.play()

	if has_node("AoE"):
		$AoE.show()
		$AoE.global_position = global_position
		$AoE.play_particles = true

	await get_tree().create_timer(destroy_cleanup_delay).timeout
	queue_free()
