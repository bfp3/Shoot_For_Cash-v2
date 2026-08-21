class_name TallyCard extends Control
@onready var winnings_label: RichTextLabel = %Winnings_label

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

var full_score := false

@onready var reveal_skill_sfx: AudioStreamPlayer = $SFX/reveal_skill_sfx
var round_manager : RoundManager
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

## Range-clear tally: keep the WINNINGS figure on screen into the map overlay.
var pending_winnings := 0
var _win_keep_winnings := false
var _winnings_fly: RichTextLabel = null
var _center: Control
var _preview_win_busy := false


func _ready() -> void:
	EventBus.instance.open_tally_card.connect(enter_state.bind(State.OPEN_MENU))
	%'100_percent'.modulate.a = 0.0
	# STORE DEFAULT TRANSFORMS
	default_scale = scale
	default_position = position
	
	round_manager = get_tree().get_first_node_in_group('round_manager')
	
	# BOTTOM RIGHT PIVOT
	default_pivot_offset = Vector2(0, size.y)
	pivot_offset = default_pivot_offset

	hide()
	_hide_sequence_labels()
	_center = get_node_or_null("CenterContainer") as Control

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

	grade_cash_label.text = ""
	grade_cash_label.show()
	grade_cash_label.modulate.a = 1.0
	grade_label.text = ""
	grade_label.show()
	grade_label.modulate.a = 1.0

	## Endless (Jetz): show survival time + keep/show bonuses earned.
	var endless := false
	var survived := 0.0
	if round_manager and round_manager.has_method("is_endless_mode"):
		endless = bool(round_manager.is_endless_mode())
	if endless and round_manager.has_method("get_endless_elapsed_seconds"):
		survived = float(round_manager.get_endless_elapsed_seconds())

	if endless:
		grade_label.text = "[wave]LASTED"
		grade_cash_label.text = _format_survival_time(survived)
		bonuses_label.text = 'CASH BANKED'
		bonuses_label.show()
		bonuses_label.modulate.a = 1.0
		bonuses_cash_label.modulate.a = 1.0
		bonuses_cash_label.show()
		var kept := int(gl_PlayerState.get_round_cash_kept()) if gl_PlayerState.has_method("get_round_cash_kept") else int(gl_PlayerState.dataset.bonus_cash)
		bonuses_cash_label.text = "$" + str(kept)
		fail_label.hide()
		grand_total_cash_label.show()
		grand_total_cash_label.modulate.a = 1.0
		grand_total_label.text = ""
		grand_total_cash_label.text = "$" + str(kept)
		return

	if gl_PlayerState.dataset.fines < 0:
		fail_label.text = "-$" + str(abs(gl_PlayerState.dataset.fines))
	## Checkpoint-banked cash is already in the wallet. Unbanked pool is forfeited.
	var earned := 0
	if gl_PlayerState.has_method("get_round_cash_kept"):
		earned = int(gl_PlayerState.get_round_cash_kept())
	else:
		earned = int(gl_PlayerState.dataset.bonus_cash)
	var fines := int(gl_PlayerState.dataset.fines)
	bonuses_label.text = 'CASH BANKED'
	bonuses_label.show()
	bonuses_label.modulate.a = 1.0
	bonuses_cash_label.modulate.a = 1.0
	bonuses_cash_label.show()
	bonuses_cash_label.text = "$" + str(earned)
	grand_total_cash_label.show()
	grand_total_cash_label.modulate.a = 1.0
	grand_total_label.text = ""
	fail_label.show()
	var net := earned + fines ## fines are negative
	if net < 0:
		grand_total_cash_label.text = "-$" + str(abs(net))
	else:
		grand_total_cash_label.text = "$" + str(net)

	return


func _format_survival_time(seconds: float) -> String:
	if round_manager and round_manager.get("round_timer") and round_manager.round_timer.has_method("format_time"):
		return String(round_manager.round_timer.format_time(seconds))
	var whole := int(maxf(seconds, 0.0))
	var hundredths := int((maxf(seconds, 0.0) - float(whole)) * 100.0)
	return "%d:%02d" % [whole, hundredths]

	
	
