extends Control
class_name RoundTimer
@onready var round_manager : RoundManager = get_tree().get_current_scene().get_node_or_null('Round_manager')

# If needed this is the TimeLabel Self Modulate #ffffff63

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
## True while balloon-check has this clock held. Resume only pops that latch.
var _checkpoint_timer_latched := false
## Endless mode: count up from 0 instead of counting down.
var count_up := false
## Last count-up elapsed, kept after stop so tally can still read it.
var _last_count_up_elapsed := 0.0

@export_group("Timer SFX")
@onready var timer_ticking_sfx: AudioStreamPlayer = $TimerTickingSFX
@export var ticking_sfx_max_db := 40.0
@export var ticking_sfx_smooth_speed := 6.0 # higher = faster response

@export_group("Crosshair Fade")
## Fade the timer when the crosshair gets near the clock label so it stays out of the way.
@export var crosshair_fade_enabled := true
## Fully faded alpha while the reticle is overlapping / very close to the timer.
@export_range(0.0, 1.0, 0.05) var crosshair_fade_min_alpha := 0.2
## Distance (px) from the timer label where fade begins.
@export var crosshair_fade_start_px := 140.0
## Distance (px) at / below which alpha is fully at `crosshair_fade_min_alpha`.
@export var crosshair_fade_full_px := 20.0
@export var crosshair_fade_speed := 10.0

var _base_modulate_a := 1.0
var _suppress_crosshair_fade := false
var _crosshair_fade_a := 1.0


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
	if visible and crosshair_fade_enabled and not _suppress_crosshair_fade:
		_update_crosshair_proximity_fade(delta)

	if timer_disabled:
		return
	
	if current_state != State.RUNNING:
		return

	if count_up:
		time_left += delta
		_last_count_up_elapsed = time_left
		update_text()
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
	## Endless: count-up survival clock.
	if round_manager and round_manager.has_method("is_endless_mode") and round_manager.is_endless_mode():
		start_count_up()
		return
	## Regular rounds don't run the countdown HUD — hold-out / boss only.
	if round_manager and round_manager.has_method("get_active_timer_seconds"):
		if float(round_manager.get_active_timer_seconds()) <= 0.0:
			hide()
			return
	## Boss duration must stick even if rollup raced or used the upgrade timer.
	count_up = false
	if round_manager and round_manager.has_method("get_active_timer_seconds"):
		var override_seconds := float(round_manager.get_active_timer_seconds())
		if override_seconds > 0.0:
			start_time = override_seconds
			time_left = override_seconds
			update_text()
	timer_ticking_sfx.volume_db = -80.0
	enter_state(State.RUNNING)


func start_count_up() -> void:
	## Don't reset if already counting (wave start + egg pulse both may call).
	if count_up and current_state == State.RUNNING:
		show()
		return
	count_up = true
	time_left = 0.0
	start_time = 0.0
	_last_count_up_elapsed = 0.0
	sent_signal = false
	show()
	_base_modulate_a = 1.0
	_crosshair_fade_a = 1.0
	modulate.a = 1.0
	if timer_label:
		timer_label.modulate = Color.WHITE
	update_text()
	if timer_ticking_sfx:
		timer_ticking_sfx.volume_db = -80.0
	enter_state(State.RUNNING)


func get_elapsed_seconds() -> float:
	if count_up:
		return maxf(time_left, _last_count_up_elapsed)
	if _last_count_up_elapsed > 0.0:
		return _last_count_up_elapsed
	return maxf(start_time - time_left, 0.0)

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
	_base_modulate_a = 1.0
	_crosshair_fade_a = 1.0
	modulate.a = 1.0
	if timer_label:
		timer_label.modulate = Color.WHITE
	sent_signal = false
	count_up = false
	set_process(true)
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
	set_process(false)
	await get_tree().create_timer(0.5).timeout
	_pause_toggle_locked = false
	
func update_resume_timer() -> void:
	_timer_paused = false
	timer_ticking_sfx.play()
	enter_state(State.RUNNING)
	await get_tree().create_timer(0.5).timeout
	_pause_toggle_locked = false


## Hold the running clock while balloon-check is in the sky.
func latch_timer() -> void:
	if _checkpoint_timer_latched:
		return
	if current_state != State.RUNNING:
		return
	_checkpoint_timer_latched = true
	enter_state(State.PAUSE_TIMER)


## Resume after balloon-check is popped (or dismissed). No-op if we didn't latch.
func unlatch_timer() -> void:
	if not _checkpoint_timer_latched:
		return
	_checkpoint_timer_latched = false
	if current_state != State.PAUSE_TIMER:
		return
	var rm = get_tree().get_first_node_in_group("round_manager")
	if rm:
		if bool(rm.get("_continue_open")):
			return
		var st = rm.get("current_state")
		if st != null and (st == rm.RoundState.PAUSE or st == rm.RoundState.CONTINUE):
			return
	enter_state(State.RESUME_TIMER)
	

func stop_timer() -> void:
	_checkpoint_timer_latched = false
	if count_up:
		_last_count_up_elapsed = maxf(_last_count_up_elapsed, time_left)
	enter_state(State.INACTIVE)
	count_up = false
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

	return "%d[font_size=44]%02d[/font_size]" % [seconds, hundredths]
	
func fade_out_timer() -> void:
	var root: CanvasItem = self
	if root == null:
		return
	_suppress_crosshair_fade = true
	var tween := create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "modulate:a", 0.0, 0.45)
	await tween.finished
	hide()
	modulate.a = 1.0
	_crosshair_fade_a = 1.0
	_suppress_crosshair_fade = false
	set_process(false)


func _update_crosshair_proximity_fade(delta: float) -> void:
	var target_a := _base_modulate_a
	var player := get_tree().get_first_node_in_group("Player")
	if player != null and is_instance_valid(player):
		var aim := Vector2(-99999, -99999)
		if "crosshair" in player and player.crosshair is Control:
			var ch: Control = player.crosshair
			aim = ch.global_position
			if "CROSSHAIR_CENTER_OFFSET" in player:
				aim += player.CROSSHAIR_CENTER_OFFSET
			else:
				aim += Vector2(20.0, 20.0)

		var timer_rect := _timer_screen_rect()
		## Grow the rect by the live reticle radius so "close" matches aim feel.
		var pad := 40.0
		if player.has_method("get_current_crosshair_hit_radius"):
			pad = float(player.get_current_crosshair_hit_radius())
		timer_rect = timer_rect.grow(pad * 0.35)

		var dist := _distance_point_to_rect(aim, timer_rect)
		var start_d := maxf(crosshair_fade_start_px, crosshair_fade_full_px + 1.0)
		var full_d := crosshair_fade_full_px
		if dist <= full_d:
			target_a = crosshair_fade_min_alpha
		elif dist < start_d:
			var t := (dist - full_d) / (start_d - full_d)
			target_a = lerpf(crosshair_fade_min_alpha, _base_modulate_a, t)

	_crosshair_fade_a = move_toward(_crosshair_fade_a, target_a, crosshair_fade_speed * delta)
	modulate.a = _crosshair_fade_a


func _timer_screen_rect() -> Rect2:
	if timer_label and is_instance_valid(timer_label):
		return timer_label.get_global_rect()
	return get_global_rect()


func _distance_point_to_rect(point: Vector2, rect: Rect2) -> float:
	var closest := Vector2(
		clampf(point.x, rect.position.x, rect.position.x + rect.size.x),
		clampf(point.y, rect.position.y, rect.position.y + rect.size.y)
	)
	return point.distance_to(closest)


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
