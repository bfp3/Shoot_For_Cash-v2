extends Node
## Shared rock SFX on `$Rocks/RocksSFXManager/SFX` and `$PianoNotesSFX`.
## Overlap uses `max_polyphony` on the existing players — never spawn voices during a pulse.

const MAX_POLYPHONY := 24
const ONESHOT_VOICES := 12

var _templates: Dictionary = {}
var _defaults: Dictionary = {}
var _oneshots: Array[AudioStreamPlayer] = []


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
	_prepare_oneshots()


func play(sfx_name: String, from_position: float = 0.0, pitch_scale: float = -1.0, volume_db: float = INF) -> void:
	var template := _template_for(sfx_name)
	if template == null:
		push_warning("RocksSfx: missing cue '%s'" % sfx_name)
		return
	var defaults: Dictionary = _defaults.get(sfx_name, {})
	# Only retune when this player is idle. Changing pitch/volume on a playing
	# polyphonic player would bend every overlapping voice of that cue.
	if not template.playing:
		if pitch_scale > 0.0:
			template.pitch_scale = pitch_scale
		else:
			template.pitch_scale = defaults.get("pitch", template.pitch_scale)
		if volume_db < 1000.0:
			template.volume_db = volume_db
		else:
			template.volume_db = defaults.get("volume", template.volume_db)
	template.play(from_position)


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
	var voice := _acquire_oneshot()
	if voice == null:
		return
	voice.stream = stream
	voice.volume_db = clampf(volume_db, -80.0, -10.0)
	voice.pitch_scale = maxf(pitch_scale, 0.01)
	voice.play()


func _prepare_oneshots() -> void:
	for i in ONESHOT_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.name = "oneshot_%d" % i
		add_child(voice)
		_oneshots.append(voice)


func _acquire_oneshot() -> AudioStreamPlayer:
	for voice in _oneshots:
		if not voice.playing:
			return voice
	if _oneshots.is_empty():
		return null
	var fallback := _oneshots[0]
	fallback.stop()
	return fallback


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
	# Pitch-shift is meant to retrigger one stacked tone, not layer 24 copies.
	if key != "pitch_shift_rock_sound" and player.max_polyphony < MAX_POLYPHONY:
		player.max_polyphony = MAX_POLYPHONY


func _template_for(sfx_name: String) -> Node:
	if _templates.has(sfx_name):
		return _templates[sfx_name]
	if sfx_name == "launched_into_distance_3d":
		return _templates.get("rock_launch_sound")
	return null
