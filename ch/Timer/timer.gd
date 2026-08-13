extends Control
class_name RoundTimer
@onready var round_manager : RoundManager = get_tree().get_current_scene().get_node_or_null('Round_manager')

enum State {
	INACTIVE,
	RUNNING,
	FINISHED,
	RESTARTING,
	PAUSE_TIMER,
	RESUME_TIMER
}

var current_state : State = State.INACTIVE

var sent_signal := false

@export var timer_disabled := false

@onready var timer_label: RichTextLabel = $TimeLabel
@export var start_time: float = 11.0 #14.0
var time_left: float = 0.0
var additional_increment := 1.0

var _timer_paused := false
var _pause_toggle_locked := false

@export_group("Timer SFX")
@onready var timer_ticking_sfx: AudioStreamPlayer = $TimerTickingSFX
@export var ticking_sfx_max_db := 40.0
@export var ticking_sfx_smooth_speed := 6.0 # higher = faster response


func _ready() -> void:
	if process_mode == Node.PROCESS_MODE_DISABLED:
		return
	
	
	update_text()
	start_time = gl_DataSet.get_value('power_time_upgrade', gl_PlayerState.dataset.power_time_upgrade)
	time_left = start_time

	#EventBus.instance.rock_destroyed.connect(_add_additional_time)
	EventBus.instance.egg_pulsed.connect(start_timer_on_pulse)
	
	fade_out_timer()
	
func _process(delta: float) -> void:
	if timer_disabled:
		return
	
	if current_state != State.RUNNING:
		set_process(false)
		return
	
	time_left -= delta
	update_text()
	
	if time_left <= 0.5:
		sent_signal = true
		EventBus.instance.detonate_sky_mines.emit()
	
	if time_left <= 0.0:
		time_left = 0.0
		ran_out_of_time()
		return

	_update_ticking_volume(time_left, delta)

func ran_out_of_time() -> void:
		
	$TimeRanOut.play()
	$TimeRanOut4.play()
	enter_state(State.FINISHED)
	#timer_label.text = "0:00"

func start_timer_on_pulse() -> void:
	if round_manager == null or not is_instance_valid(round_manager):
		round_manager = get_tree().get_first_node_in_group("round_manager")
	## Regular rounds don't run the countdown HUD — boss only.
	if round_manager and round_manager.has_method("is_boss_mode") and not round_manager.is_boss_mode():
		hide()
		return
	## Boss duration must stick even if rollup raced or used the upgrade timer.
	if round_manager and round_manager.has_method("get_active_timer_seconds"):
		var override_seconds := float(round_manager.get_active_timer_seconds())
		if override_seconds > 0.0:
			start_time = override_seconds
			time_left = override_seconds
			update_text()
	timer_ticking_sfx.volume_db = -80.0
	enter_state(State.RUNNING)

func enter_state(new_state: State) -> void:
	current_state = new_state
	
	match new_state:
		State.INACTIVE:
			update_inactive()
		
		State.RUNNING:
			update_running()
		
		State.FINISHED:
			update_finished()
		
		State.RESTARTING:
			update_restarting()
			
		State.PAUSE_TIMER:
			update_pause_timer()
			
		State.RESUME_TIMER:
			update_resume_timer()
		_:
			print("No State Exists - Timer Script")

func update_inactive() -> void:
	pass

func update_running() -> void:
	set_process(true)
	
	if not timer_ticking_sfx.playing:
		timer_ticking_sfx.play()
		
	timer_ticking_sfx.volume_db = -45.0
	timer_ticking_sfx.pitch_scale = 1.0
	

func update_finished() -> void:
	timer_ticking_sfx.stop()
	$TimeRanOut.play()
	$TimeRanOut2.play()
	update_text()
	update_round_manager()
	update_bonus_times()
	set_process(false)
	enter_state(State.INACTIVE)


func update_bonus_times() -> void:
	var bonus_time_item = get_tree().get_first_node_in_group('bonus_time_item')
	if !bonus_time_item:
		return

	bonus_time_item.time_ran_out()

