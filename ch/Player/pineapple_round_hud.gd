extends Control

var tween_blinking : Tween = null
var active := false

@onready var pineapple_particles: GPUParticles2D = %PineappleParticles
@onready var pineapple_texture: TextureRect = $PineappleTexture


func _ready() -> void:
	EventBus.instance.pineapple_round_bought.connect(start)
	EventBus.instance.pineapple_round_used.connect(stop)
	
	
func start() -> void:
	show()
	pineapple_particles.emitting = true
	active = true
	%Flicker_sound.play()
	start_blinking_tween()
	
func stop() -> void:
	active = false
	show()
	pineapple_texture.show()

	
func panel_tween() -> void:
	var tween = create_tween()
	tween.tween_property($Panel, 'modulate', Color(4.416, 0.0, 0.0), 0.5)
	
func start_blinking_tween() -> void:
	pineapple_texture.modulate = Color.WHITE
	var tween = create_tween()
	tween.tween_property(pineapple_texture, 'modulate:a', 0.3, 0.1)
	tween.tween_property(pineapple_texture, 'modulate:a', 0.9, 0.1)
	await tween.finished
	if active:
		start_blinking_tween()
	else:
		fade_modulate_tween()


func fade_modulate_tween() -> void:
	pineapple_texture.modulate.a = 1.0
	var tween = create_tween()
	tween.tween_property(pineapple_texture, 'modulate', Color('666666'), 0.5)
	tween.parallel().tween_property($Panel, 'modulate', Color.WHITE, 0.5)
