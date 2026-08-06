@tool
extends Node2D
## 2D counterpart of `res/aoe_script.gd` — plays child GPUParticles2D with optional delays.

@export var play_particles: bool = false:
	set(value):
		if value:
			_find_particles()
			_cleanup_delays()
			_start_delays()
			_play_particles()
		play_particles = false

var particle_systems: Array = []
@export var delays: Dictionary = {}

@export var cleanDelays: bool = false:
	set(value):
		if value:
			delays.clear()
		cleanDelays = false


func play_at(world_pos: Vector2) -> void:
	global_position = world_pos
	_find_particles()
	_cleanup_delays()
	_start_delays()
	_play_particles()


func _find_particles() -> void:
	particle_systems.clear()
	var existing_delays := delays.duplicate()
	for child in get_children():
		if child is GPUParticles2D:
			particle_systems.append(child)
			if not existing_delays.has(child.name):
				existing_delays[child.name] = 0.0
	delays = existing_delays


func _cleanup_delays() -> void:
	var valid_particle_names = particle_systems.map(func(p): return p.name)
	for key in delays.keys():
		if key not in valid_particle_names:
			delays.erase(key)


func _start_delays() -> void:
	for particle in particle_systems:
		if not delays.has(particle.name):
			delays[particle.name] = 0.0


func _play_particles() -> void:
	for particle in particle_systems:
		var delay: float = float(delays.get(particle.name, 0.0))
		_play_delay(particle, delay)


func _play_delay(ps: GPUParticles2D, delay: float) -> void:
	ps.emitting = false
	if delay > 0.0:
		await get_tree().create_timer(delay).timeout
	ps.restart()
	ps.emitting = true
