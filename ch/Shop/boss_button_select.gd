extends "res://ch/Shop/level_button_select.gd"
## Dedicated boss map button — locked / available / cleared visuals.

@export var boss_title_text := 'Shootout'

enum BossState {
	LOCKED,
	AVAILABLE,
	CLEARED,
}
@onready var pulse_ring: TextureRect = $PulseRing

@onready var outer_ring: TextureRect = $BadgeOuterRing
@onready var badge_front: TextureRect = $BadgeFront
@export var boss_island_index := 0
var boss_state: BossState = BossState.LOCKED
var _was_available := false
var _idle_wiggle_tween: Tween
var _idle_fx_active := false
var _pulse_ring_accum := 0.0
var _base_rotation_degrees := 0.0
var _pulse_ring_base_scale := Vector2.ONE

@export_group("Available Idle")
## Continuous wiggle + pulse rings while the boss is available.
@export var available_idle_enabled := true
@export_range(0.0, 20.0, 0.1) var available_shake_degrees := 2.5
@export_range(0.05, 1.0, 0.01) var available_wiggle_half_period := 0.18
@export_range(0.5, 10.0, 0.1) var pulse_ring_interval := 3.0
@export var pulse_ring_start_modulate := Color(1, 1, 1, 0.7)
@export_range(1.0, 5.0, 0.05) var pulse_ring_end_scale := 2.4
@export_range(0.3, 4.0, 0.05) var pulse_ring_expand_duration := 1.5
## F6 this scene with this on to preview idle FX immediately.
@export var test_play_available_pulse_on_ready := false


func _ready() -> void:
	show_round_count = false
	level_name = "Boss"
	_base_rotation_degrees = rotation_degrees
	if pulse_ring:
		_pulse_ring_base_scale = pulse_ring.scale if pulse_ring.scale != Vector2.ZERO else Vector2.ONE
		pulse_ring.visible = false
		pulse_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	super._ready()
	refresh_boss_state()
	## Editor-only preview: only pulse if this boss is actually affordable.
	if test_play_available_pulse_on_ready and OS.has_feature("editor"):
		await get_tree().create_timer(0.35).timeout
		refresh_boss_state()


func _process(delta: float) -> void:
	if not _idle_fx_active or not available_idle_enabled:
		return
	_pulse_ring_accum += delta
	if _pulse_ring_accum >= pulse_ring_interval:
		_pulse_ring_accum = 0.0
		_spawn_pulse_ring()


func _on_gui_input(event: InputEvent) -> void:
	## Right-click: force-clear this island's boss (Godot editor builds only).
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if not OS.has_feature("editor"):
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
	var permanently_unlocked := gl_PlayerState.is_boss_unlocked(boss_island_index)
	var cost := gl_DataSet.get_boss_unlock_cost(boss_island_index)
	var cash := int(gl_PlayerState.dataset.cash)
	var can_afford := cash >= cost

	## First time you can afford it → permanent unlock (even if cash drops later).
	if can_afford and not permanently_unlocked:
		gl_PlayerState.mark_boss_unlocked(boss_island_index)
		permanently_unlocked = true

	if cleared:
		_stop_available_idle()
		boss_state = BossState.CLEARED
		level_locked = false
		disabled = false
		current_state = State.COMPLETE
		## Keep the same colours as Available — only swap cost label ↔ CLEAR stamp.
		_apply_available_colours()
		if level_name_label:
			level_name_label.text = "[pulse]" + boss_title_text.to_upper()
		_set_progress_hud_visible(false)
		## Cleared: keep cost label visible alongside the CLEAR stamp.
		if round_progress_label:
			round_progress_label.visible = true
			round_progress_label.modulate.a = 1.0
			round_progress_label.text = _format_boss_cost(cost)
		if animate_clear:
			await play_clear_stamp_ceremony()
		else:
			await _refresh_completion_stamp(false)
		return

	if permanently_unlocked:
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
		_was_available = true
		## Pulse/wiggle only while they currently have the unlock cash.
		if can_afford:
			_start_available_idle()
		else:
			_stop_available_idle()
		return

	_was_available = false
	_stop_available_idle()
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


