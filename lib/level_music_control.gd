extends Node

@onready var birds: AudioStreamPlayer = $Birds
@onready var night_noises: AudioStreamPlayer = $NightNoises

@onready var wind_noises: AudioStreamPlayer = $WindNoises
@onready var shop_music: AudioStreamPlayer = $Shop_Music

var default_volume_map : Dictionary = {}

@export var current_song : AudioStreamPlayer
@export var opening_song : AudioStreamPlayer

@export var background_music_vol_in_shop := -40.0
@export var background_music_vol_out_of_shop := -40.0
## Dedicated shop-menu track volume when the shop is open.
@export var shop_music_volume := -30.0

## Streams are assigned at runtime so Main.tscn does not decode ~30MB of audio on load.
const STREAM_PATHS := {
	"Birds": "res://sfx/Sonoma_birds.ogg",
	"Birds4": "res://sfx/ocean_gulls_sfx_01.ogg",
	"Birds5": "res://sfx/ocean_waves_sfx_01.ogg",
	"Birds2": "res://sfx/birds_noises.ogg",
	"Birds3": "res://sfx/Seagull - Sound Effect.ogg",
	"WindNoises": "res://sfx/windFull.ogg",
	"NightNoises": "res://sfx/night-noises.ogg",
	"Opening_song": "res://sfx/Windmill_Sprint.ogg",
	"Shop_Music": "res://sfx/shop_music.ogg",
	"PerfectPineappleRound": "res://sfx/one_hundred_percent.ogg",
}

#const RANDOMISER_STREAM_PATHS := [
	#"res://sfx/spare_songs/Windmill_math_anim2.ogg",
	#"res://sfx/spare_songs/aa_joyful_chess.ogg",
	#"res://sfx/spare_songs/aa_joyful_frog.ogg",
	#"res://sfx/spare_songs/aa_joyful_matchmakers.ogg",
	#"res://sfx/Windmill_Sunburst_Your_name.ogg",
#]

var _audio_ready := false
var _pending_stream_loads: Dictionary = {} # path -> [AudioStreamPlayer]


func _ready() -> void:
	_strip_embedded_streams()
	default_volumes()
	_begin_threaded_audio_loads()


func _strip_embedded_streams() -> void:
	# Clear any streams that might still be assigned in the scene.
	for child in get_children():
		if child is AudioStreamPlayer:
			(child as AudioStreamPlayer).stream = null


func _begin_threaded_audio_loads() -> void:
	for player_name in STREAM_PATHS.keys():
		var path: String = STREAM_PATHS[player_name]
		var player := get_node_or_null(player_name) as AudioStreamPlayer
		if player == null:
			continue
		_queue_stream_load(path, player)
#
	#var randomiser := get_node_or_null("Randomiser") as AudioStreamPlayer
	#if randomiser:
		#for path in RANDOMISER_STREAM_PATHS:
			#_queue_stream_load(path, randomiser, true)

	set_process(true)


func _queue_stream_load(path: String, player: AudioStreamPlayer, for_randomiser := false) -> void:
	if not _pending_stream_loads.has(path):
		_pending_stream_loads[path] = []
		## use_sub_threads=false: true races/crashes on mobile (Godot 4.6).
		ResourceLoader.load_threaded_request(path, "AudioStream", false)
	_pending_stream_loads[path].append({"player": player, "randomiser": for_randomiser})


func _process(_delta: float) -> void:
	if _pending_stream_loads.is_empty():
		_finish_audio_bootstrap()
		return

	var finished_paths: Array = []
	for path in _pending_stream_loads.keys():
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			var stream := ResourceLoader.load_threaded_get(path)
			_assign_loaded_stream(path, stream)
		elif status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			var stream := ResourceLoader.load(path, "AudioStream", ResourceLoader.CACHE_MODE_REUSE)
			_assign_loaded_stream(path, stream)
		finished_paths.append(path)

	for path in finished_paths:
		_pending_stream_loads.erase(path)

	if _pending_stream_loads.is_empty():
		_finish_audio_bootstrap()


func _finish_audio_bootstrap() -> void:
	if _audio_ready:
		set_process(false)
		return
	_audio_ready = true
	_init_shop_music()
	# Former autoplay ambient beds — start muted; start_bg_noise / tween raises them.
	for player_name in ["Birds", "Birds2", "Birds3", "Birds4", "Birds5"]:
		var ambient := get_node_or_null(player_name) as AudioStreamPlayer
		if ambient and ambient.stream and not ambient.playing:
			ambient.volume_db = -80.0
			ambient.play()
	set_process(false)


