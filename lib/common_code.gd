extends Node

const SOUND_PATH = ''

var blowing_away_particles := false




func load_pattern_from_file(path: String) -> String:
	var file = FileAccess.open(path, FileAccess.READ)
	if file:
		var content := file.get_as_text().strip_edges()
		return content
	else:
		push_error("Failed to load pattern file at " + path)
		return ""



func set_all_particles_blow_away(direction : Vector3, dur : float) -> void:
	if blowing_away_particles:
		return
	
	var active_smoke : Array = get_tree().get_nodes_in_group("smoke_particles")
		
	blowing_away_particles = true
	var wind_snippet = preload("res://sfx/windSnippet.wav")
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
			if child.duplicate_particles:
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

func play_sound_instance_pitch_adjusted(sound_file : AudioStreamWAV, volume_db : float, pitch_scale : float) -> void:
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
