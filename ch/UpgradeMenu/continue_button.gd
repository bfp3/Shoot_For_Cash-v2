extends Button

enum UpgradeState {
	LOCKED,
	UNLOCKED,
	PURCHASED
}

#@export var base_colour : Color = Color("19191dff") 
#@export var border_outline_colour : Color = Color("404047ff")
@export var focus_enter_sfx: AudioStreamPlayer
@export var focus_exit_sfx: AudioStreamPlayer
@export var purchase_sfx: AudioStreamPlayer
@export var wiggle_amount := 1.0
@export var wiggle_amount_exit := 1.0
@export var custom_pivot_offset_ratio := Vector2(0.5,0.5)
@export var using_customer_pivot_offset := false
@export var state: UpgradeState = UpgradeState.LOCKED
var can_afford := false

var wiggle_tween: Tween



func _ready() -> void:
	randomize()

	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP

	mouse_entered.connect(_on_focus_entered)
	mouse_exited.connect(_on_focus_exited)

	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	
	if using_customer_pivot_offset:
		pivot_offset_ratio = custom_pivot_offset_ratio



func set_state(new_state: UpgradeState, is_affordable: bool) -> void:
	state = new_state
	can_afford = is_affordable

	disabled = (
		state == UpgradeState.LOCKED
		or state == UpgradeState.PURCHASED
		or not can_afford
	)





func _on_focus_entered() -> void:
	if !is_inside_tree():
		return
		
	if disabled:
		return
	# Focus enter sound
	if focus_enter_sfx:
		focus_enter_sfx.play()

	_play_wiggle(wiggle_amount)


func _on_focus_exited() -> void:
	if !is_inside_tree():
		return
	if disabled:
		return
		
	# Focus exit sound
	if focus_exit_sfx:
		focus_exit_sfx.play()

	_play_wiggle(wiggle_amount_exit, 0.04)


func _play_wiggle(target_scale: float, _scale_dur : float = 0.08) -> void:
	if wiggle_tween:
		wiggle_tween.kill()

	wiggle_tween = create_tween()

	#wiggle_tween.set_trans(Tween.TRANS_SINE)
	wiggle_tween.set_ease(Tween.EASE_OUT)

	wiggle_tween.tween_property(self, "scale", Vector2(target_scale, target_scale), _scale_dur)



func _make_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	#style.bg_color = bg
	#style.border_color = border

	style.set_border_width_all(width)
	style.set_corner_radius_all(10)

	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8

	return style
