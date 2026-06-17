extends CanvasLayer

const PISTOL_SFX = preload("res://sfx/Pistol_SFX.wav")
const WIN_SOUND = preload("res://sfx/ES_sound_effects/ES_Music Charge - SFX Producer.wav")
@export var next_scene: String

@export var divisible_amount = 5.0  # Change as needed

@onready var game_loop_manager := get_tree().get_first_node_in_group("game_loop_manager")

@export var bonus_level := false

var player_won_bool := false

#signal player_lost()

func _ready() -> void:
	EventBus.instance.zoom_out_finished.connect(fade_out_finished)

func start_sequence() -> void:
	print_debug('this is being called')
	return
	
	if check_hostage_health():
		player_won()
		game_loop_manager.game_ended = true
	else:
		player_failed()
		game_loop_manager.game_ended = true

func player_won() -> void:
	if player_won_bool:
		return
	player_won_bool = true
	if $"../../Zoom_out_sequence":
		$"../../Zoom_out_sequence".begin_winning_zoom_out_process()
		
	#if %"player-exit-scene":
		#%"player-exit-scene".begin_winning_zoom_out_process()
		
	var player_crosshair : Player_Crosshair = get_tree().get_first_node_in_group("HUD_crosshair")
	player_crosshair.crosshair_fade_out_mode()
	
	stop_player()	
	GameManager.pineapples_missed_this_round = GameManager.pineapples_available_within_level - GameManager.pineapples_hit


	GameManager.update_pineapples()
	#display_score_sheet()

func fade_out_finished() -> void:
	print_debug('this is also being called')
	return
	#await get_tree().create_timer(0.5).timeout
	#BackgroundForTransition.fade_in()
	await get_tree().create_timer(0.05).timeout
	var next_scene = GameManager.next_level_directory()
	get_tree().change_scene_to_file(next_scene)

func check_hostage_health() -> bool:
	var start_sequence = get_tree().get_first_node_in_group("hostage_health_bar_manager")
	if start_sequence:
		if start_sequence.health_remaining > 0:
			return true
		else:
			return false
	else:
		return false
	
	#var start_sequence = get_tree().get_first_node_in_group("Side_panel_of_hostage")
	#if hostage_health_side_panel_info.health_remaining > 0:
		#return true
	#else:
		#return false

func stop_player() -> void:
	return
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
			#get_parent().remove_child(target_launcher)
			#target_launcher.queue_free()
			var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
			tween.tween_property(self, "global_position:y", -10.0, 5.0)


#func all_bombs_hit_floor() -> void:
	#var bomb_container_array = get_tree().get_first_node_in_group("bomb_container_array")
	#
	#while bomb_container_array.get_children().size() > 0:
		#await get_tree().create_timer(0.1).timeout
	#
	## All bombs are gone now, function will return
	#return


func turn_up_the_music() -> void:
	print('DOES NOT EXIST ANYMORE')
	return

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
	tween.tween_property(screen_fade, "modulate", Color('000000aa'), 2.0)  # Fade in over 2 seconds
	await tween.finished

	#screen_fade.queue_free()  # Remove the fade effect after it finishes

	
func player_failed() -> void:
	$"../../Zoom_out_sequence".begin_zoom_out_process()
	return
	#player_lost.emit()
	#return
	
func player_gold_reward() -> void:
	var score_canvas := get_node("ScoreCanvasLayer/ScoreScreen")

	var stats = GlobalsPlayerStats
	var shots_fired = stats.shots_fired
	var time_remaining = stats.total_time_remaining
	var damage = stats.damage_to_cage
	var targets_hit = stats.targets_successfully_destroyed
	

	# 1. Calculate shot multiplier
	var shot_multiplier = 20.0
	for i in range(shots_fired):
		shot_multiplier /= 2.0

	# 2. Calculate bonuses
	var time_bonus = 100.0 - time_remaining  # Lower time = higher bonus
	var damage_bonus = damage * 5.0
	var target_bonus = targets_hit * 10.0

	# 3. Calculate final score
	var total_score = int((shot_multiplier + time_bonus + damage_bonus + target_bonus) / divisible_amount)
	
	# 4. Create labels for display
	var vbox = VBoxContainer.new()
	add_child(vbox)
	vbox.position = get_viewport().size / 2

	await _show_stat_line(vbox, "Shot Multiplier Bonus", int(shot_multiplier))
	await _show_stat_line(vbox, "Time Bonus", int(time_bonus))
	await _show_stat_line(vbox, "Damage Bonus", int(damage_bonus))
	await _show_stat_line(vbox, "Targets Hit Bonus", int(target_bonus))
	await _show_stat_line(vbox, "Gold Earned", total_score)

	# OPTIONAL: Store gold somewhere
	stats.player_gold += total_score


