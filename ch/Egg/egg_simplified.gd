class_name Egg extends Node3D


@export var flash_dur : float = 0.1
@export var reset_flash_dur : float = 0.25

func activate_pulse_wave() -> void:
	#$Start_SFX.play()
	$Egg_shape/AnimationPlayer.play('shockwave_anim')
	await get_tree().create_timer(1.9, false).timeout
	pulse()

	await $Egg_shape/AnimationPlayer.animation_finished
	$Egg_shape/Emission_energy_egg/AnimationPlayer.play('RESET')


func pulse() -> void:
	$EggPulseSfx.play()
	
	#EventBus.instance.egg_pulsed.emit()
	await get_tree().create_timer(flash_dur, false).timeout
	await get_tree().create_timer(0.25, false).timeout
	$EggPulseSfxReverse.play()
	
