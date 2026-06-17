extends Node3D


@onready var ray_forward: RayCast3D = $ray_forward
@onready var ray_down: RayCast3D = $ray_down
@onready var ray_up: RayCast3D = $ray_up
@onready var wall_mesh: Node3D = $Wall_mesh

@export var move_step := 0.25
@export var move_speed := 0.5
@export var testing := false

var forward_dir := Vector3.FORWARD
var climbing := false
var descending := false
var on_top := false

func _ready() -> void:
	if !testing:
		if $Test_kit:
			$Test_kit.queue_free()
	else:
		$Test_kit.show()
	
	forward_dir = -transform.basis.z
	
	ray_forward.enabled = true
	ray_down.enabled = false
	ray_up.enabled = false
	start_moving()

func start_moving() -> void:
	decide_next_action()

func decide_next_action() -> void:
	update_rays()

	if climbing:
		if ray_forward.is_colliding():
			print("Climbing up...")
			start_climb()
		else:
			print("Reached top.")
			climbing = false
			on_top = true
			ray_down.enabled = true
			decide_next_action()
	elif descending:
		if not ray_down.is_colliding():
			print("Descending...")
			start_descend()
		else:
			print("Reached bottom.")
			descending = false
			on_top = false
			ray_down.enabled = false
			ray_forward.enabled = true
			move_forward()
	elif on_top:
		if not ray_forward.is_colliding() and not ray_down.is_colliding():
			print("Edge detected. Start descending.")
			ray_forward.enabled = false
			descending = true
			start_descend()
		else:
			print("On top. Rolling forward.")
			move_forward()
	else:
		if ray_forward.is_colliding():
			print("Wall ahead. Start climbing.")
			climbing = true
			ray_forward.enabled = true
			ray_down.enabled = false
			start_climb()
		else:
			print("Flat ground. Rolling forward.")
			move_forward()

func update_rays() -> void:
	if ray_forward.enabled:
		ray_forward.global_position = global_position
		ray_forward.force_raycast_update()

	if ray_down.enabled:
		ray_down.global_position = global_position + forward_dir * move_step
		ray_down.force_raycast_update()

	if ray_up.enabled:
		ray_up.global_position = global_position
		ray_up.force_raycast_update()

func move_forward() -> void:
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(self, "global_position", global_position + forward_dir * move_step, move_speed)
	tween.parallel().tween_property(wall_mesh, "rotation_degrees:x", -45.0, move_speed).as_relative()
	await tween.finished
	decide_next_action()

func start_climb() -> void:
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(self, "global_position", global_position + Vector3.UP * move_step, move_speed)
	tween.parallel().tween_property(wall_mesh, "rotation_degrees:x", -45.0, move_speed).as_relative()
	await tween.finished
	decide_next_action()

func start_descend() -> void:
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(self, "global_position", global_position + Vector3.DOWN * move_step, move_speed)
	tween.parallel().tween_property(wall_mesh, "rotation_degrees:x", -45.0, move_speed).as_relative()
	await tween.finished
	decide_next_action()
