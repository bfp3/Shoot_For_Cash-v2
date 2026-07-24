extends Control

# Level 2 color palet was 
#FRONT PANEL = #441905
#INNER PANEL = #210c00

# Level 3 color palet was = Same colours
#FRONT PANEL = #05244f
#INNER PANEL = #05244f

# Level 4 color palet was = Same colours
#FRONT PANEL = #450001
#INNER PANEL = #380001

@export var mirror_enabled := true
@onready var visual_component: Control = $visual_component

@onready var bullets_remaining_label: Label = $Remaining_bullets_label
@onready var current_ammo_label: Label = $Loaded_bullets_label
@onready var ammo_container: HBoxContainer = $Bullet_cabinet/MarginContainer/HBoxContainer
@onready var ammo_unit:  TextureRect = $Bullet_reference
@onready var bonus_ammo_sfx: AudioStreamPlayer = $bonus_ammo
#@onready var visual_component: Control = $visual_component

@onready var reload_sound: AudioStreamPlayer = $reload_sound
@onready var deload_sound: AudioStreamPlayer = $deload_sound
@onready var out_of_ammo_sound: AudioStreamPlayer = $out_of_ammo_sound

@export var max_loaded_bullets: int = 6
@export var total_reserve_bullets: int = 24

@export var dev_mode := false



var orig_pos : Vector2

var first_reload := true

var bonus_ammo_amount := 1
var current_loaded_bullets: int = 0
var reserve_bullets: int = total_reserve_bullets
var label_orig_colour : Color
var loading := true

func _free_ammo_mode_start() -> void:
	var tween = create_tween().set_trans(Tween.TRANS_BACK)
	tween.tween_property(self, "position:y", 200.0, 0.5).as_relative()
	await tween.finished
	self.hide()
	
func _free_ammo_mode_finished() -> void:
	self.show()
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(self, "position", orig_pos, 0.75)
	#tween.parallel().tween_property(self, "scale", Vector2(1.26,1.26), 0.75)


func sync_ammo_state(reserve: int, loaded: int) -> void:
	reserve_bullets = reserve
	current_loaded_bullets = loaded
	update_labels()

func _mute_these_sounds() -> void:
	$reload_sound.volume_db = -80.0
	$bonus_ammo.volume_db = -80.0
	$deload_sound.volume_db = -80.0
	$out_of_ammo_sound.volume_db = -80.0
	$reloading_movement_sfx.volume_db = -80.0
#
#func colour_change() -> void:
	#var stylebox = $Bullet_cabinet.get_theme_stylebox("panel") as StyleBoxFlat
	#if stylebox:
		#var original_color = stylebox.bg_color
		#
		## Change the background color to red
		#stylebox.bg_color = player.inner_panel_colour
#
	#var stylebox_2 = $Front_metal.get_theme_stylebox("panel") as StyleBoxFlat
	#if stylebox_2:
		#var original_color = stylebox_2.bg_color
		#
		## Change the background color to red
		#stylebox_2.bg_color = player.front_panel_colour
		#
	#$Big_light/indent.modulate =player.inner_panel_colour
	#$Small_light/indent.modulate =player.inner_panel_colour
	#
	#$Big_light/top_light.modulate = player.front_panel_colour
	#$Small_light/top_light.modulate = player.front_panel_colour
	#
	#$Small_light2/top_light.modulate = player.front_panel_colour
	#$Small_light2/indent.modulate = player.inner_panel_colour
	#
	#$Small_light3/top_light.modulate = player.front_panel_colour
	#$Small_light3/indent.modulate = player.inner_panel_colour
	#
	##00080f
	 ##add_theme_color_override() 
	##var new_colour = $Bullet_cabinet.add_theme_color_override('bg_color', 'Green')
	##new_colour = Color.RED


	
	
func _ready() -> void:
	modulate = Color.TRANSPARENT
	var tween = create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(self, "modulate", Color.WHITE, 0.5)
	await tween.finished
	#_mute_these_sounds()
	orig_pos = position
	#label_orig_colour = bullets_remaining_label.label_settings.font_color
	#first_load_ammo()
	#colour_change()
	if first_reload:
		#await get_tree().create_timer(2.0).timeout
		reset_ammo_after_round()
	
	
func update_labels() -> void:
	bullets_remaining_label.text = str(reserve_bullets).pad_zeros(2)
	current_ammo_label.text = str(current_loaded_bullets).pad_zeros(2)
	#
	#bullets_remaining_label.text = $'../Ammo_auto_loading'.bullets_remaining_label.text
	#current_ammo_label.text = $'../Ammo_auto_loading'.current_ammo_label.text
	
func first_load_ammo() -> void:
	current_loaded_bullets = 6
	while ammo_container.get_children().size() < 6:
		var new_ammo = ammo_unit.duplicate()
		ammo_container.add_child(new_ammo)
		new_ammo.show()
		#await get_tree().create_timer(0.15).timeout
	#
	#await get_tree().create_timer(0.1).timeout

	update_labels()