func update_restarting() -> void:
	if timer_disabled:
		return

	if round_manager == null or not is_instance_valid(round_manager):
		round_manager = get_tree().get_first_node_in_group("round_manager")
		
	show()
	modulate.a = 1.0
	if timer_label:
		timer_label.modulate = Color.WHITE
	sent_signal = false
	var override_seconds := -1.0
	if round_manager and round_manager.has_method("get_active_timer_seconds"):
		override_seconds = float(round_manager.get_active_timer_seconds())
	if override_seconds > 0.0:
		start_time = override_seconds
	else:
		start_time = gl_DataSet.get_value('power_time_upgrade', gl_PlayerState.dataset.power_time_upgrade)
	
	await get_tree().create_timer(0.25, false).timeout
	time_left = start_time
	var _orig_pos : Vector2 = timer_label.position 
	var center_position : Vector2 = $Timer_centerPOS.position - (timer_label.size / 2)
	timer_label.position = center_position
	
	var move_to_center_tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	move_to_center_tween.tween_property(timer_label, "horizontal_alignment", 1, 0.01)
	move_to_center_tween.parallel().tween_property(timer_label, "scale", Vector2.ONE * 3, 0.01)
	await move_to_center_tween.finished
	
	await timer_rollup_sequence()
	$ReloadSound.pitch_scale = 1.0
	await get_tree().create_timer(0.20, false).timeout

	var move_back_tween := create_tween().set_trans(Tween.TRANS_CUBIC) #.set_ease(Tween.EASE_OUT)
	move_back_tween.tween_property($TimeLabel, "position", _orig_pos, 0.15)
	move_back_tween.parallel().tween_property(timer_label, "horizontal_alignment", 1, 0.1).set_delay(0.1)
	move_back_tween.parallel().tween_property(timer_label, "scale", Vector2.ONE, 0.15)
	move_back_tween.parallel().tween_callback($TimeRanOut3.play.bind(0.02)).set_delay(0.14)
	await move_back_tween.finished

func timer_rollup_sequence() -> void:


	timer_label.modulate = Color.WHITE
	var duration := 0.5
	var elapsed := 0.0
	var dt := 1.0 / 60.0

	var start_value := 0.0
	var end_value := start_time

	time_left = start_value
	update_text()

	$ReloadSound.pitch_scale = 1.0
	$ReloadSound.play()
	await get_tree().create_timer(0.1, false).timeout
	while elapsed < duration:

		await get_tree().create_timer(dt, false).timeout

		elapsed += dt

		var t : float = clamp(elapsed / duration, 0.0, 1.0)

		# Ease-out
		var eased := 1.0 - pow(1.0 - t, 3.0)

		time_left = lerp(start_value, end_value, eased)

		update_text()

		$ReloadSound.pitch_scale += 0.1
		$ReloadSound.play()

	time_left = end_value
	update_text()

	



func update_pause_timer() -> void:
	_timer_paused = true
	timer_ticking_sfx.stop()
	await get_tree().create_timer(0.5).timeout
	_pause_toggle_locked = false
	
func update_resume_timer() -> void:
	_timer_paused = false
	timer_ticking_sfx.play()
	enter_state(State.RUNNING)
	await get_tree().create_timer(0.5).timeout
	_pause_toggle_locked = false
	

func stop_timer() -> void:
	enter_state(State.INACTIVE)
	timer_ticking_sfx.stop()
	update_text()
	#display_out_of_time()
	fade_out_timer()
	set_process(false)


func _add_additional_time(additional_time : float = 0.0) -> void:
	#time_left += 5.0
	
	if additional_time > 0.0:
		time_left += additional_time
		await get_tree().create_timer(0.2, false).timeout
		return
	
	var _rand_chance : int  = randi_range(0,2)
	if _rand_chance == 0:
		time_left += additional_increment

		await get_tree().create_timer(0.2, false).timeout



func update_round_manager() -> void:
	if !round_manager:
		return

	round_manager.round_timer_time_out()
	
	
func update_text() -> void:
	timer_label.text = format_time(max(time_left, 0.0))

func format_time(time: float) -> String:
	var seconds := int(time)
	var hundredths := int((time - seconds) * 100.0)

	return "%d:%02d" % [seconds, hundredths]
	
func fade_out_timer() -> void:
	var root: CanvasItem = self
	if root == null:
		return
	var tween := create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "modulate:a", 0.0, 0.45)
	await tween.finished
	hide()
	modulate.a = 1.0

func _update_ticking_volume(seconds_left: float, delta: float) -> void:
	var target_db: float = 0.0
	var target_pitch : float = 0.0
	#if seconds_left > 50.0:
		#target_db = -80.0
		#target_pitch = 0.8
		
	if seconds_left > 10.0:
		target_db = -60.0
		target_pitch = 1.0
	
	
		
	#if seconds_left < 3.0:
		#target_db = -30.0
		#target_pitch = 1.2
	else:
		# 0–10s → ramp from 0 → +15 dB
		var t : float = clamp(1.0 - (seconds_left / 10.0), 0.0, 1.0)
		target_db = lerp(-60.0, ticking_sfx_max_db, t)
		target_pitch = lerp(1.2, 1.5, t)
		
	# Smooth interpolation
	timer_ticking_sfx.volume_db = lerp(
		timer_ticking_sfx.volume_db,
		target_db,
		delta * ticking_sfx_smooth_speed
	)
	timer_ticking_sfx.pitch_scale = lerp(
		timer_ticking_sfx.pitch_scale,
		target_pitch,
		delta * ticking_sfx_smooth_speed
	)


