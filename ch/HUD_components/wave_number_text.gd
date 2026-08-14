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
@onready var strike_hud: Panel = $Strike_system2

var wave_count := 0

const slide_distance := 560.0
const fade_in_time := 0.15#0.35
const hold_time := 0.6 #0.8
const fade_out_time := 0.15
## Total show/hide duration for the persistent strike indicators.
const strike_hud_anim_time := 0.35

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
var _strike_hud_tween: Tween
var _strike_hud_visible := false



func _ready() -> void:
	EventBus.instance.egg_pulsed.connect(reset_each_wave)
	EventBus.instance.open_shop.connect(hide_strike_hud)
	_original_position = wave_panel.position
	_original_modulate = wave_panel.modulate

	_clear_original_position = clear_panel.position
	_clear_original_modulate = clear_panel.modulate

	_perfect_original_position = perfect_panel.position
	_perfect_original_modulate = perfect_panel.modulate
	
	_strike_panel_original_position = strike_panel.position
	_strike_panel_original_modulate = strike_panel.modulate

	# Persistent strike row stays hidden until a round begins.
	_set_strike_hud_hidden_immediate()
	if has_node("Strike_system3"):
		$Strike_system3.hide()
	
	end()
	

func reset() -> void:
	clear_has_been_called_this_wave = false
	result_has_been_shown_this_wave = false
	wave_count = 0
	strike_label.text = ''
	## Kill mid-flight strike tweens and pin panels back to their home positions.
	_restore_strike_panel_position()
	reset_strikes()
	end()
	show_strike_hud()

func reset_each_wave() -> void:
	clear_has_been_called_this_wave = false
	result_has_been_shown_this_wave = false
	clear_panel.show()

func start() -> void:
	wave_count += 1
	wave_label.text = "[i]%s" % _wave_display_name(wave_count, _total_waves_in_round())
	start_tween(wave_panel, _original_position, _original_modulate)


func _total_waves_in_round() -> int:
	var round_manager := get_tree().get_first_node_in_group('round_manager')
	if round_manager and round_manager.has_method('get_current_round_wave_count'):
		return maxi(int(round_manager.get_current_round_wave_count()), 1)
	return 3


## First–Ninth for waves 1–9; "Wave N" from 10 up. Last wave is always Final Wave.
func _wave_display_name(wave: int, total_waves: int) -> String:
	if wave >= total_waves:
		return 'Final Wave'

	const ORDINALS := [
		'First',
		'Second',
		'Third',
		'Fourth',
		'Fifth',
		'Sixth',
		'Seventh',
		'Eighth',
		'Ninth',
	]
	if wave >= 1 and wave <= ORDINALS.size():
		return '%s Wave' % ORDINALS[wave - 1]

	return 'Wave %d' % wave

func start_bonus() -> void:
	wave_label.text = "[font_size=150]BONUS!"
	
	start_tween(wave_panel, _original_position, _original_modulate)
	var flash_tween := create_tween()
	flash_tween.set_loops(10)
	flash_tween.tween_property(wave_label, "modulate:a", 0.0, 0.075)
	flash_tween.tween_property(wave_label, "modulate:a", 1.0, 0.075)
	await flash_tween.finished


func start_reloading() -> void:
	show()
	if wave_panel:
		wave_panel.show()
	wave_label.text = "[font_size=120]RELOADING"
	wave_label.modulate.a = 1.0
	start_tween(wave_panel, _original_position, _original_modulate)


func Xstart_bonus() -> void:
	wave_label.text = "[font_size=150]BONUS"
	start_tween(wave_panel, _original_position, _original_modulate)
	
func start_clear() -> void:
	if clear_has_been_called_this_wave:
		return
	
	if result_has_been_shown_this_wave:
		return
		
	result_has_been_shown_this_wave = true
	clear_has_been_called_this_wave = true
	
	clear_text_label.text = "[i]Wave Clear!"
	if wave_count >= _total_waves_in_round():
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
	
	clear_text_label.text = ""
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
	_restore_strike_panel_position()
	if has_node("Strike_system2") and $Strike_system2.has_method("reset"):
		$Strike_system2.reset()


func _restore_strike_panel_position() -> void:
	## Strike flash panel can end mid-tween with a bad Y if a round restarts early.
	if strike_panel:
		strike_panel.position = _strike_panel_original_position
		strike_panel.modulate = Color(
			_strike_panel_original_modulate.r,
			_strike_panel_original_modulate.g,
			_strike_panel_original_modulate.b,
			0.0
		)
	if strike_hud and strike_hud.has_method("restore_row_position"):
		strike_hud.restore_row_position()


func ensure_extra_strike_slot() -> void:
	if has_node("Strike_system2") and $Strike_system2.has_method("ensure_extra_strike_slot"):
		$Strike_system2.ensure_extra_strike_slot()


func show_strike_hud() -> void:
	if strike_hud == null:
		return
	_restore_strike_panel_position()
	if _strike_hud_tween and _strike_hud_tween.is_valid():
		_strike_hud_tween.kill()
	_strike_hud_visible = true
	strike_hud.show()
	strike_hud.modulate.a = 0.0
	_strike_hud_tween = create_tween()
	_strike_hud_tween.tween_property(strike_hud, "modulate:a", 1.0, strike_hud_anim_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func hide_strike_hud() -> void:
	if strike_hud == null:
		return
	if not _strike_hud_visible and not strike_hud.visible:
		return
	if _strike_hud_tween and _strike_hud_tween.is_valid():
		_strike_hud_tween.kill()
	_strike_hud_visible = false
	_strike_hud_tween = create_tween()
	_strike_hud_tween.tween_property(strike_hud, "modulate:a", 0.0, strike_hud_anim_time)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_strike_hud_tween.tween_callback(func() -> void:
		if is_instance_valid(strike_hud) and not _strike_hud_visible:
			strike_hud.hide()
	)


func _set_strike_hud_hidden_immediate() -> void:
	if _strike_hud_tween and _strike_hud_tween.is_valid():
		_strike_hud_tween.kill()
	_strike_hud_visible = false
	if strike_hud:
		strike_hud.hide()
		strike_hud.modulate.a = 0.0


func restart() -> void:
	reset_strikes()
	_set_strike_hud_hidden_immediate()
	end()
