extends "res://ch/Shop/level_button_select.gd"
## Dedicated boss map button — locked / available / cleared visuals.

@export var boss_title_text := 'Shootout'

enum BossState {
	LOCKED,
	AVAILABLE,
	CLEARED,
}

@export var boss_island_index := 0
var boss_state: BossState = BossState.LOCKED


func _ready() -> void:
	show_round_count = false
	level_name = "Boss"
	super._ready()
	refresh_boss_state()


func _on_gui_input(event: InputEvent) -> void:
	## Right-click: force-clear this island's boss (editor / debug builds only).
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if not OS.is_debug_build():
			return
		gl_PlayerState.mark_boss_cleared(boss_island_index)
		var next_island := boss_island_index + 1
		if next_island < gl_DataSet.get_island_count():
			var unlocked := int(gl_PlayerState.dataset.get("unlocked_island_index", 0))
			if next_island > unlocked:
				gl_PlayerState.dataset["unlocked_island_index"] = next_island
				gl_PlayerState.save_meta_progress()
		refresh_boss_state(true)
		if main_control and main_control.has_method("notify_level_cleared"):
			main_control.notify_level_cleared()
		accept_event()
		return
	if current_state == State.LOCKED:
		return
	## Left-click handled by Button.pressed → _on_level_button_pressed.


func refresh_map_progress() -> void:
	refresh_boss_state(false)


func refresh_boss_state(animate_clear: bool = false) -> void:
	var cleared := gl_PlayerState.is_boss_cleared(boss_island_index)
	var cost := gl_DataSet.get_boss_unlock_cost(boss_island_index)
	var cash := int(gl_PlayerState.dataset.cash)
	var can_afford := cash >= cost

	if cleared:
		boss_state = BossState.CLEARED
		level_locked = false
		disabled = false
		modulate = Color.WHITE
		current_state = State.COMPLETE
		level_name_label.text = " "
		outer_ring.modulate = Color(1.0, 0.85, 0.35, 1.0)
		$TextureRect2.modulate = Color.WHITE
		_set_progress_hud_visible(false)
		await _refresh_completion_stamp(animate_clear)
		return

	if can_afford:
		boss_state = BossState.AVAILABLE
		level_locked = false
		disabled = false
		modulate = Color.WHITE
		current_state = State.IN_PROGRESS
		level_name_label.text = "[pulse]" + boss_title_text.to_upper()
		outer_ring.modulate = Color(0.95, 0.35, 0.28, 1.0)
		$TextureRect2.modulate = Color.WHITE
		_set_progress_hud_visible(false)
		_hide_completion_stamp()
		if round_progress_label:
			round_progress_label.visible = true
			round_progress_label.text = _format_boss_cost(cost)
		return

	boss_state = BossState.LOCKED
	level_locked = true
	disabled = false ## Still clickable so player can see/refresh the locked message.
	current_state = State.LOCKED
	#modulate = Color(0.75, 0.75, 0.75, 0.85)
	modulate = Color.WHITE
	level_name_label.text = boss_title_text.to_upper()
	outer_ring.modulate = Color("c9a587ff")
	$TextureRect2.modulate = Color('d8c5b7')
	_set_progress_hud_visible(false)
	_hide_completion_stamp()
	if round_progress_label:
		round_progress_label.visible = true
		## Locked: show unlock cost only (no "earn more" copy).
		round_progress_label.text = _format_boss_cost(cost)


func _format_boss_cost(cost: int) -> String:
	return "$%s" % str(cost)


func _on_level_button_pressed() -> void:
	
	if boss_state == BossState.CLEARED:
		## Already cleared — still allow re-entry via map select (cash gate inside).
		pass
	elif boss_state == BossState.LOCKED:
		## Locked messaging is already on this button — no floating popup.
		if round_progress_label:
			var tween := create_tween()
			tween.tween_property(round_progress_label, "modulate", Color(1.0, 0.35, 0.25, 1.0), 0.08)
			tween.tween_property(round_progress_label, "modulate", Color.WHITE, 0.2)
		return

	var progress_bar := $TextureProgressBar as Range
	if progress_bar:
		progress_bar.value = 0.0
	if main_control and main_control.has_method("select_level"):
		await main_control.select_level("boss", progress_bar)
	if progress_bar:
		progress_bar.value = 0.0


func _on_focus_entered() -> void:
	if focus_enter_sfx:
		focus_enter_sfx.play()
	z_index = 1
	_play_wiggle(orig_scale.x + (orig_scale.x / 10))
	locked_fader(true)


func _on_focus_exited() -> void:
	if focus_exit_sfx:
		focus_exit_sfx.play()
	z_index = 0
	_play_wiggle(orig_scale.x)
	locked_fader(false)
	
	
func locked_fader(fade_in : bool = false) -> void:
	if fade_in:
		var tween = create_tween()
		tween.tween_property(%LockPop, "modulate:a", 0.8, 0.1)
		
	else:
		var tween = create_tween()
		tween.tween_property(%LockPop, "modulate:a", 0.0, 0.15)
