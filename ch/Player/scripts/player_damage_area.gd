extends Area3D
@onready var camera_3d: Player_Camera = $'../Cam_pivot/Camera3D'

@export var health := 5
var dead := false
var hit_amount := 0

func _on_body_entered(body: Node3D) -> void:
	return
	#if body.is_in_group('cannonball'):
		#if dead:
			#return
		#
		#taken_damage_visuals()
		#hit_amount += 1
		#health -= 1
		#if health <= 0:
			#player_offline()
			#dead = true
			#var health : HealthManager = get_tree().get_first_node_in_group('HealthManager')
			#if health:
				#health.player_died()

func taken_damage_visuals() -> void:
	camera_3d.camera_shake_on_player_hit()
	
	var TV_filter : CRT_TV_Filter = get_tree().get_first_node_in_group("TV_CRT_Filter")
	TV_filter.add_crack(hit_amount)
	
	$sfx_1.play()
	$sfx_3.play()

func player_offline() -> void:
	
	$dead.play()
	var TV_filter : CRT_TV_Filter = get_tree().get_first_node_in_group("TV_CRT_Filter")
	TV_filter.player_offline()