func start_perfect_sequence() -> void:
	
	#start_fail_sequence()
	#return
	
	await get_tree().create_timer(0.5, false).timeout
	$SFX/shop_purchase_02.play()
	$SFX/shop_purchase_01.play()
	var dur := 0.33
	grade_label.show()
	grade_label.modulate.a = 1.0
	grade_label.text = "[wave]WON"
	
	if gl_PlayerState.dataset.total_current_strikes <= 0:
		grade_label.text = "[wave]PERFECT!"
		
	perfect_bonus = int(gl_DataSet.get_value('reward_perfect_round', 0))
	
	# 2. GRADE CASH LABEL
	grade_cash_label.show()
	grade_cash_label.text = '$' + str(perfect_bonus)
	grade_cash_label.modulate.a = 1.0
	gl_PlayerState.add_cash(perfect_bonus)

	# decorative particle flourish, fires in the background (non-blocking)
	
	grand_total_cash_label.show()
	grand_total_cash_label.modulate.a = 1.0
	# PAUSE
	await get_tree().create_timer(0.25, false).timeout
	#await get_tree().create_timer(dur / 2, false).timeout

	# 3. BONUSES
	$SFX/shop_purchase_02.play()
	apply_bonus_cash()
	#$CenterContainer/MainPanel/MainPanel/CashHboxcontainer/CashEarned.modulate.a = 1.0
	#$CenterContainer/MainPanel/MainPanel/CashHboxcontainer/Fines.modulate.a = 0.0

	grand_total_cash_label.modulate.a = 0.0
	var kept := int(gl_PlayerState.dataset.bonus_cash)
	if gl_PlayerState.has_method("get_round_cash_kept"):
		kept = int(gl_PlayerState.get_round_cash_kept())
	grand_total_cash_label.text = "$" + str(int(kept + perfect_bonus - gl_PlayerState.dataset.fines))
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


func start_win_sequence() -> void:
	_win_keep_winnings = true
	pending_winnings = 0
	_clear_win_row_text()

	var clear_bonus := 0
	if gl_DataSet.has_method("get_range_clear_reward"):
		var place := ""
		if gl_PlayerState:
			place = gl_DataSet.resolve_place_name(String(gl_PlayerState.dataset.level_name))
		clear_bonus = int(gl_DataSet.get_range_clear_reward(place))
	else:
		clear_bonus = int(gl_DataSet.get_value("range_clear_reward", 0))

	var banked := 0
	if gl_PlayerState and "cash_banked_this_range" in gl_PlayerState:
		banked = int(gl_PlayerState.cash_banked_this_range)
	elif gl_PlayerState and gl_PlayerState.has_method("get_round_cash_kept"):
		banked = int(gl_PlayerState.get_round_cash_kept())
	pending_winnings = clear_bonus + banked

	if clear_bonus > 0:
		gl_PlayerState.add_cash(clear_bonus)

	await get_tree().create_timer(0.5, false).timeout
	$SFX/shop_purchase_02.play()
	$SFX/shop_purchase_01.play()
	await _reveal_win_row(grade_label, grade_cash_label, "[wave]GREAT WORK", _money_text(clear_bonus))

	await get_tree().create_timer(0.5, false).timeout
	$SFX/shop_purchase_02.play()
	await _reveal_win_row(bonuses_label, bonuses_cash_label, "CASH BANKED", _money_text(banked))

	await get_tree().create_timer(0.5, false).timeout
	$SFX/shop_purchase_02.play()
	$SFX/shop_purchase_01.play()
	grand_total_cash_label.pivot_offset_ratio = Vector2(0.5, 0.5)
	await _reveal_win_row(winnings_label, grand_total_cash_label, "WINNINGS", _money_text(pending_winnings))

	var punch := create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	punch.tween_property(grand_total_cash_label, "scale", Vector2.ONE * 1.1, 0.15)
	punch.parallel().tween_property($CenterContainer/MainPanel/MainPanel/CashOut/BackgroundParticles, "emitting", true, 0.1)
	punch.tween_property(grand_total_cash_label, "scale", Vector2.ONE, 0.15)
	await punch.finished
	return


