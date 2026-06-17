extends CharacterBody3D

@onready var anim = $body/AnimationPlayer
@onready var sfx = $birdSFX

var speed = Vector3.ZERO
var start_pos : Vector3

@export var target_pos : Vector3 = Vector3(-152, 20, 706)

@onready var bird_sfx: AudioStreamPlayer3D = $birdSFX

func _ready():
	global_position.z = -20 + global_position.z
	start_pos = global_position
	#firstSetOfBirds()
	new_birds_func()
#	anim.play("beakWobble")

#func _process(delta: float) -> void:
	#if global_position != target_pos:
		##$body.look_at(target_pos, Vector3.UP, true)
		#look_at(target_pos, Vector3.UP, true)

func new_birds_func() -> void:
	var dur : float = 45.0
	var bird_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC).set_loops(10)
	bird_tween.tween_property(self, "global_position", target_pos, dur)
	bird_tween.tween_interval(15.0)
	bird_tween.tween_property(self, "global_position", start_pos, 0.1)
	await bird_tween.finished

	
func firstSetOfBirds():
	var firstTween = create_tween()
	firstTween.tween_property(self, "position", Vector3(0, 30, 490), 20).from_current()
	await get_tree().create_timer(9.0).timeout
#	sfx.play()
	
#	await get_tree().create_timer(25).timeout
	
	fly_to_random_position()

func fly_to_random_position():
	var tween = get_tree().create_tween().set_loops(20)
	tween.tween_property(self, "position", Vector3(-400, 10, 190), 40).from(Vector3(400, 10, 190))
