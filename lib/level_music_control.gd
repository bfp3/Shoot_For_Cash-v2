extends Node

@onready var birds: AudioStreamPlayer = $Birds
@onready var ambient_background_noise: AudioStreamPlayer = $Ambient_background_noise
@onready var night_noises: AudioStreamPlayer = $NightNoises
@onready var oasis: AudioStreamPlayer = $Oasis
@onready var chopin: AudioStreamPlayer = $Chopin
@onready var blue_danude: AudioStreamPlayer = $BlueDanude
@onready var ending_song: AudioStreamPlayer = $EndingSong
@onready var wind_noises: AudioStreamPlayer = $WindNoises
@onready var math_anim: AudioStreamPlayer = $MathAnim

# Stores each song's original/default volume
var default_volume_map : Dictionary = {}

@export var current_song : AudioStreamPlayer
@export var opening_song : AudioStreamPlayer

func _ready() -> void:
	default_volumes()
	

#func start_bg_music() -> void:
	##tween_item(oasis)
	#tween_item($MathAnim)

func start_bg_noise() -> void:
	tween_item(birds)
	tween_item(ambient_background_noise)
	tween_item(night_noises)
	await get_tree().create_timer(1.0).timeout
	tween_item(wind_noises)

func default_volumes() -> void:
	# Get all AudioStreamPlayers inside this node
	var songs : Array[AudioStreamPlayer] = [
		birds,
		ambient_background_noise,
		night_noises,
		oasis,
		chopin,
		blue_danude,
		wind_noises,
		math_anim,
		ending_song
	]
	
	for song in songs:
		# Save the original volume
		default_volume_map[song] = song.volume_db
		
		# Mute the song
		song.volume_db = -80.0

func tween_item(_song : AudioStreamPlayer, duration := 2.0) -> void:
	if not default_volume_map.has(_song):
		return

	if not _song.playing:
		_song.play()

	var tween : Tween = create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property(_song, "volume_db", default_volume_map[_song], duration)
	
	
func shop_music_raise_volume() -> void:
	if current_song == null:
		return
		
	var targ_volume := -30.0
	
	if current_song == math_anim:
		current_song.stop()
		current_song.play(126.0)
		targ_volume = -47.0

	
	var tween := create_tween()
	tween.tween_property(current_song, "volume_db", targ_volume, 3.0)
	
func shop_music_lower_volume() -> void:
	if current_song == null:
		return
	var tween := create_tween()
	#tween.tween_property(current_song, "volume_db", -80.0, 5.0)
	tween.tween_property(current_song, "volume_db", -45.0, 3.0)
	await tween.finished
	current_song.pitch_scale += 0.01
	
	
func game_won() -> void:
	var tween := create_tween()
	tween.tween_property(current_song, "volume_db", -80.0, 3.0)
	tween.parallel().tween_property($EndingSong, "volume_db", -35.0, 3.0) #.set_delay(1.0)
	#await tween.finished
	
func first_round() -> void:
	if current_song == null:
		return
	var curr_song : AudioStreamPlayer = current_song
	var orig_vol = curr_song.volume_db
	var _pitch_scale = curr_song.pitch_scale
	curr_song.volume_db = -80.0
	curr_song.pitch_scale = 0.1
	var tween = create_tween().set_ease(Tween.EASE_IN).set_parallel()
	tween.tween_interval(0.75)
	tween.tween_property(curr_song, "pitch_scale", _pitch_scale, 1.5)
	tween.tween_property(curr_song, "volume_db", orig_vol, 1.5)
	tween.tween_property(curr_song, "playing", true, 0.1).set_delay(0.1)
	await tween.finished
	
func start_opening_song() -> void:
	
	if opening_song == null:
		return
		
	var dur : float = 0.7
	var curr_song : AudioStreamPlayer = opening_song
	var orig_vol = curr_song.volume_db
	var _pitch_scale = curr_song.pitch_scale
	curr_song.volume_db = -80.0
	curr_song.pitch_scale = 0.1
	var tween = create_tween().set_ease(Tween.EASE_IN).set_parallel()
	#tween.tween_interval(0.75)
	tween.tween_property(curr_song, "pitch_scale", _pitch_scale, dur)
	tween.tween_property(curr_song, "volume_db", orig_vol, dur)
	tween.tween_property(curr_song, "playing", true, 0.1)#.set_delay(0.1)
	await tween.finished

func _on_start_button_pressed() -> void:
	if opening_song == null:
		return
	var curr_song : AudioStreamPlayer = opening_song

	var tween = create_tween().set_ease(Tween.EASE_IN).set_parallel()
	#tween.tween_interval(0.75)
	#tween.tween_property(curr_song, "pitch_scale", 0.0, 1.5)
	tween.tween_property(curr_song, "volume_db", -7.0, 1.0).as_relative()
	await tween.finished


func stop_opening_song() -> void:
	if opening_song == null:
		return
	var curr_song : AudioStreamPlayer = opening_song

	var tween = create_tween().set_ease(Tween.EASE_IN).set_parallel()
	#tween.tween_interval(0.75)
	tween.tween_property(curr_song, "pitch_scale", 0.0, 1.5)
	tween.tween_property(curr_song, "volume_db", -80.0, 1.5)
	await tween.finished
	curr_song.stop()