## Editor / debug: Shift+C — run the range-clear tally then fly WINNINGS into map cash (no map stamp).
func play_test_win_sequence() -> void:
	if _preview_win_busy:
		return
	if not OS.has_feature("editor") and not OS.is_debug_build():
		return
	_preview_win_busy = true
	menu_in_display = false
	_win_keep_winnings = false
	pending_winnings = 0
	_free_winnings_fly()
	z_index = 10
	if _center:
		_center.show()
		_center.modulate.a = 1.0
	scale = default_scale
	modulate.a = 0.0
	position = default_position
	pivot_offset = default_pivot_offset
	_hide_sequence_labels()
	sfx_open_tally()
	show()
	var open_tween := create_tween()
	open_tween.set_trans(Tween.TRANS_LINEAR)
	open_tween.set_ease(Tween.EASE_OUT)
	open_tween.parallel().tween_property(self, "scale", default_scale, 0.3)
	open_tween.parallel().tween_property(self, "modulate:a", 1.0, 0.18)
	await open_tween.finished
	await start_win_sequence()
	await get_tree().create_timer(1.0, false).timeout
	await update_close_menu()
	var held := pending_winnings
	var menus := get_tree().get_first_node_in_group("deferred_menu_loader")
	var map_menu: Node = null
	if menus and menus.has_method("ensure_ticket_map"):
		map_menu = menus.ensure_ticket_map()
	if map_menu == null:
		map_menu = get_tree().get_first_node_in_group("map_menu")
	if map_menu and map_menu.has_method("preview_winnings_from_tally"):
		await map_menu.preview_winnings_from_tally(held, self)
	elif map_cash_exists(map_menu):
		await fly_winnings_to_map(map_menu.get_node("%MapCashBalanceLabel"))
	else:
		_cleanup_winnings_overlay()
	_preview_win_busy = false


func map_cash_exists(map_menu: Node) -> bool:
	return map_menu != null and map_menu.get_node_or_null("%MapCashBalanceLabel") != null


func _hide_sequence_labels() -> void:
	for label in [
		grade_label, grade_cash_label,
		bonuses_label, bonuses_cash_label,
		grand_total_label, grand_total_cash_label,
		winnings_label,
	]:
		if label == null:
			continue
		label.hide()
		label.modulate.a = 0.0
	if fail_label:
		fail_label.hide()
	var stamp := get_node_or_null("%100_percent") as CanvasItem
	if stamp:
		stamp.modulate.a = 0.0
		stamp.hide()


func _clear_win_row_text() -> void:
	_hide_sequence_labels()


func _reveal_win_row(title: Control, amount: Control, title_text: String, amount_text: String) -> void:
	if title:
		title.text = title_text
		title.modulate.a = 0.0
		title.show()
	if amount:
		amount.text = amount_text
		amount.modulate.a = 0.0
		amount.show()
	var tween := create_tween().set_parallel(true)
	if title:
		tween.tween_property(title, "modulate:a", 1.0, 0.2)
	if amount:
		tween.tween_property(amount, "modulate:a", 1.0, 0.2)
	await tween.finished


func _money_text(amount: int) -> String:
	return CommonCode.format_money(amount)


func fly_winnings_to_map(map_cash: Control) -> void:
	if not is_instance_valid(_winnings_fly) or map_cash == null or not is_instance_valid(map_cash):
		_cleanup_winnings_overlay()
		return
	var from_center := _winnings_fly.global_position + _winnings_fly.size * 0.5
	var to_center := map_cash.global_position + map_cash.size * 0.5
	var dest := _winnings_fly.global_position + (to_center - from_center)
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_winnings_fly, "global_position", dest, 0.55)
	tween.parallel().tween_property(_winnings_fly, "scale", Vector2.ONE * 0.45, 0.55)
	await tween.finished
	if is_instance_valid(_winnings_fly):
		var pop := create_tween()
		pop.tween_property(_winnings_fly, "modulate:a", 0.0, 0.12)
		await pop.finished
	_cleanup_winnings_overlay()


