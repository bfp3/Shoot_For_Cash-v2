class_name RocksRemainingCounter extends Control

@onready var rock_texture_2d: TextureRect = $Container/RockTexture2D

@onready var container: Control = $Container
@onready var label_rocks_remaining: RichTextLabel = $Container/LabelRocksRemaining

var rocks_currently_active := 0
@export var round_manager : RoundManager
#
#func _ready() -> void:
	#GlobalPlayerMoney.moss_rocks_total = 0
	#GlobalPlayerMoney.moss_rocks_remaining = 0
	##EventBus.instance.rock_destroyed.connect(update_rocks_destroyed)
	##EventBus.instance.rock_created.connect(update_rocks_created)
	##EventBus.instance.egg_pulsed.connect(update_counter)
	#
##func update_rocks_destroyed() -> void:
	##rocks_currently_active -= 1
	##update_label()
	##
	##GlobalPlayerMoney.moss_rocks_remaining -= 1
	##if GlobalPlayerMoney.moss_rocks_remaining <= 0:
	###if rocks_currently_active <= 0 && round_manager.current_round_state == round_manager.RoundState.ROUND_IN_PROGRESS:
		###EventBus.instance.game_won.emit()
		###round_manager.enter_state(round_manager.RoundState.ROUND_END)
		##print('This Ocean is Clean! - receive an upgrade and can go to a new area')
#
#func update_rocks_created() -> void:
	#GlobalPlayerMoney.moss_rocks_total += 1
	#GlobalPlayerMoney.moss_rocks_remaining = GlobalPlayerMoney.moss_rocks_total
	#rocks_currently_active += (1 * 4)
	#update_label()
	#
#func update_counter() -> void:
	#var duration := 1.0
	#var elapsed := 0.0
	#var dt := 1.0 / 60.0
	#var start_value := 0.0
	#var end_value := float(rocks_currently_active)
	#
	#$ReloadSound.pitch_scale = 0.5
#
	##await get_tree().create_timer(0.20).timeout
	#var _counter := 0.0
	#while elapsed < duration:
		##rocks_currently_active -= 1
		#
		#elapsed += dt
		#var t : float = clamp(elapsed / duration, 0.0, 1.0)
		#var eased := 1.0 - pow(1.0 - t, 3.0)
#
		#_counter = lerp(start_value, end_value, eased)
#
		#label_rocks_remaining.text = str(int(_counter)).pad_zeros(2)
#
		#$ReloadSound.pitch_scale += 0.1
		#$ReloadSound.play()
		#await get_tree().create_timer(dt).timeout
	#
	##rocks_currently_active = 0
	#update_label()
	#
	#
	#
	#
	#
	##
	##var counter := 0
	##while counter < rocks_currently_active:
		##counter += 1
		##var tween = create_tween()
		##label_rocks_remaining.text = str(counter).pad_zeros(2)
		##tween.tween_interval(0.04)
		##await tween.finished
	##
	##label_rocks_remaining.text = str(rocks_currently_active).pad_zeros(2)
#
	#
	#
#func update_label() -> void:
	#rocks_currently_active = clamp(rocks_currently_active, 0, 9999)
	#label_rocks_remaining.text = str(rocks_currently_active).pad_zeros(2)
#
#func reset_rocks() -> void:
#
	#var duration := 0.25
	#var elapsed := 0.0
	#var dt := 1.0 / 60.0
	#var start_value := 0.0
	#var end_value := 0.0
	#
	#$ReloadSound.pitch_scale = 1.0
	#$ReloadSound.play()
	#await get_tree().create_timer(0.20).timeout
	#while elapsed < duration:
		##rocks_currently_active -= 1
		#await get_tree().create_timer(dt).timeout
		#elapsed += dt
		#var t : float = clamp(elapsed / duration, 0.0, 1.0)
		#var eased := 1.0 - pow(1.0 - t, 3.0)
#
		#rocks_currently_active = lerp(start_value, end_value, eased)
#
		#update_label()
#
		#$ReloadSound.pitch_scale += 0.1
		#$ReloadSound.play()
	#
	#rocks_currently_active = 0
	#update_label()
	#
	#
	##if rocks_currently_active > 0:
		##rocks_currently_active -= 1
##
		##reset_rocks()
	##
	##else:
		##rocks_currently_active = 0
		#
#func shot_hit_something_blink() -> void:
	#var tween = create_tween()
	#tween.tween_property(rock_texture_2d, "modulate", Color('878787'), 0.4)
	#tween.tween_property(rock_texture_2d, "modulate", Color('87878796'), 0.8)
	#await tween.finished
