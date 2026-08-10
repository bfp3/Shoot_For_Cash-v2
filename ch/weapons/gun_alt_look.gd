extends Node3D

## Applied on ready so this mesh reads as a different weapon from the default gun.
## Tweak colors / scale here, or edit the instance under Player_gun in Player.tscn.

@export var body_color := Color(0.06, 0.14, 0.16, 1.0)
@export var accent_color := Color(0.12, 0.95, 0.82, 1.0)
@export var accent_emission := 2.2
@export var mesh_scale := Vector3(1.08, 1.12, 1.2)


func _ready() -> void:
	scale = mesh_scale
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = body_color
	body_mat.metallic = 0.9
	body_mat.roughness = 0.18

	var accent_mat := StandardMaterial3D.new()
	accent_mat.albedo_color = accent_color
	accent_mat.metallic = 0.55
	accent_mat.roughness = 0.12
	accent_mat.emission_enabled = true
	accent_mat.emission = accent_color
	accent_mat.emission_energy_multiplier = accent_emission

	var top := get_node_or_null("top")
	if top == null:
		return
	for mesh in top.find_children("*", "MeshInstance3D", true, false):
		var mi := mesh as MeshInstance3D
		if mi == null or not mi.visible:
			continue
		var n := String(mi.name).to_lower()
		if n.contains("bump") or n.contains("glass") or n.contains("eye"):
			mi.material_override = accent_mat
		else:
			mi.material_override = body_mat
