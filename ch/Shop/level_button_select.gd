extends Button

enum State {
	LOCKED,
	UNLOCKED,
	COMPLETE
}

var current_state : State = State.LOCKED

@export var focus_enter_sfx: AudioStreamPlayer
@export var focus_exit_sfx: AudioStreamPlayer
@export var pressed_sfx: AudioStreamPlayer

var interaction_tween: Tween

@onready var orig_scale := self.scale
@onready var outer_ring: TextureRect = $OuterRing

@onready var level_name_label: RichTextLabel = $level_name_label
@onready var round_progress_label: RichTextLabel = %RoundProgressLabel
#@onready var egg_silhouettes: HBoxContainer = %EggSilhouettes
@onready var cash_earned_label: RichTextLabel = %CashEarnedLabel
@export var level_name := 'Locked'

@export var level_locked := true
@export var main_control : Control

var round_manager : RoundManager = null


func _ready() -> void:

	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP

	pressed.connect(_on_pressed)

	mouse_entered.connect(_on_focus_entered)
	mouse_exited.connect(_on_focus_exited)

	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)

	if level_locked:
		set_locked_visuals()

	else:
		current_state = State.UNLOCKED
		level_name_label.text = "[wave]" + level_name.to_upper()
		#level_name_label.modulate = Color('15181c')
		#level_name_label.add_theme_font_size_override("normal_font_size", 109)
		$HSeparator.scale.x = 1.0
		
		
	self.pressed.connect(_on_level_button_pressed)
	round_manager = get_tree().get_first_node_in_group('round_manager')
	
	if disabled:
		modulate= Color("ababab59")
		level_name_label.modulate = Color("1f1f1fff")

	refresh_map_progress()
	

func set_locked_visuals() -> void:
	current_state = State.LOCKED
	#level_name_label.text = "Locked".to_upper()
	level_name_label.text = ""
	#level_name_label.modulate = Color("dbcfc5ff")
	#level_name_label.add_theme_font_size_override("normal_font_size", 85)
	outer_ring.modulate = Color("c9a587ff")
	$HSeparator.scale.x = 1.13
	$TextureRect2.modulate = Color('d8c5b7')
	current_state = State.LOCKED
	_set_progress_hud_visible(false)


func set_unlocked_visuals() -> void:
	level_locked = false
	current_state = State.UNLOCKED
	level_name_label.text = "[wave]" + level_name.to_upper()
	#level_name_label.modulate = Color.WHITE
	#level_name_label.add_theme_font_size_override("normal_font_size", 109)
	outer_ring.modulate = Color.WHITE
	$HSeparator.scale.x = 1.0
	$TextureRect2.modulate = Color.WHITE
	disabled = false
	modulate = Color.WHITE
	_set_progress_hud_visible(true)
	refresh_map_progress()
	_refresh_completion_stamp(false)


## Round counter, cash earned on this island, and uncollected egg silhouettes.
func refresh_map_progress() -> void:
	if level_locked or current_state == State.LOCKED:
		_set_progress_hud_visible(false)
		return
	_set_progress_hud_visible(true)
	var total := int(gl_DataSet.get_value("map_rounds_per_island", 0))
	if total <= 0:
		total = 12
	# Placeholder until per-island round tracking drives the numerator.
	var current_round := 1
	if round_progress_label:
		#round_progress_label.text = "%d/%d" % [current_round, total]
		round_progress_label.text = str(current_round).pad_zeros(2)
	var place := gl_DataSet.resolve_place_name(String(level_name).to_lower())

	# Eggs stay blacked-out silhouettes until collection is wired up.


func _set_progress_hud_visible(is_visible: bool) -> void:
	if round_progress_label:
		round_progress_label.visible = is_visible
	#if egg_silhouettes:
		#egg_silhouettes.visible = is_visible
	if cash_earned_label:
		cash_earned_label.visible = is_visible


func mark_completed(animate: bool = true) -> void:
	current_state = State.COMPLETE
	level_locked = false
	await _refresh_completion_stamp(animate)


func _refresh_completion_stamp(animate: bool) -> void:
	var stamp_root := get_node_or_null("100_percent") as Control
	if stamp_root == null:
		return
	var stamp_label := stamp_root.get_node_or_null("RichTextLabel") as Control
	var place := gl_DataSet.resolve_place_name(String(level_name).to_lower())
	var completed := gl_PlayerState.is_place_completed(place) or current_state == State.COMPLETE
	if not completed:
		stamp_root.visible = false
		stamp_root.modulate.a = 0.0
		return

	current_state = State.COMPLETE
	stamp_root.visible = true
	if not animate:
		stamp_root.modulate.a = 1.0
		if stamp_label:
			stamp_label.scale = Vector2.ONE
		return

	stamp_root.modulate.a = 0.0
	if stamp_label:
		stamp_label.scale = Vector2.ONE * 3.0
	var stamp_sfx := get_node_or_null("purchase") as AudioStreamPlayer
	var tween := create_tween()
	tween.tween_property(stamp_root, "modulate:a", 1.0, 0.2)
	if stamp_label:
		tween.parallel().tween_property(stamp_label, "scale", Vector2.ONE, 0.2)
	if stamp_sfx:
		tween.parallel().tween_callback(stamp_sfx.play.bind(0.05)).set_delay(0.15)
	tween.tween_interval(0.35)
	await tween.finished


func _on_level_button_pressed() -> void:
	if level_locked:
		return

	await fill_progress_bar()
	
	await get_tree().create_timer(0.6, false).timeout
	
	var level_name_lower_case: String = level_name.to_lower()
	if main_control and main_control.has_method('select_level'):
		await main_control.select_level(level_name_lower_case)
	elif round_manager:
		# Fallback if map popup wiring is missing.
		var place := gl_DataSet.resolve_place_name(level_name_lower_case)
		if gl_DataSet.has_place(place) and place != gl_DataSet.get_start_place_name():
			round_manager.travel_to_level(place)
		else:
			print('other button pressed: ', level_name_lower_case)
	
	await get_tree().create_timer(0.3, false).timeout
	$TextureProgressBar.value = 0.0

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

	tween.tween_property($TextureProgressBar, "value", 100.0, 0.15)
#
	#tween.tween_interval(0.15)
	await tween.finished
	
	
	
func _on_focus_entered() -> void:
	if current_state == State.LOCKED:
		return
	
	if focus_enter_sfx:
		focus_enter_sfx.play()

	z_index = 1
	_play_wiggle(orig_scale.x + (orig_scale.x / 10))


func _on_focus_exited() -> void:
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
