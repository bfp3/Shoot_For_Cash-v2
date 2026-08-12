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
var _was_available := false
var _available_pulse_tween: Tween

@export_group("Available Pulse")
## Shake / punch when the boss button first becomes affordable.
@export var available_pulse_enabled := true
@export_range(0.0, 20.0, 0.1) var available_shake_degrees := 5.0
@export_range(1.0, 1.5, 0.01) var available_scale_punch := 1.12
@export_range(0.1, 1.5, 0.01) var available_pulse_duration := 0.45
@export_range(1, 6, 1) var available_shake_wiggles := 3
## F6 this scene with this on to preview the pulse immediately.
@export var test_play_available_pulse_on_ready := false


func _ready() -> void:
	show_round_count = false
	level_name = "Boss"
	super._ready()
	refresh_boss_state()
	if test_play_available_pulse_on_ready:
		await get_tree().create_timer(0.35).timeout
		play_available_pulse()


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
		current_state = State.COMPLETE
		## Keep the same colours as Available — only swap cost label ↔ CLEAR stamp.
		_apply_available_colours()
		if level_name_label:
			level_name_label.text = "[pulse]" + boss_title_text.to_upper()
		_set_progress_hud_visible(false)
		if animate_clear:
			await play_clear_stamp_ceremony()
		else:
			if round_progress_label:
				round_progress_label.visible = false
				round_progress_label.modulate.a = 1.0
			await _refresh_completion_stamp(false)
		return

	if can_afford:
		var became_available := boss_state != BossState.AVAILABLE and not _was_available
		boss_state = BossState.AVAILABLE
		level_locked = false
		disabled = false
		current_state = State.IN_PROGRESS
		_apply_available_colours()
		if level_name_label:
			level_name_label.text = "[pulse]" + boss_title_text.to_upper()
		_set_progress_hud_visible(false)
		_hide_completion_stamp()
		if round_progress_label:
			round_progress_label.visible = true
			round_progress_label.modulate.a = 1.0
			round_progress_label.text = _format_boss_cost(cost)
		if became_available:
			play_available_pulse()
		_was_available = true
		return

	_was_available = false
	boss_state = BossState.LOCKED
	level_locked = true
	disabled = false ## Still clickable so player can see/refresh the locked message.
	current_state = State.LOCKED
	modulate = Color.WHITE
	if level_name_label:
		level_name_label.text = boss_title_text.to_upper()

	_set_progress_hud_visible(false)
	_hide_completion_stamp()
	if round_progress_label:
		round_progress_label.visible = true
		round_progress_label.modulate.a = 1.0
		## Locked: show unlock cost only (no "earn more" copy).
		round_progress_label.text = _format_boss_cost(cost)


func _apply_available_colours() -> void:
	modulate = Color.WHITE


## Shake + scale punch when the boss fight becomes affordable.
func play_available_pulse() -> void:
	if not available_pulse_enabled:
		return
	if _available_pulse_tween:
		_available_pulse_tween.kill()
	var base_scale: Vector2 = orig_scale if orig_scale != Vector2.ZERO else scale
	var base_rot := rotation_degrees
	var dur := maxf(available_pulse_duration, 0.08)
	var punch := maxf(available_scale_punch, 1.0)
	var shake := available_shake_degrees
	var wiggles := maxi(available_shake_wiggles, 1)
	pivot_offset = size * 0.5
	_available_pulse_tween = create_tween()
	_available_pulse_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_available_pulse_tween.tween_property(self, "scale", base_scale * punch, dur * 0.35)
	var step := (dur * 0.45) / float(wiggles * 2)
	for i in wiggles:
		var dir := 1.0 if (i % 2) == 0 else -1.0
		_available_pulse_tween.tween_property(self, "rotation_degrees", base_rot + shake * dir, step)
		_available_pulse_tween.tween_property(self, "rotation_degrees", base_rot - shake * dir * 0.6, step)
	_available_pulse_tween.tween_property(self, "rotation_degrees", base_rot, dur * 0.1)
	_available_pulse_tween.parallel().tween_property(self, "scale", base_scale, dur * 0.35)




## Show Available look + cost (stamp hidden) before the post-tally clear ceremony.
func prepare_clear_ceremony_visuals() -> void:
	boss_state = BossState.CLEARED
	level_locked = false
	disabled = true
	current_state = State.COMPLETE
	_apply_available_colours()
	

	_set_progress_hud_visible(false)
	_hide_completion_stamp()
	var cost := gl_DataSet.get_boss_unlock_cost(boss_island_index)
	if round_progress_label:
		round_progress_label.visible = true
		round_progress_label.modulate.a = 1.0
		round_progress_label.text = _format_boss_cost(cost)


## Stamp in like the tally card while the cost label fades out.
func play_clear_stamp_ceremony() -> void:
	await _refresh_completion_stamp(true)
	disabled = false


## Boss clear stamp only — never retint panels/textures via `_set_completed_gui`.
func _refresh_completion_stamp(animate: bool) -> void:
	var stamp_root := get_node_or_null("100_percent") as Control
	if stamp_root == null:
		return
	var stamp_label := stamp_root.get_node_or_null("RichTextLabel") as Control
	stamp_root.visible = true
	if stamp_label is RichTextLabel:
		(stamp_label as RichTextLabel).text = "[wave]CLEAR!"
	if not animate:
		stamp_root.modulate.a = 1.0
		if stamp_label:
			stamp_label.scale = Vector2.ONE
		if round_progress_label:
			round_progress_label.visible = false
			round_progress_label.modulate.a = 1.0
		return

	stamp_root.modulate.a = 0.0
	if stamp_label:
		stamp_label.scale = Vector2.ONE * 3.0
	if round_progress_label:
		round_progress_label.visible = true
	var stamp_sfx := $purchase as AudioStreamPlayer
	var tween := create_tween()
	tween.tween_property(stamp_root, "modulate:a", 1.0, 0.2)
	if stamp_label:
		tween.parallel().tween_property(stamp_label, "scale", Vector2.ONE, 0.2)
	if round_progress_label:
		tween.parallel().tween_property(round_progress_label, "modulate:a", 0.0, 0.2)
	if stamp_sfx:
		tween.parallel().tween_callback(stamp_sfx.play.bind(0.05)).set_delay(0.15)
	tween.tween_interval(0.35)
	await tween.finished
	if round_progress_label:
		round_progress_label.visible = false
		round_progress_label.modulate.a = 1.0


func _format_boss_cost(cost: int) -> String:
	return CommonCode.format_money(cost)


func _on_level_button_pressed() -> void:
	
	if boss_state == BossState.CLEARED:
		## Already cleared — still allow re-entry via map select (cash gate inside).
		pass
	elif boss_state == BossState.LOCKED:
		var cost := gl_DataSet.get_boss_unlock_cost(boss_island_index)
		if main_control and main_control.has_method("show_boss_access_holdout"):
			await main_control.show_boss_access_holdout(cost)
		elif round_progress_label:
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



func _on_focus_exited() -> void:
	if focus_exit_sfx:
		focus_exit_sfx.play()
	z_index = 0
	_play_wiggle(orig_scale.x)
