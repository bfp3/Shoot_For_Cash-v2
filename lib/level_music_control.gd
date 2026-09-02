extends Node

@onready var birds: AudioStreamPlayer = $Birds
@onready var night_noises: AudioStreamPlayer = $NightNoises

@onready var wind_noises: AudioStreamPlayer = $WindNoises
@onready var shop_music: AudioStreamPlayer = $Shop_Music
@onready var game_over_music: AudioStreamPlayer = get_node_or_null("GameOver_Music") as AudioStreamPlayer

var default_volume_map : Dictionary = {}

@export var current_song : AudioStreamPlayer
@export var opening_song : AudioStreamPlayer
@onready var title_select_music: AudioStreamPlayer = get_node_or_null("Title_Select_Music") as AudioStreamPlayer

@export var background_music_vol_in_shop := -40.0
@export var background_music_vol_out_of_shop := -40.0
## Dedicated shop-menu track volume when the shop is open.
@export var shop_music_volume := -30.0
## Strike-out / continue / game-over track (USERSONG164).
@export var game_over_music_volume := -30.0
## Title difficulty / level select track.
@export var title_select_music_volume := 0.0

var _music_silenced := false

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
	#"Shop_Music": "res://sfx/shop_music.ogg",
	"Shop_Music": "res://sfx/USERSONG166.ogg",
	"GameOver_Music": "res://sfx/USERSONG164.ogg",
	"Title_Select_Music": "res://sfx/greyscale_compressed.ogg",
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
var _title_select_tween: Tween
var _game_over_music_tween: Tween
var _opening_fade_tween: Tween
var _opening_song_rest_db := -35.0
var _opening_song_rest_pitch := 1.0


func _ready() -> void:
	if opening_song:
		_opening_song_rest_db = opening_song.volume_db
		_opening_song_rest_pitch = opening_song.pitch_scale
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


## Cut gameplay / script / menu music immediately (strike-out). Ambient birds/wind stay.
func stop_all_music_immediate() -> void:
	_music_silenced = true
	var keep := {
		"Birds": true,
		"Birds2": true,
		"Birds3": true,
		"Birds4": true,
		"Birds5": true,
		"NightNoises": true,
		"WindNoises": true,
		"GameOver_Music": true,
	}
	for child in get_children():
		if child is AudioStreamPlayer and not keep.has(child.name):
			(child as AudioStreamPlayer).stop()
	if current_song and is_instance_valid(current_song) and current_song.playing:
		current_song.stop()
	if opening_song and is_instance_valid(opening_song) and opening_song.playing:
		opening_song.stop()


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


## Fade in USERSONG164 at strike-out. Keeps playing through continue / game over.
func raise_game_over_music(fade_sec := 2.0) -> void:
	var player := _ensure_game_over_player()
	if player == null:
		return
	if player.stream == null:
		var path := String(STREAM_PATHS.get("GameOver_Music", ""))
		if not path.is_empty() and ResourceLoader.exists(path):
			player.stream = load(path) as AudioStream
	if player.stream == null:
		return
	if player.playing and _game_over_music_tween != null and is_instance_valid(_game_over_music_tween):
		return
	_kill_game_over_music_tween()
	if not player.playing:
		player.volume_db = -80.0
		player.play()
	elif absf(player.volume_db - game_over_music_volume) < 0.4:
		return
	_game_over_music_tween = create_tween()
	_game_over_music_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_game_over_music_tween.tween_property(player, "volume_db", game_over_music_volume, maxf(fade_sec, 0.05))


## Fade out USERSONG164 after the continue screen closes.
func lower_game_over_music(fade_sec := 3.0) -> void:
	var player := _ensure_game_over_player()
	if player == null or not player.playing:
		return
	_kill_game_over_music_tween()
	var song := player
	_game_over_music_tween = create_tween()
	_game_over_music_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_game_over_music_tween.tween_property(song, "volume_db", -80.0, maxf(fade_sec, 0.05))
	_game_over_music_tween.tween_callback(func() -> void:
		if is_instance_valid(song):
			song.stop()
	)


func _ensure_game_over_player() -> AudioStreamPlayer:
	if game_over_music != null and is_instance_valid(game_over_music):
		return game_over_music
	game_over_music = get_node_or_null("GameOver_Music") as AudioStreamPlayer
	if game_over_music == null:
		game_over_music = AudioStreamPlayer.new()
		game_over_music.name = "GameOver_Music"
		game_over_music.bus = &"MusicBus"
		game_over_music.volume_db = -80.0
		add_child(game_over_music)
	return game_over_music


