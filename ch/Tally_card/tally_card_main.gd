class_name TallyCard extends Control

@export var perfect_bonus := 50
@export var pass_bonus := 20
@onready var fail_label: RichTextLabel = %Fail_Label

@onready var grade_label: RichTextLabel = %GradeLabel
@onready var grade_cash_label : RichTextLabel = %GradeCashLabel

@onready var bonuses_label: RichTextLabel = $CenterContainer/MainPanel/MainPanel/CashHboxcontainer/CashEarned/BonusesLabel
@onready var bonuses_cash_label: RichTextLabel = %BonusesCashLabel

@onready var grand_total_label: RichTextLabel = %TotalLabel
@onready var grand_total_cash_label: RichTextLabel = %TotalCashCashLabel

enum ScoreResult {
	ZERO_SCORE,
	PARTIAL_SCORE,
	PERFECT_SCORE
}

var start_sequence := false
var score_result : ScoreResult = ScoreResult.PARTIAL_SCORE

#@onready var hazard_mine: HBoxContainer = $CenterContainer/MainPanel/MainPanel/Item_List2/Panel/ScrollContainer/SalvageTable/Mine

@onready var score_label: RichTextLabel = $CenterContainer/MainPanel/MainPanel/CashHboxcontainer2/TotalRocks/NumberLabel #$CenterContainer/MainPanel/MainPanel/CashHboxcontainer/TotalRocks/NumberLabel
@onready var penalties_number_label: RichTextLabel = $CenterContainer/MainPanel/MainPanel/CashHboxcontainer/Fines/NumberLabel
@onready var cash_number_label: RichTextLabel = $'CenterContainer/MainPanel/MainPanel/Cash Out/NumberLabel'

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
	#grade_cash_label.text = "$0"
	fail_label.show()
	grade_cash_label.modulate = Color('a6a6a6ff')
	#grade_label.text = "[i]Try Again"
	grade_label.text = ""
	grade_label.modulate = Color("a6a6a6ff")
	grade_cash_label.modulate = Color('a6a6a6ff')

	if gl_PlayerState.dataset.fines < 0:
		fail_label.text = "-$" + str(abs(gl_PlayerState.dataset.fines))

		

	bonuses_cash_label.modulate.a = 0.0

	grand_total_label.hide()
	bonuses_label.hide()
	#$CenterContainer/MainPanel/MainPanel/CashHboxcontainer/Fines.modulate.a = 1.0
	grand_total_cash_label.modulate = Color('a6a6a6ff')
	#$'CenterContainer/MainPanel/MainPanel/Cash Out/NumberLabel'.text = "$" + str(0)
	return
	
	
	
func start_perfect_sequence() -> void:
	await get_tree().create_timer(0.5).timeout
	var dur := 1.0

	# 1. GRADE LABEL
	grade_label.modulate = Color("ffc700ff")
	grade_label.text = "[i][wave]PERFECT"

	# 2. GRADE CASH LABEL
	grade_cash_label.text = '$50'
	grade_cash_label.modulate = Color("42d100")
	gl_PlayerState.add_cash(perfect_bonus)

	# decorative particle flourish, fires in the background (non-blocking)
	perfect_particles()
	grand_total_cash_label.modulate = Color("42d100")
	# PAUSE
	await get_tree().create_timer(dur).timeout

	# 3. BONUSES
	$SFX/shop_purchase_02.play()
	apply_bonus_cash()
	$CenterContainer/MainPanel/MainPanel/CashHboxcontainer/CashEarned.modulate.a = 1.0
	$CenterContainer/MainPanel/MainPanel/CashHboxcontainer/Fines.modulate.a = 0.0

	# PAUSE
	await get_tree().create_timer(dur).timeout
	$'CenterContainer/MainPanel/MainPanel/Cash Out/BackgroundParticles'.emitting = true
	$SFX/shop_purchase_02.play()
	grand_total_cash_label.text = "$" + str(int(gl_PlayerState.dataset.bonus_cash + perfect_bonus - gl_PlayerState.dataset.fines ))
	await get_tree().create_timer(dur).timeout
	return