## Boss win: slide timer to center, stamp CLEARED!, confetti, then return control.
func play_boss_cleared_celebration() -> void:
	return
	show()
	modulate.a = 1.0
	set_process(false)
	time_left = 0.0
	if timer_label:
		timer_label.text = "[wave]CLEARED!"
		timer_label.modulate = Color.WHITE

	var rest_pos := position
	var rest_scale := scale
	var viewport_size := get_viewport().get_visible_rect().size
	var target_pos := Vector2(
		(viewport_size.x - size.x * scale.x) * 0.5,
		(viewport_size.y - size.y * scale.y) * 0.35
	)

	var stamp := _ensure_cleared_stamp()
	stamp.visible = true
	stamp.modulate.a = 0.0
	stamp.scale = Vector2.ONE * 3.0

	var confetti := _ensure_cleared_confetti()
	confetti.emitting = false

	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", target_pos, 0.45)
	tween.parallel().tween_property(self, "scale", rest_scale * 1.35, 0.45)
	await tween.finished

	var stamp_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	stamp_tween.tween_property(stamp, "modulate:a", 1.0, 0.2)
	stamp_tween.parallel().tween_property(stamp, "scale", Vector2.ONE, 0.25)
	confetti.restart()
	confetti.emitting = true
	await stamp_tween.finished
	await get_tree().create_timer(1.6, false).timeout

	confetti.emitting = false
	stamp.visible = false
	position = rest_pos
	scale = rest_scale
	if timer_label:
		timer_label.text = format_time(0.0)


func _ensure_cleared_stamp() -> Control:
	var stamp := get_node_or_null("ClearedStamp") as Control
	if stamp:
		return stamp
	stamp = Control.new()
	stamp.name = "ClearedStamp"
	stamp.set_anchors_preset(Control.PRESET_CENTER)
	stamp.size = Vector2(320, 120)
	stamp.position = Vector2(-160, -40)
	stamp.pivot_offset_ratio = Vector2(0.5,0.5)
	stamp.mouse_filter = Control.MOUSE_FILTER_IGNORE

	stamp.z_index = 20
	var label := RichTextLabel.new()
	label.name = "StampLabel"
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.add_theme_font_size_override("normal_font_size", 284)
	label.add_theme_color_override("default_color", Color(0.631, 0.008, 0.016, 1.0))
	label.text = "[wave]100%"
	label.pivot_offset_ratio = Vector2(0.5,0.5)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stamp.add_child(label)
	add_child(stamp)
	return stamp


func _ensure_cleared_confetti() -> CPUParticles2D:
	var confetti := get_node_or_null("ClearedConfetti") as CPUParticles2D
	if confetti:
		return confetti
	confetti = CPUParticles2D.new()
	confetti.name = "ClearedConfetti"
	confetti.z_index = 19
	confetti.position = Vector2(size.x * 0.5, size.y * 0.35)
	confetti.amount = 64
	confetti.lifetime = 1.4
	confetti.one_shot = true
	confetti.explosiveness = 0.92
	confetti.direction = Vector2(0, -1)
	confetti.spread = 180.0
	confetti.initial_velocity_min = 180.0
	confetti.initial_velocity_max = 420.0
	confetti.gravity = Vector2(0, 480)
	confetti.scale_amount_min = 3.0
	confetti.scale_amount_max = 7.0
	confetti.color = Color(0.95, 0.2, 0.15, 1.0)
	
	confetti.emitting = false
	add_child(confetti)
	return confetti




func rollup_without_timer() -> void:
	if timer_disabled:
		return

	if round_manager == null or not is_instance_valid(round_manager):
		round_manager = get_tree().get_first_node_in_group("round_manager")

	## Keep the countdown HUD off — this is SFX-only for regular rounds.
	hide()
	set_process(false)

	await get_tree().create_timer(0.25, false).timeout

	var duration := 0.5
	var elapsed := 0.0
	var dt := 1.0 / 60.0

	$ReloadSound.pitch_scale = 1.0
	$ReloadSound.play()
	await get_tree().create_timer(0.1, false).timeout
	while elapsed < duration:
		await get_tree().create_timer(dt, false).timeout
		elapsed += dt
		$ReloadSound.pitch_scale += 0.1
		$ReloadSound.play()

	$ReloadSound.pitch_scale = 1.0
	await get_tree().create_timer(0.20, false).timeout

	var tween := create_tween().set_trans(Tween.TRANS_CUBIC)
	tween.tween_interval(0.5)
	tween.parallel().tween_callback($TimeRanOut3.play.bind(0.02)).set_delay(0.14)
	await tween.finished
	hide()
