extends Node

const SOUND_PATH = ''
## Master bus effect indices matching default_bus_layout.tres (HighPass, Reverb, Chorus).
const MASTER_BUS_IDX_HIGHPASS := 0
const MASTER_BUS_IDX_REVERB := 1
const MASTER_BUS_IDX_CHORUS := 2
const MASTER_BUS_RETRO_FX_COUNT := 3
## High-pass cutoff that is effectively transparent (used at fade start/end).
const RETRO_HIGHPASS_OFF_HZ := 20.0

# --- Retro Master-bus FX tuning (edit these) --------------------------------
## Seconds to blend into retro when enabling.
var retro_fade_in_sec := 0.85
## Seconds to blend back to normal when disabling.
var retro_fade_out_sec := 0.7
## Master bus volume while retro is fully on (absolute dB). Leave as default layout value if unsure.
var retro_master_volume_db := 6.02
## Master bus volume while retro is fully off (normal gameplay).
## Prefer the player's Master Volume setting so 100% stays at the project baseline.
var retro_normal_master_volume_db := 6.02
## High-pass cutoff when fully retro (Hz). Higher = thinner / more "radio".
var retro_highpass_cutoff_hz := 720.0
var retro_highpass_resonance := 0.55
## Reverb mix when fully retro (0–1).
var retro_reverb_wet := 0.18
var retro_reverb_dry := 0.82
## Chorus mix when fully retro (0–1).
var retro_chorus_wet := 0.12
var retro_chorus_dry := 0.9
# ---------------------------------------------------------------------------

var blowing_away_particles := false
var _master_retro_fx_enabled := false
var _retro_fade_tween: Tween
## 0 = normal gameplay, 1 = full retro.
var _retro_blend := 0.0


func _normal_master_volume_db() -> float:
	if GameSettings and GameSettings.has_method("effective_master_volume_db"):
		return GameSettings.effective_master_volume_db()
	return retro_normal_master_volume_db


