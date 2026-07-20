extends Control

@onready var fade_in_sfx: AudioStreamPlayer = $FadeInSFX

@onready var wave_label: RichTextLabel = $Panel/WaveLabel
@onready var panel: Panel = $Panel

var wave_count := 0

@export var slide_distance := 250.0
@export var fade_in_time := 0.35
@export var hold_time := 0.8
@export var fade_out_time := 0.35

var _original_position: Vector2
var _original_modulate: Color


func _ready() -> void:
	_original_position = panel.position
	_original_modulate = panel.modulate
	
	end()
	

func reset() -> void:
	wave_count = 0
	end()


func start() -> void:
	wave_count += 1

	match wave_count:
		1:
			wave_label.text = "[i]First Wave"
			#fade_in_time = 0.5
			#hold_time = 1.05
			#fade_out_time = 0.35
		2:
			wave_label.text = "[i]Second Wave"
		3:
			wave_label.text = "[i]Final Wave"
		_:
			wave_label.text = "Wave %d" % wave_count


	start_tween()
	
func start_bonus() -> void:
	wave_label.text = "[i][rainbow][pulse]Bonus Round"	
	start_tween()
	
func start_tween() -> void:
	# Start off-screen to the right and invisible
	panel.position = _original_position - Vector2(slide_distance, 0)
	panel.modulate = Color(
		_original_modulate.r,
		_original_modulate.g,
		_original_modulate.b,
		0.0
	)
	
	var tween := create_tween()

	tween.tween_interval(0.2)
	# Slide in + fade in
	tween.tween_property(panel, "position", _original_position, fade_in_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(panel, "modulate:a", _original_modulate.a, fade_in_time)
	tween.parallel().tween_callback(fade_in_sfx.play.bind(0.5)).set_delay(0.3)
	tween.tween_interval(hold_time)

	# Slide out + fade out
	tween.tween_property(panel, "modulate:a", 0.0, fade_out_time)
	#tween.parallel().tween_property(panel, "position", _original_position + Vector2(slide_distance, 0), fade_out_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(panel, "position:x", 200.0, fade_out_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT).as_relative()
	tween.parallel().tween_callback(fade_in_sfx.play.bind(0.5)) #.set_delay(0.0)

func end() -> void:
	if is_instance_valid(panel):
		panel.position = _original_position
		panel.modulate = Color(
			_original_modulate.r,
			_original_modulate.g,
			_original_modulate.b,
			0.0
		)
