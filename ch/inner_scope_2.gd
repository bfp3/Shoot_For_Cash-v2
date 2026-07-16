extends Control

@export var movement_speed := 300.0

var target_position: Vector2

func _ready() -> void:
	target_position = global_position

func _process(delta: float) -> void:
	if !visible:
		set_process(false)
		return
	
	var input_dir := Vector2.ZERO

	if Input.is_action_pressed("left"):
		input_dir.x -= 1

	if Input.is_action_pressed("right"):
		input_dir.x += 1

	if Input.is_action_pressed("forward"):
		input_dir.y -= 1

	if Input.is_action_pressed("backward"):
		input_dir.y += 1

	if input_dir != Vector2.ZERO:
		target_position += input_dir.normalized() * movement_speed * delta

	var viewport_size := get_viewport_rect().size
	var half_size := size * scale * 0.5

	target_position.x = clamp(
		target_position.x,
		half_size.x,
		viewport_size.x - half_size.x
	)

	target_position.y = clamp(
		target_position.y,
		half_size.y,
		viewport_size.y - half_size.y
	)

	global_position = global_position.lerp(target_position, 10.0 * delta)

	scale = %Inner_scope.scale
