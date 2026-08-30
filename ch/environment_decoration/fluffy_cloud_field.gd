extends Node3D
## Spawns a field of drifting, morphing fluffy clouds.

@export var cloud_scene: PackedScene
@export var cloud_count := 10
@export var area_size := Vector3(80.0, 12.0, 50.0)
@export var area_center := Vector3(0.0, 18.0, 30.0)
@export var drift_speed_min := 0.8
@export var drift_speed_max := 2.4
@export var drift_axis := Vector3(1.0, 0.0, 0.15)
@export var cloud_scale_min := 0.8
@export var cloud_scale_max := 1.8
@export var morph_speed := 0.07
@export var rebuild_on_ready := true

const DEFAULT_CLOUD := preload("res://ch/environment_decoration/FluffyCloud.tscn")


func _ready() -> void:
	if cloud_scene == null:
		cloud_scene = DEFAULT_CLOUD
	if rebuild_on_ready:
		rebuild()


func rebuild() -> void:
	for child in get_children():
		child.queue_free()

	var half := area_size * 0.5
	var amin := area_center - half
	var amax := area_center + half
	var axis := drift_axis
	if axis.length_squared() < 0.0001:
		axis = Vector3.RIGHT
	axis = axis.normalized()

	for i in maxi(cloud_count, 1):
		var cloud: Node3D = cloud_scene.instantiate()
		var speed := randf_range(drift_speed_min, drift_speed_max)
		## Configure before add_child so FluffyCloud._ready / puff build see final values.
		if "drift_velocity" in cloud:
			cloud.drift_velocity = axis * speed
		if "morph_speed" in cloud:
			cloud.morph_speed = morph_speed * randf_range(0.7, 1.4)

		var local_pos := Vector3(
			randf_range(amin.x, amax.x),
			randf_range(amin.y, amax.y),
			randf_range(amin.z, amax.z)
		)
		cloud.position = local_pos
		var s := randf_range(cloud_scale_min, cloud_scale_max)
		cloud.scale = Vector3.ONE * s

		add_child(cloud)
		if cloud.has_method("configure_wrap"):
			cloud.configure_wrap(global_transform * amin, global_transform * amax)
		if cloud.has_method("reset_bob_anchor"):
			cloud.reset_bob_anchor()
