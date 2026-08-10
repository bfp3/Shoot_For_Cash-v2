class_name TallyCard extends Control

var perfect_bonus := 0
var pass_bonus := -1
@onready var fail_label: RichTextLabel = %Fail_Label

@onready var grade_label: RichTextLabel = %GradeLabel
@onready var grade_cash_label : RichTextLabel = %GradeCashLabel

@onready var bonuses_label: RichTextLabel = $CenterContainer/MainPanel/MainPanel/CashHboxcontainer/CashEarned/BonusesLabel
@onready var bonuses_cash_label: RichTextLabel = %BonusesCashLabel

@onready var grand_total_label: RichTextLabel = %TotalLabel
@onready var grand_total_cash_label: RichTextLabel = %TotalCashCashLabel
#@onready var cash_number_label: RichTextLabel = $CenterContainer/MainPanel/MainPanel/CashOut/NumberLabel

enum ScoreResult {
	ZERO_SCORE,
	PARTIAL_SCORE,
	PERFECT_SCORE
}

var start_sequence := false
var score_result : ScoreResult = ScoreResult.PARTIAL_SCORE

#@onready var hazard_mine: HBoxContainer = $CenterContainer/MainPanel/MainPanel/Item_List2/Panel/ScrollContainer/SalvageTable/Mine

#@onready var score_label: RichTextLabel = $CenterContainer/MainPanel/MainPanel/CashHboxcontainer2/TotalRocks/NumberLabel #$CenterContainer/MainPanel/MainPanel/CashHboxcontainer/TotalRocks/NumberLabel
@onready var penalties_number_label: RichTextLabel = $CenterContainer/MainPanel/MainPanel/CashHboxcontainer/Fines/NumberLabel

var full_score := false

@onready var reveal_skill_sfx: AudioStreamPlayer = $SFX/reveal_skill_sfx
@export var round_manager : RoundManager
@export var cash_earned_label : RichTextLabel
@export var total_cash_earned_label : RichTextLabel
@export var test_mode := false
#@onready var game_progress: HBoxContainer = $CenterContainer/MainPanel/MainPanel/GameProgress

enum State {
	INACTIVE,
	OPEN_MENU,
	IN_MENU,
	CLOSE_MENU
}

var current_cash : int = 0
var current_bonuses : int = 0
var current_fines : int = 0

var current_state : State = State.INACTIVE
var updating_stats := false
var menu_in_display := false

var selected_stats : Array

var default_scale := Vector2.ONE
var default_position := Vector2.ZERO
var default_pivot_offset := Vector2.ZERO

var total_cash_earned : int = 0
var total_penalties_earned : int = 0


func _ready() -> void:
	EventBus.instance.open_tally_card.connect(enter_state.bind(State.OPEN_MENU))
	%'100_percent'.modulate.a = 0.0
	# STORE DEFAULT TRANSFORMS
	default_scale = scale
	default_position = position

	# BOTTOM RIGHT PIVOT
	default_pivot_offset = Vector2(0, size.y)
	pivot_offset = default_pivot_offset

	hide()

	if test_mode:
		enter_state(State.OPEN_MENU)

	
func enter_state(new_state: State) -> void:
	current_state = new_state
	
	match new_state:
		State.INACTIVE:
			update_inactive()
		
		State.OPEN_MENU:
			update_open_menu()
		
		State.IN_MENU:
			update_in_menu()
		
		State.CLOSE_MENU:
			update_close_menu()
		_:
			print("No State Exists - Skill Menu Script")


func update_inactive() -> void:
	pass


func start_fail_sequence() -> void:

	#grade_cash_label.text = ""
	grade_cash_label.text = ""
	grade_cash_label.modulate.a = 1.0
	#grade_label.text = "[i]Try Again"
	grade_label.text = ""
	grade_label.modulate.a = 1.0
	grade_cash_label.modulate.a = 1.0

	if gl_PlayerState.dataset.fines < 0:
		fail_label.text = "-$" + str(abs(gl_PlayerState.dataset.fines))
	bonuses_label.text = 'Fines'
	bonuses_cash_label.modulate.a = 0.0
	grand_total_cash_label.show()
	grand_total_label.text = "Total Losses"
	fail_label.show()
	if abs(gl_PlayerState.dataset.fines) > 0:
		grand_total_cash_label.text = "-$" + str(abs(gl_PlayerState.dataset.fines))
		
	else:
		grand_total_cash_label.text = "$0"
		
	bonuses_label.show()


	return

	
	
