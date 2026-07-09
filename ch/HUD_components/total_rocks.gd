extends Control

@export var use_incrementing_counter := false



@onready var rocks_hit_label: RichTextLabel = $NumberLabel
@onready var perfect_score_particles: GPUParticles2D = %perfectScoreParticles
@export var on_tally_sheet := false

var orig_pos : Vector2 = Vector2(-180.0,-130.0)
@export var temp_disabled := false

enum ScoreResult {
	ZERO_SCORE,
	PARTIAL_SCORE,
	PERFECT_SCORE
}

var score_result : ScoreResult = ScoreResult.PARTIAL_SCORE

var target_pos : Vector2 = Vector2(1606.0,918.0)


func _ready() -> void:
	if temp_disabled:
		modulate.a = 0.0
		return
	#orig_pos = position
	target_pos = global_position
	EventBus.instance.open_tally_card.connect(display_round_counter)
	EventBus.instance.open_shop.connect(_update_for_new_round)

	EventBus.instance.rock_destroyed.connect(_on_rock_destroyed)
	
	
func _update_for_new_round() -> void:
	if !on_tally_sheet:
		var tween = create_tween().set_trans(Tween.TRANS_SINE)
		tween.tween_property(self, "modulate:a", 1.0, 0.1)

	show()

	if use_incrementing_counter:
		update_label()
		#rocks_hit_label.text = str(gl_PlayerState.dataset.round).pad_zeros(2) + "/20"
		return

	#var settings = gl_PlayerState.get_all()
	#var _total_rocks_in_round = settings.rock_limit
	update_label()
	
func update_label() -> void:
	var round_manager : RoundManager = get_tree().get_first_node_in_group('round_manager')
	var total_rounds := round_manager.rounds_to_complete
	rocks_hit_label.text = str(gl_PlayerState.dataset.round) + "[i][color=DDDDDD]/[/color][color=ffc700]" + str(total_rounds) +"[/color]"

func display_round_counter() -> void:

	# Alternate mode
	if use_incrementing_counter:

		update_label()

		if !on_tally_sheet:
			var fade = create_tween().set_trans(Tween.TRANS_SINE)
			fade.tween_property(self, "modulate:a", 0.0, 0.1)
			await fade.finished
			return

		# Always play the perfect-score animation.
		var tween = create_tween()
		tween.tween_interval(2.0)
		tween.tween_property(self, "scale", Vector2.ONE * 0.48, 0.15)
		tween.parallel().tween_property(rocks_hit_label, "self_modulate", Color("b3b3b3ff"), 0.15)
		tween.tween_property(rocks_hit_label, "modulate:a", 0.0, 0.05)
		tween.tween_property(rocks_hit_label, "modulate:a", 1.0, 0.05)
		tween.tween_interval(1.5)
		tween.parallel().tween_property(self, "scale", Vector2.ONE * 0.46, 0.15)

		return

	# ---------------- Original behaviour ----------------

	if !on_tally_sheet:
		var tween = create_tween().set_trans(Tween.TRANS_SINE)
		tween.tween_property(self, "modulate:a", 0.0, 0.1)
		await tween.finished
		calculate_score()
		return

	calculate_score()

	match score_result:
		ScoreResult.PERFECT_SCORE:
			var tween = create_tween()
			tween.tween_interval(2.0)
			tween.tween_property(self, "scale", Vector2.ONE * 1.0, 0.15)
			tween.parallel().tween_property(rocks_hit_label, "self_modulate", Color("00ff4c"), 0.15)
			tween.parallel().tween_callback(_update_for_new_round).set_delay(0.5)
			tween.tween_property(rocks_hit_label, "modulate:a", 0.0, 0.05)
			tween.tween_property(rocks_hit_label, "modulate:a", 1.0, 0.05)
			tween.tween_interval(1.5)
			tween.parallel().tween_property(self, "scale", Vector2.ONE * 0.46, 0.15)

		ScoreResult.ZERO_SCORE:
			var tween = create_tween()
			tween.tween_property(rocks_hit_label, "self_modulate", Color("ff1700"), 0.2)
			tween.tween_interval(1.5)
			tween.tween_property(rocks_hit_label, "self_modulate", Color.WHITE, 0.2)

		ScoreResult.PARTIAL_SCORE:
			var tween2 = create_tween().set_trans(Tween.TRANS_SINE)
			tween2.tween_property(self, "modulate:a", 1.0, 0.15)
			tween2.tween_interval(0.25)
			await tween2.finished
			shake_label()
			_update_for_new_round()


