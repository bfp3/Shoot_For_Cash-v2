extends Node

@onready var birds: AudioStreamPlayer = $Birds
@onready var night_noises: AudioStreamPlayer = $NightNoises
@onready var oasis: AudioStreamPlayer = $Oasis
@onready var ending_song: AudioStreamPlayer = $EndingSong
@onready var wind_noises: AudioStreamPlayer = $WindNoises
@onready var shop_music: AudioStreamPlayer = $Shop_Music
# Stores each song's original/default volume
var default_volume_map : Dictionary = {}

@export var current_song : AudioStreamPlayer
@export var opening_song : AudioStreamPlayer

@export var background_music_vol_in_shop := -40.0
@export var background_music_vol_out_of_shop := -40.0
## Dedicated shop-menu track volume when the shop is open.
@export var shop_music_volume := -30.0


func _ready() -> void:
	default_volumes()
	_init_shop_music()


#func start_bg_music() -> void:
	##tween_item(oasis)
	#tween_item($MathAnim)

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
		oasis,

		wind_noises,

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


func _init_shop_music() -> void:
	if shop_music == null:
		return
	shop_music.volume_db = -80.0
	if not shop_music.playing:
		shop_music.play()


## Start/restart the shop menu track (muted until raise).
func ensure_shop_music_playing() -> void:
	if shop_music == null:
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
		
	$Randomiser.play()
	
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
	#tween.tween_property(curr_song, "pitch_scale", 0.01, 1.5)
	tween.tween_property(curr_song, "volume_db", -7.0, 1.0).as_relative()
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
	$Randomiser.play()
