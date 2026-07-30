extends Node3D

@onready var sparks_01: GPUParticles3D = %gunEmbers

@onready var gun: Node3D = $mockGun
@onready var gun_2: Node3D = $mockGun2
@onready var gun_3: Node3D = $mockGun3

@export var gun_recoil := 0.2
@export var use_multi_guns : bool = false

var amount_of_guns : int = 0
var guns : Array[Node3D] = []
var current_gun_index : int = 0

# Stores EACH gun's original Z position
var gun_orig_z : Dictionary = {}
var current_gun : Node3D

func _ready() -> void:
	end_position()
	#guns = [gun_2, gun_3, mock_gun_4, mock_gun_5]
	guns = [ $mockGun ,gun_2, gun_3]
	for i in guns:
		i.hide()

func update_guns() -> void:
	amount_of_guns = gl_PlayerState.dataset.power_gun
	
	for i in guns:
		i.hide()
		
	if amount_of_guns == 1:
		current_gun = $mockGun
		current_gun.show()
	
	if amount_of_guns == 2:
		current_gun = $mockGun2
		current_gun.show()


func get_barrel_position(pos_x : float = 0.0) -> Transform3D:
	
	if amount_of_guns > 1:
		if pos_x > 0:
			current_gun = gun_3
		else:
			current_gun = gun_2

	#if use_multi_guns:
		#current_gun = guns[current_gun_index]
	#else:
		#current_gun = gun_2

	var barrel_pos : Marker3D = current_gun.get_node("bullet_marker_pos")

	play_sparks(barrel_pos)
	current_gun.get_node('AnimationPlayer').play('shoot')
	#recoil_anim(current_gun)

	var shoot_pos := barrel_pos.global_transform

	# Only cycle when enabled
	if use_multi_guns:
		current_gun_index += 1

		if current_gun_index >= guns.size():
			current_gun_index = 0

	return shoot_pos


func start_position() -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT) #.set_trans(Tween.TRANS_BACK)
	#tween.tween_property(self, "global_position:y", -1.65, 0.5)
	#tween.tween_property(self, "rotation_degrees:x", 0.0, 0.5)
	tween.parallel().tween_property(self, "position:y", -0.665, 0.5)

func end_position() -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	#tween.tween_property(self, "rotation_degrees:x", 20.0, 0.5)
	tween.parallel().tween_property(self, "position:y", -1.335, 0.5)

func play_sparks(barrel_pos : Marker3D) -> void:

	var new_sparks = sparks_01.duplicate()

	add_child(new_sparks)

	new_sparks.finished.connect(new_sparks.queue_free)

	new_sparks.global_position = barrel_pos.global_position
	new_sparks.one_shot = true
	new_sparks.emitting = true
