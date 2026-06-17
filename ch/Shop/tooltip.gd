class_name Tooltip extends PanelContainer

#@export var OFFSET := Vector2.ONE * 60
var tooltip_tween: Tween = null

func _ready() -> void:
	self.hide()

func _toggle_tooltip(_showing : bool, _description : String = "") -> void:
	if _showing:
		fade_in()
		$RichTextLabel.text = _description
		
	else:
		fade_out()


func fade_in() -> void:
	show()
	if tooltip_tween:
		tooltip_tween.kill()
		
	var dur := 0.25
	tooltip_tween = create_tween()
	#tooltip_tween.tween_interval(0.2)
	tooltip_tween.tween_property(self, "modulate", Color.WHITE, dur)

func fade_out() -> void:
	if tooltip_tween:
		tooltip_tween.kill()
		
	var dur := 0.1
	tooltip_tween = create_tween()
	
	tooltip_tween.tween_property(self, "modulate", Color.TRANSPARENT, dur)
	await tooltip_tween.finished
	hide()
	
#func _input(event: InputEvent) -> void:
	#if visible and event is InputEventMouse:
		#global_position = get_global_mouse_position() + OFFSET
