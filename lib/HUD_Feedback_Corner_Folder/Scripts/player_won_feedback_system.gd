extends Control

@onready var pulse: TextureRect = $Pulse_point_1/Pulse
@onready var pulse_2: TextureRect = $Pulse_point_2/Pulse
@onready var pulse_3: TextureRect = $Pulse_point_3/Pulse

var counter := 0

func _ready() -> void:
	pulse.hide()
	pulse_2.hide()
	pulse_3.hide()

func start_sequence() -> void:
	
	pulse_ring(pulse)
	
	#await get_tree().create_timer(0.5).timeout
	#pulse_ring(pulse_2)
	#await get_tree().create_timer(0.5).timeout
	#pulse_ring(pulse_3)
	
func pulse_ring(texture : TextureRect) -> void:
	var new_pulse = texture.duplicate()
	texture.get_parent().add_child(new_pulse)
	texture.show()
	new_pulse.modulate = Color('8a8a8a8a')
	var tween = create_tween().set_ease(Tween.EASE_IN)
	tween.tween_property(new_pulse, "modulate", Color('FFFFFF00'), 1.5)
	tween.parallel().tween_property(new_pulse, "scale", new_pulse.scale * 2.0, 1.5)
	tween.tween_interval(0.25)
	await tween.finished
	#counter += 1
	#if counter >= 3:
		#counter = 0
		#start_sequence()
	if new_pulse:
		new_pulse.queue_free()
		
	start_sequence()
		
