class_name Egg_Cage_Hostage extends Node3D

# Colour of the egg in emission set to 0.2 strength and #ffcc96
const SMOKE_QUICK : PackedScene = preload("res://res/Particles/Smoke_particles/SmokeQuick.tscn")
@onready var handle_damage_decal: Node = $Handle_damage_decal

@export var health := 3

var taking_damage := false
var dev_mode := false
var dying := false
var pulse_wave_active := false

signal taken_a_hit_from_a_target
signal hostage_killed_signal

var game_won := false
var await_time_for_later := 0.1

func _ready() -> void:
	EventBus.instance.game_won.connect(func():
		game_won = true)
	
	EventBus.instance.player_has_hit_winning_score.connect(func():
		dying = true)
		
	EventBus.instance.in_dev_mode.connect(func():
		dev_mode = true)
	
	EventBus.instance.release_hostages_start.connect(release_eggs)
	
	#$Pedestal.rotation_degrees.y += 180
	
	await_time_for_later = randf_range(0.25, 4.5)
	await get_tree().create_timer(await_time_for_later).timeout
	$Egg_shape/AnimationPlayer.play('wobble')
	


func _on_area_3d_body_entered(body: Node3D) -> void:
	if body.is_in_group('bullet'):
		took_a_hit()
		
	if body.is_in_group('cannonball') && !taking_damage:
		if dev_mode:
			return
			
		if body.has_method('was_hit_tween'):
			body.was_hit_tween()
			
		taking_damage = true
		
		took_a_hit()
		
func took_a_hit() -> void:
	$SFX/took_damage.play()
	
	if pulse_wave_active:
		pulse_wave_active = false
		$Egg_shape/AnimationPlayer.stop()
		$Egg_shape/Emission_energy_egg/AnimationPlayer.stop()
		$Egg_shape/Emission_energy_egg/AnimationPlayer.play("RESET")
	
	if game_won || dying:
		return

	
	health = health - 1

	smoke_particles()
	shake_self_upon_damage()
	slow_mo_moment()
	
	if health <= 0:
		die()

	
	await get_tree().create_timer(0.1).timeout
	taking_damage = false


func die() -> void:
	if dying:
		return
	
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

	if $Egg_shape_old:
		$Egg_shape_old.hide()
	
		
	if $Area3D:
		$Area3D.queue_free()
		$Egg_shape.queue_free()


func slow_mo_moment() -> void:
	var dur : float = 0.1
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(Engine, "time_scale", 0.2, 0.1)
	tween.tween_interval(0.005)
	tween.tween_property(Engine, "time_scale", 1.5, 0.1)
	tween.tween_property(Engine, "time_scale", 1.0, 0.2).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	await tween.finished




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


func smoke_particles() -> void:
	var smoke_particles = SMOKE_QUICK.instantiate()
	get_tree().get_current_scene().add_child(smoke_particles)
	smoke_particles.global_position = global_position
	smoke_particles.emitting = true
	smoke_particles.show()
	smoke_particles.duplicate_particles = true


func _on_area_3d_area_entered(area: Area3D) -> void:
	if area.is_in_group('spotter_projectile') && !taking_damage:
		if area.has_method('was_hit_tween'):
			area.was_hit_tween()
			
		taking_damage = true
		took_a_hit()
		
	if area.is_in_group('bullet') && !taking_damage:
		
		#escape_tween()
		
		if area.has_method('was_hit_tween'):
			area.was_hit_tween()
			
		taking_damage = true
		took_a_hit()
		
func escape_tween() -> void:
	var new_pos : Vector3 = global_position
	var EGG_HOSTAGE_ESCAPEE = preload('res://ch/Egg/Hostage_egg/Egg_hostage_escapee.tscn')
	var new_escapee = EGG_HOSTAGE_ESCAPEE.instantiate()
	get_tree().get_current_scene().add_child(new_escapee)
	new_escapee.global_position = new_pos
	die()
	
func release_eggs() -> void:
	if dying:
		return
		
	else:
		await get_tree().create_timer(await_time_for_later).timeout
		$Egg_shape/AnimationPlayer.play('emission_power_down')
		await $Egg_shape/AnimationPlayer.animation_finished
		$Egg_shape/AnimationPlayer.play('wobble_free')
		await $Egg_shape/AnimationPlayer.animation_finished
		rope_loose_tween()
		
		
		
		
		
func rope_loose_tween() -> void:

	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK).set_parallel()
	tween.tween_property(%Rope, "scale", Vector3(4.0,0.0,4.0), 0.5)
	tween.tween_property(%Rope2, "scale", Vector3(4.0,0.0,4.0), 0.5)
	tween.tween_property($SFX/Egg_damage, "playing", true, 0.01).set_delay(0.25)
	await tween.finished
	fall_down()
	
		
func fall_down() -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "global_position:y", -2.0, 1.5)
	await tween.finished
	escape_tween()
