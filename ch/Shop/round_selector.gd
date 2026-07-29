@tool
extends TextureButton



@onready var outer_ring: TextureRect = $OuterRing

@export var outerRingColour_default: Color = Color("666b78ff"):
	set(value):
		outerRingColour_default = value
		_update_editor_preview()

@export var outerRingColour_active: Color = Color("ffc700ff"):
	set(value):
		outerRingColour_active = value
		_update_editor_preview()

@export var outerRingColour_levelCompleted: Color = Color("42d100ff"):
	set(value):
		outerRingColour_levelCompleted = value
		_update_editor_preview()

var outer_ring_mod_orig: Color


@export var shop_main_menu : Control

@export var focus_enter_sfx: AudioStreamPlayer
@export var focus_exit_sfx: AudioStreamPlayer
@export var pressed_sfx: AudioStreamPlayer
@onready var round_number: RichTextLabel = $RoundNumber


@onready var orig_scale := self.scale

var interaction_tween: Tween
var round_manager : RoundManager = null

var all_levels : Array = []

enum State {
	LOCKED,
	AVAILABLE,
	CLEARED,
	PERFECTED
}

@export var current_state : State = State.LOCKED
var old_state : State = State.LOCKED
var tween_available : Tween = null




func _ready() -> void:

	outer_ring_mod_orig = outerRingColour_default
	round_number.modulate = Color.TRANSPARENT
	
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
	
	if !self.has_signal('pressed'):
		self.pressed.connect(_on_pressed)
	round_manager = get_tree().get_first_node_in_group('round_manager')

	enter_state(current_state)
	_update_editor_preview()
	


func enter_state(new_state : State) -> void:
	current_state = new_state
	
	if tween_available:
		tween_available.kill()
	
	match current_state:
		State.LOCKED:
			update_locked()
			
		State.AVAILABLE:
			update_available()
			
		State.CLEARED:
			update_cleared()
			
		State.PERFECTED:
			update_perfected()
			
func update_locked() -> void:
	#disabled = true
	$CheckMark.hide()
	$'100_percent'.hide()
	$ArrowIndication.hide()
	outer_ring.modulate = outerRingColour_default
	round_number.hide()
	round_number.modulate.a = 0.0
	self.custom_minimum_size = Vector2(40.0,40.0)

func update_available() -> void:
	disabled = false
	$ArrowIndication.show()
	$CheckMark.hide()
	$'100_percent'.hide()
	outer_ring.modulate = outerRingColour_active
	round_number.show()
	round_number.modulate.a = 100.0
	blink_tween()
	self.custom_minimum_size = Vector2(50.0,50.0)
	
func update_cleared() -> void:
	#disabled = true
	$CheckMark.show()
	$'100_percent'.hide()
	$ArrowIndication.hide()
	outer_ring.modulate = outerRingColour_levelCompleted
	round_number.hide()
	self.custom_minimum_size = Vector2(40.0,40.0)
	
func update_perfected() -> void:
	#disabled = true
	$CheckMark.show()
	$ArrowIndication.hide()
	var round_bonus := int(gl_DataSet.get_value('reward_perfect_round'))
	%CashEarned.text = "[i]$" + str(gl_PlayerState.dataset.bonus_cash + round_bonus - gl_PlayerState.dataset.fines)
	$'100_percent'.show()
	outer_ring.modulate = outerRingColour_levelCompleted
	round_number.hide()
	self.custom_minimum_size = Vector2(40.0,40.0)
	
func blink_tween() -> void:
	var dur : float = 0.2
	if tween_available:
		tween_available.kill()
	
	tween_available = create_tween()
	tween_available.tween_property($OuterRing, "modulate:a", 0.2, dur)
	tween_available.tween_property($OuterRing, "modulate:a", 1.0, dur)
	await tween_available.finished
	
	if current_state == State.AVAILABLE:
		blink_tween()
	
	
func _on_pressed() -> void:
	#return
	if pressed_sfx:
		pressed_sfx.play()
		
	#disabled = true
	#_deselect_all_buttons()
	#set_selected(true)
	
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
	
	if current_state == State.LOCKED:
		return
	
	if focus_enter_sfx:
		focus_enter_sfx.play()

	z_index = 1
	_play_wiggle(orig_scale.x + (orig_scale.x / 5))


func _on_focus_exited() -> void:
	
	if current_state == State.LOCKED:
		return

	if focus_exit_sfx:
		focus_exit_sfx.play()

	z_index = 0
	_play_wiggle(orig_scale.x)


func _play_wiggle(target_scale: float) -> void:
	#return
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

	#interaction_tween.tween_property(self, "rotation_degrees", -2.0, 0.04)
	#interaction_tween.tween_property(self, "rotation_degrees", 2.0, 0.08)
	#interaction_tween.tween_property(self, "rotation_degrees", 0.0, 0.04)
	#
	
func set_selected(selected: bool) -> void:
	if selected:
		outer_ring.modulate = outerRingColour_active
	else:
		outer_ring.modulate = outer_ring_mod_orig


func _deselect_all_buttons() -> void:
	for child in get_parent().get_children():
		if child.has_method("set_selected"):
			child.set_selected(false)


func restart() -> void:
	if tween_available:
		tween_available.kill()

	if interaction_tween:
		interaction_tween.kill()

	scale = orig_scale
	rotation_degrees = 0.0
	z_index = 0
	disabled = false
	$%CashEarned.text = ""

	if get_index() == 0:
		enter_state(State.AVAILABLE)
	else:
		enter_state(State.LOCKED)

func _update_editor_preview() -> void:
	if !is_inside_tree() or !Engine.is_editor_hint():
		return

	if outer_ring == null:
		return

	match current_state:
		State.LOCKED:
			outer_ring.modulate = outerRingColour_default
		State.AVAILABLE:
			outer_ring.modulate = outerRingColour_active
		State.CLEARED, State.PERFECTED:
			outer_ring.modulate = outerRingColour_levelCompleted
