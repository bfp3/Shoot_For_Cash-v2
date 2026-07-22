extends TextureButton

@export var focus_enter_sfx: AudioStreamPlayer
@export var focus_exit_sfx: AudioStreamPlayer
@export var pressed_sfx: AudioStreamPlayer

var interaction_tween: Tween

@onready var orig_scale := self.scale

@onready var level_name_label: RichTextLabel = $level_name_label
@export var level_name := 'Locked'

var round_manager : RoundManager = null

func _ready() -> void:

	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP

	pressed.connect(_on_pressed)

	mouse_entered.connect(_on_focus_entered)
	mouse_exited.connect(_on_focus_exited)

	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)

	level_name_label.text = "[i]" + level_name
	self.pressed.connect(_on_level_button_pressed)
	round_manager = get_tree().get_first_node_in_group('round_manager')
	
	if disabled:
		modulate= Color("ababab59")
		level_name_label.modulate = Color("1f1f1fff")
	
func _on_level_button_pressed() -> void:
	await fill_progress_bar()
	
	var level_name_lower_case : String = level_name.to_lower()

	match level_name_lower_case:
		'moss':
			round_manager.move_to_moss()
			$"../../../../..".ticket_used()
			
		_:
			print('other button pressed')



func _on_pressed() -> void:
	if pressed_sfx:
		pressed_sfx.play()

	if interaction_tween:
		interaction_tween.kill()
	
	
	var original_scale := scale

	interaction_tween = create_tween()
	interaction_tween.set_trans(Tween.TRANS_SINE)
	interaction_tween.set_ease(Tween.EASE_OUT)

	interaction_tween.tween_property(self, "scale", original_scale * 0.85, 0.06)
	interaction_tween.tween_property(self, "scale", original_scale, 0.08)
	
	
	await interaction_tween.finished

func fill_progress_bar() -> void:
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_OUT)

	tween.tween_property($TextureProgressBar, "value", 100.0, 0.35)
#
	#tween.tween_interval(0.15)
	await tween.finished
	
	$TextureProgressBar.value = 0.0
	
func _on_focus_entered() -> void:
	if focus_enter_sfx:
		focus_enter_sfx.play()

	z_index = 1
	_play_wiggle(orig_scale.x + (orig_scale.x / 10))


func _on_focus_exited() -> void:
	if focus_exit_sfx:
		focus_exit_sfx.play()

	z_index = 0
	_play_wiggle(orig_scale.x)


func _play_wiggle(target_scale: float) -> void:
	if interaction_tween:
		interaction_tween.kill()

	interaction_tween = create_tween()

	interaction_tween.set_trans(Tween.TRANS_SINE)
	interaction_tween.set_ease(Tween.EASE_IN_OUT)

	interaction_tween.tween_property(
		self,
		"scale",
		Vector2(target_scale, target_scale),
		0.08
	)

	interaction_tween.tween_property(self, "rotation_degrees", -2.0, 0.04)
	interaction_tween.tween_property(self, "rotation_degrees", 2.0, 0.08)
	interaction_tween.tween_property(self, "rotation_degrees", 0.0, 0.04)
