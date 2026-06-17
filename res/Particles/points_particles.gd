extends GPUParticles3D


var duplicate_particles := false
const RED_MATERIAL = preload('uid://bvua8wvwd23iu')
#@onready var target_pos : Marker3D = get_tree().get_first_node_in_group('points_particles_marker')
@onready var target_pos : Node3D = get_tree().get_first_node_in_group('Egg_Cage')
var red := false 


func _ready() -> void:
	set_physics_process(false)
		
func _one_shot() -> void:
	one_shot = true
	finished.connect(_on_finished)
	
func _on_finished() -> void:
	if duplicate_particles == true:
		self.queue_free()

func activate() -> void:
	if red:
		material_override = RED_MATERIAL

	add_to_group("points_particles")
	emitting = true
	duplicate_particles = true
	
	await get_tree().create_timer(0.5).timeout
	show()
	#one_shot = true
	set_physics_process(true)
	await get_tree().create_timer(0.5).timeout
	
	var points_receptor_ui : Points_receptor_UI = get_tree().get_first_node_in_group('points_receptor_ui')
	if points_receptor_ui:
		points_receptor_ui.update_points_receptor()

func _physics_process(delta: float) -> void:
	var dist := global_position.distance_to(target_pos.global_position)
	
	if dist <= 0.01:
		global_position = target_pos.global_position  # snap exactly to position
		set_physics_process(false)
		_one_shot()
	else:
		global_position = global_position.lerp(target_pos.global_position, 0.2)
