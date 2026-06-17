extends Node


@export var flash_dur : float = 1.0
@export var reset_flash_dur : float = 1.0

func activate_the_flash() -> void:
	#var world_light : DirectionalLight3D = get_tree().get_first_node_in_group('directional_light_for_egg')
	#var world_env : WorldEnvironment = get_tree().get_first_node_in_group('world_env')
	#world_env.environment.glow_enabled = true
	$EggPulseSfx.play()
	EventBus.instance.egg_pulsed.emit()
	
	#var tween = create_tween()
	#tween.tween_property(world_env, "environment:glow_bloom", 1.0, flash_dur)
	#tween.parallel().tween_property(world_env, "environment:glow_strength", 0.5, flash_dur)
	#tween.parallel().tween_property(world_env, "environment:background_energy_multiplier", 0.5, flash_dur)
	##tween.parallel().tween_property(world_light, "visible", true, 0.1)
	#tween.parallel().tween_property(world_light, "light_energy", 1.0, 0.25)
	##tween.tween_interval(0.25)
	#await tween.finished
	#
	await get_tree().create_timer(flash_dur).timeout
	#EventBus.instance.egg_pulsed.emit()
	await get_tree().create_timer(0.25).timeout
	reset_flash_values()
	

	
func reset_flash_values() -> void:
	$EggPulseSfxReverse.play()
	var world_light : DirectionalLight3D = get_tree().get_first_node_in_group('directional_light_for_egg')
	var world_env : WorldEnvironment = get_tree().get_first_node_in_group('world_env')
	var tween = create_tween()
	tween.tween_property(world_light, "visible", false, 0.1)
	tween.parallel().tween_property(world_light, "light_energy", 0.0, 0.5)
	tween.parallel().tween_property(world_env, "environment:background_energy_multiplier", 1.0, 0.5)
	tween.parallel().tween_property(world_env, "environment:glow_bloom", 0.0, reset_flash_dur)
	tween.parallel().tween_property(world_env, "environment:glow_strength", 0.6, reset_flash_dur)
	await tween.finished
	#%ProgressBar._reset_value()
	#world_env.environment.glow_enabled = false
	#
#func _input(event: InputEvent) -> void:
	#if Input.is_key_label_pressed(KEY_F):
		#activate_the_flash()
