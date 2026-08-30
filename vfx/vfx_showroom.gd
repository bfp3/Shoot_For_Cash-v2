extends Node3D
## Open this scene to preview pooled VFX templates spaced along +X.
## Select a child and toggle `play_particles` on its AoE root (in the inspector) to preview.

@export var auto_play_on_ready := false
@export_range(0.5, 10.0, 0.1) var auto_play_gap_sec := 1.5


func _ready() -> void:
	if not auto_play_on_ready:
		return
	for child in get_children():
		if "play_particles" in child:
			child.set("play_particles", true)
			await get_tree().create_timer(auto_play_gap_sec).timeout
