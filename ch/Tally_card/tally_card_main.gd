class_name TallyCard extends Control


@onready var nothing: Button = $CenterContainer/MainPanel/MainPanel/Item_List/Nothing
@onready var rocks: Button = $CenterContainer/MainPanel/MainPanel/Item_List/Rocks
@onready var coal: Button = $CenterContainer/MainPanel/MainPanel/Item_List/Coal
@onready var gold: Button = $CenterContainer/MainPanel/MainPanel/Item_List/Gold
@onready var clay_rocks: Button = $'CenterContainer/MainPanel/MainPanel/Item_List/Clay Rocks'
#@onready var plastic_bottles: Button = $'CenterContainer/MainPanel/MainPanel/Item_List/Plastic Bottles'
#@onready var tires: Button = $CenterContainer/MainPanel/MainPanel/Item_List/Tires
#@onready var scrap_metal: Button = $'CenterContainer/MainPanel/MainPanel/Item_List/Scrap Metal'
#@onready var oil_drums: Button = $'CenterContainer/MainPanel/MainPanel/Item_List/Oil Drums'
#@onready var cargo_crates: Button = $'CenterContainer/MainPanel/MainPanel/Item_List/Cargo Crates'
#@onready var rare_goodies: Button = $'CenterContainer/MainPanel/MainPanel/Item_List/Rare Goodies'
#@onready var crackers: Button = $CenterContainer/MainPanel/MainPanel/Item_List/Crackers

enum ScoreResult {
	ZERO_SCORE,
	PARTIAL_SCORE,
	PERFECT_SCORE
}

var score_result : ScoreResult = ScoreResult.PARTIAL_SCORE

#@onready var hazard_mine: HBoxContainer = $CenterContainer/MainPanel/MainPanel/Item_List2/Panel/ScrollContainer/SalvageTable/Mine

@onready var score_label: RichTextLabel = $CenterContainer/MainPanel/MainPanel/CashHboxcontainer2/TotalRocks/NumberLabel #$CenterContainer/MainPanel/MainPanel/CashHboxcontainer/TotalRocks/NumberLabel
@onready var earnings_number_label: RichTextLabel = $CenterContainer/MainPanel/MainPanel/CashHboxcontainer/CashEarned/NumberLabel
@onready var penalties_number_label: RichTextLabel = $CenterContainer/MainPanel/MainPanel/CashHboxcontainer/Fines/NumberLabel
@onready var cash_number_label: RichTextLabel = $'CenterContainer/MainPanel/MainPanel/Cash Out/NumberLabel'

var full_score := false

@onready var reveal_skill_sfx: AudioStreamPlayer = $SFX/reveal_skill_sfx
@export var round_manager : RoundManager
@export var cash_earned_label : RichTextLabel
@export var total_cash_earned_label : RichTextLabel
@export var test_mode := false
@onready var game_progress: HBoxContainer = $CenterContainer/MainPanel/MainPanel/GameProgress

enum State {
	INACTIVE,
	OPEN_MENU,
	IN_MENU,
	CLOSE_MENU
}

var current_cash : int = 0
var current_earnings : int = 0
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


func update_all() -> void:
	gl_PlayerState.check_score()
	var settings 		= gl_PlayerState.get_all()
	var current_round 	= settings.round
	var items_hit 		= gl_PlayerState.get_item_hits(current_round)

	current_cash 		= settings.cash
	current_earnings 	= settings.earnings
	current_fines 		= settings.fines

	cash_number_label.text 		= "$" + str(0)
	earnings_number_label.text 	= "$" + str(0)
	#penalties_number_label.text = "$" + str(0)
	
	var total_rocks_in_round = settings.total_rocks_in_round
	var total_rocks_destroyed = settings.total_rocks_destroyed
	score_label.text = 	str(total_rocks_destroyed) + "/" + str(total_rocks_in_round)

	$CenterContainer/MainPanel/MainPanel/CashHboxcontainer2/TotalRocks/TitleLabel.text = '[i]SCORE'
	
	if total_rocks_destroyed == 0:
		score_result = ScoreResult.ZERO_SCORE
	elif total_rocks_destroyed == total_rocks_in_round:
		score_result = ScoreResult.PERFECT_SCORE
		$CenterContainer/MainPanel/MainPanel/CashHboxcontainer2/TotalRocks/TitleLabel.text = ''
		score_label.text = "[rainbow][wave]" + str(total_rocks_destroyed) + "/" + str(total_rocks_in_round)
	else:
		score_result = ScoreResult.PARTIAL_SCORE

	var has_hits := false

	for item in items_hit:
		if items_hit[item] > 0:
			has_hits = true
			object_destroyed(item, items_hit[item])
			


	nothing.update_nothing()
	nothing.visible = !has_hits
	

