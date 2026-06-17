extends CanvasLayer

const PISTOL_SFX = preload("res://sfx/Pistol_SFX.wav")
const LOSING_WIND_FULL = preload("res://sfx/windFull.WAV")

@export var next_scene: String

var sequence_start := false

var mission_failure_text : Array = [
	"Oops!",
	"Flattened...",
	"Hostage Pancake'd...",
	"Mission: Squashed...",
	"Hostage Cause of Death, Incompetence...",
	"Yikes. That’s Gonna Leave a Mark… Or Not.",
	"Hope nobody saw that...",
	"Will I still be getting paid for this?",
	"Welp… That’s One Less Problem?",
	"Smushed Like a Bug!",
	"Wonder if our insurance will cover that…",
	"Press F for… Failure."
]

func _ready() -> void:
	var hostage_health_bar_manager = get_tree().get_first_node_in_group('hostage_health_bar_manager')
	hostage_health_bar_manager.out_of_health.connect(start_sequence_losing)
	
	#$"../level_completed_sequence".player_lost.connect(start_sequence_losing)

func start_sequence_losing() -> void:
	
	$"../../Zoom_out_sequence".begin_zoom_out_process()
	
	if sequence_start: return
	stop_timer()
	sequence_start = true
	stop_player()
	#stop_targets()
	stop_target_launcher()
	lower_the_music()
	#all_bombs_hit_floor()
	await fade_to_black()
	display_failure_retry()
	

	var tween = create_tween()
	tween.tween_property($TextureRect, "scale", Vector2.ONE / 2, 1.0).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property($TextureRect, "self_modulate", Color('FFFFFF'), 2.0)
	await tween.finished
	
	
func all_bombs_hit_floor() -> void:
	var bomb_container_array = get_tree().get_first_node_in_group("bomb_container_array")
	
	while bomb_container_array.get_children().size() > 0:
		await get_tree().create_timer(0.1).timeout
	
	# All bombs are gone now, function will return
	return

	
func stop_timer() -> void:
	var timer = get_tree().get_first_node_in_group('level_timer')
	if timer:
		timer.stop_timer_lose_condition()


func stop_player() -> void:
	var player = get_tree().get_first_node_in_group('Player')
	if player:
		player.set_process(false)
		player.set_physics_process(false)
		player.set_process_input(false)

func stop_targets() -> void:
	var targets = get_tree().get_nodes_in_group('Moving_target')
	if targets.size() > 0:
		for target in targets:
			target.was_hit_tween()
			target.set_physics_process(false)
		
func stop_target_launcher() -> void:
	var target_launchers = get_tree().get_nodes_in_group('Target_launcher')
	if target_launchers.size() > 0:
		for target_launcher in target_launchers:
			target_launcher.process_mode = Node.PROCESS_MODE_DISABLED
			var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tween.tween_property(target_launcher, "global_position:y", -2.0, 10.0)
			#get_parent().remove_child(target_launcher)
			#target_launcher.queue_free()


func lower_the_music() -> void:
	
	return
	var dur : float = 2.0
	var level_song : AudioStreamPlayer = get_tree().get_first_node_in_group("level_song")
	if level_song:
		#print("found level song")
		var tween = create_tween()
		tween.tween_property(level_song, "volume_db", -40.0, 3.0)
		await tween.finished
		
		#var bus_index = AudioServer.get_bus_index("Master")
		#var current_volume = AudioServer.get_bus_volume_db(bus_index)
		#AudioServer.set_bus_volume_db(bus_index, current_volume - 15.0)
		#level_song.stop()
		
		CommonCode.play_sound_instance_await_time(LOSING_WIND_FULL, 0.0, 0.0, 4.0)
		


func reset_music_volumes() -> void:
	var dur : float = 1.0
	var level_song : AudioStreamPlayer = get_tree().get_first_node_in_group("level_song")
	if level_song:
		var tween = create_tween()
		tween.tween_property(level_song, "volume_db", -30.0, dur)
		await tween.finished
		
		#var bus_index = AudioServer.get_bus_index("Master")
		#var current_volume = AudioServer.get_bus_volume_db(bus_index)
		#AudioServer.set_bus_volume_db(bus_index, current_volume + 15.0)

