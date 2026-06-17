extends Control

var tween_blinking : Tween = null
var active := false

@onready var tooltip: Tooltip = $Tooltip
@export var using_tooltip := false

func _ready() -> void:
	$Tooltip.hide()
	$Button.mouse_entered.connect(_on_focus_entered)
	$Button.mouse_exited.connect(_on_focus_exited)

func start() -> void:
	show()
	$SkyMineParticles2D.emitting = true
	active = true
	%Flicker_sound.play()
	%SkyMineLabel.modulate.a = 1.0
	start_blinking_tween()
	#panel_tween()
	
func panel_tween() -> void:
	var tween = create_tween()
	tween.tween_property($Panel, 'modulate', Color(4.416, 0.0, 0.0), 0.5)
	
func start_blinking_tween() -> void:
	%SkyMineLabel.modulate = Color.WHITE
	var tween = create_tween()
	tween.tween_property(%SkyMineLabel, 'modulate:a', 0.3, 0.1)
	tween.tween_property(%SkyMineLabel, 'modulate:a', 0.9, 0.1)
	await tween.finished
	if active:
		start_blinking_tween()
	else:
		fade_modulate_tween()


func fade_modulate_tween() -> void:
	%SkyMineLabel.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(%SkyMineLabel, 'modulate', Color('666666'), 0.5)
	tween.parallel().tween_property($Panel, 'modulate', Color.WHITE, 0.5)

	
func stop() -> void:
	active = false
	show()
	%SkyMineLabel.show()


func _on_focus_entered() -> void:
	if tooltip && using_tooltip:
		var bbcode_des : String = "[pulse freq=2.0 color=#ffc70099 ease=-2.0]Fire A Sky Mine[/pulse]"
		if tooltip:
			tooltip._toggle_tooltip(true, bbcode_des)
func _on_focus_exited() -> void:
	if tooltip && using_tooltip:
		if tooltip:
			tooltip._toggle_tooltip(false)