func object_destroyed(rock_type : String, amount_hit : int = 0) -> void:
	match rock_type:
		"Small Rock":
			rocks.temporary_count += amount_hit
			rocks.permanent_count += amount_hit
			rocks.update_name()
			gl_DataSet.update_rocks(amount_hit)

		"Coal":
			coal.temporary_count += amount_hit
			coal.permanent_count += amount_hit
			coal.update_name()
			gl_DataSet.update_rocks(amount_hit)
		
		"Gold":
			gold.temporary_count += amount_hit
			gold.permanent_count += amount_hit
			gold.update_name()
			gl_DataSet.update_rocks(amount_hit)
		
		"Red Rock":
			clay_rocks.temporary_count += amount_hit
			clay_rocks.permanent_count += amount_hit
			clay_rocks.update_name()
			gl_DataSet.update_rocks(amount_hit)
			
		#"Hazard Large":
			#hazard_mine = $CenterContainer/MainPanel/MainPanel/Item_List2/Panel/ScrollContainer/SalvageTable/Mine
			#hazard_mine.temporary_count += amount_hit
			#hazard_mine.permanent_count += amount_hit
			#hazard_mine.update_name()

	
	
	
func update_open_menu() -> void:
	if menu_in_display:
		return
	
	update_all()
	
	menu_in_display = true
	game_progress.update_game_progress()
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
	
	if score_result == ScoreResult.PERFECT_SCORE:
		await get_tree().create_timer(0.5).timeout
		await get_tree().create_timer(2.0).timeout
		_on_shop_pressed()
	else:
		await get_tree().create_timer(2.0).timeout
		_on_shop_pressed()
		
func update_close_menu() -> void:
	#sfx_close_tally()
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
	
	#earnings_number_label.text = "$"
	##penalties_number_label.text = "$"
	#cash_number_label.text = "$"
	
	hide()


func notify_round_manager() -> void:
	if !round_manager:
		var _round_manager : RoundManager = get_tree().get_first_node_in_group('round_manager')
		if _round_manager:
			_round_manager.enter_state(_round_manager.RoundState.TALLY_END)
			
	else:
		round_manager.enter_state(round_manager.RoundState.TALLY_END)


func update_in_menu() -> void:
	update_stats_visual()

func update_stats_visual() -> void:
	if updating_stats:
		return
	
	updating_stats = true

	
	#cash_number_label.text = "$" + str(GlobalPlayerMoney.gl_player_money + total_cash_earned)

	await get_tree().create_timer(0.1).timeout
	
	if score_result != ScoreResult.ZERO_SCORE:
		reset_cash_earned()
		reset_penalties_earned()
		add_earned_cash_to_total_cash()
	
	else:
		earnings_number_label.text = "$" + str(0)
		cash_number_label.text = "[wave amp=2.0 freq=20.0 connected=1][pulse freq=3 color=#42d100 ease=-2.0][color=#42d100]$" + str(current_cash) + "[/color][/pulse][/wave]"
		penalties_number_label.text = "--"

	
		
func reset_cash_earned() -> void:

	if current_earnings > 0:

		earnings_number_label.self_modulate = Color("42d100")

		await animate_money_counter(
			earnings_number_label,
			0,
			current_earnings,
			0.25,
			func(v): return "$" + str(int(v))
		)

		earnings_number_label.text = "$" + str(current_earnings)

	else:

		earnings_number_label.self_modulate = Color.WHITE
		earnings_number_label.text = "$" + str(current_earnings)



