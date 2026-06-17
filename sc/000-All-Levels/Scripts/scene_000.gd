extends Node3D

@onready var camera = $Camera3D
@onready var birds = $birdContainer
var transitioning := false
@export var file_link : String = 'Scene-000.txt'


func _ready():
	$HoodLogo.logo_clicked.connect(_on_start_menu)
	BackgroundForTransition.fade_out()
	camera.current = true
	camera.position.y = 205.887
	set_process(false)

func _on_start_menu() -> void:
	BackgroundForTransition.fade_in()
	await get_tree().create_timer(0.2)
	get_tree().change_scene_to_file('res://100_levels/000-All-Levels/' + %Choreographer.frame_settings['next-scene'] + '.tscn')
	
	
func bh_Activate(parent : Node3D, behaviour : String) -> void:
	var tokens = behaviour.strip_edges().split("-", false)

	for token in tokens:
		var name = token.strip_edges().to_lower()
		match name:
			"start":
				set_process(true)

func _process(delta):
	camera.position.y += 0.174
	birds.position.z -=2
	birds.position.x +=3
	
	if birds.position.x >= 353.888:
		birds.rotation.y = 180
		birds.position.z -=4

	if birds.position.z <= -7000:
		$birdContainer2.position.x +=1.6
	
	if camera.position.y >= 291:
		camera.position.y = 291
		


func _on_timer_timeout():
	$birdContainer/birdWindNoise.play()

#func _on_voice_timer_timeout():
	#$voices.play()