func _assign_loaded_stream(path: String, stream: Resource) -> void:
	if stream == null or not (stream is AudioStream):
		push_warning("Music: failed to load %s" % path)
		return
	var targets: Array = _pending_stream_loads.get(path, [])
	for entry in targets:
		var player: AudioStreamPlayer = entry.get("player")
		if player == null or not is_instance_valid(player):
			continue
		if entry.get("randomiser", false):
			var randomiser_stream := player.stream as AudioStreamRandomizer
			if randomiser_stream == null:
				randomiser_stream = AudioStreamRandomizer.new()
				player.stream = randomiser_stream
			randomiser_stream.add_stream(randomiser_stream.streams_count, stream as AudioStream)
		else:
			player.stream = stream as AudioStream


func start_bg_noise() -> void:
	tween_item(birds)
	tween_item(night_noises)
	await get_tree().create_timer(1.0).timeout
	tween_item(wind_noises)

func default_volumes() -> void:
	# Get all AudioStreamPlayers inside this node
	var songs : Array[AudioStreamPlayer] = [
		birds,
		night_noises,
		wind_noises,
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


func _init_shop_music() -> void:
	if shop_music == null:
		return
	shop_music.volume_db = -80.0
	if shop_music.stream and not shop_music.playing:
		shop_music.play()


## Start/restart the shop menu track (muted until raise).
func ensure_shop_music_playing() -> void:
	if shop_music == null:
		return
	if shop_music.stream == null:
		return
	if not shop_music.playing:
		shop_music.volume_db = -80.0
		shop_music.play()


## Fade in the dedicated shop-menu track (was BG_Music in the shop scene).
func raise_shop_menu_music() -> void:
	if shop_music == null:
		return
	ensure_shop_music_playing()
	var tween := create_tween()
	tween.tween_property(shop_music, "volume_db", shop_music_volume, 0.25)


## Fade out the dedicated shop-menu track.
func lower_shop_menu_music() -> void:
	
	if shop_music == null:
		return
	var tween := create_tween()
	tween.tween_property(shop_music, "volume_db", -80.0, 3.0)

	
func shop_music_raise_volume() -> void:
	if current_song == null:
		return
		
	var targ_volume := background_music_vol_in_shop
		
	var tween := create_tween()
	tween.tween_property(current_song, "volume_db", targ_volume, 3.0)
	
func shop_music_lower_volume() -> void:
	if current_song == null:
		return
	var tween := create_tween()
	#tween.tween_property(current_song, "volume_db", -80.0, 5.0)
	tween.tween_property(current_song, "volume_db", background_music_vol_out_of_shop, 3.0)
	await tween.finished
	#current_song.pitch_scale = 1.0
	
	
func game_won() -> void:
	var tween := create_tween()
	tween.tween_property(current_song, "volume_db", -80.0, 3.0)
	tween.parallel().tween_property($EndingSong, "volume_db", -35.0, 3.0) #.set_delay(1.0)
	#await tween.finished
	
func first_round() -> void:
	if current_song == null:
		return
		
	if current_song.playing:
		return

	if $Randomiser.playing:
		return 
		
	if $Randomiser.stream:
		$Randomiser.play()
	
	return
	
	
	#var curr_song : AudioStreamPlayer = current_song
	#var orig_vol = curr_song.volume_db
	#var _pitch_scale = curr_song.pitch_scale
	#curr_song.volume_db = -80.0
	#curr_song.pitch_scale = 0.1
	#var tween = create_tween().set_ease(Tween.EASE_IN).set_parallel()
	#tween.tween_interval(0.75)
	#tween.tween_property(curr_song, "pitch_scale", _pitch_scale, 1.5)
	#tween.tween_property(curr_song, "volume_db", orig_vol, 1.5)
	#tween.tween_property(curr_song, "playing", true, 0.1).set_delay(0.1)
	#await tween.finished
	
func start_opening_song() -> void:
	
	if opening_song == null:
		return
	if opening_song.stream == null:
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
	#tween.tween_property(curr_song, "pitch_scale", 0.01, 1.5)
	tween.tween_property(curr_song, "volume_db", -10.0, 1.0).as_relative()
	await tween.finished


func stop_opening_song() -> void:
	if opening_song == null:
		return
	var curr_song : AudioStreamPlayer = opening_song

	var tween = create_tween().set_ease(Tween.EASE_IN).set_parallel()
	#tween.tween_interval(0.75)
	tween.tween_property(curr_song, "pitch_scale", 0.01, 1.5)
	tween.tween_property(curr_song, "volume_db", -80.0, 1.5)
	await tween.finished
	curr_song.stop()


func _on_randomiser_finished() -> void:
	if $Randomiser.stream:
		$Randomiser.play()