func fade_to_black() -> void:
	var screen_fade = ColorRect.new()
	screen_fade.name = "ScreenFade"
	screen_fade.modulate = Color('00000000')  # Fully transparent
	screen_fade.size = get_viewport().size  # Full-screen size
	screen_fade.anchor_left = 0
	screen_fade.anchor_top = 0
	screen_fade.anchor_right = 1
	screen_fade.anchor_bottom = 1
	screen_fade.z_index = 1000
	add_child(screen_fade)
	move_child(screen_fade, 0)  # Ensure it's drawn on top

	
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(screen_fade, "modulate", Color('00000080'), 2.0)  # Fade in over 2 seconds
	await tween.finished

func display_failure_retry() -> void:
	# Make the mouse visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Create a CanvasLayer to ensure UI stays on top
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "ScoreCanvasLayer"
	canvas_layer.layer = 10  # Ensure it's rendered on top
	add_child(canvas_layer)

	# Create the main UI container (500x500, centered)
	var control_node = Control.new()
	control_node.name = "ScoreScreen"
	control_node.set_size(Vector2(500, 500))
	control_node.pivot_offset = control_node.size / 2
	control_node.set_position((get_viewport().size / 2))  # Center on screen
	control_node.position = control_node.position - control_node.position / 2 + Vector2(250, 0)
	control_node.z_index = 1001
	canvas_layer.add_child(control_node)  # Attach to CanvasLayer

	# Create a full-screen ColorRect (background)
	var screen_fade = ColorRect.new()
	screen_fade.name = "ScreenFade"
	screen_fade.color = Color(0.5, 0.5, 0.5, 0.5)  # Semi-transparent black
	screen_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control_node.add_child(screen_fade)

	# Create a VBoxContainer to hold UI elements
	var vbox = VBoxContainer.new()
	vbox.anchor_left = 0
	vbox.anchor_top = 0
	vbox.anchor_right = 1
	vbox.anchor_bottom = 1
	vbox.size_flags_horizontal = Control.SIZE_FILL
	vbox.size_flags_vertical = Control.SIZE_FILL
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	control_node.add_child(vbox)

	var failure_label = Label.new()
	failure_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	failure_label.text = mission_failure_text[randi() % mission_failure_text.size()]
	failure_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	failure_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	failure_label.add_theme_color_override("font_color", Color('A0A0A0'))
	
	var word_count = failure_label.text.split(" ").size()
	var font_size = 80
	if word_count > 4:
		font_size = 30
	if word_count > 8:
		font_size = 10
	
	var font = ThemeDB.fallback_font
	failure_label.add_theme_font_override("font", font)
	failure_label.add_theme_font_size_override("font_size", font_size)
	vbox.add_child(failure_label)

	# Create Retry Button
	var retry_button = Button.new()
	retry_button.text = "Retry"
	retry_button.add_theme_font_override("font", font)
	retry_button.add_theme_font_size_override("font_size", 40)
	retry_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	retry_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	retry_button.pressed.connect(retry_mission)
	vbox.add_child(retry_button)
	control_node.add_to_group('temp_control')
	
	control_node.modulate = Color('FFFFFF00')
	retry_button.modulate = Color('FFFFFF00')
	
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(control_node, "modulate", Color('FFFFFF'), 0.5)
	tween.tween_interval(0.2)
	tween.tween_property(retry_button, "modulate", Color('FFFFFF'), 0.5)
	await tween.finished

	
func retry_mission() -> void:
	
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	
	var dur : float = 0.3
	
	var control_node = get_tree().get_first_node_in_group('temp_control')
	#await reset_music_volumes()
	$Smoke_sprite.global_position = get_viewport().size / 2
	$Smoke_sprite.show()
	$Smoke_sprite.play("default")
	CommonCode.play_sound_instance_pitch_adjusted(PISTOL_SFX, -40.0, 3.0)
	var tween = create_tween()
	tween.tween_property(control_node, "scale", control_node.scale * 1.1, 0.15)
	tween.tween_property(control_node, "modulate", Color('FFFFFF00'), dur)  # Fade in over 2 seconds
	tween.parallel().tween_property(control_node, "scale", Vector2.ZERO, dur)
	tween.parallel().tween_property($Smoke_sprite, "modulate", Color('FFFFFF00'), dur).set_delay(0.25)
	#await tween.finished
	await $Smoke_sprite.animation_finished
	hide()
	get_tree().reload_current_scene()
