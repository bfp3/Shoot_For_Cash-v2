extends Area3D
@onready var money_label_3d: Label3D = $Money_Label3D
@export var current_multiplier := 2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	EventBus.instance.egg_pulsed.connect(update_text)

func _on_body_entered(body: Node3D) -> void:
	if not body is RockInstance:
		return
	
	body.went_through_cash_multi_zone()
	body.current_cash_multiplier = current_multiplier




func update_text() -> void:
	money_label_3d.text = "x" + str(current_multiplier)
