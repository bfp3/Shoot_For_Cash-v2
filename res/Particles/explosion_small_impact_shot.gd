extends Node3D

@onready var explosion_sfx: AudioStreamPlayer3D = $Explosion_particles/Explosion_sfx
@onready var explosion_sfx_2: AudioStreamPlayer3D = $Explosion_particles/Explosion_sfx2

@onready var debris: GPUParticles3D = $Explosion_particles/Debris
@onready var debris_2: GPUParticles3D = $Explosion_particles/Debris2
@onready var debris_3: GPUParticles3D = $Explosion_particles/Debris3


func _ready() -> void:
	debris.emitting = true
	debris_2.emitting = true
	debris_3.emitting = true
	#fire.emitting = true
	explosion_sfx.play()
	explosion_sfx_2.play()


func _on_timer_timeout() -> void:
	queue_free()