func _show_stat_line(vbox: VBoxContainer, label_text: String, final_value: int) -> void:
	var container = HBoxContainer.new()
	var label = Label.new()
	label.text = label_text + ": "
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var value_label = Label.new()
	value_label.text = "0"
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_child(label)
	container.add_child(value_label)
	vbox.add_child(container)

	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	tween.tween_method(func(val): value_label.text = str(val), 0, final_value, 1.5)
	await tween.finished

	await get_tree().create_timer(0.2).timeout  # small delay before next stat


func display_score_sheet() -> void:
	# Make the mouse visible
	#await player_gold_reward()
	
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
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
	control_node.position = control_node.position - control_node.position / 2 + Vector2(250,0 )
	control_node.z_index = 1001
	canvas_layer.add_child(control_node)  # Attach to CanvasLayer

	# Create a full-screen ColorRect (background)
	var screen_fade = ColorRect.new()
	screen_fade.name = "ScreenFade"
	#screen_fade.color = Color(1, 1, 1, 0.05)  # Semi-transparent black
	screen_fade.color = Color('FFD70000')
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

	# Create "PASS" label
	var label = Label.new()
	label.text = "PASS"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color('FFD700'))
	# Set large font size (80px)
	var font = ThemeDB.fallback_font
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 80)
	vbox.add_child(label)

	# Create Retry Button
	var retry_button = Button.new()
	retry_button.text = "Retry"
	retry_button.add_theme_font_override("font", font)
	retry_button.add_theme_font_size_override("font_size", 40)
	retry_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	retry_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	retry_button.pressed.connect(retry_mission)
	vbox.add_child(retry_button)

	# Create Next Mission Button
	var next_button = Button.new()
	next_button.text = "Next Mission"
	next_button.add_theme_font_override("font", font)
	next_button.add_theme_font_size_override("font_size", 40)
	next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	next_button.pressed.connect(next_mission)
	vbox.add_child(next_button)
	
	control_node.add_to_group('temp_control')
	
	control_node.modulate = Color('FFFFFF00')
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(control_node, "modulate", Color('FFFFFF'), 0.5)  # Fade in over 2 seconds
	await tween.finished
	
# Define the retry function
#func retry_mission() -> void:
	#var control_node = get_tree().get_first_node_in_group('temp_control')
	#
	#var tween = create_tween()
	#tween.tween_property(control_node, "modulate", Color('FFFFFF00'), 0.25)  # Fade in over 2 seconds
	#await CommonCode.play_sound_instance_pitch_adjusted(PISTOL_SFX, -40.0, 3.0)
	#get_tree().reload_current_scene()
	#
	
func retry_mission() -> void:
	#Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
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
	
	

func next_mission() -> void:
	var control_node = get_tree().get_first_node_in_group('temp_control')
	var tween = create_tween()
	tween.tween_property(control_node, "modulate", Color('FFFFFF00'), 0.25)
	await CommonCode.play_sound_instance_pitch_adjusted(PISTOL_SFX, -40.0, 3.0)

	if bonus_level:
		# For retry world, keep same level index but set available pineapples to missed ones
		GameManager.pineapples_available_within_level = GameManager.pineapples_missed_this_round
		get_tree().change_scene_to_file('res://500_sequences/Bonus_Round/Bonus_transition_screen.tscn')
	else:
		# For normal progression, increment level index
		#GameManager.current_level_index += 1
		if GameManager.current_level_index >= GameManager.pineapples_per_level.size():
			GameManager.current_level_index = 0  # Loop back to level 1 if we've completed all levels
			
		if next_scene == null:
			push_error('Push Error: There is no scene to change to')
		else:
			get_tree().change_scene_to_file(next_scene)