func load_pattern_from_file(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var content := file.get_as_text().strip_edges()
		return content
	else:
		push_error("Failed to load pattern file at " + path)
		return ""


## Smoothly enable/disable Master-bus retro FX (high-pass + reverb + chorus + volume).
## Call `CommonCode.set_master_bus_retro_fx(true)` / `false`.
## Optional `fade_sec` overrides `retro_fade_in_sec` / `retro_fade_out_sec` for that call.
## Tune blend speed and loudness via the `retro_*` vars at the top of this script.
func set_master_bus_retro_fx(enabled: bool, fade_sec: float = -1.0) -> void:
	_master_retro_fx_enabled = enabled
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx < 0:
		push_warning("CommonCode.set_master_bus_retro_fx: Master bus not found")
		return
	if AudioServer.get_bus_effect_count(master_idx) < MASTER_BUS_RETRO_FX_COUNT:
		push_warning("CommonCode.set_master_bus_retro_fx: Master bus missing retro FX slots")
		return

	var target_blend := 1.0 if enabled else 0.0
	var dur := fade_sec
	if dur < 0.0:
		dur = retro_fade_in_sec if enabled else retro_fade_out_sec
	dur = maxf(dur, 0.0)

	if enabled:
		_ensure_retro_effects_enabled(master_idx, true)

	if _retro_fade_tween and _retro_fade_tween.is_valid():
		_retro_fade_tween.kill()

	if dur <= 0.001:
		_retro_blend = target_blend
		_apply_retro_blend(_retro_blend, master_idx)
		if not enabled:
			_ensure_retro_effects_enabled(master_idx, false)
		return

	_retro_fade_tween = create_tween()
	_retro_fade_tween.set_trans(Tween.TRANS_SINE)
	_retro_fade_tween.set_ease(Tween.EASE_IN_OUT if enabled else Tween.EASE_IN)
	_retro_fade_tween.tween_method(
		func(blend: float) -> void:
			_retro_blend = blend
			_apply_retro_blend(blend, master_idx),
		_retro_blend,
		target_blend,
		dur
	)
	if not enabled:
		_retro_fade_tween.tween_callback(_ensure_retro_effects_enabled.bind(master_idx, false))


func is_master_bus_retro_fx_enabled() -> bool:
	return _master_retro_fx_enabled


func _ensure_retro_effects_enabled(master_idx: int, enabled: bool) -> void:
	for i in range(MASTER_BUS_RETRO_FX_COUNT):
		AudioServer.set_bus_effect_enabled(master_idx, i, enabled)


func _apply_retro_blend(blend: float, master_idx: int = -1) -> void:
	return
	if master_idx < 0:
		master_idx = AudioServer.get_bus_index("Master")
	if master_idx < 0:
		return

	var t := clampf(blend, 0.0, 1.0)
	AudioServer.set_bus_volume_db(
		master_idx,
		lerpf(_normal_master_volume_db(), retro_master_volume_db, t)
	)

	var highpass := AudioServer.get_bus_effect(master_idx, MASTER_BUS_IDX_HIGHPASS) as AudioEffectHighPassFilter
	if highpass:
		highpass.cutoff_hz = lerpf(RETRO_HIGHPASS_OFF_HZ, retro_highpass_cutoff_hz, t)
		highpass.resonance = lerpf(0.5, retro_highpass_resonance, t)

	var reverb := AudioServer.get_bus_effect(master_idx, MASTER_BUS_IDX_REVERB) as AudioEffectReverb
	if reverb:
		reverb.wet = lerpf(0.0, retro_reverb_wet, t)
		reverb.dry = lerpf(1.0, retro_reverb_dry, t)

	var chorus := AudioServer.get_bus_effect(master_idx, MASTER_BUS_IDX_CHORUS) as AudioEffectChorus
	if chorus:
		chorus.wet = lerpf(0.0, retro_chorus_wet, t)
		chorus.dry = lerpf(1.0, retro_chorus_dry, t)



func set_all_particles_blow_away(direction : Vector3, dur : float) -> void:
	if blowing_away_particles:
		return
	
	var active_smoke : Array = get_tree().get_nodes_in_group("smoke_particles")
		
	blowing_away_particles = true
	var wind_snippet = preload("res://sfx/windSnippet.ogg")
	CommonCode.play_sound_instance_pitch_adjusted(wind_snippet, -10.0, 0.0)
	#CommonCode.set_all_particles_transparency(1.0, 1.0, 5.0)
	for child in active_smoke:
		if child is GPUParticles3D:
			var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(child, "global_position", direction, dur).as_relative()
			tween.parallel().tween_property(child, "transparency", 1.0, dur / 2)
	
	await get_tree().create_timer(dur).timeout
			#tween.tween_callback(child.queue_free)
	blowing_away_particles = false
	for child in active_smoke:
		if is_instance_valid(child):
			child.transparency = 0.0
			if child.get("duplicate_particles"):
				child.queue_free()


## Blow smoke particles within `radius` of `origin` outward (away from the blast).
## Use for orange / AOE blasts: radius = blast radius + buffer.
func blow_nearby_smoke_particles(
	origin: Vector3,
	radius: float,
	strength: float = 6.0,
	dur: float = 1.25
) -> void:
	if blowing_away_particles:
		return

	var active_smoke: Array = []
	for child in get_tree().get_nodes_in_group("smoke_particles"):
		if child is GPUParticles3D and is_instance_valid(child):
			if child.global_position.distance_to(origin) <= radius:
				active_smoke.append(child)

	if active_smoke.is_empty():
		return

	blowing_away_particles = true
	var wind_snippet = preload("res://sfx/windSnippet.ogg")
	CommonCode.play_sound_instance_pitch_adjusted(wind_snippet, -12.0, 0.05)

	for child in active_smoke:
		if not (child is GPUParticles3D):
			continue
		var away: Vector3 = child.global_position - origin
		if away.length_squared() < 0.0001:
			away = Vector3(randf_range(-1.0, 1.0), 0.35, randf_range(-1.0, 1.0))
		away = away.normalized() * strength
		away.y = maxf(away.y, strength * 0.25)
		var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(child, "global_position", away, dur).as_relative()
		tween.parallel().tween_property(child, "transparency", 1.0, dur * 0.55)

	await get_tree().create_timer(dur).timeout
	blowing_away_particles = false
	for child in active_smoke:
		if is_instance_valid(child):
			child.transparency = 0.0
			if child.get("duplicate_particles"):
				child.queue_free()
	
	
func set_all_particles_transparency(transparency: float, dur : float, delay_duration: float) -> void:
	
	for child in get_tree().get_nodes_in_group("smoke_particles"):
		if child is GPUParticles3D:
			var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(child, "transparency", transparency, dur)
	
func set_all_particles_speed_temporarily(new_speed: float, dur : float, delay_duration: float) -> void:
	var original_speeds := {}
	
	for child in get_tree().get_nodes_in_group("smoke_particles"):
		if child is GPUParticles3D:
			original_speeds[child] = child.speed_scale
			var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			tween.tween_property(child, "speed_scale", new_speed, dur)

	await get_tree().create_timer(delay_duration).timeout

	for child in original_speeds.keys():
		if is_instance_valid(child):
			var original_speed = original_speeds[child]
			var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			tween.tween_property(child, "speed_scale", original_speed, dur)

	
# TWEENS
func standard_tween() -> void:
	var dur : float = 2.0
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "volume_db", -80.0, dur)
	await tween.finished

