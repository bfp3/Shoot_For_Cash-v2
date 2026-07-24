extends Control

@onready var fade_in_sfx: AudioStreamPlayer = $FadeInSFX

@onready var wave_label: RichTextLabel = $Panel/WaveLabel
@onready var wave_panel: Panel = $Panel

@onready var clear_panel: Panel = $Clear_Panel
@onready var clear_text_label: RichTextLabel = $Clear_Panel/ClearTextLabel

@onready var perfect_panel: Panel = $Perfect_Panel
@onready var perfect_label: RichTextLabel = $Perfect_Panel/PerfectLabel


@onready var strike_panel: Panel = $Strike_system
@onready var strike_label: RichTextLabel = $Strike_system/StrikeLabel

var wave_count := 0

@export var slide_distance := 250.0
@export var fade_in_time := 0.35
@export var hold_time := 0.8
@export var fade_out_time := 0.35

var _original_position: Vector2
var _original_modulate: Color

var _clear_original_position: Vector2
var _clear_original_modulate: Color

var _perfect_original_position: Vector2
var _perfect_original_modulate: Color

var _strike_panel_original_position : Vector2
var _strike_panel_original_modulate : Color

var clear_has_been_called_this_wave := false
var result_has_been_shown_this_wave := false


var strikes_int : int = 0



func _ready() -> void:
	EventBus.instance.egg_pulsed.connect(reset_each_wave)
	_original_position = wave_panel.position
	_original_modulate = wave_panel.modulate

	_clear_original_position = clear_panel.position
	_clear_original_modulate = clear_panel.modulate

	_perfect_original_position = perfect_panel.position
	_perfect_original_modulate = perfect_panel.modulate
	
	_strike_panel_original_position = strike_panel.position
	_strike_panel_original_modulate = strike_panel.modulate
	
	end()
	

func reset() -> void:
	clear_has_been_called_this_wave = false
	result_has_been_shown_this_wave = false
	wave_count = 0
	strike_label.text = ''
	end()

func reset_each_wave() -> void:
	clear_has_been_called_this_wave = false
	result_has_been_shown_this_wave = false
	clear_panel.show()

func start() -> void:
	wave_count += 1

	match wave_count:
		1:
			wave_label.text = "[i]First Wave"
		2:
			wave_label.text = "[i]Second Wave"
		3:
			wave_label.text = "[i]Final Wave"
		_:
			wave_label.text = "Wave %d" % wave_count


	start_tween(wave_panel, _original_position, _original_modulate)
	
func start_bonus() -> void:
	wave_label.text = "[i][rainbow]Bonus Round"
	start_tween(wave_panel, _original_position, _original_modulate)
	
func start_clear() -> void:
	if clear_has_been_called_this_wave:
		return
	
	if result_has_been_shown_this_wave:
		return
		
	result_has_been_shown_this_wave = true
	clear_has_been_called_this_wave = true
	
	clear_text_label.text = "[i]Wave Clear!"
	if wave_count >= 3:
		clear_text_label.text = "[i]Round Clear!"
	start_tween(clear_panel, _clear_original_position, _clear_original_modulate)

func add_strike() -> void:
	strikes_int += 1
	if strikes_int > 3:
		#strike_label.text = 'X X X'
		return

	#match strikes_int:
		#1:
			#strike_label.text = 'X '
		#2:
			#strike_label.text = 'X X '
		#3:
			#strike_label.text = 'X X X'
		#_:
			#strike_label.text = ''

	# Individual strike flashes stay on the old center panel.
	# Persistent indicators + three-strike finale live on Strike_system2.
	start_tween(strike_panel, _strike_panel_original_position, _strike_panel_original_modulate)


func start_miss() -> void:
	if result_has_been_shown_this_wave:
		return
		
	result_has_been_shown_this_wave = true
	
	clear_text_label.text = "[i]You're Out!"
	clear_text_label.modulate = Color("c70102ff")
	start_tween(clear_panel, _clear_original_position, _clear_original_modulate)

func start_perfect() -> void:
	result_has_been_shown_this_wave = true
	clear_has_been_called_this_wave = true
	
	clear_panel.modulate.a = 0.0
	clear_panel.hide()
	clear_panel.position = _clear_original_position

	perfect_label.text = "[i][wave]PERFECT!"
	start_tween(perfect_panel, _perfect_original_position, _perfect_original_modulate)


func start_tween(panel: Control, original_position: Vector2, original_modulate: Color) -> void:
	panel.position = original_position - Vector2(slide_distance, 0)
	panel.modulate = Color(
		original_modulate.r,
		original_modulate.g,
		original_modulate.b,
		0.0
	)

	var tween := create_tween()

	tween.tween_interval(0.2)
	tween.tween_property(panel, "position", original_position, fade_in_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(panel, "modulate:a", original_modulate.a, fade_in_time)
	tween.parallel().tween_callback(fade_in_sfx.play.bind(0.5)).set_delay(0.3)
	tween.tween_interval(hold_time)

	tween.tween_property(panel, "modulate:a", 0.0, fade_out_time)
	tween.parallel().tween_property(panel, "position:x", 200.0, fade_out_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).as_relative()
	tween.parallel().tween_callback(fade_in_sfx.play.bind(0.5))
	
	
	
func end() -> void:
	if is_instance_valid(wave_panel):
		wave_panel.position = _original_position
		wave_panel.modulate = Color(
			_original_modulate.r,
			_original_modulate.g,
			_original_modulate.b,
			0.0
		)

	if is_instance_valid(clear_panel):
		clear_panel.position = _clear_original_position
		clear_panel.modulate = Color(
			_clear_original_modulate.r,
			_clear_original_modulate.g,
			_clear_original_modulate.b,
			0.0
		)

	if is_instance_valid(perfect_panel):
		perfect_panel.position = _perfect_original_position
		perfect_panel.modulate = Color(
			_perfect_original_modulate.r,
			_perfect_original_modulate.g,
			_perfect_original_modulate.b,
			0.0
		)
		
	if is_instance_valid(strike_panel):
		strike_panel.position = _strike_panel_original_position
		strike_panel.modulate = Color(
			_strike_panel_original_modulate.r,
			_strike_panel_original_modulate.g,
			_strike_panel_original_modulate.b,
			0.0
		)

func reset_strikes() -> void:
	strikes_int = 0
	strike_label.text = ''
	if has_node("Strike_system2") and $Strike_system2.has_method("reset"):
		$Strike_system2.reset()


func restart() -> void:
	reset_strikes()
	end()
