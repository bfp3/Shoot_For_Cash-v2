extends Node3D

@onready var sparks_01: GPUParticles3D = %gunEmbers

@onready var gun: Node3D = $mockGun
@onready var gun_2: Node3D = $mockGun2
@onready var gun_3: Node3D = $mockGun3
@onready var gun_alt: Node3D = get_node_or_null("mockGunAlt")

@export var gun_recoil := 0.2
@export var use_multi_guns : bool = false

var amount_of_guns : int = 0
var guns : Array[Node3D] = []
var current_gun_index : int = 0

# Stores EACH gun's original Z position
var gun_orig_z : Dictionary = {}
var current_gun : Node3D
## When true, Shift+G alternate mesh is active instead of default barrels.
var using_alt_weapon := false


func _ready() -> void:
	end_position()
	guns = [$mockGun, gun_2, gun_3]
	for i in guns:
		i.hide()
	if gun_alt:
		gun_alt.hide()


func set_weapon_slot(use_alt: bool) -> void:
	using_alt_weapon = use_alt
	update_guns()


func update_guns() -> void:
	amount_of_guns = gl_PlayerState.dataset.power_gun

	for i in guns:
		i.hide()
	if gun_alt:
		gun_alt.hide()

	if using_alt_weapon and gun_alt:
		current_gun = gun_alt
		current_gun.show()
		return

	if amount_of_guns == 1:
		current_gun = $mockGun
		current_gun.show()

	if amount_of_guns == 2:
		current_gun = $mockGun2
		current_gun.show()


func get_active_gun() -> Node3D:
	if current_gun and is_instance_valid(current_gun):
		return current_gun
	return gun


func get_barrel_position(pos_x : float = 0.0) -> Transform3D:
	if using_alt_weapon and gun_alt:
		current_gun = gun_alt
	elif amount_of_guns > 1:
		if pos_x > 0:
			current_gun = gun_3
		else:
			current_gun = gun_2

	var barrel_pos : Marker3D = current_gun.get_node("bullet_marker_pos")

	play_sparks(barrel_pos)
	current_gun.get_node('AnimationPlayer').play('shoot')

	var shoot_pos := barrel_pos.global_transform

	if use_multi_guns:
		current_gun_index += 1
		if current_gun_index >= guns.size():
			current_gun_index = 0

	return shoot_pos


func start_position() -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "position:y", -0.665, 0.5)

func end_position() -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(self, "position:y", -1.335, 0.5)

func play_sparks(barrel_pos : Marker3D) -> void:
	var new_sparks = sparks_01.duplicate()
	add_child(new_sparks)
	new_sparks.finished.connect(new_sparks.queue_free)
	new_sparks.global_position = barrel_pos.global_position
	new_sparks.one_shot = true
	new_sparks.emitting = true
