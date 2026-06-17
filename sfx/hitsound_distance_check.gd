extends AudioStreamPlayer

@onready var parent = get_parent()
@export var max_distance = 15.0
@export var max_volume_db = -30.0 # -24.0
@export var min_volume_db = -40.0
@onready var _player = get_tree().get_nodes_in_group('Player')

func play_sound() -> void:
	distance_from_player()
	if not playing:
		play()
		#await self.finished
		#self.queue_free()

func distance_from_player() -> void:
	if !_player:
		print('No player')
		return
	print('Player distance working ')
	var _distance = parent.global_position.distance_to(_player.global_position)
	#print_debug("DISTANCE", distance)
	_distance = clamp(_distance, 1.0, max_distance)
	var _volume_db = max_volume_db + (min_volume_db - max_volume_db) * (_distance - 1) / (max_distance - 1)
	_volume_db = clamp(_volume_db, min_volume_db, max_volume_db)
	self.volume_db = _volume_db