func start_perfect_sequence() -> void:
	
	#start_fail_sequence()
	#return
	
	await get_tree().create_timer(0.5, false).timeout
	$SFX/shop_purchase_02.play()
	$SFX/shop_purchase_01.play()
	var dur := 0.33
	grade_label.modulate.a = 1.0
	grade_label.text = "[i][wave]Clear!"
	
	if gl_PlayerState.dataset.total_current_strikes <= 0:
		grade_label.text = "[i][wave]PERFECT!"
		
	perfect_bonus = int(gl_DataSet.get_value('reward_perfect_round', 0))
	
	# 2. GRADE CASH LABEL
	grade_cash_label.text = '$' + str(perfect_bonus)
	grade_cash_label.modulate.a = 1.0
	gl_PlayerState.add_cash(perfect_bonus)

	# decorative particle flourish, fires in the background (non-blocking)
	
	grand_total_cash_label.modulate.a = 1.0
	# PAUSE
	await get_tree().create_timer(0.25, false).timeout
	#await get_tree().create_timer(dur / 2, false).timeout

	# 3. BONUSES
	$SFX/shop_purchase_02.play()
	apply_bonus_cash()
	#$CenterContainer/MainPanel/MainPanel/CashHboxcontainer/CashEarned.modulate.a = 1.0
	$CenterContainer/MainPanel/MainPanel/CashHboxcontainer/Fines.modulate.a = 0.0

	grand_total_cash_label.modulate.a = 0.0
	grand_total_cash_label.text = "$" + str(int(gl_PlayerState.dataset.bonus_cash + perfect_bonus - gl_PlayerState.dataset.fines))
	grand_total_cash_label.pivot_offset_ratio = Vector2(0.5,0.5)
	#await get_tree().create_timer(0.5, false).timeout

	await get_tree().create_timer(dur, false).timeout
	
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	tween.tween_property(grand_total_cash_label, 'modulate:a', 1.0, 0.15)
	tween.parallel().tween_property(grand_total_cash_label, 'scale', Vector2.ONE * 1.1, 0.15)
	
	tween.parallel().tween_property($CenterContainer/MainPanel/MainPanel/CashOut/BackgroundParticles, "emitting", true, 0.1).set_delay(0.1)
	tween.parallel().tween_callback($SFX/shop_purchase_02.play).set_delay(0.1)
	tween.tween_property(grand_total_cash_label, 'scale', Vector2.ONE, 0.15)
	#await get_tree().create_timer(dur / 3, false).timeout
	await tween.finished
	#$CenterContainer/MainPanel/MainPanel/CashOut/BackgroundParticles.emitting = true
	#$SFX/shop_purchase_02.play()
	
	
	await get_tree().create_timer(dur, false).timeout
	await get_tree().create_timer(dur, false).timeout
	#await get_tree().create_timer(dur, false).timeout
	
	await perfect_particles()
	
	#await get_tree().create_timer(dur, false).timeout
	return



func check_white_rocks() -> void:
	
	grand_total_label.show()
	bonuses_label.show()
	fail_label.hide()
	fail_label.text = "$0"
	grade_label.text = ""
	grade_cash_label.text = ""
	grade_cash_label.modulate.a = 1.0
	
	bonuses_label.text = 'BONUSES'
	bonuses_cash_label.text = ""
	
	grand_total_label.text = 'TOTAL WINNINGS'
	grand_total_cash_label.text = ""
	
	start_sequence = true
	
	gl_PlayerState.subtract_penalties_from_cash()
	
	#
	#if gl_PlayerState.dataset.total_hazards > 0:
		#start_fail_sequence()
		#start_sequence = false
		#return
		
	if gl_PlayerState.dataset.total_current_strikes >= 3:
		start_fail_sequence()
		start_sequence = false
		return
		
	#if white_rocks > 0 && gl_PlayerState.dataset.perfect_rounds < 3:
		#start_fail_sequence()
		#start_sequence = false
		#return
		
	else:
		await start_perfect_sequence()
		start_sequence = false
		return
		
	#elif white_rocks == 0 && gl_PlayerState.dataset.perfect_rounds >= 3:
		#await start_perfect_sequence()
		#start_sequence = false
		#return
		
	#elif white_rocks == 0:
		#await start_pass_sequence()
		#start_sequence = false
		#
		#return
		
	#else:
		#%GradeLabel.text = ""
		#print('Some other condition was met')
		#start_sequence = false

func perfect_particles() -> void:
	
	
	play_cash_sfx()
	#%perfectScoreParticles.emitting = true
	#await get_tree().create_timer(0.25, false).timeout
	
	$SFX/perfect_score.play()
	var stamp := $'CenterContainer/MainPanel/MainPanel/100_percent/RichTextLabel'
	stamp.scale = Vector2.ONE * 3.0
	var tween = create_tween()
	tween.tween_property(%'100_percent', "modulate:a", 1.0, 0.2)
	tween.parallel().tween_property(stamp, "scale", Vector2.ONE * 1.0, 0.2)
	tween.parallel().tween_callback($SFX/Stamp_sfx.play.bind(0.05)).set_delay(0.15)
	#tween.tween_interval(0.1)
	tween.tween_property(self, "scale", Vector2.ONE * 0.998, 0.1)
	tween.tween_property(self, "scale", Vector2.ONE, 0.05)
	
	tween.tween_interval(1.0)
	

	await tween.finished


