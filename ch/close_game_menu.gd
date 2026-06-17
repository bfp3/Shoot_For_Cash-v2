extends Button

enum UpgradeState {
	LOCKED,
	UNLOCKED,
	PURCHASED
}

@export var base_colour : Color = Color("19191dff") 
@export var border_outline_colour : Color = Color("404047ff")
@export var editable := false
@export var focus_enter_sfx: AudioStreamPlayer
@export var focus_exit_sfx: AudioStreamPlayer
@export var purchase_sfx: AudioStreamPlayer
@export var wiggle_amount := 1.0


@export var state: UpgradeState = UpgradeState.LOCKED
var can_afford := false

var wiggle_tween: Tween


#func _process(delta: float) -> void:
	#
	#if editable:
		#base_colour = base_colour
		#border_outline_colour = border_outline_colour
		#_update_visual_state()
	#else:
		#set_process(false)

func _ready() -> void:
	randomize()

	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP

	mouse_entered.connect(_on_focus_entered)
	mouse_exited.connect(_on_focus_exited)

	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)

	_update_visual_state()



func configure(config: Dictionary) -> void:
	_update_visual_state()


func set_state(new_state: UpgradeState, is_affordable: bool) -> void:
	state = new_state
	can_afford = is_affordable

	disabled = (
		state == UpgradeState.LOCKED
		or state == UpgradeState.PURCHASED
		or not can_afford
	)

	_update_visual_state()





func _on_focus_entered() -> void:
	_update_visual_state()

	# Focus enter sound
	if focus_enter_sfx:
		focus_enter_sfx.play()

	_play_wiggle(wiggle_amount)


func _on_focus_exited() -> void:
	_update_visual_state()

	# Focus exit sound
	if focus_exit_sfx:
		focus_exit_sfx.play()

	_play_wiggle(wiggle_amount, 0.04)


func _play_wiggle(target_scale: float, _scale_dur : float = 0.08) -> void:
	if wiggle_tween:
		wiggle_tween.kill()

	wiggle_tween = create_tween()

	#wiggle_tween.set_trans(Tween.TRANS_SINE)
	wiggle_tween.set_ease(Tween.EASE_OUT)

	wiggle_tween.tween_property(self, "scale", Vector2(target_scale, target_scale), _scale_dur)


func _update_visual_state() -> void:
	if not is_node_ready():
		return

	var base := Color(0.22, 0.23, 0.26, 0.95)
	var border := Color(0.40, 0.42, 0.47, 1.0)

	match state:
		UpgradeState.LOCKED:
			base = base_colour
			border = border_outline_colour

		UpgradeState.UNLOCKED:
			base = Color(0.20, 0.24, 0.30, 0.98) if can_afford else Color(0.26, 0.20, 0.20, 0.95)
			border = Color("738cb3ff") if can_afford else Color(0.58, 0.30, 0.30, 1.0)

		UpgradeState.PURCHASED:
			base = Color(0.15, 0.35, 0.22, 0.98)
			border = Color(0.40, 0.88, 0.52, 1.0)

	var hover_boost := is_hovered() or has_focus()

	var normal_style := _make_style(base, border, 2)
	var hover_style := _make_style(base.lightened(0.10), border.lightened(0.15), 3)
	var pressed_style := _make_style(base.darkened(0.07), border, 3)
	var focus_style := _make_style(base.lightened(0.15), Color(0.95, 0.95, 1.0, 1.0), 3)
	var disabled_style := _make_style(base.darkened(0.20), border.darkened(0.25), 2)

	add_theme_stylebox_override("normal", hover_style if hover_boost else normal_style)
	add_theme_stylebox_override("hover", hover_style)
	add_theme_stylebox_override("pressed", pressed_style)
	add_theme_stylebox_override("focus", focus_style)
	add_theme_stylebox_override("disabled", disabled_style)

	#var text_color := Color(1, 1, 1, 0.95)
#
	#if state == UpgradeState.LOCKED:
		#text_color = Color(0.75, 0.75, 0.75, 0.80)
#
	#elif not can_afford and state == UpgradeState.UNLOCKED:
		#text_color = Color(1.0, 0.85, 0.85, 0.90)
#
	##add_theme_color_override("font_color", text_color)


func _make_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = bg
	style.border_color = border

	style.set_border_width_all(width)
	style.set_corner_radius_all(10)

	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8

	return style


func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed('escape'):
		_on_pressed()
	
	
func _on_pressed() -> void:
	if %QuitMenu.visible:
		%QuitMenu.hide()
	else:
		%QuitMenu.show()
	
	#get_tree().quit()


func _on_close_game_pressed() -> void:
	get_tree().quit()


func _on_cancel_menu_pressed() -> void:
	%QuitMenu.hide()
