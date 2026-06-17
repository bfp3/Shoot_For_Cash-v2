extends Node3D

@onready var player: Player = get_tree().get_first_node_in_group('Player')
@onready var camera_3d := get_tree().get_first_node_in_group('player_cam')

@export var zoom_out_position : Vector3 = Vector3(0, 20, -20)
@export var cam_rotation_x : float = 35.0
@export var dur := 2.5

@export var speed_of_moving := 0.5

var total_pineapples := 0
var camera : Camera3D
var zooming_out_process := false

func _ready() -> void:
	#set_process(false)
	EventBus.instance.pineapple_shot.connect(_remove_pineapple)
	EventBus.instance.pineapple_hit_ground.connect(_remove_pineapple)
	EventBus.instance.pineapple_launched.connect(_add_pineapple)

func bh_Activate(parent : Node3D, behaviour : String) -> void:
	print('reached the end')
	#begin_winning_zoom_out_process()


func begin_zoom_out_process_death() -> void:
	dur = 4.0
	begin_zoom_out_process()
	
func begin_zoom_out_process() -> void:
	player.camera_pan_able = false
	camera_3d.camera_stop_all_shaking = true
	camera_tween(camera_3d)
	$"../GameLoopManager".game_ended = true
	

func _add_pineapple() -> void:
	total_pineapples += 1


func _remove_pineapple() -> void:
	total_pineapples -= 1
	
	if total_pineapples <= 0:
		notify_game_over()

func begin_winning_zoom_out_process() -> void:
	dur = 8.0
	player.camera_pan_able = false
	camera_3d.camera_stop_all_shaking = true
	camera_tween(camera_3d)
	if $"../GameLoopManager":
		$"../GameLoopManager".game_ended = true


func rotation_tween(camera_copy : Camera3D) -> void:
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC) #.set_ease(Tween.EASE_OUT)
	tween.tween_property(camera_copy, "rotation_degrees:z", 1.5, 0.2).as_relative()
	tween.tween_property(camera_copy, "rotation_degrees:z", -1.5, 0.2).as_relative()


#func _process(delta: float) -> void:
	#player.global_position.z -= speed_of_moving * delta

func camera_tween(camera_copy : Camera3D) -> void:
	if zooming_out_process:
		return
		
	zooming_out_process = true
	
	var tween = create_tween()
	tween.tween_property(player, "global_position:z", -1.5, 0.1).as_relative().set_trans(Tween.TRANS_LINEAR) #.set_ease(Tween.EASE_IN_OUT)
	camera = camera_copy
	set_process(true)
	#tween.tween_property(camera_copy, "global_position:z", -8.5, 6.5).as_relative().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	#tween.tween_property(camera_copy, "global_position:z", -2.5, 0.25).as_relative().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	#tween.parallel().tween_property($reload_sound, "playing", true, 0.01)
	#
	#tween.tween_property(camera_copy, "global_position:z", -2.5, 0.3).as_relative().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	#
	#tween.tween_property(camera_copy, "global_position:z", -3.5, 0.35).as_relative().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	#tween.parallel().tween_property($reload_sound, "playing", true, 0.01)
#
	#tween.tween_interval(0.25)
	#tween.tween_property(camera_copy, "global_position", zoom_out_position, dur).as_relative().set_delay(0.15)
	#tween.parallel().tween_property(camera_copy, "rotation_degrees:x", -cam_rotation_x, dur).as_relative().set_delay(0.5)
	
	#tween.parallel().tween_callback(notify_game_over).set_delay(dur - 2.5)
	#tween.parallel().tween_callback(fade_out).set_delay(dur - 2.5)

	await tween.finished



## Side to Side
#tween.tween_property(camera_copy, "global_position:z", -1.5, 0.25).as_relative().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
#tween.parallel().tween_property(camera_copy, "global_position:x", -1.5, 0.25).as_relative().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
#tween.tween_property(camera_copy, "global_position:z", -1.5, 0.3).as_relative().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
#tween.parallel().tween_property(camera_copy, "global_position:x", 3.0, 0.3).as_relative().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
#tween.tween_property(camera_copy, "global_position:z", -2.5, 0.35).as_relative().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
#tween.parallel().tween_property(camera_copy, "global_position:x", -1.5, 0.35).as_relative().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

#func camera_tween(camera_copy : Camera3D) -> void:
#
	#if zooming_out_process:
		#return
	#zooming_out_process = true
	##rotation_tween(camera_copy)
	#
	#var tween = create_tween().set_trans(Tween.TRANS_CUBIC) #.set_ease(Tween.EASE_OUT)
	##tween.tween_property(camera_copy, "global_position", Vector3(0,0.1,-0.1), 0.25).as_relative()
	##tween.tween_property(camera_copy, "global_position", Vector3(0,-0.1,0.1), 0.25).as_relative()
	#
	#tween.tween_property(camera_copy, "global_position:z", -5.0, 1.0).as_relative()
	##tween.tween_property(camera_copy, "rotation_degrees:z", 1.5, 0.1).as_relative()
	##tween.tween_property(camera_copy, "rotation_degrees:z", -1.5, 0.1).as_relative()
	#
	##
	##tween.tween_property(camera_copy, "global_position", Vector3(0,0.1,-0.5), 0.5).as_relative().set_trans(Tween.TRANS_BACK) 
	##tween.tween_property(camera_copy, "global_position", Vector3(0,0.3,0.1), 1.5).as_relative().set_trans(Tween.TRANS_LINEAR)
	##tween.tween_property(camera_copy, "global_position", Vector3(0.0,0.0,1.5), 1.0).as_relative()
	##tween.tween_property(camera_copy, "rotation_degrees:x", -2.5, 0.5).as_relative()
	##tween.tween_interval(0.5)
	#tween.tween_property(camera_copy, "global_position", zoom_out_position, dur).as_relative()
	#tween.parallel().tween_property(camera_copy, "rotation_degrees:x", -cam_rotation_x, dur).as_relative()
	#
	#tween.parallel().tween_callback(notify_game_over).set_delay(dur - 2.0)
	#tween.parallel().tween_callback(fade_out).set_delay(dur - 2.0)
	#await tween.finished
	##notify_game_over()
	##await get_tree().create_timer(2.0).timeout



func fade_out() -> void:
	return
	#$"../TV_hud".tween(200.0, 2.0)
	#$"../TV_hud".crt_brightness_tween(0.0, 1.5)

func notify_game_over() -> void:
	EventBus.instance.wrapping_up_a_level.emit()
	#player.ammo_panel_3d
	var tween = create_tween()
	tween.tween_interval(0.75)
	tween.tween_property(player.ammo_panel_3d, "modulate", Color.TRANSPARENT, 0.25)
	await tween.finished
	await get_tree().create_timer(1.0).timeout
	player.smoke_ending.emitting = true
	await get_tree().create_timer(0.3).timeout
	
	
	#EventBus.instance.zoom_out_finished.emit()
	
#func _input(event: InputEvent) -> void:
	#if Input.is_mouse_button_pressed(MOUSE_BUTTON_MIDDLE):
		#begin_zoom_out_process()