func apply_bonus_cash() -> void:
	var bonus_cash = gl_PlayerState.dataset.bonus_cash
	#gl_PlayerState.add_bonus(bonus_cash)
	bonuses_cash_label.show()
	bonuses_cash_label.modulate.a = 1.0
	bonuses_cash_label.text = "$" + str(bonus_cash)

func update_open_menu() -> void:
	if menu_in_display:
		return
	
	check_white_rocks()
	menu_in_display = true
	sfx_open_tally()

	modulate.a = 0.0
	scale = Vector2.ONE * 0.01
	position = default_position
	pivot_offset = default_pivot_offset

	show()

	# OPEN ANIMATION
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_OUT)

	tween.parallel().tween_property(self, "scale", default_scale, 0.3)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.18)

	await tween.finished
	await reveal_stats()
	
	enter_state(State.IN_MENU)
	var next := get_node_or_null("NextRound") as Control
	UiFocus.grab_in(self, next)

	
	await get_tree().create_timer(2.0, false).timeout
	
	while start_sequence:
		await get_tree().process_frame
	
	await get_tree().create_timer(1.0, false).timeout
	
	_on_shop_pressed()
		
func update_close_menu() -> void:
	
	
	# ENSURE PIVOT IS CORRECT
	pivot_offset = default_pivot_offset

	var tween := create_tween()

	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN)

	tween.parallel().tween_property(self, "scale", Vector2.ONE * 0.01, 0.4)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.16)

	await tween.finished

	# PERFECT RESET AFTER CLOSE
	scale = default_scale
	modulate.a = 1.0
	position = default_position
	menu_in_display = false
	updating_stats = false
	total_cash_earned = 0
	total_penalties_earned = 0
	$'%100_percent'.modulate.a = 0.0
	
	hide()




func update_in_menu() -> void:
	update_stats_visual()
	
	await get_tree().create_timer(2.0, false).timeout
	
	

func update_stats_visual() -> void:
	if updating_stats:
		return
	
	updating_stats = true


func play_cash_sfx() -> void:
	$SFX/shop_purchase_01.play()
	$SFX/shop_purchase_02.play()
	$SFX/shop_purchase_03.play()

func reveal_stats() -> void:

	# Clear existing displayed skills first
	var _orig_pitch_scale :float = reveal_skill_sfx.pitch_scale
	

	for skill in selected_stats:

		var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		reveal_skill_sfx.play()
		
		tween.parallel().tween_property(skill, "self_modulate:a", 1.0, 0.1)
		tween.parallel().tween_property(skill, "scale", Vector2.ONE * 1.15, 0.1)
		tween.tween_property(skill, "scale", Vector2.ONE, 0.05)
		
		await tween.finished
		reveal_skill_sfx.pitch_scale += 0.1
		
	reveal_skill_sfx.pitch_scale = _orig_pitch_scale

func sfx_purchase_made() -> void:
	$SFX/shop_purchase_01.play()
	#$SFX/shop_purchase_02.play()
	await get_tree().create_timer(0.1, false).timeout
	$SFX/shop_purchase_02.play()
	$SFX/shop_coin_sfx_01.play()
	
func sfx_purchase_not_made() -> void:
	$SFX/purchase.play()


func sfx_open_tally() -> void:
	$SFX/shop_open_sfx_01.play(0.3)
	$SFX/hud_click_1.play()
	$SFX/hud_click_2.play()
	$SFX/hud_click_3.play()
	$SFX/low_humming.play()
	
func sfx_close_tally() -> void:
	$SFX/shop_close_sfx_01.play(0.5)
	$SFX/hud_click_1.play()
	$SFX/hud_click_2.play()
	$SFX/hud_click_3.play()
	$SFX/low_humming.stop()

func blink_penalty_red() -> void:
	var _original_color := penalties_number_label.self_modulate

	for i in 3:
		penalties_number_label.self_modulate = Color("aa000050")
		$SFX/purchase.play() # replace with your preferred penalty SFX

		await get_tree().create_timer(0.08, false).timeout

		penalties_number_label.self_modulate = Color("d10000")

		await get_tree().create_timer(0.08, false).timeout

	penalties_number_label.self_modulate = Color("d10000")

func _on_shop_pressed() -> void:
	enter_state(State.CLOSE_MENU)
	round_manager.enter_state(round_manager.RoundState.TALLY_END)
