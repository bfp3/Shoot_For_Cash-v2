extends Node3D

func _ready() -> void:
	#BackgroundForTransition.instant_fade_in()
	#await get_tree().create_timer(1.0)
	#BackgroundForTransition.fade_out()
	#await get_tree().create_timer(0.5)
	%TV_hud.reset_hud()

func bh_Activate(parent : Node3D, behaviour : String) -> void:
	return
	var tokens = behaviour.strip_edges().split("-", false)

	for token in tokens:
		var name = token.strip_edges().to_lower()
		match name:
			"fade_in":
				BackgroundForTransition.fade_in()
				
			"fade_out":
				BackgroundForTransition.fade_out()

			_:
				push_error("Unknown behavior name: '%s'" % name)
