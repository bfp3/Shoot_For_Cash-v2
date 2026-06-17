extends Node

var parent: Node = null

#func _ready():
	#parent = get_parent()
#
#func throw_rock_at_the_egg() -> void:
	#if !parent.can_throw_projectiles:
		#return
#
	#parent.projectile_throw_cancelled = false
	#await parent.get_node('Mesh/throw_arm').throw_projectile()
	#if parent.projectile_throw_cancelled:
		#return
#
	#var SPOTTER_PROJECTILE = preload("res://500_sequences/Cannonball_System/Cannonballs/Spotter_projectiles.tscn")
	#var new_projectile : Standard_Cannonball = SPOTTER_PROJECTILE.instantiate()
	#new_projectile.arc_strength = randf_range(0.1, 0.2)
	#new_projectile.probability_of_special_bomb = 1.0
	#parent.get_tree().get_current_scene().add_child(new_projectile)
	#new_projectile.global_position = %spawn_projectile_marker.global_position
#
	#var target : Egg_Cage = parent.get_tree().get_first_node_in_group("Egg_Cage")
	#new_projectile.target_position = target.global_position
#
	#var rand_targ : int = randi_range(0, 10)
	#var targ_colour : String = "GREY"
	#if rand_targ >= 8:
		#targ_colour = "RED"
	#new_projectile.target_launcher_fire(targ_colour)
#
	#await parent.get_tree().create_timer(0.5).timeout
	#if parent.projectile_throw_cancelled:
		#return
#
	#parent.looking_over_wall_sequence.take_cover_behind_wall()