func _on_rock_destroyed() -> void:
	#var settings 		= gl_PlayerState.get_all()
	#var total_rocks_in_round = settings.total_rocks_in_round
	#var total_rocks_destroyed = settings.total_rocks_destroyed
	#rocks_hit_label.text = 	str(total_rocks_in_round).pad_zeros(2)
	perfect_score_particles.amount += 1
	perfect_score_particles.emitting = true
	scale_tween()

	
func shake_label() -> void:
	var tween = create_tween().set_trans(Tween.TRANS_SINE)
	tween.tween_property(rocks_hit_label, "modulate:a", 0.2, 0.1)
	tween.tween_property(rocks_hit_label, "modulate:a", 1.0, 0.1)
	tween.tween_property(rocks_hit_label, "modulate:a", 0.2, 0.1)
	tween.tween_property(rocks_hit_label, "modulate:a", 1.0, 0.1)
	tween.tween_property(rocks_hit_label, "modulate:a", 0.2, 0.1)
	tween.tween_property(rocks_hit_label, "modulate:a", 1.0, 0.1)



	
	#global_position = Vector2()
func scale_tween() -> void:
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(rocks_hit_label, "scale", Vector2.ONE * 1.1, 0.1)
	tween.tween_property(rocks_hit_label, "scale", Vector2.ONE, 0.1)
	


func calculate_score() -> void:
	var settings 		= gl_PlayerState.get_all()
	#var current_round 	= settings.round
	#var items_hit 		= gl_PlayerState.get_item_hits(current_round)
	
	var _total_rocks_in_round = settings.total_rocks_in_round
	var total_rocks_destroyed = settings.total_rocks_destroyed
	var total_rocks_remaining = settings.total_rocks_in_round_remaining
	#rocks_hit_label.text = 	str(total_rocks_in_round).pad_zeros(2)
		
	if total_rocks_destroyed == 0:
		score_result = ScoreResult.ZERO_SCORE
		
	if total_rocks_destroyed > 1 && total_rocks_remaining <= 0:
		score_result = ScoreResult.PERFECT_SCORE
		
	else:
		score_result = ScoreResult.PARTIAL_SCORE
		
		
		
		

#func Xdisplay_round_counter() -> void:
	#if !on_tally_sheet:
		##_update_for_new_round()
		#var tween = create_tween().set_trans(Tween.TRANS_SINE)
		#tween.tween_property(self, "modulate:a", 0.0, 0.1)
		#await tween.finished
		#calculate_score()
		#return
	#
	#calculate_score()
#
	##await get_tree().create_timer(1.0).timeout
	#
	#match score_result:
		#ScoreResult.PERFECT_SCORE:
			##old_method()
#
			#var tween = create_tween()
			##tween.tween_property(self, "modulate:a", 0.0, 0.01)
			#tween.tween_interval(2.0)
			#tween.tween_property(self, "scale", Vector2.ONE * 1.0, 0.15)
			#tween.parallel().tween_property(rocks_hit_label, "self_modulate", Color("00ff4c"), 0.15)
			#tween.parallel().tween_callback(_update_for_new_round).set_delay(0.5)
#
			#tween.tween_property(rocks_hit_label, "modulate:a", 0.0, 0.05)
			#tween.tween_property(rocks_hit_label, "modulate:a", 1.0, 0.05)
			#tween.tween_interval(1.5)
	#
			#tween.parallel().tween_property(self, "scale", Vector2.ONE * 0.46, 0.15)
			#
			##perfect_score_particles.amount = 25
			##perfect_score_particles.emitting = true
			#
		#ScoreResult.ZERO_SCORE:
			#var tween = create_tween()
			#tween.tween_property(rocks_hit_label, "self_modulate", Color("ff1700"), 0.2)
			#tween.tween_interval(1.5)
			#tween.tween_property(rocks_hit_label, "self_modulate", Color.WHITE, 0.2)
#
		#ScoreResult.PARTIAL_SCORE:
#
			#var tween2 = create_tween().set_trans(Tween.TRANS_SINE)
			##tween2.tween_property(self, "modulate:a", 0.0, 0.01)
			##tween2.tween_interval(1.2)
			#tween2.tween_property(self, "modulate:a", 1.0, 0.15)
			#tween2.tween_interval(0.25)
			#await tween2.finished
			#shake_label()
			#_update_for_new_round()
