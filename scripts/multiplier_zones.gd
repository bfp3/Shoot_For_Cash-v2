extends Area3D
@onready var money_label_3d: Label3D = $Money_Label3D
@export var current_multiplier := 2

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_entered.connect(_on_body_exited)
	EventBus.instance.egg_pulsed.connect(update_text)

func _on_body_entered(body: Node3D) -> void:
	if not body is RockInstance:
		return
	body.current_cash_multiplier = current_multiplier

func _on_body_exited(body: Node3D) -> void:
	return
	if not body is RockInstance:
		return

	body.current_cash_multiplier = 1.0


func update_text() -> void:
	money_label_3d.text = "x" + str(current_multiplier)
