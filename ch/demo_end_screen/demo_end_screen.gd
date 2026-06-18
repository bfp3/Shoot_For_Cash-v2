extends Control

@onready var rounds_label : RichTextLabel = %Rounds
@onready var rocks_label : RichTextLabel = %RocksDestroyed
@onready var earned_label : RichTextLabel = %MoneyEarned
@onready var fines_label : RichTextLabel = %Fines
@onready var remaining_label : RichTextLabel = %CashRemaining

@onready var nothing: Button = $CenterContainer/MainPanel/MainPanel/Item_List/Nothing
@onready var rocks: Button = $CenterContainer/MainPanel/MainPanel/Item_List/Rocks
@onready var coal: Button = $CenterContainer/MainPanel/MainPanel/Item_List/Coal
@onready var gold: Button = $CenterContainer/MainPanel/MainPanel/Item_List/Gold
@onready var clay_rocks: Button = $'CenterContainer/MainPanel/MainPanel/Item_List/Clay Rocks'

@onready var earnings_number_label: RichTextLabel = $CenterContainer/MainPanel/MainPanel/CashHboxcontainer/CashEarned/NumberLabel
@onready var penalties_number_label: RichTextLabel = $CenterContainer/MainPanel/MainPanel/CashHboxcontainer/Fines/NumberLabel
@onready var cash_number_label: RichTextLabel = $'CenterContainer/MainPanel/MainPanel/Cash Out/NumberLabel'

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


	# STORE DEFAULT TRANSFORMS
	default_scale = scale
	default_position = position

	# BOTTOM RIGHT PIVOT
	default_pivot_offset = Vector2(0, size.y)
	pivot_offset = default_pivot_offset

	#enter_state(State.OPEN_MENU)



func show_end_screen():

	var stats = gl_PlayerState.get_demo_stats()

	rounds_label.text = str(stats.rounds)

	rocks_label.text = str(stats.rocks_destroyed)

	earned_label.text ="$" + str(stats.money_earned)

	fines_label.text ="-$" + str(stats.fines)

	remaining_label.text ="$" + str(stats.cash_remaining)

	show()

	
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
	var settings 		= gl_PlayerState.get_all()
	var current_round 	= settings.round
	var items_hit 		= gl_PlayerState.get_item_hits(current_round)

	current_cash 		= settings.cash
	current_earnings 	= settings.earnings
	current_fines 		= settings.fines

	cash_number_label.text 		= "$" + str(0).pad_zeros(2)
	earnings_number_label.text 	= "$" + str(0).pad_zeros(2)
	penalties_number_label.text = "$" + str(0).pad_zeros(2)
	
	
	
	var _has_hits := false

	for item in items_hit:
		if items_hit[item] > 0:
			_has_hits = true
			object_destroyed(item, items_hit[item])
			


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
	#game_progress.update_game_progress()
	#sfx_open_tally()

	modulate.a = 0.0
	scale = Vector2.ONE * 0.01
	position = default_position
	pivot_offset = default_pivot_offset

	show()

	# OPEN ANIMATION
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_OUT)

	tween.parallel().tween_property(self, "scale", default_scale, 0.4)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.18)

	await tween.finished
	await reveal_stats()
	
	enter_state(State.IN_MENU)
	#$SFX/Demo_finished_music.play()

func update_close_menu() -> void:
	sfx_close_tally()
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
	
	earnings_number_label.text = "$" + str(0).pad_zeros(2)
	penalties_number_label.text = "$" + str(0).pad_zeros(2)
	cash_number_label.text = "$" + str(0).pad_zeros(2)
	
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

	
	#cash_number_label.text = "$" + str(GlobalPlayerMoney.gl_player_money + total_cash_earned).pad_zeros(2)

	await get_tree().create_timer(0.5).timeout
	await reset_cash_earned()
	await reset_penalties_earned()
	await add_earned_cash_to_total_cash()
	#item_2.update_round_statistics(rocks_created)
	
		