func spawn_particles(PARTICLES : PackedScene, lifetime : float, pos : Vector3, mention_duplicate : bool) -> void:
	var particles = PARTICLES.instantiate()
	get_tree().get_current_scene().add_child(particles)
	particles.global_position = pos
	particles.lifetime = lifetime
	particles.emitting = true
	if mention_duplicate:
		particles.duplicate_particles = true
	else:
		pass

func creating_sound_instance() -> void:
	var sound_instance = AudioStreamPlayer.new()
	add_child(sound_instance)
	sound_instance.stream = SOUND_PATH
	sound_instance.volume_db = -25.0
	sound_instance.play()
	await sound_instance.finished
	
	# Remove Sounds Safely
	if sound_instance != null:
		remove_child(sound_instance)
		sound_instance.queue_free()
		

func play_sound_duplicate_instance(node: Node, stream_start_point : float, volume_db : float) -> void:
	var sound_duplicate_instance = node.duplicate()
	add_child(sound_duplicate_instance)
	sound_duplicate_instance.volume_db = volume_db
	sound_duplicate_instance.play(stream_start_point)
	await sound_duplicate_instance.finished
	
	# Remove Sounds Safely
	if sound_duplicate_instance != null:
		remove_child(sound_duplicate_instance)
		sound_duplicate_instance.queue_free()


func play_sound_instance(sound_file : AudioStreamWAV, volume_db : float) -> void:
	var sound_instance = AudioStreamPlayer.new()
	add_child(sound_instance)
	sound_instance.stream = sound_file
	sound_instance.volume_db = volume_db
	sound_instance.play()
	await sound_instance.finished
	
	# Remove Sounds Safely
	if sound_instance != null:
		remove_child(sound_instance)
		sound_instance.queue_free()


func play_sound_instance_await_time(sound_file : AudioStreamWAV, volume_db : float, start_time : float, wait_time : float) -> void:
	var sound_instance = AudioStreamPlayer.new()
	add_child(sound_instance)
	sound_instance.stream = sound_file
	sound_instance.volume_db = volume_db
	sound_instance.play(start_time)
	await get_tree().create_timer(wait_time).timeout
	
	# Remove Sounds Safely
	if sound_instance != null:
		remove_child(sound_instance)
		sound_instance.queue_free()
		
func play_sound_instance_delay_time(sound_file : AudioStreamWAV, volume_db : float, start_time : float, wait_time : float) -> void:
	var sound_instance = AudioStreamPlayer.new()
	add_child(sound_instance)
	sound_instance.stream = sound_file
	sound_instance.volume_db = volume_db
	await get_tree().create_timer(wait_time).timeout
	sound_instance.play(start_time)
	await sound_instance.finished
	# Remove Sounds Safely
	if sound_instance != null:
		remove_child(sound_instance)
		sound_instance.queue_free()

func play_sound_instance_pitch_adjusted(sound_file : AudioStream, volume_db : float, pitch_scale : float = 0.02) -> void:
	var sound_instance = AudioStreamPlayer.new()
	sound_instance.name = str(sound_file)
	add_child(sound_instance)
	sound_instance.stream = sound_file
	sound_instance.volume_db = volume_db
	sound_instance.pitch_scale = pitch_scale
	sound_instance.play()
	await sound_instance.finished
	
	# Remove Sounds Safely
	if sound_instance != null:
		remove_child(sound_instance)
		sound_instance.queue_free()

#func lower_the_music() -> void:
	#var _dur : float = 2.0
	#var level_song : AudioStreamPlayer = get_tree().get_first_node_in_group("")
	#if level_song:
		#var tween = create_tween()
		#tween.tween_property(level_song, "volume_db", -80.0, 2.0)
		#await tween.finished
		#level_song.stop()

func add_instance_to_get_tree(instance_scene : PackedScene, pos : Vector3) -> void:
	var new_instance = instance_scene.instantiate()
	get_tree().get_current_scene().add_child(new_instance)
	new_instance.global_position = pos


#func _process(delta: float) -> void:
	#




func bird_fly_by() -> void:

	var birds = get_tree().get_first_node_in_group('fly_by_birds')
	if birds:
		birds.bird_fly_by()
	await get_tree().create_timer(0.25).timeout
	CommonCode.set_all_particles_blow_away(Vector3(0.0, 1.0, 5.0), 5.0)
