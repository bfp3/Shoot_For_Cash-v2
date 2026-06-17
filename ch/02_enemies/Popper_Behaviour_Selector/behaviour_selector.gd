extends Node3D
#
#@onready var choreo : Node3D = get_tree().get_first_node_in_group('Popper_choreographer')
#
#@onready var parent: CharacterBody3D = $'..'
#@onready var idle: Node3D = %Idle
#@onready var walk: Node3D = %Walk
#@onready var throw: Node3D = %Throw
#@onready var dying: Node3D = %Dying
#@onready var ducking: Node3D = %Ducking
#@onready var stunned: Node3D = %Stunned
#
#var current_behavior: Node3D = null
#var current_index := 0
#var behavior_sequence: Array = []
#
#var finished_set := false
#
#func _ready() -> void:
	#pass
	##behavior_sequence = [idle, walk, throw]  # Order matters
	##start_next_behavior()
	#
#
#func notify_choreo_to_get_next_set() -> void:
	#choreo.obtain_next_set_of_behaviours(parent.name)
	#print('requesting next behaviour set')
#
#
#func behavior_set(input_string: String) -> void:
	#print(input_string)
	#var tokens = input_string.strip_edges().split(",", false)
	#behavior_sequence.clear()
#
	#for token in tokens:
		#var name = token.strip_edges().to_lower()
		#match name:
			#"idle":
				#behavior_sequence.append(idle)
			#"walk":
				#behavior_sequence.append(walk)
			#"throw":
				#behavior_sequence.append(throw)
			##"dying":
				##behavior_sequence.append(dying)
			##"ducking":
				##behavior_sequence.append(ducking)
			##"stunned":
				##behavior_sequence.append(stunned)
			#_:
				#push_error("Unknown behavior name: '%s'" % name)
#
	#finished_set = false
	#start_next_behavior()
#
#
#func start_next_behavior():
	#print('start next behaviour')
	#if finished_set: return
	#if current_index >= behavior_sequence.size():
		#current_index = 0
		##behavior_sequence.clear()
		##finished_set = true
		##notify_choreo_to_get_next_set()
		#
		#return
#
	#var next_behavior = behavior_sequence[current_index]
		#
	#switch_to_behavior(next_behavior)
	#current_index += 1
#
#func switch_to_behavior(new_behavior: Node3D) -> void:
	#
	#if current_behavior == new_behavior:
		#return  # Already active
#
	## Disconnect previous signal to avoid duplicates
	##if current_behavior and current_behavior.has_signal("finished"):
		##current_behavior.finished.disconnect(_on_behavior_finished)
#
	#current_behavior = new_behavior
#
	#if current_behavior.has_method("start"):
		#current_behavior.start(parent)
#
	#if current_behavior.has_signal("finished"):
		#current_behavior.finished.connect(_on_behavior_finished)
#
#
#func _on_behavior_finished() -> void:
	#if finished_set: return
	##current_behavior = null
	#start_next_behavior()
	#
#
#func stunned_cancel_current_behaviour() -> void:
	#return
	#if current_behavior.can_interrupt():
		#await current_behavior.cancel()
		#current_behavior = stunned
		#stunned.start(parent)
	#else:
		#pass
	#
#func crosshair_touched_me_cancel_current_behaviour() -> void:
	#return
	#if current_behavior.can_interrupt():
		#await current_behavior.cancel()
		#current_behavior = ducking
		#ducking.start(parent)
	#else:
		#pass
#
#
#func has_been_shot() -> void:
	#if $'..'.health <= 0:
		#die()
	#
	#else:
		#start_next_behavior()
#
#func die() -> void:
	#dying.start(parent)
