extends TextureButton

@onready var data_manager: Node = $"../Data_manager"
var default_color: Color

@export var next_scene : String
@export var corresponding_texture : TextureRect

@export var reveal_dur := 0.5
@onready var reveal_sound: AudioStreamPlayer = $'../reveal_sound'

@export var not_ready := false

var transitioning := true


func _ready() -> void:
	EventBus.instance.button_pushed_in_level_select.connect(fade_out)
	default_color = modulate
	pressed.connect(_on_pressed)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	fade_in()
	
	
func fade_in() -> void:
	modulate = Color.TRANSPARENT
	var tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	tween.tween_interval(1.1)
	tween.tween_property(self, "modulate", default_color, 1.0).set_ease(Tween.EASE_OUT)
	await tween.finished
	transitioning = false
	
func fade_out() -> void:
	transitioning = true
	
	var tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	tween.tween_interval(0.5)
	tween.tween_property(self, "modulate",  Color.TRANSPARENT, 0.5).set_ease(Tween.EASE_OUT)


func _on_mouse_entered() -> void:
	if transitioning:
		return
	
	modulate = Color.ORANGE
	#reveal_sound.volume_db = -30.0
	reveal_sound.play()
	corresponding_texture.modulate = Color.TRANSPARENT
	corresponding_texture.show()
	var tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(corresponding_texture, "modulate", Color.WHITE, reveal_dur).set_ease(Tween.EASE_OUT)
	
	if not_ready:
		if %not_ready_label:
			%not_ready_label.show()
			
	else:
		$level_description.show()

func _on_mouse_exited() -> void:
	if transitioning:
		return
	
	modulate = default_color
	#reveal_sound.pitch_scale = 2.5
	#reveal_sound.volume_db = -35.0
	#reveal_sound.play()
	#$'../reveal_sound2'.play()
	var tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	tween.tween_property(corresponding_texture, "modulate", Color.TRANSPARENT, reveal_dur).set_ease(Tween.EASE_OUT)
	
	if not_ready:
		if %not_ready_label:
			%not_ready_label.hide()
			
	else:
		$level_description.hide()

func _on_pressed() -> void:
	EventBus.instance.button_pushed_in_level_select.emit()
	
	data_manager.button_pushed = true
	data_manager.next_scene = next_scene
	data_manager.switch_scene()
