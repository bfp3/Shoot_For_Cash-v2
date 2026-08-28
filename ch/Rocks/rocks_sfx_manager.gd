extends Node
## Shared rock SFX on `$Rocks/RocksSFXManager/SFX` and `$PianoNotesSFX`.
## Overlapping plays clone a voice so pitch/volume tweaks do not stomp each other.

const MAX_VOICES_PER_CUE := 8

var _templates: Dictionary = {}
var _defaults: Dictionary = {}
var _pools: Dictionary = {}
var _active: Dictionary = {}


func _ready() -> void:
	add_to_group("rocks_sfx")
	_index_players(self)
	var piano := _piano_host()
	if piano and piano != self:
		_index_players(piano)
	var rocks := get_parent()
	if rocks:
		for child in rocks.get_children():
			if child is AudioStreamPlayer or child is AudioStreamPlayer3D:
				_register_player(child)


func play(sfx_name: String, from_position: float = 0.0, pitch_scale: float = -1.0, volume_db: float = INF) -> void:
	var template := _template_for(sfx_name)
	if template == null:
		push_warning("RocksSfx: missing cue '%s'" % sfx_name)
		return
	var voice := _acquire_voice(sfx_name, template)
	if voice == null:
		return
	var defaults: Dictionary = _defaults.get(sfx_name, {})
	if pitch_scale > 0.0:
		voice.pitch_scale = pitch_scale
	else:
		voice.pitch_scale = defaults.get("pitch", template.pitch_scale)
	if volume_db < 1000.0:
		voice.volume_db = volume_db
	else:
		voice.volume_db = defaults.get("volume", template.volume_db)
	voice.play(from_position)


func play_piano(note_name: String, pitch_scale: float = -1.0) -> void:
	play(note_name, 0.0, pitch_scale)


func play_pitch_shift() -> void:
	var player := _template_for("pitch_shift_rock_sound")
	if player == null:
		return
	player.pitch_scale = clampf(player.pitch_scale + 0.1, 0.5, 1.2)
	player.play()


func play_stream(stream: AudioStream, volume_db: float, pitch_scale: float) -> void:
	if stream == null:
		return
	var voice := AudioStreamPlayer.new()
	voice.stream = stream
	voice.volume_db = clampf(volume_db, -80.0, -10.0)
	voice.pitch_scale = maxf(pitch_scale, 0.01)
	add_child(voice)
	voice.finished.connect(voice.queue_free, CONNECT_ONE_SHOT)
	voice.play()


func _piano_host() -> Node:
	var nested := get_node_or_null("PianoNotesSFX")
	if nested:
		return nested
	nested = get_node_or_null("PianoNotes")
	if nested:
		return nested
	var rocks := get_parent()
	if rocks:
		var sibling := rocks.get_node_or_null("PianoNotesSFX")
		if sibling:
			return sibling
		sibling = rocks.get_node_or_null("PianoNotes")
		if sibling:
			return sibling
	return get_node_or_null("SFX")


func _index_players(host: Node) -> void:
	if host == null:
		return
	if host is AudioStreamPlayer or host is AudioStreamPlayer3D:
		_register_player(host)
	for child in host.get_children():
		_index_players(child)


func _register_player(player: Node) -> void:
	if player == null:
		return
	var key := String(player.name)
	if key.is_empty() or _templates.has(key):
		return
	_templates[key] = player
	_defaults[key] = {
		"pitch": player.pitch_scale,
		"volume": player.volume_db,
	}
	_pools[key] = []
	_active[key] = []


func _template_for(sfx_name: String) -> Node:
	if _templates.has(sfx_name):
		return _templates[sfx_name]
	if sfx_name == "launched_into_distance_3d":
		return _templates.get("rock_launch_sound")
	return null


func _acquire_voice(sfx_name: String, template: Node) -> Node:
	if not template.playing:
		return template
	var pool: Array = _pools.get(sfx_name, [])
	for voice in pool:
		if is_instance_valid(voice) and not voice.playing:
			return voice
	var active: Array = _active.get(sfx_name, [])
	if active.size() + 1 >= MAX_VOICES_PER_CUE:
		var oldest = active[0]
		if is_instance_valid(oldest):
			oldest.stop()
			return oldest
	var clone = template.duplicate()
	clone.name = "%s_voice" % sfx_name
	clone.unique_name_in_owner = false
	add_child(clone)
	pool.append(clone)
	_pools[sfx_name] = pool
	active.append(clone)
	_active[sfx_name] = active
	if clone.has_signal("finished"):
		clone.finished.connect(_on_voice_finished.bind(sfx_name, clone))
	return clone


func _on_voice_finished(sfx_name: String, voice: Node) -> void:
	var active: Array = _active.get(sfx_name, [])
	active.erase(voice)
	_active[sfx_name] = active
