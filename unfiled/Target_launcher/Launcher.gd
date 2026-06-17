extends Node3D


@export var fire_rate = 1.0
@export var missile_speed = 70.0
@export var missile_turn_speed = 150.0

var target : Node3D

const MISSILE = preload("res://300_assets/Target_launcher/Missile.tscn")
func _ready():
	target = get_tree().get_nodes_in_group("targets")[0]
	#$FireTimer.connect("timeout", self, "fire_missile")
	$FireTimer.wait_time = fire_rate
	$FireTimer.start()

func fire_missile():
	var missile_inst = MISSILE.instantiate()
	missile_inst.setup(target, missile_speed, missile_turn_speed)
	missile_inst.global_transform = $LauncherBase/FirePoint.global_transform
	get_tree().get_root().add_child(missile_inst)
