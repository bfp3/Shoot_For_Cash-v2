extends TextureButton
@export var shop_main_menu : Control

@export var focus_enter_sfx: AudioStreamPlayer
@export var focus_exit_sfx: AudioStreamPlayer
@export var pressed_sfx: AudioStreamPlayer
@onready var round_number: RichTextLabel = $RoundNumber
@onready var outer_ring: TextureRect = $OuterRing
var outer_ring_mod_orig : Color = Color('1c1f26')
@onready var orig_scale := self.scale

var interaction_tween: Tween


var round_manager : RoundManager = null

var all_levels : Array = []

func _ready() -> void:
	round_manager = get_tree().get_first_node_in_group('round_manager')
	all_levels = round_manager.current_rock_sequence
	
	round_number.text = str(get_index() + 1)
	
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP

	pressed.connect(_on_pressed)

	mouse_entered.connect(_on_focus_entered)
	mouse_exited.connect(_on_focus_exited)

	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)

	self.pressed.connect(_on_pressed)
	round_manager = get_tree().get_first_node_in_group('round_manager')
	

func _on_pressed() -> void:
	if pressed_sfx:
		pressed_sfx.play()
	disabled = true
	_deselect_all_buttons()
	set_selected(true)
	
	var sequence_index := get_index() # Same as (get_index() + 1) - 1
	
	round_manager.current_sequence_index = sequence_index #- 1
	
	if interaction_tween:
		interaction_tween.kill()

	var original_scale := scale

	interaction_tween = create_tween()
	interaction_tween.set_trans(Tween.TRANS_SINE)
	interaction_tween.set_ease(Tween.EASE_OUT)

	interaction_tween.tween_property(self, "scale", original_scale * 0.85, 0.06)
	interaction_tween.tween_property(self, "scale", original_scale, 0.08)
	
	
	await interaction_tween.finished
	
	shop_main_menu.play_round_button_pressed()
	await get_tree().create_timer(1.0).timeout
	
	disabled = false
	

func _on_focus_entered() -> void:
	if focus_enter_sfx:
		focus_enter_sfx.play()

	z_index = 1
	_play_wiggle(orig_scale.x + (orig_scale.x / 5))


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
	
	
func set_selected(selected: bool) -> void:
	if selected:
		outer_ring.modulate = Color.GOLD
	else:
		outer_ring.modulate = outer_ring_mod_orig


func _deselect_all_buttons() -> void:
	for child in get_parent().get_children():
		if child.has_method("set_selected"):
			child.set_selected(false)
