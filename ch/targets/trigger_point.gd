class_name TriggerPoint
extends StaticBody3D
## Shootable pad that launches an upward blast wave on hit (cooldown before reuse).

const BLAST_WAVE_SCENE := preload("res://ch/targets/TriggerBlastWave.tscn")

@onready var main_col: CollisionShape3D = $main_col
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

@export_group("Blast Wave")
## World Z the blast is pinned to (rocks sit near this plane).
@export var blast_plane_z := 23.0
## Cylinder radius of the blast volume.
@export var blast_radius := 0.5
## Cylinder height of the blast volume.
@export var blast_height := 1.0
## Upward travel speed (world units per second).
@export var blast_speed := 8.0
## Blast dissipates once its center reaches this world Y.
@export var blast_max_y := 10.0

@export_group("Cooldown")
@export_range(0.0, 10.0, 0.05) var cooldown_sec := 1.0

var _on_cooldown := false
var _ready_modulate := Color.WHITE
var _cooldown_modulate := Color(0.45, 0.45, 0.45, 0.7)


func _ready() -> void:
	add_to_group("Target")
	add_to_group("trigger_point")
	#if mesh_instance:
		#_ready_modulate = mesh_instance.modulate


func start_bullet_to_target() -> void:
	pass


func hit_by_player(_damage: int = 1, _screen_offset: Vector2 = Vector2.ZERO) -> void:
	if _on_cooldown:
		return
	_activate_blast()
	_begin_cooldown()


func _activate_blast() -> void:
	var blast := BLAST_WAVE_SCENE.instantiate() as Node3D
	var root := get_tree().get_current_scene()
	if root == null:
		root = get_tree().root
	root.add_child(blast)

	var start_pos := global_position
	start_pos.z = blast_plane_z
	blast.global_position = start_pos

	if blast.has_method("configure"):
		blast.configure(blast_radius, blast_height, blast_speed, blast_max_y)
	elif blast.has_method("start_wave"):
		blast.start_wave(blast_radius, blast_height, blast_speed, blast_max_y)


func _begin_cooldown() -> void:
	_on_cooldown = true
	if is_in_group("Target"):
		remove_from_group("Target")
	#if mesh_instance:
		#mesh_instance.modulate = _cooldown_modulate

	if cooldown_sec <= 0.0:
		_end_cooldown()
		return

	await get_tree().create_timer(cooldown_sec, false).timeout
	if is_instance_valid(self):
		_end_cooldown()


func _end_cooldown() -> void:
	_on_cooldown = false
	if not is_in_group("Target"):
		add_to_group("Target")
	#if mesh_instance:
		#mesh_instance.modulate = _ready_modulate
