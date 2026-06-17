extends Control

@onready var title_label: RichTextLabel = $TitleLabel
@onready var rocks_hit_label: RichTextLabel = $NumberLabel

@onready var perfect_score_particles: GPUParticles2D = %perfectScoreParticles

enum ScoreResult {
	ZERO_SCORE,
	PARTIAL_SCORE,
	PERFECT_SCORE
}

var score_result : ScoreResult = ScoreResult.PARTIAL_SCORE

var target_pos : Vector2 = Vector2(1606.0,918.0)


func _ready() -> void:
	target_pos = global_position
	EventBus.instance.open_tally_card.connect(_move_to_center)
	EventBus.instance.open_shop.connect(_update_for_new_round)
	#EventBus.instance.close_shop.connect(_update_for_new_round)
	EventBus.instance.rock_destroyed.connect(_on_rock_destroyed)
	_move_to_corner()
	
func _update_for_new_round() -> void:
	await get_tree().create_timer(1.0).timeout
	show()
	var settings 		= gl_PlayerState.get_all()
	var total_rocks_in_round = settings.rock_limit
	rocks_hit_label.text =  str(total_rocks_in_round).pad_zeros(2)

func _on_rock_destroyed() -> void:
	#var settings 		= gl_PlayerState.get_all()
	#var total_rocks_in_round = settings.total_rocks_in_round
	#var total_rocks_destroyed = settings.total_rocks_destroyed
	#rocks_hit_label.text = 	str(total_rocks_in_round).pad_zeros(2)
	perfect_score_particles.amount += 1
	perfect_score_particles.emitting = true
	scale_tween()

func _move_to_corner() -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "global_position", target_pos, 0.3)
	tween.parallel().tween_property(title_label, "self_modulate", Color('3d3d3d'), 0.3)
	scale_tween()
	
func _move_to_center() -> void:
	return
	#calculate_score()
	#
	#var target_pos : Vector2 = Vector2(860.0,455.0)
	#var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	#tween.tween_interval(0.1)
	#tween.tween_property(self, "global_position", target_pos, 0.3)
	#tween.parallel().tween_property(title_label, "self_modulate", Color('FFFFFF'), 0.5)
	#await tween.finished
	#
	#if score_result == ScoreResult.PERFECT_SCORE:
		#perfect_score_particles.amount = 25
		#perfect_score_particles.emitting = true
		#var tween2 = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		#tween2.tween_property(rocks_hit_label, "scale", Vector2.ONE * 1.2, 0.1)
	#
	#await get_tree().create_timer(1.0).timeout
	#var settings 		= gl_PlayerState.get_all()
	#var total_rocks_destroyed = settings.total_rocks_destroyed
	#var total_rocks_in_round = settings.rock_limit
	#rocks_hit_label.text = str(total_rocks_in_round).pad_zeros(2)
	
func scale_tween() -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(rocks_hit_label, "scale", Vector2.ONE * 1.1, 0.1)
	tween.tween_property(rocks_hit_label, "scale", Vector2.ONE, 0.1)
	


func calculate_score() -> void:
	var settings 		= gl_PlayerState.get_all()
	#var current_round 	= settings.round
	#var items_hit 		= gl_PlayerState.get_item_hits(current_round)
	
	var total_rocks_in_round = settings.total_rocks_in_round
	var total_rocks_destroyed = settings.total_rocks_destroyed
	rocks_hit_label.text = 	str(total_rocks_in_round).pad_zeros(2)
		
	if total_rocks_destroyed == 0:
		score_result = ScoreResult.ZERO_SCORE
	elif total_rocks_destroyed == total_rocks_in_round:
		score_result = ScoreResult.PERFECT_SCORE
	else:
		score_result = ScoreResult.PARTIAL_SCORE
		
		
