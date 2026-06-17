class_name Egg_Cage extends Node3D


# Colour of the egg in emission set to 0.2 strength and #ffcc96
const SMOKE_QUICK = preload('uid://dldwpcrllmhxj')
@onready var handle_damage_decal: Node = $Handle_damage_decal

@export var health := 5
@export var secondary_bonus_egg := false

var taking_damage := false
var dev_mode := false
var dying := false
var pulse_wave_active := false

signal taken_a_hit_from_a_target
signal hostage_killed_signal

var game_won := false

func _ready() -> void:
	EventBus.instance.game_won.connect(func():
		game_won = true)
	
	EventBus.instance.player_has_hit_winning_score.connect(func():
		dying = true)
		
	EventBus.instance.in_dev_mode.connect(func():
		dev_mode = true)
		
	EventBus.instance.egg_pulse_activated.connect(activate_pulse_wave)
	
	if secondary_bonus_egg:
		$Rope.show() 
		$Rope2.show()
		$Egg_shape.hide()
		$Egg_shape_old.show()
		$Pedastal.rotation_degrees.y += 180
		if $Ring:
			$Ring.queue_free()
		
		if $StaticBody3D:
			$StaticBody3D.queue_free()
			
	
			

func _on_area_3d_body_entered(body: Node3D) -> void:
	return
	#if body.is_in_group('bullet') && secondary_bonus_egg:
		#if dev_mode:
			#return
		#
		#took_a_hit()
		#
	#if body.is_in_group('cannonball') && !taking_damage:
		#if dev_mode:
			#return
			#
		#if body.has_method('was_hit_tween'):
			#body.was_hit_tween()
			#
		#taking_damage = true
		#
		#took_a_hit()
		
func took_a_hit() -> void:
	$SFX/took_damage.play()
	
	# If pulsing, cancel it and reset everything
	if pulse_wave_active:
		pulse_wave_active = false
		$Egg_shape/AnimationPlayer.stop()
		$Egg_shape/Emission_energy_egg/AnimationPlayer.stop()
		$Egg_shape/Emission_energy_egg/AnimationPlayer.play("RESET")
	
	if game_won:
		return
	
	if dying:
		return
	
	handle_damage_decal.taken_damage()
	health = health - 1
	
	#if health <= 1:
		#$Egg_shape.hide()
		#$cracked_egg.show()
	
	if !secondary_bonus_egg:
		EventBus.instance.egg_taken_damage.emit()
		taken_a_hit_from_a_target.emit()
		var health_manager : HealthManager = get_tree().get_first_node_in_group('HealthManager')
		if health_manager:
			health_manager.egg_took_damage()
			
	#else:
		#GameManager.current_score_not_displayed -= 100.0
		#$Secondary_egg.show()
		#$Secondary_egg/Label3D.text = str(-100.0)
		#$Secondary_egg/Label3D.modulate = Color.RED
		
		
	smoke_particles()
	shake_self_upon_damage()
	slow_mo_moment()
	
	if health <= 0:
		die()

	
	await get_tree().create_timer(0.1).timeout
	taking_damage = false
	$SubViewport/ProgressBar.set_process(true)

func die() -> void:
	if dying:
		return

	
	if !secondary_bonus_egg:
		EventBus.instance.main_egg_destroyed.emit()
	
	dying = true
	$SFX/EggDamaged4.play()
	$SFX/EggDamaged9CrackAtEnd.play(0.43)
	$Special_particles.emitting = true
	$Smoke_quick2.emitting = true
	$Smoke_blast_radius.top_level = true
	$Smoke_blast_radius.global_position = global_position
	$Smoke_blast_radius.emitting = true
	
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property($Egg_shape, "scale", Vector3.ZERO, 0.15)
	await tween.finished
	
	$Egg_shape.hide()
	$cracked_egg.hide()
	if $Egg_shape_old:
		$Egg_shape_old.hide()
	
	#if secondary_bonus_egg:
		#var tween_label = create_tween()
		#tween_label.tween_interval(0.25)
		#tween_label.tween_property($Secondary_egg, "visible", false, 0.1)
		#await tween_label.finished
		
	if $Area3D:
		$Area3D.queue_free()
		$Egg_shape.queue_free()
		$Egg_shape_old.queue_free()


func slow_mo_moment() -> void:
	var dur : float = 0.1
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(Engine, "time_scale", 0.2, 0.1)
	tween.tween_interval(0.005)
	tween.tween_property(Engine, "time_scale", 1.5, 0.1)
	tween.tween_property(Engine, "time_scale", 1.0, 0.2).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	await tween.finished


	
