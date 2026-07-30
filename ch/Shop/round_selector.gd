@tool
extends TextureButton

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

@export var shop_main_menu: Control

@export var focus_enter_sfx: AudioStreamPlayer
@export var focus_exit_sfx: AudioStreamPlayer
@export var pressed_sfx: AudioStreamPlayer

@onready var orig_scale := scale

var interaction_tween: Tween
var round_manager: RoundManager = null

var all_levels: Array = []

enum State {
	LOCKED,
	AVAILABLE,
	CLEARED,
	PERFECTED
}

@export var current_state: State = State.LOCKED
var old_state: State = State.LOCKED
var tween_available: Tween = null

@onready var icon_control: Control = %Icon_Control
@onready var outer_ring_3: TextureRect = %OuterRing3
@onready var outer_ring: TextureRect = %OuterRing
@onready var outer_ring_2: TextureRect = %OuterRing2
@onready var check_mark: TextureRect = %CheckMark
@onready var round_number: RichTextLabel = $RoundNumber
@onready var cash_earned: RichTextLabel = %CashEarned
@onready var one_hundred_percent_control: Control = %'100_percent'
@onready var one_hundred_percent_label: RichTextLabel = %perfected_label
@onready var arrow_indication: Control = %ArrowIndication

var stored_text := ''

func _ready() -> void:

	round_manager = get_tree().get_first_node_in_group("round_manager")
	all_levels = round_manager.current_rock_sequence
	stored_text = str(get_index() + 1)
	
	round_number.text = stored_text
	
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP

	pressed.connect(_on_pressed)

	mouse_entered.connect(_on_focus_entered)
	mouse_exited.connect(_on_focus_exited)

	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)

	if !has_signal("pressed"):
		pressed.connect(_on_pressed)

	round_manager = get_tree().get_first_node_in_group("round_manager")
	
	outer_ring_mod_orig = outerRingColour_default
	round_number.modulate.a = 0.0
	one_hundred_percent_control.modulate.a = 0.0
	arrow_indication.modulate.a = 0.0
	cash_earned.modulate.a = 0.0
	
	enter_state(current_state)
	_update_editor_preview()


func enter_state(new_state: State) -> void:
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
	outer_ring.modulate = outerRingColour_default
	icon_control.scale = Vector2.ONE / 3


func update_available() -> void:
	disabled = false
	arrow_indication.modulate.a = 1.0
	outer_ring.modulate = outerRingColour_active
	round_number.modulate.a = 1.0
	round_number.text = '[wave]' + stored_text
	outer_ring_2.modulate = Color('940104')
	round_number.modulate = Color("ffffffff")
	#blink_tween()
	icon_control.scale = Vector2.ONE



func update_cleared() -> void:
	#disabled = true
	#check_mark.show()
	#round_number.hide()
	round_number.text = stored_text
	one_hundred_percent_control.modulate.a = 0.0
	arrow_indication.modulate.a = 0.0
	cash_earned.modulate.a = 1.0
	outer_ring.modulate = outerRingColour_levelCompleted
	outer_ring_2.modulate = Color('ebe0d8')
	round_number.modulate = Color("dbc4b2ff")
	

func update_perfected() -> void:
	round_number.text = stored_text
	arrow_indication.modulate.a = 0.0
	
	var round_bonus := int(gl_DataSet.get_value("reward_perfect_round"))
	cash_earned.text = "[i]$" + str(gl_PlayerState.dataset.bonus_cash + round_bonus - gl_PlayerState.dataset.fines)
	cash_earned.modulate.a = 1.0

	one_hundred_percent_control.modulate.a = 1.0
	outer_ring.modulate = outerRingColour_levelCompleted
	outer_ring_2.modulate = Color('ebe0d8')
	round_number.modulate = Color("dbc4b2ff")
	
	
func blink_tween() -> void:
	var dur := 0.2

	if tween_available:
		tween_available.kill()

	tween_available = create_tween()
	tween_available.tween_property(outer_ring, "modulate:a", 0.2, dur)
	tween_available.tween_property(outer_ring, "modulate:a", 1.0, dur)

	await tween_available.finished

	if current_state == State.AVAILABLE:
		blink_tween()


func _on_pressed() -> void:
	if pressed_sfx:
		pressed_sfx.play()

	var sequence_index := get_index()
	round_manager.current_sequence_index = sequence_index

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
	if !OS.is_debug_build():
		return
		
	if current_state == State.LOCKED:
		return

	if focus_enter_sfx:
		focus_enter_sfx.play()

	z_index = 1
	_play_wiggle(orig_scale.x + (orig_scale.x / 5))


func _on_focus_exited() -> void:
	if !OS.is_debug_build():
		return
	
	if current_state == State.LOCKED:
		return

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

	#interaction_tween.tween_property(self, "rotation_degrees", -2.0, 0.04)
	#interaction_tween.tween_property(self, "rotation_degrees", 2.0, 0.08)
	#interaction_tween.tween_property(self, "rotation_degrees", 0.0, 0.04)


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
	cash_earned.text = ""

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
