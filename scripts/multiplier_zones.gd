extends Area3D
@onready var money_label_3d: Label3D = $Money_Label3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	# Make sure it's actually a rock that entered
	if not body.is_in_group("rock") and not ("cash_value" in body):
		return

	var multiplier: float = get_current_multiplier()

	# Apply the multiplier to the rock's cash value
	body.cash_value *= multiplier

	# Neutralise the multiplier so it doesn't apply again
	neutralize_multiplier()


func get_current_multiplier() -> float:
	# Parses text like "x2", "X3", or "2" into a float
	var raw_text: String = money_label_3d.text
	var cleaned: String = raw_text.lstrip("xX").strip_edges()
	if cleaned.is_valid_float():
		return cleaned.to_float()
	return 1.0 # fallback if parsing fails


func neutralize_multiplier() -> void:
	money_label_3d.text = "x1"