func reset_cash_earned() -> void:
	var sfx := $SFX/shop_purchase_01
	var tween = create_tween()
	tween.tween_property(earnings_number_label, 'scale', earnings_number_label.scale * 1.15, 0.1)
	await tween.finished
	
	if current_earnings > 0:
		var counter := 0.0
		earnings_number_label.modulate = Color('42d100')
		var duration := 0.25
		var elapsed := 0.0
		var dt := 1.0 / 60.0
		
		var start_value := 0.0
		var end_value := float(current_earnings)
		
		sfx.pitch_scale = 1.0
		sfx.play()
		
		while elapsed < duration:
			await get_tree().create_timer(dt).timeout
			elapsed += dt
			var t : float = clamp(elapsed / duration, 0.0, 1.0)
			var eased : float = 1.0 - pow(1.0 - t, 3.0)
			earnings_number_label.text = "$" + str(int(counter)).pad_zeros(2)
			counter = lerp(start_value, end_value, eased)
			sfx.pitch_scale += 0.1
			sfx.play()
		
		earnings_number_label.text = "$" + str(current_earnings).pad_zeros(2)
	
	else:
		earnings_number_label.modulate = Color('FFFFFF')
		earnings_number_label.text = "$" + str(current_earnings).pad_zeros(2)
	
	var tween2 = create_tween()
	tween2.tween_property(earnings_number_label, 'scale', Vector2.ONE, 0.1)
	await tween2.finished
	

func reset_penalties_earned() -> void:
	var sfx := $SFX/shop_purchase_01
	var fines_container = $CenterContainer/MainPanel/MainPanel/CashHboxcontainer/Fines
	
	var tween = create_tween()
	#tween.tween_property(penalties_number_label, 'scale', penalties_number_label.scale * 1.15, 0.1)
	tween.tween_property(fines_container, 'scale', fines_container.scale * 1.15, 0.1)
	await tween.finished
	
	if abs(current_fines) > 0:
		var counter := 0.0
		penalties_number_label.modulate = Color('d10000')
		var duration := 0.25
		var elapsed := 0.0
		var dt := 1.0 / 60.0
	
		var start_value := 0.0
		var end_value := float(current_fines)

		sfx.pitch_scale = 1.0
		sfx.play()
		
		while elapsed < duration:
			await get_tree().create_timer(dt).timeout
			elapsed += dt
			var t : float = clamp(elapsed / duration, 0.0, 1.0)
			var eased : float = 1.0 - pow(1.0 + t, 3.0)
			penalties_number_label.text = "$" + str(int(counter)).pad_zeros(2)
			counter = lerp(start_value, end_value, eased)
			sfx.pitch_scale += 0.1
			sfx.play()
		
		penalties_number_label.text = "-$" + str(abs(current_fines)).pad_zeros(2)
	
	else:
		penalties_number_label.modulate = Color.WHITE
		#penalties_number_label.text = "$" + str(0).pad_zeros(2)
		penalties_number_label.text = "[i]nil[/i]"
	
	var tween2 = create_tween()
	#tween2.tween_property(penalties_number_label, 'scale', penalties_number_label.scale * 1.0, 0.2)
	tween2.tween_property(fines_container, 'scale', Vector2.ONE, 0.1)
	await tween2.finished

func add_earned_cash_to_total_cash() -> void:
	var sfx := $SFX/shop_purchase_01

	await get_tree().create_timer(0.2).timeout

	var tween = create_tween()
	tween.tween_property(cash_number_label, "scale", cash_number_label.scale * 1.15, 0.1)
	await tween.finished

	var start_value : int = 0
	var end_value : int = current_cash

	#cash_number_label.text = "$" + str(start_value).pad_zeros(2)

	var duration := 0.2
	var elapsed := 0.0
	var dt := 1.0 / 60.0

	sfx.pitch_scale = 1.0
	sfx.play()

	while elapsed < duration:
		await get_tree().create_timer(dt).timeout
		elapsed += dt

		var t : float = clamp(elapsed / duration, 0.0, 1.0)
		var eased : float = 1.0 - pow(1.0 - t, 3.0)

		var counter : int = int(lerp(float(start_value), float(end_value), eased))

		cash_number_label.text = "$" + str(counter).pad_zeros(2)

		sfx.pitch_scale += 0.05
		sfx.play()

	if end_value > 0:
		cash_number_label.modulate = Color("42d100")
	else:
		cash_number_label.modulate = Color.GRAY

	cash_number_label.text = "[wave amp=2.0 freq=20.0 connected=1][pulse freq=3 color=#ffc700 ease=-2.0][color=#42d100]$" + str(current_cash).pad_zeros(2) + "[/color][/pulse][/wave]"
	var tween2 = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween2.tween_property(cash_number_label, "scale", cash_number_label.scale * 1.0, 0.1)
	tween2.tween_callback(play_cash_sfx)

	await tween2.finished
	
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
		
		tween.parallel().tween_property(skill, "modulate:a", 1.0, 0.1)
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


func _on_shop_pressed() -> void:
	enter_state(State.CLOSE_MENU)
	round_manager.enter_state(round_manager.RoundState.TALLY_END)
	
func _on_next_round_pressed() -> void:
	enter_state(State.CLOSE_MENU)
	round_manager.game_has_been_beaten = false
	