func reset_penalties_earned() -> void:

	if abs(current_fines) > 0:

		penalties_number_label.self_modulate = Color("d10000")
		blink_penalty_red()
		await animate_money_counter(
			penalties_number_label,
			0,
			current_fines,
			0.25,
			func(v): return "$" + str(int(v)),
			false
		)

		penalties_number_label.text = "-$" + str(abs(current_fines))
		
	else:

		penalties_number_label.self_modulate = Color.WHITE
		penalties_number_label.text = "--"

		
func add_earned_cash_to_total_cash() -> void:

	#await get_tree().create_timer(0.2).timeout

	await animate_money_counter(
		cash_number_label,
		0,
		current_cash,
		0.2,
		func(v): return "$" + str(int(v)),
		true,
		0.05
	)

	if current_cash > 0:
		cash_number_label.self_modulate = Color("42d100")
	else:
		cash_number_label.self_modulate = Color.GRAY

	cash_number_label.text = "[wave amp=2.0 freq=20.0 connected=1][pulse freq=3 color=#42d100 ease=-2.0][color=#42d100]$" + str(current_cash) + "[/color][/pulse][/wave]"
	
	
	
	feedback_effects()
	
func feedback_effects() -> void:
	
	if score_result == ScoreResult.ZERO_SCORE:
		print("hit here")
		return
		
	#if score_result != ScoreResult.ZERO_SCORE:
	play_cash_sfx()
		
	
	$'CenterContainer/MainPanel/MainPanel/Cash Out/BackgroundParticles'.emitting = true
	
	if score_result == ScoreResult.PERFECT_SCORE:
		
		%perfectScoreParticles.emitting = true
		await get_tree().create_timer(0.5).timeout
		$SFX/perfect_score.play()
		
		var tween = create_tween()
		tween.tween_property(%'100_percent', "modulate:a", 1.0, 0.15)
		tween.tween_interval(1.7)
		tween.tween_property(%'100_percent', "modulate:a", 0.0, 0.15)
		await tween.finished
		$'CenterContainer/MainPanel/MainPanel/Cash Out/BackgroundParticles'.amount += 1
		$'CenterContainer/MainPanel/MainPanel/Cash Out/BackgroundParticles'.emitting = false
		
func animate_money_counter(label: RichTextLabel, start_value: float,
	end_value: float,
	duration: float,
	text_callback: Callable,
	ease_out := true,
	pitch_step := 0.1
) -> void:

	var sfx := $SFX/shop_purchase_01

	var elapsed := 0.0
	var dt := 1.0 / 60.0

	sfx.pitch_scale = 1.0
	sfx.play()

	while elapsed < 0.05:
		await get_tree().create_timer(dt).timeout

		elapsed += dt

		var t : float = clamp(elapsed / duration, 0.0, 1.0)

		var eased : float
		if ease_out:
			eased = 1.0 - pow(1.0 - t, 3.0)
		else:
			eased = 1.0 - pow(1.0 + t, 3.0)

		var value : float = lerp(start_value, end_value, eased)

		label.text = text_callback.call(value)

		sfx.pitch_scale += pitch_step
		sfx.play()




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
	var original_color := penalties_number_label.self_modulate

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
	
func _on_next_round_pressed() -> void:
	enter_state(State.CLOSE_MENU)
	round_manager.enter_state(round_manager.RoundState.SHOP_END)
	

func _on_area_completed() -> void:
	if gl_PlayerState.dataset.stage_name == gl_DataSet.get_string("place_name",0):
		print('COMPLETED')
	else:
		%EndDemo.show() 
	
	
	
	

func _on_go_to_next_place_pressed() -> void:
	#var main_scene = get_tree().get_first_node_in_group('scene_manager')
	#if main_scene:
		#main_scene.load_next_level()
	%GoToNextPlace.hide()
	enter_state(State.CLOSE_MENU)
	round_manager.enter_state(round_manager.RoundState.NEXT_LEVEL)


func _on_end_demo_pressed() -> void:
	%EndDemo.hide()
	enter_state(State.CLOSE_MENU)
	round_manager.enter_state(round_manager.RoundState.END_DEMO)