func _input(event: InputEvent) -> void:
	if Input.is_key_label_pressed(KEY_F):
		#activate_the_flash()
		activate_pulse_wave()

	if Input.is_action_pressed('cam_right'):
		rotation_degrees.y += 1
		
	if Input.is_action_pressed('cam_left'):
		rotation_degrees.y -= 1

func shake_self_upon_damage() -> void:
	
	var dur : float = 0.15
	var shake_power := 2.5
	if $Egg_shape/AnimationPlayer.is_playing():
		await $Egg_shape/AnimationPlayer.animation_finished
		
	$Egg_shape/AnimationPlayer.play('wobble')
	$Egg_shape/AnimationPlayer.seek(2.0, true)
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "rotation_degrees:y", -shake_power, dur).as_relative()
	tween.parallel().tween_property(self, "rotation_degrees:x", -shake_power, dur).as_relative()
	tween.tween_property(self, "rotation_degrees:y", shake_power, dur).as_relative()
	tween.parallel().tween_property(self, "rotation_degrees:x", shake_power, dur).as_relative()
	await tween.finished
	if !dying:
		$Egg_shape/AnimationPlayer.play('wobble')
		$Egg_shape/AnimationPlayer.seek(2.0, true)

#func explode() -> void:
	#var smoke_particles = SMOKE_QUICK.instantiate()
	#get_tree().get_current_scene().add_child(smoke_particles)
	#smoke_particles.global_position = global_position
	#smoke_particles.emitting = true
	#smoke_particles.duplicate_particles = true
	#await get_tree().create_timer(0.1).timeout
	#hostage_killed_signal.emit()
	#self.queue_free()

func smoke_particles() -> void:
	var _smoke_particles = SMOKE_QUICK.instantiate()
	get_tree().get_current_scene().add_child(_smoke_particles)
	_smoke_particles.global_position = global_position
	_smoke_particles.emitting = true
	_smoke_particles.show()
	_smoke_particles.duplicate_particles = true

func reduce_health_star() -> void:
	return
	#$Star_decals.reduce_health_star()

func activate_pulse_wave() -> void:
	if dying || secondary_bonus_egg:
		return

	pulse_wave_active = true

	#$Egg_shape/AnimationPlayer.play('quick_wobble')
	#$Egg_shape/AnimationPlayer.play('wave_wobble_3')
	$Egg_shape/AnimationPlayer.play('shockwave_anim')
	await $Egg_shape/AnimationPlayer.animation_finished
	#$OmniLight3D/AnimationPlayer.play('telegraph_flashing_light')
	#$Egg_shape/Emission_energy_egg/AnimationPlayer.play('release_emission')
#
	#await $OmniLight3D/AnimationPlayer.animation_finished

	if !pulse_wave_active:
		return  # interrupted by damage

	#$Egg_shape/AnimationPlayer.play('wave_wobble')
	#await get_tree().create_timer(1.0).timeout

	if !pulse_wave_active:
		return

	#$Flash_sequence.activate_the_flash()
	
	#await $Egg_shape/AnimationPlayer.animation_finished
	$Egg_shape/Emission_energy_egg/AnimationPlayer.play('RESET')

	pulse_wave_active = false

	
	
func power_ring_tween() -> void:
	var ring_decal : Decal = $Power_ring.duplicate()
	add_child(ring_decal)
	ring_decal.show()
	ring_decal.global_position = global_position

	var tween = create_tween()
	tween.tween_property(ring_decal, "size", Vector3(60,30,60), 3.0)
	tween.parallel().tween_callback(EventBus.instance.egg_pulsed.emit).set_delay(1.0)
	tween.parallel().tween_property(ring_decal, "modulate", Color.TRANSPARENT, 3.0)
	await tween.finished
	ring_decal.queue_free()


func _on_area_3d_area_entered(area: Area3D) -> void:
	if area.is_in_group('spotter_projectile') && !taking_damage:
		print('took a hit from spotter projectile')
		
		#if dev_mode:
			#return
			
		if area.has_method('was_hit_tween'):
			area.was_hit_tween()
			
		taking_damage = true
		took_a_hit()
		
	if area.is_in_group('bullet') && !taking_damage && secondary_bonus_egg:
		print('took a hit from spotter projectile')
		
		#if dev_mode:
			#return
			
		if area.has_method('was_hit_tween'):
			area.was_hit_tween()
			
		taking_damage = true
		took_a_hit()
