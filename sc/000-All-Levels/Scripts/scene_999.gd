extends Node3D

func _ready() -> void:
	BackgroundForTransition.instant_fade_in()
	$Control.modulate = Color.TRANSPARENT
	await get_tree().create_timer(1.0).timeout
	BackgroundForTransition.fade_out()

func bh_Activate(parent : Node3D, behaviour : String) -> void:
	var tokens = behaviour.strip_edges().split("-", false)

	for token in tokens:
		var name = token.strip_edges().to_lower()
		match name:
			"fade_in":
				start()
				
			"fade_out":
				end()
				
func start() -> void:
	
	var tween = create_tween()
	tween.tween_property($Control, "modulate", Color.WHITE, 1.5)
	await tween.finished
	
	
func end() -> void:
	var tween = create_tween()
	tween.tween_property($Control, "modulate", Color.WHITE, 1.5)
	await tween.finished
