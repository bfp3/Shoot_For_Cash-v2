extends Node3D

@onready var btn: TextureButton = $Play_button

func _ready() -> void:
	btn.modulate = Color.TRANSPARENT
	btn.disabled = true

func bh_Activate(parent : Node3D, behaviour : String) -> void:
	var tokens = behaviour.strip_edges().split("-", false)

	for token in tokens:
		var name = token.strip_edges().to_lower()
		match name:
			"show_button":
				fade_in()
				
			"hide_button":
				fade_out()
		
			_:
				push_error("Unknown behavior name: '%s'" % name)


func fade_in() -> void:
	btn.disabled = false
	var tween = create_tween()
	tween.tween_property(btn, "modulate", Color.WHITE, 1.5)
	await tween.finished
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
func fade_out() -> void:
	#Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	btn.disabled = true
	var tween = create_tween()
	tween.tween_property(btn, "modulate", Color.TRANSPARENT, 0.75)
	

func _on_play_button_pressed() -> void:
	EventBus.instance.actor_event.emit(self.name, "button-accept")


func _on_play_button_focus_entered() -> void:
	if btn.disabled:
		return
	btn.modulate = Color.RED