func reload_ammo(amount: int, temp_bullets : int, temp_reserve : int) -> void:
	if !first_reload:
		await reloading_phase()
	bullets_remaining_label.text = str(temp_reserve).pad_zeros(2)
	current_ammo_label.text = str(temp_bullets).pad_zeros(2)
	
	for i in range(amount):
		var new_ammo = ammo_unit.duplicate()
		ammo_container.add_child(new_ammo)
		new_ammo.show()
		if !first_reload:
			reload_sound.play()
		temp_bullets += 1
		temp_reserve -= 1
		reserve_label_animation()
		current_ammo_label_animation()
		
		await get_tree().create_timer(0.075).timeout
		bullets_remaining_label.text = str(temp_reserve).pad_zeros(2)
		current_ammo_label.text = str(temp_bullets).pad_zeros(2)
		if i >= amount - 1:
			await get_tree().create_timer(0.375).timeout
		else:
			await get_tree().create_timer(0.05).timeout
	await get_tree().create_timer(0.1).timeout
	first_reload = false
	loading = false
	#update_labels()
	reloading_phase_complete()


func reserve_label_animation() -> void:
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(bullets_remaining_label, "scale", Vector2.ONE * 1.2, 0.075)
	tween.parallel().tween_property(bullets_remaining_label, "label_settings:font_color", Color('FFFFFF'), 0.075)
	tween.tween_property(bullets_remaining_label, "scale", Vector2.ONE, 0.075)
	tween.parallel().tween_property(bullets_remaining_label, "label_settings:font_color", Color('FFFFFF'), 0.075)
	
func current_ammo_label_animation() -> void:
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(0.075)
	tween.tween_property(current_ammo_label, "scale", Vector2.ONE * 1.2, 0.075)
	tween.parallel().tween_property(current_ammo_label, "label_settings:font_color", Color('FFFFFF'), 0.075)
	tween.tween_property(current_ammo_label, "scale", Vector2.ONE, 0.075)
	tween.parallel().tween_property(current_ammo_label, "label_settings:font_color", Color('FFFFFF'), 0.075)
	
#
#func _process(delta: float) -> void:
	#bullets_remaining_label.text = $'../Ammo_auto_loading'.bullets_remaining_label.text
	#current_ammo_label.text = $'../Ammo_auto_loading'.current_ammo_label.text
	#colour_change()
	

func reset_ammo_after_round() -> void:
	# Do nothing here; the old script is responsible for logic.
	# If you still want a visual pulse:
	# await reloading_phase()
	pass


func reset_ammo_after_round_delay() -> void:
	var needed_bullets = max_loaded_bullets - current_loaded_bullets
	var bullets_to_load = min(needed_bullets, reserve_bullets)
	
	var temp_bullets_amount = current_loaded_bullets
	var temp_reserve_amount = reserve_bullets
	
	reserve_bullets -= bullets_to_load
	current_loaded_bullets += bullets_to_load
	
	# Refill the visual ammo container
	reload_ammo(bullets_to_load, temp_bullets_amount, temp_reserve_amount)

func check_can_shoot() -> bool:
	if loading:
		out_of_ammo_sound.play()
		show_out_of_ammo_effect()
		return false
	
	if dev_mode:
		current_loaded_bullets += 1
		return true
	
	if current_loaded_bullets > 0: # || !out_of_ammo:
		current_loaded_bullets = clamp(current_loaded_bullets - 1, 0, current_loaded_bullets)
		return true
	else:
		out_of_ammo_sound.play()
		show_out_of_ammo_effect()
		return false
		


func show_out_of_ammo_effect() -> void:
	modulate = Color.RED
	await get_tree().create_timer(0.5).timeout
	modulate = Color.WHITE

# VISUAL COMPONENT HANDLES

func ammo_used_remove_one() -> void:
	if visual_component:
		visual_component.deduct_ammo()
	update_labels()

func received_bonus_ammo() -> void:
	for i in range(bonus_ammo_amount):
		bonus_ammo_sfx.play()
		reserve_bullets += 1
		bullets_remaining_label.scale = Vector2.ONE * 1.5
		bullets_remaining_label.label_settings.font_color = Color('FFFFFF')
		await get_tree().create_timer(0.15).timeout
		bullets_remaining_label.text = str(reserve_bullets).pad_zeros(2)
		bullets_remaining_label.scale = Vector2.ONE * 1.0
		bullets_remaining_label.label_settings.font_color = label_orig_colour
		
	update_labels()

func reloading_phase() -> void:
	var dur : float = 0.25
	$reloading_movement_sfx.pitch_scale = 4.5
	$reloading_movement_sfx.play()
	
	var tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(self, "position:y", -20.0, dur).as_relative()
	tween.parallel().tween_property(self, "scale", Vector2(1.27,1.27), dur)
	await tween.finished
	
func reloading_phase_complete() -> void:
	var dur : float = 0.5

	$reloading_movement_sfx.pitch_scale = 3.0
	$reloading_movement_sfx.play()
	
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	tween.tween_property(self, "position", orig_pos, dur)
	tween.parallel().tween_property(self, "scale", Vector2(1.26,1.26), dur)
