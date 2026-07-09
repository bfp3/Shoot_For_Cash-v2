extends TextureRect
class_name CRT_TV_Filter

@export var setting_1 := 0.0
@export var setting_2 := 0.5
@export var setting_3 := 1.0

@export var start_up := false

var shader_mat: ShaderMaterial
var tween_node: Tween
var tween_brightness_node : Tween
var tween_brightness_start_up : Tween
var tween_shut_down : Tween
var tween_warp : Tween

func _ready():
	
	EventBus.instance.egg_pulsed.connect(egg_pulsed)
	
	shader_mat = material
	if shader_mat is ShaderMaterial:
		shader_mat.set_shader_parameter("warp_amount", 0.15) # Set starting value
	else:
		print("No ShaderMaterial found!")
	
	# Create a Tween node
	#tween_node = create_tween()
	#tween_brightness_node = create_tween()
	#tween_shut_down = create_tween()
	#tween_warp = create_tween()
	
	shader_mat.set_shader_parameter("crack_opacity", 0.0)
	shader_mat.set_shader_parameter("crack_count", 0)
	shader_mat.set_shader_parameter("aberration", 0.000)

func taking_damage_tween() -> void:
	if shader_mat == null:
		return

	var tween_damage = create_tween()
	show()
	shader_mat.set_shader_parameter("warp_amount", 0.0)
	# Flash in
	tween_damage.tween_method(
		func(val):
			shader_mat.set_shader_parameter("vignette_intensity", val),
		shader_mat.get_shader_parameter("vignette_intensity"),
		0.8,
		0.2
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween_damage.tween_interval(1.5)
	# Flash back out
	tween_damage.tween_method(
		func(val):
			shader_mat.set_shader_parameter("vignette_intensity", val),
		0.8,
		0.0,
		3.5
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tween_damage.finished
	hide()
	
	

func egg_pulsed() -> void:
	if shader_mat == null:
		return
	
	tween_brightness_start_up = create_tween().set_parallel(true)
	var _dur : float = 0.5
	
	# WARP_AMOUNT
	var _start_value_warp : float = shader_mat.get_shader_parameter("warp_amount")
	var _end_value_warp : float = 0.02
	
	tween_brightness_start_up.tween_method(
		func(val):
			shader_mat.set_shader_parameter("warp_amount", val), _start_value_warp, _end_value_warp, _dur
	).set_trans(Tween.TRANS_LINEAR) #.set_ease(Tween.EASE_IN)


func reset_hud() -> void:
	if shader_mat == null:
		return
	
	tween_brightness_start_up = create_tween().set_parallel(true)
	var _dur : float = 0.7
	
	var _start_value : float = shader_mat.get_shader_parameter("brightness")
	var _end_value : float = 1.0
	
	# WARP_AMOUNT
	var _start_value_warp : float = shader_mat.get_shader_parameter("warp_amount")
	var _end_value_warp : float = 0.1
	
	tween_brightness_start_up.tween_method(
		func(val):
			shader_mat.set_shader_parameter("warp_amount", val), _start_value_warp, _end_value_warp, _dur
	).set_trans(Tween.TRANS_LINEAR) #.set_ease(Tween.EASE_IN)
	
	tween_brightness_start_up.tween_method(
		func(val):
			shader_mat.set_shader_parameter("brightness", val), _start_value, _end_value, _dur
	).set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT).set_delay(_dur / 2)
	
	

func round_end() -> void:
	if shader_mat == null:
		return
	
	tween_brightness_start_up = create_tween().set_parallel(true)
	var _dur : float = 0.5
	
	var _start_value : float = 1.0
	var _end_value : float = 0.5
	
	# WARP_AMOUNT
	var _start_value_warp : float = 0.25
	var _end_value_warp : float = 5.0
		
	tween_brightness_start_up.tween_method(
		func(val):
			shader_mat.set_shader_parameter("warp_amount", val), _start_value_warp, _end_value_warp, _dur
	).set_trans(Tween.TRANS_LINEAR) #.set_ease(Tween.EASE_IN)
	
	#tween_brightness_start_up.tween_method(
		#func(val):
			#shader_mat.set_shader_parameter("brightness", val), _start_value, _end_value, _dur - 0.25
	#).set_trans(Tween.TRANS_LINEAR).set_delay(0.25) #.set_ease(Tween.EASE_IN)
	
	
func Xround_over_fade_in() -> void:
	if shader_mat == null:
		return
	
	tween_brightness_start_up = create_tween().set_parallel(true)
	var _dur : float = 1.5
	
	var _start_value : float = 1.0
	var _end_value : float = 0.0
	
	# WARP_AMOUNT
	var _start_value_warp : float = 0.25
	var _end_value_warp : float = 50.0
		
	tween_brightness_start_up.tween_method(
		func(val):
			shader_mat.set_shader_parameter("warp_amount", val), _start_value_warp, _end_value_warp, _dur
	).set_trans(Tween.TRANS_LINEAR) #.set_ease(Tween.EASE_IN)
	
	tween_brightness_start_up.tween_method(
		func(val):
			shader_mat.set_shader_parameter("brightness", val), _start_value, _end_value, _dur - 0.25
	).set_trans(Tween.TRANS_LINEAR).set_delay(0.25) #.set_ease(Tween.EASE_IN)
	
func title_screen() -> void:
	if shader_mat == null:
		return
	
	var tween_title = create_tween()
	
	var start_value = shader_mat.get_shader_parameter("warp_amount")
	tween_title.tween_method(
		func(val):
			shader_mat.set_shader_parameter("warp_amount", val),
		start_value,
		0.0,
		0.1 # Duration in seconds
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tween_title.parallel().tween_method(
		func(val):
			shader_mat.set_shader_parameter("brightness", val),
		start_value,
		0.0,
		0.1 # Duration in seconds
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	tween_title.tween_method(
		func(val):
			shader_mat.set_shader_parameter("brightness", val),
		start_value,
		1.0,
		1.5# Duration in seconds
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
func crt_start_up() -> void:
	if start_up:
		tween_start_up()
		#tween(0.0, 2.0)
		var HUD_feedback = get_tree().get_first_node_in_group("HUD_feedback_corner")
		if HUD_feedback:
			HUD_feedback.bootup_sequence()
			
func start_game() -> void:
	# WARP_AMOUNT
	var _dur := 0.5
	var _start_value_warp : float = shader_mat.get_shader_parameter("warp_amount")
	var _end_value_warp : float = 0.05
	
	tween_brightness_start_up = create_tween()
	tween_brightness_start_up.tween_method(
		func(val):
			shader_mat.set_shader_parameter("warp_amount", val), _start_value_warp, _end_value_warp, _dur
	).set_trans(Tween.TRANS_LINEAR) #.set_ease(Tween.EASE_IN)
	
	var HUD_feedback = get_tree().get_first_node_in_group("HUD_feedback_corner")
	if HUD_feedback:
		HUD_feedback.bootup_sequence()

func game_won_sequence() -> void:
	tween_game_won_shrink_screen()

func tween_start_up() -> void:

	if shader_mat == null:
		return
	
	tween_brightness_start_up = create_tween()
	
	#var start_value = shader_mat.get_shader_parameter("warp_amount")
	
	#tween_brightness_start_up.tween_method(
		#func(val):
			#shader_mat.set_shader_parameter("warp_amount", val),
	
	var _start_value = shader_mat.get_shader_parameter("brightness")
	
	tween_brightness_start_up.tween_method(
		func(val):
			shader_mat.set_shader_parameter("brightness", val),
		0.0,
		1.0,
		#5.0 f# Duration in seconds
		0.05
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
func tween_game_won_shrink_screen() -> void:
	
	tween_brightness(0.0)
	
	if shader_mat == null:
		return
	
	tween_shut_down = create_tween()
	
	#var start_value = shader_mat.get_shader_parameter("warp_amount")
	
	#tween_shut_down.tween_method(
		#func(val):
			#shader_mat.set_shader_parameter("warp_amount", val),
	
	var start_value = shader_mat.get_shader_parameter("warp_amount")
	
	
	tween_shut_down.tween_method(
		func(val):
			shader_mat.set_shader_parameter("warp_amount", val),
		start_value,
		100.0,
		2.0 # Duration in seconds
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	
	await get_tree().create_timer(3.0).timeout
	tween(0.0, 2.0)
	tween_start_up()
	
func crt_tween_warp_amount(target_value: float, duration : float) -> void:
		
	if shader_mat == null:
		return
	
	tween_warp = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	var start_value = shader_mat.get_shader_parameter("warp_amount")
	
	tween_warp.tween_method(
		func(val):
			shader_mat.set_shader_parameter("warp_amount", val), start_value, target_value, duration)
	await tween_warp.finished
	

func tween(target_value: float, duration : float) -> void:
	if shader_mat == null:
		return
	
	# Kill existing tween if it’s running
	if tween_node.is_running():
		tween_node.kill()
	
	# Start a new tween
	tween_node = create_tween()
	
	var start_value = shader_mat.get_shader_parameter("warp_amount")
	
	tween_node.tween_method(
		func(val):
			shader_mat.set_shader_parameter("warp_amount", val),
		start_value,
		target_value,
		duration # Duration in seconds
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	

#func crt_brightness_tween(target_value: float, dur : float) -> void:
	#
	#var start_value = shader_mat.get_shader_parameter("brightness")
	#var tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	#tween.tween_method(
		#func(val):
			#shader_mat.set_shader_parameter("brightness", val),	start_value, target_value, dur)
	
func tween_brightness(target_value: float) -> void:
	return
	#if shader_mat == null:
		#return
	#
	## Kill existing tween if it’s running
	#if tween_brightness_node.is_running():
		#tween_brightness_node.kill()
	#
	## Start a new tween
	#tween_brightness_node = create_tween()
	#
	#var start_value = shader_mat.get_shader_parameter("brightness")
	#
	#tween_brightness_node.tween_method(
		#func(val):
			#shader_mat.set_shader_parameter("brightness", val),
		#start_value,
		#target_value,
		#0.2 # Duration in seconds
	#).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)



func pause_filter() -> void:
	if shader_mat == null:
		return

	#shader_mat.set_shader_parameter("roll_speed", 1.0)
	#shader_mat.set_shader_parameter("roll_size", 8.0)
	#shader_mat.set_shader_parameter("roll", true)54
	#shader_mat.set_shader_parameter("scanlines_opacity", 0.4)
	#shader_mat.set_shader_parameter("scanlines_width", 0.25)
	#shader_mat.set_shader_parameter("grille_opacity", 0.3)
	#shader_mat.set_shader_parameter("resolution", Vector2(960.0,540.0))
	#shader_mat.set_shader_parameter("pixelate", true)

func unpause_filter() -> void:
	if shader_mat == null:
		return
		
	shader_mat.set_shader_parameter("roll_speed", 0.0)
	shader_mat.set_shader_parameter("roll_size", 0.0)
	shader_mat.set_shader_parameter("roll", false)
	shader_mat.set_shader_parameter("scanlines_opacity", 0.0)
	shader_mat.set_shader_parameter("scanlines_width", 0.0)
	shader_mat.set_shader_parameter("grille_opacity", 0.0)
	#shader_mat.set_shader_parameter("pixelate", false)

#func crt_vignette_intensity(target_value: float, duration : float) -> void:
	#if shader_mat == null:
		#return
	#
	## Start a new tween
	#var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	#var start_value = shader_mat.get_shader_parameter("vignette_intensity")
	#
	#tween.tween_method(
		#func(val):
			#shader_mat.set_shader_parameter("vignette_intensity", val), start_value, target_value, duration)

func add_crack(crack_amount : float) -> void:
	shader_mat.set_shader_parameter("crack_opacity", 1.0)
	shader_mat.set_shader_parameter("crack_count", crack_amount)
	
func player_offline() -> void:
	var tween_special = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var start_value = shader_mat.get_shader_parameter("aberration")

	tween_special.tween_method(
		func(val):
			shader_mat.set_shader_parameter("aberration", val), start_value, 1.0, 0.25)
	tween_special.tween_method(
		func(val):
			shader_mat.set_shader_parameter("brightness", val), start_value, 0.1, 1.0)
