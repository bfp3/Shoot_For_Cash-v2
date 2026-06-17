extends Control
@onready var main_control: Control = $Main_control
@onready var pineapple_ring: Node2D = $Main_control/PineappleRing
@onready var background_gradient: TextureRect = $Background_gradient

var tween_fade : Tween = null

signal finished_fade_out()

func _ready() -> void:
	BackgroundForTransition.instant_fade_in()
	main_control.modulate = Color('FFFFFF00')
	pineapple_ring.modulate = Color('FFFFFF00')
	fade_in()
	fade_music_in()
	BackgroundForTransition.fade_out()
	
func fade_music_in() -> void:
	var dur : float = 2.0
	var music : AudioStreamPlayer = $SFX/Incidental_music
	var default_vol : float = music.volume_db
	music.volume_db = -70.0
	music.play()
	var tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	#tween.tween_interval(0.35)
	tween.tween_property(music, "volume_db", default_vol, dur)
	
	
func fade_in() -> void:
	tween_fade = create_tween().set_trans(Tween.TRANS_LINEAR)
	tween_fade.tween_interval(0.35)
	tween_fade.tween_property(main_control, "modulate", Color('FFFFFF'), 1.0).set_ease(Tween.EASE_OUT)
	tween_fade.tween_property(background_gradient, "modulate", Color('ffffff09'), 1.0).set_ease(Tween.EASE_OUT)
	tween_fade.tween_property(pineapple_ring, "modulate", Color('FFFFFF'), 1.0).set_ease(Tween.EASE_IN)


func fast_forward() -> void:
	fade_out()
	
func fade_out() -> void:
	
	if tween_fade:
		tween_fade.kill()
		
	var dur : float = 0.5
	
	var tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(main_control, "modulate", Color('FFFFFF00'), dur).set_ease(Tween.EASE_OUT)
	tween.tween_property(background_gradient, "modulate", Color('ffffff00'), dur).set_ease(Tween.EASE_OUT)
	tween.tween_property(pineapple_ring, "modulate", Color('FFFFFF00'), dur).set_ease(Tween.EASE_IN)
	await tween.finished
	finished_fade_out.emit()
	
#func prepare_for_transition() -> void:
	#BackgroundForTransition.fade_in()
	#await get_tree().create_timer(0.15).timeout
	#var next_scene = GameManager.next_level_directory()
	#get_tree().change_scene_to_file(next_scene)