func _lift_winnings_overlay() -> void:
	_free_winnings_fly()
	if grand_total_cash_label == null:
		return
	var fly := grand_total_cash_label.duplicate() as RichTextLabel
	if fly == null:
		return
	fly.name = "WinningsFlyLabel"
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly.z_index = 80
	fly.top_level = true
	add_child(fly)
	fly.set_anchors_preset(Control.PRESET_TOP_LEFT)
	fly.global_position = grand_total_cash_label.global_position
	fly.size = grand_total_cash_label.size
	fly.pivot_offset = fly.size * 0.5
	fly.text = _money_text(pending_winnings)
	fly.modulate.a = 1.0
	_winnings_fly = fly
	grand_total_cash_label.modulate.a = 0.0
	z_index = 50
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _cleanup_winnings_overlay() -> void:
	_free_winnings_fly()
	_win_keep_winnings = false
	pending_winnings = 0
	z_index = 10
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _center:
		_center.show()
		_center.modulate.a = 1.0
	hide()


func _free_winnings_fly() -> void:
	if is_instance_valid(_winnings_fly):
		_winnings_fly.queue_free()
	_winnings_fly = null



func check_white_rocks() -> void:
	_hide_sequence_labels()
	fail_label.text = "$0"
	
	start_sequence = true
	
	gl_PlayerState.subtract_penalties_from_cash()
	
	var max_strikes := 3
	if gl_PlayerState.has_method("get_max_strikes"):
		max_strikes = gl_PlayerState.get_max_strikes()
	if gl_PlayerState.dataset.total_current_strikes >= max_strikes:
		start_fail_sequence()
		start_sequence = false
		return

	if _is_range_clear_win():
		await start_win_sequence()
		start_sequence = false
		return

	await start_perfect_sequence()
	start_sequence = false
	return

func perfect_particles() -> void:
	
	
	play_cash_sfx()
	#%perfectScoreParticles.emitting = true
	#await get_tree().create_timer(0.25, false).timeout
	
	$SFX/perfect_score.play()
	var stamp_root := %'100_percent' as CanvasItem
	if stamp_root:
		stamp_root.show()
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


func _is_range_clear_win() -> bool:
	if round_manager and round_manager.has_method("is_range_clear_win_tally"):
		return bool(round_manager.is_range_clear_win_tally())
	return false


func apply_bonus_cash() -> void:
	var bonus_cash = int(gl_PlayerState.dataset.bonus_cash)
	if gl_PlayerState.has_method("get_round_cash_kept"):
		bonus_cash = int(gl_PlayerState.get_round_cash_kept())
	#gl_PlayerState.add_bonus(bonus_cash)
	bonuses_cash_label.show()
	bonuses_cash_label.modulate.a = 1.0
	bonuses_cash_label.text = "$" + str(bonus_cash)
	if bonuses_label:
		bonuses_label.show()
		bonuses_label.modulate.a = 1.0
		bonuses_label.text = "CASH BANKED"

func update_open_menu() -> void:
	if menu_in_display:
		return

	_win_keep_winnings = false
	pending_winnings = 0
	z_index = 10
	if _center:
		_center.show()
		_center.modulate.a = 1.0
	_hide_sequence_labels()
	
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
	pivot_offset = default_pivot_offset
	sfx_close_tally()

	if _win_keep_winnings:
		_lift_winnings_overlay()
		await get_tree().process_frame
		if _center:
			var fade := create_tween()
			fade.set_trans(Tween.TRANS_LINEAR)
			fade.set_ease(Tween.EASE_IN)
			fade.tween_property(_center, "modulate:a", 0.0, 0.28)
			await fade.finished
			_center.hide()
			_center.modulate.a = 1.0
		menu_in_display = false
		updating_stats = false
		return

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



func _on_shop_pressed() -> void:
	current_state = State.CLOSE_MENU
	await update_close_menu()
	if round_manager:
		round_manager.enter_state(round_manager.RoundState.TALLY_END)