func _kill_game_over_music_tween() -> void:
	if _game_over_music_tween != null and is_instance_valid(_game_over_music_tween):
		_game_over_music_tween.kill()
	_game_over_music_tween = null

	
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
	_music_silenced = false
	if current_song == null:
		return
		
	if current_song.playing:
		return

	if $Randomiser:
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
	fade_out_title_select_music(0.6)
	if opening_song == null:
		return
	if opening_song.stream == null:
		return
		
	var dur : float = 0.7
	var curr_song : AudioStreamPlayer = opening_song
	var orig_vol = _opening_song_rest_db
	var _pitch_scale = _opening_song_rest_pitch
	curr_song.volume_db = -80.0
	curr_song.pitch_scale = 0.1
	_kill_opening_fade_tween()
	var tween = create_tween().set_ease(Tween.EASE_IN).set_parallel()
	_opening_fade_tween = tween
	#tween.tween_interval(0.75)
	tween.tween_property(curr_song, "pitch_scale", _pitch_scale, dur)
	tween.tween_property(curr_song, "volume_db", orig_vol, dur)
	tween.tween_property(curr_song, "playing", true, 0.1)#.set_delay(0.1)
	await tween.finished

func _on_start_button_pressed() -> void:
	_fade_out_opening_song(1.2)
	play_title_select_music(1.4)


func _fade_out_opening_song(duration := 1.2) -> void:
	if opening_song == null or not is_instance_valid(opening_song):
		return
	_kill_opening_fade_tween()
	if not opening_song.playing:
		return
	var song := opening_song
	_opening_fade_tween = create_tween()
	_opening_fade_tween.set_ease(Tween.EASE_IN)
	_opening_fade_tween.tween_property(song, "volume_db", -80.0, duration)
	_opening_fade_tween.tween_callback(func() -> void:
		if is_instance_valid(song):
			song.stop()
	)


func play_title_select_music(fade_sec := 1.2) -> void:
	_music_silenced = false
	var player := _ensure_title_select_player()
	if player == null:
		return
	if player.stream == null:
		var path := String(STREAM_PATHS.get("Title_Select_Music", ""))
		if not path.is_empty() and ResourceLoader.exists(path):
			player.stream = load(path) as AudioStream
	if player.stream == null:
		return
	_kill_title_select_tween()
	if not player.playing:
		player.volume_db = -80.0
		player.play()
	elif absf(player.volume_db - title_select_music_volume) < 0.4:
		return
	_title_select_tween = create_tween()
	_title_select_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_title_select_tween.tween_property(player, "volume_db", title_select_music_volume, maxf(fade_sec, 0.05))


func fade_out_title_select_music(fade_sec := 1.2) -> void:
	var player := _ensure_title_select_player()
	if player == null or not player.playing:
		return
	_kill_title_select_tween()
	var song := player
	_title_select_tween = create_tween()
	_title_select_tween.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_title_select_tween.tween_property(song, "volume_db", -80.0, maxf(fade_sec, 0.05))
	_title_select_tween.tween_callback(func() -> void:
		if is_instance_valid(song):
			song.stop()
	)


func fade_out_title_menu_music() -> void:
	stop_opening_song()
	fade_out_title_select_music(1.2)


func _ensure_title_select_player() -> AudioStreamPlayer:
	if title_select_music != null and is_instance_valid(title_select_music):
		return title_select_music
	title_select_music = get_node_or_null("Title_Select_Music") as AudioStreamPlayer
	if title_select_music == null:
		title_select_music = AudioStreamPlayer.new()
		title_select_music.name = "Title_Select_Music"
		title_select_music.bus = &"MusicBus"
		title_select_music.volume_db = -80.0
		add_child(title_select_music)
	return title_select_music


func _kill_title_select_tween() -> void:
	if _title_select_tween != null and is_instance_valid(_title_select_tween):
		_title_select_tween.kill()
	_title_select_tween = null


func _kill_opening_fade_tween() -> void:
	if _opening_fade_tween != null and is_instance_valid(_opening_fade_tween):
		_opening_fade_tween.kill()
	_opening_fade_tween = null


func stop_opening_song() -> void:
	if opening_song == null:
		return
	_kill_opening_fade_tween()
	var curr_song : AudioStreamPlayer = opening_song
	if not curr_song.playing:
		return
	_opening_fade_tween = create_tween().set_ease(Tween.EASE_IN).set_parallel()
	#tween.tween_interval(0.75)
	_opening_fade_tween.tween_property(curr_song, "pitch_scale", 0.01, 1.5)
	_opening_fade_tween.tween_property(curr_song, "volume_db", -80.0, 1.5)
	_opening_fade_tween.chain().tween_callback(curr_song.stop)


func _on_randomiser_finished() -> void:
	if _music_silenced:
		return
	if $Randomiser.stream:
		$Randomiser.play()
