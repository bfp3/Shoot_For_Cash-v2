extends CharacterBody3D
class_name Popper_Behaviour

@onready var player : Player = get_tree().get_first_node_in_group('Player')
@onready var egg: Egg_Cage = get_tree().get_first_node_in_group('Egg_Cage')
@onready var choose_available_marker_logic: Node = %Choose_available_marker_logic
@export var gravity := -9.0
#@export var pulse_magnitude := 2.75

var health := 1
var stunned := false
var dying := false

var crosshair_touching_me := false
var first_time_crosshair_touching_me := true

var start_pos : Vector3
var is_active := true

var current_marker : Marker3D = null

@onready var parent: CharacterBody3D = self
@onready var bh_idle: Node3D = %Idle
@onready var bh_walk: Node3D = %Walk
@onready var bh_throw: Node3D = %Throw
@onready var bh_dying: Node3D = %Dying
@onready var bh_duck: Node3D = %Ducking
@onready var bh_stunned: Node3D = %Stunned
@onready var bh_notify: Node3D

var bh_CurrentBehavior: Node3D = null
var bh_CurrentIndex := 0
var bh_CurrentSequence: Array = []
var bh_FinishedSet := false
var bh_ResumingAfterStun := false
var bh_parent : Node3D 


func _ready() -> void:
	var parent_name = get_parent().name

	if parent_name.begins_with('camp_'):
		self.name = parent_name.replace('camp_', "")

	
	start_pos = global_position

	await get_tree().create_timer(1.0).timeout #Buffer so that the birds can be counted
	EventBus.instance.enemy_present.emit()
	EventBus.instance.egg_pulsed.connect(ev_Stunned)
	#EventBus.instance.enemy_popper_shot.connect(ev_HasDied)

	hide()
	set_process_mode(Node.PROCESS_MODE_DISABLED)
	
func bh_Activate(parent : Node3D, behaviour : String) -> void:
	if !is_active:
		return
		
	bh_parent = parent
	
	bh_CurrentSequence.clear()
	bh_CurrentSequence = behaviour.strip_edges().split("-", false)
	bh_CurrentIndex = -1

	show()
	set_process_mode(Node.PROCESS_MODE_INHERIT)

	bh_Step('')


func bh_Step(action:String):
	
	if action == '':
		bh_CurrentIndex += 1
		if bh_CurrentIndex >= bh_CurrentSequence.size():
			bh_CurrentIndex = 0
		action = bh_CurrentSequence[bh_CurrentIndex]

	#print(bh_CurrentIndex)
	#print(action)

	match action:
		"notify":
			bh_CurrentBehavior = null
			EventBus.instance.actor_event.emit(self.name, "notify")
			bh_CurrentSequence[bh_CurrentIndex] = ''
		"idle":
			bh_CurrentBehavior = bh_idle
		"walk":
			bh_CurrentBehavior = bh_walk
		"throw":
			bh_throw.throw_smoke = false
			bh_CurrentBehavior = bh_throw
		"smokebomb":
			bh_throw.throw_smoke = true
			bh_CurrentBehavior = bh_throw
		"duck":
			bh_CurrentBehavior = bh_duck
		"stunned":
			bh_CurrentBehavior = bh_stunned
		"die":
			bh_CurrentBehavior = bh_dying
		_:
			bh_CurrentBehavior = null

	if not bh_CurrentBehavior:
		bh_Step('')
		return

	bh_CurrentBehavior.start(parent)
	bh_CurrentBehavior.finished.connect(_on_behavior_finished)

func _on_behavior_finished() -> void:

	if bh_ResumingAfterStun:
		bh_ResumingAfterStun = false
	
	if bh_CurrentBehavior:
		bh_CurrentBehavior.disconnect('finished', _on_behavior_finished)

	bh_Step('')


func ev_Stunned() -> void:

	if bh_CurrentBehavior == null:
		return

	if bh_CurrentBehavior.has_method('cancel'):
		await bh_CurrentBehavior.cancel()

	bh_Step('stunned')
	
	# bh_stunned.start(parent)
	
func crosshair_touched_me_cancel_current_behaviour() -> void:
	return
	if bh_CurrentBehavior.can_interrupt():
		await bh_CurrentBehavior.cancel()
		bh_CurrentBehavior = bh_duck
		bh_duck.start(parent)
	else:
		pass


func ev_HitByPlayerBullet() -> void:
	if health <= 0:
		ev_Die()
	
	else:
		bh_Step('')

func ev_Die() -> void:
	bh_dying.start(parent)


func ev_HasDied() -> void:
	hide()
	is_active = false
	EventBus.instance.actor_event.emit(self.name, "die")
	set_process_mode(Node.PROCESS_MODE_DISABLED)
	


func attach_self_to_nearest_marker() -> void:
	var marker = %Choose_available_marker_logic.get_available_marker()
	if marker == null:
		return
	marker.is_occupied = true
	current_marker = marker


func ev_AvoidBullet() -> void:
	crosshair_touching_me = false
	change_facial_expression('scared')
	ev_CrosshairOnPopper()


func ev_CrosshairOnPopper() -> void:
	if crosshair_touching_me:
		return
	
	crosshair_touching_me = true
	
	crosshair_touched_me_cancel_current_behaviour()
	
	if first_time_crosshair_touching_me:
		first_time_crosshair_touching_me = false
		change_facial_expression('scared')
	else:
		change_facial_expression('blinking')
	
	%duck_sfx.pitch_scale = randf_range(0.9,1.15)
	%duck_sfx.play()
		
	look_at(player.global_position, Vector3.UP, false)
	
	await get_tree().create_timer(0.2).timeout
	crosshair_touching_me = false
	
	
func change_facial_expression(expression: String) -> void:
	var face_nodes := {
		"standard": %Standard_face,
		"blinking": %Blinking_face,
		"scared": %Scared_face
	}
	
	for key in face_nodes.keys():
		if key == expression:
			face_nodes[key].show()
			await get_tree().create_timer(1.0).timeout
			face_nodes[key].hide()
			face_nodes['standard'].show()
		else:
			face_nodes[key].hide()
			

#func _physics_process(delta: float) -> void:
	##if not is_on_floor():

		##velocity.y -= gravity
	##else:

		##velocity.y = 0.0
		#
	#if is_on_floor():

	#else:
		#velocity.y = gravity * delta
	#
	#if global_position.y <= -15.0 && not is_on_floor():

		#health -= 1
		#ev_Die()

		#set_physics_process(false)
#
	#move_and_slide()