func start_pass_sequence() -> void:
	var dur := 1.0

	# 1. GRADE LABEL
	grade_label.modulate = Color("cccccc")
	grade_label.text = "All Clear!"

	# 2. GRADE CASH LABEL
	grade_cash_label.text = '$20'
	gl_PlayerState.add_cash(pass_bonus)

	# PAUSE
	await get_tree().create_timer(dur).timeout

	# 3. BONUSES
	$SFX/shop_purchase_02.play()
	apply_bonus_cash()
	$CenterContainer/MainPanel/MainPanel/CashHboxcontainer/CashEarned.modulate.a = 1.0
	$CenterContainer/MainPanel/MainPanel/CashHboxcontainer/Fines.modulate.a = 1.0

	# PAUSE
	await get_tree().create_timer(dur).timeout

	# 4. TOTAL CASH EARNED
	$SFX/shop_purchase_02.play()
	$'CenterContainer/MainPanel/MainPanel/Cash Out/BackgroundParticles'.emitting = true
	grand_total_cash_label.text = "$" + str(int(gl_PlayerState.dataset.bonus_cash + perfect_bonus - gl_PlayerState.dataset.fines))
	grand_total_cash_label.modulate = Color("42d100")
	await get_tree().create_timer(dur).timeout
	return
	
func check_white_rocks() -> void:
	
	var white_rocks = gl_PlayerState.dataset.total_white_rocks
	
	grand_total_label.show()
	bonuses_label.show()
	fail_label.hide()
	fail_label.text = "$0"
	grade_label.text = ""
	grade_cash_label.text = ""
	grade_cash_label.modulate = Color("42d100")
	
	bonuses_label.text = 'BONUSES'
	bonuses_cash_label.text = ""
	
	grand_total_label.text = 'TOTAL WINNINGS'
	grand_total_cash_label.text = ""
	
	start_sequence = true
	
	gl_PlayerState.subtract_penalties_from_cash()
	
	
	if gl_PlayerState.dataset.total_hazards > 0:
		await start_fail_sequence()
		start_sequence = false
		return
		
	if white_rocks > 0 && gl_PlayerState.dataset.perfect_rounds < 3:
		await start_fail_sequence()
		start_sequence = false
		return
		
	elif white_rocks == 0 && gl_PlayerState.dataset.perfect_rounds >= 3:
		await start_perfect_sequence()
		start_sequence = false
		return
		
	elif white_rocks == 0:
		await start_pass_sequence()
		start_sequence = false
		
		return
		
	else:
		%GradeLabel.text = ""
		print('Some other condition was met')
		start_sequence = false

func perfect_particles() -> void:
	play_cash_sfx()
	%perfectScoreParticles.emitting = true
	#await get_tree().create_timer(0.25).timeout
	
	$SFX/perfect_score.play()
	
	var tween = create_tween()
	tween.tween_property(%'100_percent', "modulate:a", 1.0, 0.1)
	tween.tween_interval(0.35)
	tween.tween_property(cash_number_label, "text", "$" + str(int(gl_PlayerState.dataset.cash)), 0.0001)
	tween.tween_interval(2.0)
	tween.tween_property(%'100_percent', "modulate:a", 0.0, 0.15)
	await tween.finished
	$'CenterContainer/MainPanel/MainPanel/Cash Out/BackgroundParticles'.amount += 1
	$'CenterContainer/MainPanel/MainPanel/Cash Out/BackgroundParticles'.emitting = false
	

func apply_bonus_cash() -> void:
	var bonus_cash = gl_PlayerState.dataset.bonus_cash
	#gl_PlayerState.add_bonus(bonus_cash)
	bonuses_cash_label.show()
	bonuses_cash_label.modulate.a = 1.0
	bonuses_cash_label.modulate = Color("42d100ff")
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

	
	await get_tree().create_timer(2.0).timeout
	
	while start_sequence:
		await get_tree().process_frame
	
	await get_tree().create_timer(1.0).timeout
	
	_on_shop_pressed()
		
func update_close_menu() -> void:
	
	total_cash_earned = 0
	total_penalties_earned = 0

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
	
	
	hide()




func update_in_menu() -> void:
	update_stats_visual()
	
	await get_tree().create_timer(2.0).timeout
	
	

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
	await get_tree().create_timer(0.1).timeout
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

		await get_tree().create_timer(0.08).timeout

		penalties_number_label.self_modulate = Color("d10000")

		await get_tree().create_timer(0.08).timeout

	penalties_number_label.self_modulate = Color("d10000")

func _on_shop_pressed() -> void:
	enter_state(State.CLOSE_MENU)
	round_manager.enter_state(round_manager.RoundState.TALLY_END)
	