func _start_available_idle() -> void:
	if not available_idle_enabled or not visible:
		_stop_available_idle()
		return
	if _idle_fx_active:
		return
	_idle_fx_active = true
	_pulse_ring_accum = pulse_ring_interval ## First ring soon after becoming available.
	_start_wiggle_loop()


func _stop_available_idle() -> void:
	_idle_fx_active = false
	_pulse_ring_accum = 0.0
	if _idle_wiggle_tween:
		_idle_wiggle_tween.kill()
		_idle_wiggle_tween = null
	rotation_degrees = _base_rotation_degrees


func _start_wiggle_loop() -> void:
	if _idle_wiggle_tween:
		_idle_wiggle_tween.kill()
	var shake := available_shake_degrees
	var half := maxf(available_wiggle_half_period, 0.05)
	_idle_wiggle_tween = create_tween()
	_idle_wiggle_tween.set_loops()
	_idle_wiggle_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_wiggle_tween.tween_property(self, "rotation_degrees", _base_rotation_degrees + shake, half)
	_idle_wiggle_tween.tween_property(self, "rotation_degrees", _base_rotation_degrees - shake, half * 2.0)
	_idle_wiggle_tween.tween_property(self, "rotation_degrees", _base_rotation_degrees, half)


func _spawn_pulse_ring() -> void:
	if pulse_ring == null or not is_instance_valid(pulse_ring):
		return
	var ring := pulse_ring.duplicate() as TextureRect
	if ring == null:
		return
	add_child(ring)
	## Keep rings under the badge art.
	move_child(ring, 0)
	ring.visible = true
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.modulate = pulse_ring_start_modulate
	ring.scale = _pulse_ring_base_scale
	var end_scale := _pulse_ring_base_scale * maxf(pulse_ring_end_scale, 1.0)
	var end_mod := pulse_ring_start_modulate
	end_mod.a = 0.0
	var dur := maxf(pulse_ring_expand_duration, 0.1)
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "scale", end_scale, dur)
	tween.tween_property(ring, "modulate", end_mod, dur)
	tween.set_parallel(false)
	tween.tween_callback(ring.queue_free)


## Show Available look + cost (stamp hidden) before the post-tally clear ceremony.
func prepare_clear_ceremony_visuals() -> void:
	_stop_available_idle()
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
	_stop_available_idle()
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
	var cost := gl_DataSet.get_boss_unlock_cost(boss_island_index)
	if not animate:
		stamp_root.modulate.a = 1.0
		if stamp_label:
			stamp_label.scale = Vector2.ONE
		if round_progress_label:
			round_progress_label.visible = true
			round_progress_label.modulate.a = 1.0
			round_progress_label.text = _format_boss_cost(cost)
		return

	stamp_root.modulate.a = 0.0
	if stamp_label:
		stamp_label.scale = Vector2.ONE * 3.0
	if round_progress_label:
		round_progress_label.visible = true
		round_progress_label.modulate.a = 1.0
		round_progress_label.text = _format_boss_cost(cost)
	var stamp_sfx := $purchase as AudioStreamPlayer
	var tween := create_tween()
	tween.tween_property(stamp_root, "modulate:a", 1.0, 0.2)
	if stamp_label:
		tween.parallel().tween_property(stamp_label, "scale", Vector2.ONE, 0.2)
	if stamp_sfx:
		tween.parallel().tween_callback(stamp_sfx.play.bind(0.05)).set_delay(0.15)
	tween.tween_interval(0.35)
	await tween.finished
	if round_progress_label:
		round_progress_label.visible = true
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


func _exit_tree() -> void:
	_stop_available_idle()
