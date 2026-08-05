class_name PerformanceTargetProfile
extends Resource

## Recommended maximum (or minimum for higher-is-better) values for each metric.
## Edit the .tres profiles under profiles/, or duplicate and assign at runtime.

@export var profile_id: StringName = &"desktop"
@export var display_name: String = "Forward+ (Desktop)"
@export_multiline var description: String = ""

## StringName metric id -> recommended limit.
## For higher-is-better metrics (e.g. FPS), this is the recommended minimum.
@export var targets: Dictionary = {}


func get_target(metric_id: StringName, fallback: float = 0.0) -> float:
	if targets.has(metric_id):
		return float(targets[metric_id])
	# Allow String keys from .tres / inspector edits.
	var as_str := String(metric_id)
	if targets.has(as_str):
		return float(targets[as_str])
	return fallback


func set_target(metric_id: StringName, value: float) -> void:
	targets[metric_id] = value


func duplicate_profile() -> PerformanceTargetProfile:
	var copy := PerformanceTargetProfile.new()
	copy.profile_id = profile_id
	copy.display_name = display_name
	copy.description = description
	copy.targets = targets.duplicate(true)
	return copy
