extends Control

enum State {
	START,
	MIDDLE,
	END
}

var current_state : State = State.START

@onready var game_title: TextureButton = $GameTitle
@onready var secondary_title: Control = $SecondaryTitle


func _ready() -> void:
	game_title.mouse_entered.connect(_on_game_title_focus_entered)
	game_title.mouse_exited.connect(_on_game_title_focus_exited)
	game_title.pressed.connect(_on_game_title_pressed)


func enter_state(_new_state : State) -> void:
	current_state = _new_state
	
	match _new_state:
		State.START:
			update_start()


func update_start() -> void:
	var _orig_pos : Vector2 = self.global_position
	var int_dur := 1.5
	var tween = create_tween()
	
	tween.tween_property(self, "position:x", -1600.0, 0.01)
	tween.parallel().tween_callback($stone_grinding.play)
	
	tween.tween_interval(int_dur)
	
	tween.tween_property(self, "position:x", 400.0, 0.5).as_relative()
	tween.parallel().tween_callback($stone_grinding.play)
	
	tween.tween_interval(int_dur)
	
	tween.tween_property(self, "position:x", 400.0, 0.5).as_relative()
	tween.parallel().tween_callback($stone_grinding.play)
	
	tween.tween_interval(int_dur)
	
	tween.tween_property(self, "position:x", _orig_pos.x, 0.6)\
		.set_trans(Tween.TRANS_LINEAR)\
		.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_callback($stone_grinding.play)
	
	#tween.parallel().tween_property(
		#self,
		#"modulate",
		#Color.WHITE,
		#1.0
	#).set_delay(1.5)


func _on_game_title_focus_entered() -> void:
	$hover_sfx.stop()
	$hover_sfx.pitch_scale = 0.2
	$hover_sfx.volume_db = -15.0
	$hover_sfx.play(0.1)
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(game_title, "scale", Vector2.ONE * 1.15, 0.15)

func _on_game_title_focus_exited() -> void:
	$hover_sfx.stop()
	$hover_sfx.pitch_scale = 0.18
	$hover_sfx.volume_db = -20.0
	$hover_sfx.play(0.1)
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(game_title, "scale", Vector2.ONE, 0.15)

func _on_game_title_pressed() -> void:
	$pressed_sfx.play()
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	
	# Shrink and fade the main title
	tween.parallel().tween_property(game_title, "scale", Vector2.ZERO, 0.25)
	tween.parallel().tween_property(game_title, "modulate:a", 0.0, 0.25)
	
	# Fade out the secondary title
	tween.parallel().tween_property(secondary_title, "modulate:a", 0.0, 0.4)
	$'../..'.start_game()
