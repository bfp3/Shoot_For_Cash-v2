extends RichTextLabel

@onready var tooltip : Tooltip = $Tooltip
@export var tooltip_dataset : String = "tooltip_total_cash"

func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	
func _on_mouse_entered() -> void:
	var description = gl_DataSet.get_string(tooltip_dataset, 0)
	
	var tooltip_description : String = description
	
	if tooltip:
		tooltip._toggle_tooltip(true, str(tooltip_description))


func _on_mouse_exited() -> void:
	if tooltip:
		tooltip._toggle_tooltip(false)
