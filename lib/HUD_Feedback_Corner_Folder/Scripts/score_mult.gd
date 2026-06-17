extends Control

@onready var acquired: TextureRect = $Acquired
@onready var remaining: TextureRect = $Remaining

@onready var label: Label = $Label
@onready var hbox_container: HBoxContainer = $GridContainer

var points_accumulated := 0

# Dots required per rank-up: rank 1 → 2 requires 3, 2 → 3 requires 8, etc.
var rank_thresholds := [3, 5, 8, 12, 15]

#func _ready() -> void:
	#EventBus.instance.mult_increase.connect(increase_mult)
	#EventBus.instance.mult_decrease.connect(decrease_mult)
	#EventBus.instance.mult_decrease.connect(reset_mult)
#
	#EventBus.instance.standard_cannonball_destroyed.connect(reset_mult)
	#EventBus.instance.special_cannonball_destroyed_astray.connect(increase_mult)
	#EventBus.instance.red_cannonball_destroyed.connect(increase_mult)
#
	#ScoreGl.score_multiplier = clamp(ScoreGl.score_multiplier, 1, rank_thresholds.size() + 1)
	#label.text = 'x' + str(ScoreGl.score_multiplier)
	#update_dots()

func get_required_for_current_rank(multiplier: int) -> int:
	if multiplier - 1 >= rank_thresholds.size():
		return rank_thresholds[-1]
	return rank_thresholds[multiplier - 1]

func update_dots() -> void:
	for child in hbox_container.get_children():
		child.queue_free()

	await get_tree().process_frame  # ensure children are cleared before adding new ones

	var required = get_required_for_current_rank(ScoreGl.score_multiplier)
	var acquired_count = clamp(points_accumulated, 0, required)
	var remaining_count = max(0, required - acquired_count)

	for i in range(acquired_count):
		var dot = acquired.duplicate()
		dot.visible = true
		hbox_container.add_child(dot)

	for i in range(remaining_count):
		var dot = remaining.duplicate()
		dot.visible = true
		hbox_container.add_child(dot)

func increase_mult() -> void:
	points_accumulated += 1
	var required = get_required_for_current_rank(ScoreGl.score_multiplier)

	if points_accumulated >= required:
		ScoreGl.score_multiplier += 1
		ScoreGl.score_multiplier = clamp(ScoreGl.score_multiplier, 1, rank_thresholds.size() + 1)
		points_accumulated = 0

	label.text = 'x' + str(ScoreGl.score_multiplier)
	update_dots()

func decrease_mult() -> void:
	ScoreGl.score_multiplier = max(1, ScoreGl.score_multiplier - 1)
	points_accumulated = 0
	label.text = 'x' + str(ScoreGl.score_multiplier)
	update_dots()

func reset_mult() -> void:
	ScoreGl.score_multiplier = 1
	points_accumulated = 0
	label.text = 'x' + str(ScoreGl.score_multiplier)
	update_dots()
