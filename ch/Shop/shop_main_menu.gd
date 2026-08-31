extends Control

## TEMP publish flag — set true again after the export build to restore Shoot for Cents.
const ENABLE_SHOOT_FOR_CENTS := false

const SHOP_MINI_GAME_SCENE_PATH := "res://ch/Shop/ShopMiniGame.tscn"
const ABANDON_RUN_PROMPT_PATH := "res://ch/Shop/abandon_run_prompt.tscn"
const SHOP_PANEL_STYLEBOX := preload("res://res/custom_themes_by_blake/shop_main_panel_stylebox.tres")

@export var round_manager : RoundManager
@export var money_control : Node
@export var reveal_skill_sfx: AudioStreamPlayer
@onready var cash_label: RichTextLabel = %PlayerTotalCash
@onready var reward_money: RichTextLabel = %RewardMoney
@onready var shop_crate_overlay: Node = get_node_or_null("%ShopCrateOverlay")
#@onready var available_upgrades: HBoxContainer = $CenterContainer/MainPanel/VBoxContainer/TreePanel/AvailableUpgrades
#@onready var reroll_button: Button = %Reroll
var available_upgrades
var reroll_button
var all_skills_container
#@onready var all_skills_container: Control = %TreeCanvas
@export var can_appear_when_maxed := false


var default_scale := Vector2.ONE
var default_position := Vector2.ZERO
var default_pivot_offset := Vector2.ZERO

var price_reroll := 0
var reroll_unlocked := false
var reroll_index := 0
var is_rerolling := false

var all_skills : Array
## When true, shop open won't flash the CLEAR! stamp before its animation plays.
var _pending_level_complete_stamp := false

enum SkillState {
	INACTIVE,
	OPEN_MENU,
	IN_MENU,
	CLOSE_MENU
}

var current_state : SkillState = SkillState.INACTIVE


var current_round := 0
var player_cash := 0

var _ammo_popup: Control
var _boss_challenge_banner: RichTextLabel
var _ammo_popup_tween: Tween
var _ammo_popup_rest_scale := Vector2.ONE
var _ammo_popup_rest_position := Vector2.ZERO
var _pause_popup: Control
var _pause_popup_tween: Tween
var _pause_popup_rest_scale := Vector2.ONE
var _pause_popup_rest_position := Vector2.ZERO
var _shop_mini_game: Control
var _abandon_prompt: Control = null


func _ready() -> void:
	
	EventBus.instance.update_money.connect(update_shop_labels)
	if EventBus.instance.has_signal("continue_fee_changed"):
		EventBus.instance.continue_fee_changed.connect(_on_continue_fee_changed)
	if EventBus.instance.has_signal("continue_reserve_broken"):
		EventBus.instance.continue_reserve_broken.connect(_on_continue_reserve_broken)

	_music_control_call("ensure_shop_music_playing")

	# STORE DEFAULT TRANSFORMS
	default_scale = scale
	default_position = position
	await get_tree().process_frame

	# BOTTOM RIGHT PIVOT
	#default_pivot_offset = size 
	#pivot_offset = default_pivot_offset
	pivot_offset_ratio = Vector2(0.5,1.5)

	
	hide()

	#all_skills = all_skills_container.get_children()

	EventBus.instance.open_shop.connect(enter_state.bind(SkillState.OPEN_MENU))
	#$NextRound.pressed.connect(enter_state.bind(SkillState.CLOSE_MENU))
	if cash_label:
		cash_label.text = "$0"
	if reward_money:
		reward_money.text = "$0"
	_set_shop_crate_overlay_visible(false)
	

	
	_setup_ammo_count_popup()
	_setup_pause_label_popup()
	_setup_shop_extra_buttons()
	_setup_abandon_run_prompt()
	_strip_non_interactive_focus(self)


func _setup_shop_extra_buttons() -> void:
	var pause_btn := get_node_or_null("%PauseGameButton") as Button
	if pause_btn:
		# "x" pause is mobile-only; desktop/console use the pause key / pause menu.
		if OS.has_feature("mobile"):
			pause_btn.show()
			if not pause_btn.pressed.is_connected(_on_pause_game_button_pressed):
				pause_btn.pressed.connect(_on_pause_game_button_pressed)
		else:
			pause_btn.hide()

	var cents_btn := get_node_or_null("%ShootForCentsButton") as Button
	if cents_btn:
		cents_btn.visible = ENABLE_SHOOT_FOR_CENTS
		cents_btn.disabled = not ENABLE_SHOOT_FOR_CENTS
		if ENABLE_SHOOT_FOR_CENTS and not cents_btn.pressed.is_connected(_on_shoot_for_cents_pressed):
			cents_btn.pressed.connect(_on_shoot_for_cents_pressed)


func _on_pause_game_button_pressed() -> void:
	var menus := get_tree().get_first_node_in_group("deferred_menu_loader")
	if menus and menus.has_method("ensure_pause"):
		menus.ensure_pause()
	var pause_menu = get_tree().get_first_node_in_group("pause_menu")
	if pause_menu and pause_menu.has_method("open_menu"):
		pause_menu.open_menu()
	elif pause_menu and pause_menu.has_method("start"):
		pause_menu.start()


func _on_shoot_for_cents_pressed() -> void:
	if not ENABLE_SHOOT_FOR_CENTS:
		return
	if current_state != SkillState.IN_MENU and current_state != SkillState.OPEN_MENU:
		return
	_ensure_shop_mini_game()
	if _shop_mini_game and _shop_mini_game.has_method("toggle"):
		_shop_mini_game.toggle()
	elif _shop_mini_game and _shop_mini_game.has_method("open"):
		_shop_mini_game.open()


func ticket_purchased() -> void:
	if gl_PlayerState.dataset.tickets > 0:
		reroll_unlocked = true
		
	update_shop()
	open_map_menu()


## Opens the island map after returning to the start layout (beginning scenery).
func open_map_menu() -> void:
	if round_manager and round_manager.has_method("return_to_start_with_map"):
		await round_manager.return_to_start_with_map()
		return
	var menus := get_tree().get_first_node_in_group("deferred_menu_loader")
	if menus and menus.has_method("ensure_ticket_map"):
		menus.ensure_ticket_map()
	var map_menu := get_tree().get_first_node_in_group('map_menu')
	if map_menu and map_menu.has_method('open_pop_up'):
		CommonCode.apply_ui_overlay_blur()
		map_menu.open_pop_up()
	else:
		push_warning('Shop: map menu missing')


func _setup_abandon_run_prompt() -> void:
	if _abandon_prompt and is_instance_valid(_abandon_prompt):
		return
	var packed := load(ABANDON_RUN_PROMPT_PATH) as PackedScene
	if packed == null:
		push_warning("Shop: abandon run prompt missing")
		return
	_abandon_prompt = packed.instantiate() as Control
	add_child(_abandon_prompt)
	_abandon_prompt.hide()
	if _abandon_prompt.has_signal("confirmed"):
		_abandon_prompt.confirmed.connect(_on_abandon_run_confirmed)
	if _abandon_prompt.has_signal("cancelled"):
		_abandon_prompt.cancelled.connect(_on_abandon_run_cancelled)


func _on_shop_back_pressed() -> void:
	if _abandon_prompt and _abandon_prompt.has_method("open_prompt"):
		_abandon_prompt.open_prompt()
		return
	_on_abandon_run_confirmed()


func _on_abandon_run_cancelled() -> void:
	var play := get_node_or_null("%PlayButton") as Control
	UiFocus.grab_in(self, play)


func _on_abandon_run_confirmed() -> void:
	if _abandon_prompt and _abandon_prompt.has_method("close_prompt"):
		_abandon_prompt.close_prompt()
	if round_manager and round_manager.has_method("play_run_over_and_restart"):
		await round_manager.play_run_over_and_restart()
		return
	soft_hide_for_level_editor()
	if round_manager and round_manager.has_method("return_to_difficulty_select"):
		await round_manager.return_to_difficulty_select()


func _format_cash_label(amount: int, waved: bool = true) -> String:
	var money := CommonCode.format_money(amount)
	if waved:
		return "[wave amp=2.0 freq=20.0 connected=1]%s" % money
	return money


func _wallet_label() -> RichTextLabel:
	if cash_label:
		return cash_label
	return reward_money


func _current_range_reward() -> int:
	if round_manager and round_manager.has_method("get_current_range_reward"):
		return int(round_manager.get_current_range_reward())
	if gl_DataSet and gl_DataSet.has_method("get_range_clear_reward"):
		return int(gl_DataSet.get_range_clear_reward())
	return int(gl_DataSet.get_value("range_clear_reward", 0))


func _refresh_range_reward_label() -> void:
	if reward_money == null:
		return
	reward_money.text = "[wave]" + _format_cash_label(_current_range_reward(), false)
	reward_money.show()
	reward_money.modulate.a = 1.0


func _refresh_player_money_label() -> void:
	if gl_PlayerState:
		player_cash = int(gl_PlayerState.dataset.cash)
	var label := _wallet_label()
	if label == null:
		return
	label.text = _format_cash_label(player_cash, false)
	label.show()
	label.modulate.a = 1.0


func update_place_label() -> void:
	var place_root := get_node_or_null('CenterContainer/MainPanel/VBoxContainer/TopRedPanel/Place_name') as CanvasItem
	var place_label := get_node_or_null('CenterContainer/MainPanel/VBoxContainer/TopRedPanel/Place_name/PlaceLabel') as RichTextLabel
	var is_boss := false
	if round_manager and round_manager.has_method("is_boss_mode"):
		is_boss = bool(round_manager.is_boss_mode())
	elif String(gl_PlayerState.dataset.level_name).to_lower().begins_with("boss"):
		is_boss = true

	if place_root:
		place_root.visible = not is_boss
	if place_label:
		if is_boss:
			place_label.text = ""
		else:
			var place_id := gl_DataSet.resolve_place_name(String(gl_PlayerState.dataset.level_name))
			var display := gl_DataSet.display_place_name(place_id)
			place_label.text = display
	## Round number buttons are retired — keep Play / Ammo / Pause, hide the selector row.
	_hide_round_selector_buttons()
	_apply_shop_panel_shadow_for_place()
	_refresh_background_completion_stamp(false)
	_refresh_place_challenge_banner()


func _format_range_target_cash(amount: int) -> String:
	var s := str(absi(amount))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


func _apply_shop_panel_shadow_for_place() -> void:
	var style := SHOP_PANEL_STYLEBOX as StyleBoxFlat
	if style == null:
		return
	var place := gl_DataSet.resolve_place_name(String(gl_PlayerState.dataset.level_name))
	## Dark ranges: light panel shadow for contrast.
	style.shadow_size = 1 if (place == "redd" or place == "noir") else 0


func _refresh_place_challenge_banner() -> void:
	var banner := _ensure_boss_challenge_banner()
	if banner == null:
		return
	var is_hold_out := false
	if round_manager and round_manager.has_method("is_hold_out_round"):
		is_hold_out = bool(round_manager.is_hold_out_round())
	elif round_manager and round_manager.has_method("is_boss_mode"):
		is_hold_out = bool(round_manager.is_boss_mode())
	elif String(gl_PlayerState.dataset.level_name).to_lower().begins_with("boss"):
		is_hold_out = true

	if is_hold_out:
		var seconds := 60
		if round_manager and round_manager.has_method("get_active_timer_seconds"):
			var s := float(round_manager.get_active_timer_seconds())
			if s > 0.0:
				seconds = int(round(s))
		var boss_fmt := gl_DataSet.get_string("shop_challenge_boss", 0)
		if boss_fmt.is_empty():
			#boss_fmt = "HOLD OUT\n %d seconds"
			boss_fmt = "HOLD OUT %d"
		_set_mission_label_text(banner, boss_fmt % seconds)
		return

	var place := gl_DataSet.resolve_place_name(String(gl_PlayerState.dataset.level_name))
	var idx := gl_DataSet.get_place_index(place)
	if idx < 0:
		_set_mission_label_text(banner, "")
		return

	## Jetz endless: show best survival time once the player has a recorded run.
	if gl_DataSet.is_testing_place(place) or place.to_lower() == "jetz":
		var best := 0.0
		if gl_PlayerState.has_method("get_endless_best_seconds"):
			best = float(gl_PlayerState.get_endless_best_seconds(place))
		if best > 0.0:
			var time_txt := _format_endless_best_time(best)
			_set_mission_label_text(banner, "BEST TIME\n%s" % time_txt)
			return

	var challenge := gl_DataSet.get_string("shop_challenge_text", idx)
	_set_mission_label_text(banner, challenge)


func _set_mission_label_text(banner: RichTextLabel, raw: String) -> void:
	var body := raw.strip_edges()
	var host := banner.get_parent() as CanvasItem
	if body.is_empty():
		banner.text = ""
		banner.visible = false
		if host:
			host.visible = false
		return
	banner.visible = true
	if host:
		host.visible = true
	banner.text = "[wave]%s[/wave]" % body


func _format_endless_best_time(seconds: float) -> String:
	if round_manager and round_manager.get("round_timer") and round_manager.round_timer.has_method("format_time"):
		return String(round_manager.round_timer.format_time(seconds))
	var whole := int(maxf(seconds, 0.0))
	var hundredths := int((maxf(seconds, 0.0) - float(whole)) * 100.0)
	return "%d:%02d" % [whole, hundredths]


func _refresh_boss_challenge_banner() -> void:
	_refresh_place_challenge_banner()


func _ensure_boss_challenge_banner() -> RichTextLabel:
	if _boss_challenge_banner != null and is_instance_valid(_boss_challenge_banner):
		return _boss_challenge_banner
	var banner := get_node_or_null("%MissionLabel") as RichTextLabel
	if banner == null:
		banner = get_node_or_null("CenterContainer/MainPanel/VBoxContainer/TopRedPanel/MissionLabelControl/MissionLabel") as RichTextLabel
	_boss_challenge_banner = banner
	return _boss_challenge_banner


## Hide stamp until play_level_complete_stamp animates it in.
func prepare_level_complete_stamp() -> void:
	_pending_level_complete_stamp = true
	var stamp_root := _get_background_complete_stamp()
	if stamp_root == null:
		return
	stamp_root.visible = false
	stamp_root.modulate.a = 0.0
	var stamp_label := stamp_root.get_node_or_null("stampLabel") as Control
	if stamp_label == null:
		stamp_label = stamp_root.get_node_or_null("RichTextLabel") as Control
	if stamp_label:
		stamp_label.modulate.a = 1.0
		stamp_label.scale = Vector2.ONE * 3.0


func play_level_complete_stamp(_place_id: String = "") -> void:
	var stamp_root := _get_background_complete_stamp()
	if stamp_root == null:
		return
	var stamp_label := stamp_root.get_node_or_null("stampLabel") as Control
	if stamp_label == null:
		stamp_label = stamp_root.get_node_or_null("RichTextLabel") as Control
	if stamp_label is RichTextLabel:
		(stamp_label as RichTextLabel).text = "[wave]CLEAR!"

	## Always start hidden so nothing flashes before the stamp animation.
	_pending_level_complete_stamp = false
	stamp_root.visible = false
	stamp_root.modulate.a = 0.0
	if stamp_label:
		stamp_label.modulate.a = 1.0
		stamp_label.scale = Vector2.ONE * 3.0
	await get_tree().process_frame

	stamp_root.visible = true
	stamp_root.modulate.a = 0.0

	var stamp_sfx := get_node_or_null("SFX/shop_purchase_01") as AudioStreamPlayer
	var tween := create_tween()
	tween.tween_property(stamp_root, "modulate:a", 1.0, 0.2)
	if stamp_label:
		tween.parallel().tween_property(stamp_label, "scale", Vector2.ONE, 0.2)
	if stamp_sfx:
		tween.parallel().tween_callback(stamp_sfx.play.bind(0.05)).set_delay(0.15)
	tween.tween_property(self, "scale", default_scale * 0.998, 0.1)
	tween.tween_property(self, "scale", default_scale, 0.05)
	tween.tween_interval(0.85)
	if stamp_label:
		tween.tween_property(stamp_label, "modulate:a", 0.2, 1.0)
	await tween.finished


func _refresh_background_completion_stamp(_animate: bool = false) -> void:
	var place := gl_DataSet.resolve_place_name(String(gl_PlayerState.dataset.level_name))
	var stamp_root := _get_background_complete_stamp()
	if stamp_root == null:
		return
	## Don't flash the stamp early when the clear-screen flow is about to animate it.
	if _pending_level_complete_stamp:
		stamp_root.visible = false
		stamp_root.modulate.a = 0.0
		return
	if gl_PlayerState.is_place_completed(place):
		stamp_root.visible = true
		stamp_root.modulate.a = 1.0
		var stamp_label := stamp_root.get_node_or_null("stampLabel") as Control
		if stamp_label == null:
			stamp_label = stamp_root.get_node_or_null("RichTextLabel") as Control
		if stamp_label is RichTextLabel:
			(stamp_label as RichTextLabel).text = "[wave]CLEAR!"
		if stamp_label:
			stamp_label.scale = Vector2.ONE
			stamp_label.modulate.a = 1.0
	else:
		stamp_root.visible = false
		stamp_root.modulate.a = 0.0


func _get_background_complete_stamp() -> Control:
	return get_node_or_null("CenterContainer/MainPanel/BackgroundImages/100_percent") as Control


func purchase_made(_upgrade_type:String = '') -> void:
	
	update_cash_label_color()
	var old_cash := player_cash
	
	var reroll_colour_tween := create_tween().set_trans(Tween.TRANS_SINE)
	reroll_colour_tween.tween_property(cash_label, "modulate", Color('FF0000'), 0.1)
	reroll_colour_tween.tween_callback(update_shop)
	reroll_colour_tween.tween_property(cash_label, "modulate", Color(1, 1, 1, 1), 0.2)
	reroll_colour_tween.tween_callback(reset_cash_label_color)
	sfx_purchase_made()
	update_shop()
	
	var spent := old_cash - player_cash
	if spent > 0:
		spawn_spent_cash_label(spent)
	
	EventBus.instance.player_update_stats_visually.emit()
	
	for i in all_skills:
		if i.has_method("update_cost"):
			i.update_cost()
			
	update_cash_label_color()
	
func spawn_spent_cash_label(amount: int) -> void:
	var source := _wallet_label()
	if source == null:
		return
	var floating_label := source.duplicate() as RichTextLabel

	# Detach from layout so it can float freely over everything
	floating_label.top_level = true
	floating_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floating_label.z_index = 100

	add_child(floating_label)

	floating_label.global_position = source.global_position
	floating_label.size = source.size
	floating_label.text = "[color=#ff4444]-%s[/color]" % CommonCode.format_money(amount)
	floating_label.modulate = Color(1, 1, 1, 1)
	floating_label.show()

	var start_pos := floating_label.global_position

	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(floating_label, "global_position:y", start_pos.y - 150.0, 1.0)
	tween.tween_property(floating_label, "modulate:a", 0.0, 2.0)
	tween.set_parallel(false)

	await tween.finished
	floating_label.queue_free()


## Shoot for Cents payout — show dollars won, then add them to player cash.
func receive_cents_winnings(dollars: int) -> void:
	if dollars <= 0:
		return
	var before := int(gl_PlayerState.dataset.cash)
	gl_PlayerState.add_cash(dollars)
	player_cash = int(gl_PlayerState.dataset.cash)
	_show_cents_winnings_float(dollars)
	_roll_cash_from_to(before, player_cash)
	if EventBus.instance:
		EventBus.instance.update_money.emit()


func _show_cents_winnings_float(dollars: int) -> void:
	var source := _wallet_label()
	if source == null:
		return
	var floating_label := source.duplicate() as RichTextLabel
	floating_label.top_level = true
	floating_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floating_label.z_index = 100
	add_child(floating_label)
	floating_label.global_position = source.global_position
	floating_label.size = source.size
	floating_label.text = "[color=#2ecc71]+%s[/color]" % CommonCode.format_money(dollars)
	floating_label.modulate = Color(1, 1, 1, 1)
	floating_label.show()
	var start_pos := floating_label.global_position
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(floating_label, "global_position:y", start_pos.y - 150.0, 1.0)
	tween.tween_property(floating_label, "modulate:a", 0.0, 1.6)
	tween.set_parallel(false)
	tween.tween_callback(floating_label.queue_free)


func _roll_cash_from_to(from_cash: int, to_cash: int) -> void:
	#return
	var label := _wallet_label()
	if label == null:
		return
	label.show()
	label.modulate.a = 1.0
	var duration := clampf(absf(float(to_cash - from_cash)) / 80.0, 0.35, 1.4)
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(
		func(value: float):
			label.text = _format_cash_label(int(value)),
		float(from_cash),
		float(to_cash),
		duration
	)
	tween.tween_callback(update_shop_labels)
	if has_node("SFX/shop_coin_sfx_01"):
		$SFX/shop_coin_sfx_01.play()
	if has_node("SFX/cash_roll_up"):
		$SFX/cash_roll_up.play()
	
	
func enter_state(new_state: SkillState) -> void:
	current_state = new_state

	match new_state:
		SkillState.INACTIVE:
			update_inactive()
		
		SkillState.OPEN_MENU:
			update_open_menu()
		
		SkillState.IN_MENU:
			update_in_menu()
		
		SkillState.CLOSE_MENU:
			update_close_menu()
		_:
			print("No State Exists - Skill Menu Script")


func _set_shop_crate_overlay_visible(is_open: bool) -> void:
	if shop_crate_overlay == null:
		return
	if is_open:
		if shop_crate_overlay.has_method("show_overlay"):
			shop_crate_overlay.show_overlay()
		else:
			shop_crate_overlay.show()
	else:
		if shop_crate_overlay.has_method("hide_overlay"):
			shop_crate_overlay.hide_overlay()
		else:
			shop_crate_overlay.hide()


func update_inactive() -> void:
	pass


func update_shop() -> void:
	var settings = gl_PlayerState.get_all()
	
	player_cash = settings.cash
	current_round = settings.round
	
	price_reroll = int(gl_DataSet.get_value('price_reroll', reroll_index))
	_update_buy_ammo_cost_label()
	
	update_shop_labels()


func _update_buy_ammo_cost_label() -> void:
	var buy_ammo := get_node_or_null('%BuyAmmo') as Control
	if buy_ammo == null:
		return
	var cost_label := buy_ammo.find_child('CostLabel', true, false) as RichTextLabel
	if cost_label:
		var ammo_price := int(gl_DataSet.get_value('price_max_ammo', gl_PlayerState.dataset.power_max_ammo))
		cost_label.text = "[wave]$" + str(ammo_price)
	_refresh_ammo_popup_text()


func _setup_ammo_count_popup() -> void:
	var buy_ammo := get_node_or_null('%BuyAmmo') as Control
	if buy_ammo == null:
		return

	_ammo_popup = buy_ammo.get_node_or_null('AmmoCountPopUp') as Control
	if _ammo_popup == null:
		return

	_ammo_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in _ammo_popup.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_ammo_popup.pivot_offset_ratio = Vector2(0.5, 0.0)
	_ammo_popup_rest_scale = _ammo_popup.scale if _ammo_popup.scale != Vector2.ZERO else Vector2.ONE
	_ammo_popup_rest_position = _ammo_popup.position
	_ammo_popup.scale = Vector2(_ammo_popup_rest_scale.x, 0.01)
	_ammo_popup.hide()

	_refresh_ammo_popup_text()

	if not buy_ammo.mouse_entered.is_connected(_show_ammo_count_popup):
		buy_ammo.mouse_entered.connect(_show_ammo_count_popup)
	if not buy_ammo.mouse_exited.is_connected(_hide_ammo_count_popup):
		buy_ammo.mouse_exited.connect(_hide_ammo_count_popup)


func _refresh_ammo_popup_text() -> void:
	if _ammo_popup == null:
		return
	var pack_size := int(gl_DataSet.get_value('ammo_pack_size', 0))
	if _ammo_popup is RichTextLabel:
		(_ammo_popup as RichTextLabel).text = "+" + str(pack_size)


func _show_ammo_count_popup() -> void:
	if _ammo_popup == null:
		return

	_refresh_ammo_popup_text()
	if _ammo_popup_tween:
		_ammo_popup_tween.kill()

	_ammo_popup.show()
	_ammo_popup.pivot_offset_ratio = Vector2(0.5, 0.0)
	_ammo_popup.scale = Vector2(_ammo_popup_rest_scale.x, 0.01)
	_ammo_popup.position = _ammo_popup_rest_position + Vector2(0.0, -12.0)

	_ammo_popup_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_ammo_popup_tween.tween_property(_ammo_popup, 'scale', _ammo_popup_rest_scale, 0.22)
	_ammo_popup_tween.parallel().tween_property(_ammo_popup, 'position', _ammo_popup_rest_position, 0.22)


func _hide_ammo_count_popup() -> void:
	if _ammo_popup == null:
		return

	if _ammo_popup_tween:
		_ammo_popup_tween.kill()

	_ammo_popup.pivot_offset_ratio = Vector2(0.5, 0.0)
	var collapsed_scale := Vector2(_ammo_popup_rest_scale.x, 0.01)
	var tuck_up := _ammo_popup_rest_position + Vector2(0.0, -10.0)

	_ammo_popup_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_ammo_popup_tween.tween_property(_ammo_popup, 'scale', collapsed_scale, 0.16)
	_ammo_popup_tween.parallel().tween_property(_ammo_popup, 'position', tuck_up, 0.16)
	_ammo_popup_tween.tween_callback(_ammo_popup.hide)


func _force_hide_ammo_count_popup() -> void:
	if _ammo_popup == null:
		return
	if _ammo_popup_tween:
		_ammo_popup_tween.kill()
	_ammo_popup.scale = Vector2(_ammo_popup_rest_scale.x, 0.01)
	_ammo_popup.position = _ammo_popup_rest_position
	_ammo_popup.hide()


func _setup_pause_label_popup() -> void:
	var pause_btn := get_node_or_null("%PauseGameButton") as Control
	if pause_btn == null:
		return

	_pause_popup = pause_btn.get_node_or_null("PauseLabelPopUp") as Control
	if _pause_popup == null:
		return

	_pause_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in _pause_popup.get_children():
		if child is Control:
			child.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_pause_popup.pivot_offset_ratio = Vector2(0.5, 1.0)
	_pause_popup_rest_scale = _pause_popup.scale if _pause_popup.scale != Vector2.ZERO else Vector2.ONE
	_pause_popup_rest_position = _pause_popup.position
	_pause_popup.scale = Vector2(_pause_popup_rest_scale.x, 0.01)
	_pause_popup.hide()

	if not pause_btn.mouse_entered.is_connected(_show_pause_label_popup):
		pause_btn.mouse_entered.connect(_show_pause_label_popup)
	if not pause_btn.mouse_exited.is_connected(_hide_pause_label_popup):
		pause_btn.mouse_exited.connect(_hide_pause_label_popup)


func _show_pause_label_popup() -> void:
	if _pause_popup == null:
		return

	if _pause_popup_tween:
		_pause_popup_tween.kill()

	_pause_popup.show()
	_pause_popup.pivot_offset_ratio = Vector2(0.5, 1.0)
	_pause_popup.scale = Vector2(_pause_popup_rest_scale.x, 0.01)
	_pause_popup.position = _pause_popup_rest_position + Vector2(0.0, 12.0)

	_pause_popup_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pause_popup_tween.tween_property(_pause_popup, "scale", _pause_popup_rest_scale, 0.22)
	_pause_popup_tween.parallel().tween_property(_pause_popup, "position", _pause_popup_rest_position, 0.22)


func _hide_pause_label_popup() -> void:
	if _pause_popup == null:
		return

	if _pause_popup_tween:
		_pause_popup_tween.kill()

	_pause_popup.pivot_offset_ratio = Vector2(0.5, 1.0)
	var collapsed_scale := Vector2(_pause_popup_rest_scale.x, 0.01)
	var tuck_down := _pause_popup_rest_position + Vector2(0.0, 10.0)

	_pause_popup_tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_pause_popup_tween.tween_property(_pause_popup, "scale", collapsed_scale, 0.16)
	_pause_popup_tween.parallel().tween_property(_pause_popup, "position", tuck_down, 0.16)
	_pause_popup_tween.tween_callback(_pause_popup.hide)


func _force_hide_pause_label_popup() -> void:
	if _pause_popup == null:
		return
	if _pause_popup_tween:
		_pause_popup_tween.kill()
	_pause_popup.scale = Vector2(_pause_popup_rest_scale.x, 0.01)
	_pause_popup.position = _pause_popup_rest_position
	_pause_popup.hide()


func update_open_menu() -> void:
	if gl_PlayerState.dataset.round == 1:
		_music_control_call("ensure_shop_music_playing")
	
	reset_cash_label_color()
	sfx_open_shop()
	update_shop()
	update_place_label()
	_refresh_place_challenge_banner()
	#%Play_round_text.text = "[i][wave][color=]PLAY\n[color=c70102]%s" % CommonCode.format_money(_current_play_price())

	
	update_shop_labels()

	# PERFECT RESET
	modulate.a = 0.0
	scale = Vector2.ONE * 0.01
	position = default_position
	pivot_offset = default_pivot_offset

	show()
	_set_shop_crate_overlay_visible(true)

	# OPEN ANIMATION
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_OUT)

	tween.parallel().tween_property(self, "scale", default_scale, 0.3)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.18)

	_music_control_call("raise_shop_menu_music")

	await tween.finished
	
	await get_tree().create_timer(0.15, false).timeout
	
	#await reveal_random_skills(0.05)

	enter_state(SkillState.IN_MENU)
	
func play_round_button_pressed() -> void:
	# Hide focus triangle during the play-out animation (avoids jumping to MapButton).
	UiFocus.set_indicator_suppressed(true)
	var focused := get_viewport().gui_get_focus_owner() as Control
	if focused:
		focused.release_focus()

	var player := get_tree().get_first_node_in_group('Player') as Player
	if player and player.has_method("refill_ammo_to_max_animated"):
		player.refill_ammo_to_max_animated()
	elif player and player.has_method("refill_ammo_to_max"):
		player.refill_ammo_to_max(true)

	shake_shop()
	if reroll_button:
		reroll_button.hide()
	%PlayButton.disabled = true
	#$CenterContainer/MainPanel/VBoxContainer/TreePanel/AvailableUpgrades.modulate.a = 0.0
	#$CenterContainer/MainPanel/VBoxContainer/UpgradeStats.modulate.a = 0.0
	var play_round_cost = _current_play_price()
	gl_PlayerState.log_buy('debug_add_cash', play_round_cost)
	var round_hbox := $CenterContainer/MainPanel/VBoxContainer/RoundSelector/Panel/VBoxContainer/HBoxContainer
	var tween := create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	tween.tween_callback(purchase_made.bind('debug_add_cash'))
	tween.tween_interval(0.15)
	tween.tween_property(round_hbox, "modulate:a", 0.0, 0.15)

	tween.tween_interval(0.8)
	await tween.finished
	
	#purchase_made('debug_add_cash')
	
	
	#await get_tree().create_timer(1.0, false).timeout
	update_close_menu()
	await get_tree().create_timer(0.1, false).timeout
	%PlayButton.disabled = false
	round_hbox.modulate.a = 1.0


## Hide shop for the debug level editor without firing CLOSE_MENU / SHOP_END.
func soft_hide_for_level_editor() -> void:
	reset_cash_label_color()
	_close_shop_mini_game()
	_set_shop_crate_overlay_visible(false)
	current_state = SkillState.INACTIVE
	hide()
	_music_control_call("lower_shop_menu_music")


## Re-open shop after leaving the level editor (BACK).
func soft_show_from_level_editor() -> void:
	enter_state(SkillState.OPEN_MENU)
	
func update_close_menu() -> void:
	UiFocus.set_indicator_suppressed(true)
	reset_cash_label_color()
	sfx_close_shop()
	_force_hide_ammo_count_popup()
	_force_hide_pause_label_popup()
	_close_shop_mini_game()
	_set_shop_crate_overlay_visible(false)
	
	$CenterContainer/MainPanel/VBoxContainer/Money_control.show()
	#$CenterContainer/MainPanel/VBoxContainer/UpgradeStats.show()
	%QuitMenu.hide()
	
	clear_available_skills()

	_music_control_call("lower_shop_menu_music")
	reroll_index = 0
	
	# ENSURE PIVOT IS CORRECT
	pivot_offset = default_pivot_offset
	player_cash = gl_PlayerState.dataset.cash
	update_cost_label()
	
	
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
	
	hide()
	EventBus.instance.close_shop.emit()

	#reroll_button.show()
	#$CenterContainer/MainPanel/VBoxContainer/TreePanel/AvailableUpgrades.modulate.a = 1.0
	#$CenterContainer/MainPanel/VBoxContainer/UpgradeStats.modulate.a = 1.0
	%PlayButton.modulate.a = 1.0
	
	if round_manager:
		round_manager.enter_state(round_manager.RoundState.SHOP_END)
				
	for i in all_skills:
		i.new_round = true
		
		
		
func roll_up_cash_first_round() -> void:
	_refresh_range_reward_label()
	_refresh_player_money_label()
	update_cost_label()
	return
	if gl_PlayerState.dataset.power_gun < 1:
		return

	var target_cash: int = gl_PlayerState.dataset.cash

	# Show "0" immediately, invisible, then fade in
	cash_label.text = _format_cash_label(0)
	cash_label.modulate.a = 0.0
	cash_label.show()

	var duration: float = clamp(target_cash / 1000.0, 0.5, 3.0)
	duration = clamp(duration, 0.5, 1.5)
	var sfx := $SFX/shop_reroll_sfx_02
	var sfx_2 := $SFX/cash_roll_up
	var default_pitch: float = sfx.pitch_scale
	var default_pitch_2: float = sfx_2.pitch_scale

	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)

	tween.tween_property(cash_label, "modulate:a", 1.0, 0.2)

	tween.tween_method(
		func(value: float):
			cash_label.text = _format_cash_label(int(value)),
		0.0,
		float(target_cash),
		duration
	)

	# Ramp both SFX pitches up over the course of the roll-up
	tween.tween_property(sfx, "pitch_scale", 1.8, duration)
	tween.tween_property(sfx_2, "pitch_scale", 1.8, duration)

	tween.set_parallel(false)

	# Retrigger both tick sounds repeatedly while the tween runs
	var tick_interval := 0.08
	var elapsed := 0.0
	while elapsed < duration:
		var pitch : float = lerp(0.8, 1.8, elapsed / duration)
		sfx.pitch_scale = pitch
		sfx_2.pitch_scale = pitch
		sfx.play(0.08)
		sfx_2.play(0.08)
		await get_tree().create_timer(tick_interval, false).timeout
		elapsed += tick_interval

	await tween.finished

	# Reset pitch back to default once the roll-up finishes
	sfx.pitch_scale = default_pitch
	sfx_2.pitch_scale = default_pitch_2

	await get_tree().create_timer(1.0, false).timeout
	update_cost_label()

	 
func is_skill_maxed(skill) -> bool:
	
	if can_appear_when_maxed:
		return false


	var power_name : String = "power_" + skill.upgrade_type

	if !gl_PlayerState.dataset.has(power_name):
		return false

	var current_level : int = gl_PlayerState.dataset[power_name]

	if !gl_DataSet.dataset_float.has(power_name):
		return false

	var max_level : int = gl_DataSet.dataset_float[power_name].size() - 1

	return current_level >= max_level



func update_in_menu() -> void:
	roll_up_cash_first_round()
	UiFocus.set_indicator_suppressed(false)
	_wire_shop_focus_neighbors()
	_focus_shop_controls()


func _strip_non_interactive_focus(node: Node) -> void:
	# Decorative panels/labels must not steal controller focus from real buttons.
	if node is Control and not (node is BaseButton):
		var control := node as Control
		if control is RichTextLabel or control is Label or control is Panel \
				or control is PanelContainer or control is TextureRect or control is ColorRect:
			control.focus_mode = Control.FOCUS_NONE
	for child in node.get_children():
		_strip_non_interactive_focus(child)


func _focus_shop_controls() -> void:
	var preferred: Control = null
	var play_btn := get_node_or_null("%PlayButton") as Control
	if play_btn and UiFocus.can_focus(play_btn):
		preferred = play_btn
	#else:
		#for child in available_upgrades.get_children():
			#if child is Control and UiFocus.can_focus(child as Control):
				#preferred = child as Control
				#break
	if preferred == null:
		var map_btn := get_node_or_null("%MapButton") as Control
		if map_btn and UiFocus.can_focus(map_btn):
			preferred = map_btn
	UiFocus.grab_in(self, preferred)


func _wire_shop_focus_neighbors() -> void:
	var map_btn := get_node_or_null("%MapButton") as Control
	var play_btn := get_node_or_null("%PlayButton") as Control
	var ammo_btn := get_node_or_null("%BuyAmmo") as Control
	var pause_btn := get_node_or_null("%PauseGameButton") as Control
	var cents_btn := get_node_or_null("%ShootForCentsButton") as Control

	var upgrades: Array[Control] = []
	#for child in available_upgrades.get_children():
		#if child is Control and UiFocus.can_focus(child as Control):
			#upgrades.append(child as Control)

	var rounds: Array[Control] = []
	var round_row := get_node_or_null("CenterContainer/MainPanel/VBoxContainer/RoundSelector/Panel/VBoxContainer/HBoxContainer")
	if round_row:
		for child in round_row.get_children():
			if child is Control and UiFocus.can_focus(child as Control):
				rounds.append(child as Control)

	var bottom: Array[Control] = []
	for btn in [play_btn, ammo_btn, pause_btn, cents_btn]:
		if btn and UiFocus.can_focus(btn):
			bottom.append(btn)

	# Horizontal chains.
	UiFocus.wire_horizontal(upgrades)
	UiFocus.wire_horizontal(rounds)
	UiFocus.wire_horizontal(bottom)

	var mid: Control = null
	if not upgrades.is_empty():
		mid = upgrades[0]
	elif reroll_button and UiFocus.can_focus(reroll_button):
		mid = reroll_button
	elif not rounds.is_empty():
		mid = rounds[0]
	elif not bottom.is_empty():
		mid = bottom[0]

	if map_btn and mid:
		map_btn.focus_neighbor_bottom = mid.get_path()
		map_btn.focus_neighbor_top = mid.get_path()
		map_btn.focus_next = mid.get_path()
		mid.focus_neighbor_top = map_btn.get_path()

	if not upgrades.is_empty() and not rounds.is_empty():
		for u in upgrades:
			u.focus_neighbor_bottom = rounds[0].get_path()
		for r in rounds:
			r.focus_neighbor_top = upgrades[0].get_path()

	if not rounds.is_empty() and not bottom.is_empty():
		for r in rounds:
			r.focus_neighbor_bottom = bottom[0].get_path()
		for b in bottom:
			b.focus_neighbor_top = rounds[0].get_path()
	elif not upgrades.is_empty() and not bottom.is_empty():
		for u in upgrades:
			u.focus_neighbor_bottom = bottom[0].get_path()
		for b in bottom:
			b.focus_neighbor_top = upgrades[0].get_path()

	if map_btn and not bottom.is_empty():
		bottom[0].focus_neighbor_bottom = map_btn.get_path()

func gun_purchased() -> void:
	reroll_unlocked = true
	#transport_tickets.modulate.a = 0.0
	#transport_tickets.show()
	#$CenterContainer/MainPanel/VBoxContainer/UpgradeStats.show()
	sfx_purchase_made()
	update_shop()

	#var tween = create_tween()
	#tween.tween_property(transport_tickets, "modulate:a", 1.0, 0.5)
	#tween.parallel().tween_property($CenterContainer/MainPanel/VBoxContainer/UpgradeStats, "modulate:a", 1.0, 0.5)
	
	open_map_menu()

func _on_re_roll_pressed() -> void:
		
	if is_rerolling:
		return
	
	var reroll_current_price = gl_DataSet.get_value('price_reroll', reroll_index)
		
	var button_down := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	button_down.tween_property(reroll_button, "position:y", 5.0, 0.1).as_relative()
	button_down.tween_property(reroll_button, "position:y", -5.0, 0.1).as_relative()
	# Not enough money
	
	if reroll_current_price != 0:
		if player_cash < reroll_current_price:
			purchase_denied_tween()
			return
	
	is_rerolling = true
	
	for i in all_skills:
		i.cost = -1
		i.new_round = true
	
	sfx_reroll_purchased()
	# Remove money
	spawn_spent_cash_label(reroll_current_price)
	gl_PlayerState.log_buy("reroll", reroll_current_price)
	reroll_index += 1
	await get_tree().create_timer(0.1, false).timeout
	update_shop()
	#EventBus.instance.update_money.emit()
	
	
	

	
	# Hide current buttons quickly
	# Hide current displayed skills
	for skill in available_upgrades.get_children():
		
		var hide_tween := create_tween()
		hide_tween.set_trans(Tween.TRANS_SINE)
		hide_tween.set_ease(Tween.EASE_IN)
		
		hide_tween.parallel().tween_property(skill, "modulate:a", 0.0, 0.12)
		hide_tween.parallel().tween_property(skill, "scale", Vector2(0.8, 0.8), 0.12)

	await get_tree().create_timer(0.05, false).timeout
	
	# Reveal new ones
	#await reveal_random_skills(0.05, true)
	_wire_shop_focus_neighbors()

	
	is_rerolling = false

func _on_continue_fee_changed(_new_fee: int = 0) -> void:
	_refresh_keep_continue_label()


func _refresh_keep_continue_label() -> void:
	var keep := get_node_or_null("%KeepContinueLabel") as RichTextLabel
	if keep == null:
		return
	var fee := 100
	if gl_PlayerState and gl_PlayerState.has_method("get_continue_fee"):
		fee = int(gl_PlayerState.get_continue_fee())



func _current_play_price() -> int:
	if round_manager and round_manager.has_method("get_current_play_price"):
		return int(round_manager.get_current_play_price())
	return int(gl_DataSet.get_value("price_play_round", 0))


func _refresh_play_button_cost() -> void:
	var play_btn := get_node_or_null("%PlayButton") as Control
	if play_btn == null:
		return
	var cost := play_btn.find_child("CostLabel", true, false) as RichTextLabel
	if cost:
		var price := _current_play_price()
		if price <= 0:
			cost.text = "[wave]FREE"
		else:
			cost.text = "[wave]%s" % CommonCode.format_money(price)

func _on_continue_reserve_broken() -> void:
	var warning := get_node_or_null("%ShortContinueWarning") as RichTextLabel
	if warning == null:
		return
	warning.text = "[center]THIS LEAVES YOU SHORT"
	warning.modulate.a = 1.0
	warning.show()
	var tween := create_tween()
	tween.tween_interval(1.4)
	tween.tween_property(warning, "modulate:a", 0.0, 0.35)
	tween.tween_callback(warning.hide)


func purchase_denied_tween() -> void:
	$SFX/purchase.play()
	var denied_tween := create_tween()
		
	denied_tween.set_trans(Tween.TRANS_SINE)
	denied_tween.set_ease(Tween.EASE_OUT)
	
	var original_position := position
	
	denied_tween.tween_property(self, "position:x", original_position.x - 12, 0.05)
	denied_tween.tween_property(self, "position:x", original_position.x + 12, 0.05)
	denied_tween.tween_property(self, "position:x", original_position.x, 0.05)
		



func update_shop_labels() -> void:
	
	_refresh_range_reward_label()
	_refresh_player_money_label()
	update_cash_label_color()
	update_cost_label()
	_refresh_keep_continue_label()
	_refresh_play_button_cost()
	return
	#if price_reroll == 0:
		#reroll_button.get_child(0).text = "REROLL\n[wave][color=#c70102]FREE[/color]"
#
	#else:
		#reroll_button.get_child(0).text = "[wave]REROLL\n[color=#c70102]%s[/color]" % CommonCode.format_money(price_reroll)

func sfx_purchase_made() -> void:
	$SFX/shop_purchase_01.play()
	#$SFX/shop_purchase_02.play()
	await get_tree().create_timer(0.1, false).timeout
	$SFX/shop_purchase_02.play()
	$SFX/shop_coin_sfx_01.play()

func sfx_reroll_purchased() -> void:
	#$SFX/shop_purchase_01.play()
	##$SFX/shop_purchase_02.play()
	#await get_tree().create_timer(0.1, false).timeout
	$SFX/shop_purchase_02.play()
	$SFX/shop_coin_sfx_01.play()


func _music_control_call(method_name: String) -> void:
	var music := _get_music_control()
	if music and music.has_method(method_name):
		music.call(method_name)


func _get_music_control() -> Node:
	if round_manager and round_manager.music_manager:
		return round_manager.music_manager
	return get_tree().get_first_node_in_group("level_music")


func sfx_open_shop() -> void:
	$SFX/shop_open_sfx_01.play(0.3)
	$SFX/hud_click_1.play()
	$SFX/hud_click_2.play()
	$SFX/hud_click_3.play()
	$SFX/low_humming.play()
	
func sfx_close_shop() -> void:
	$SFX/shop_close_sfx_01.play(0.5)
	$SFX/hud_click_1.play()
	$SFX/hud_click_2.play()
	$SFX/hud_click_3.play()
	$SFX/low_humming.stop()


func _on_add_money_pressed() -> void:
	gl_PlayerState.log_buy('debug_add_cash', -1000)
	update_shop()

	for skills in available_upgrades.get_children():
		#skills.show()
		#skills.modulate.a = 1.0)
		#skills.scale = Vector2.ONE * 0.8
		skills.reset_buttons_settings()


func _on_reset_money_pressed() -> void:
	gl_PlayerState.reset_cash_debug_tool()
	update_shop()

	for skills in available_upgrades.get_children():
		skills.reset_buttons_settings()


func _on_max_out_powers_pressed() -> void:
	gl_PlayerState.buy_all_upgrades()
	update_shop()

	for skills in available_upgrades.get_children():
		skills.reset_buttons_settings()
		
func update_cost_label() -> void:
	_refresh_player_money_label()
	update_cash_label_color()
	await get_tree().process_frame

	var label := _wallet_label()
	if label:
		label.pivot_offset.x = label.size.x * 0.5
	
func _setup_shop_mini_game() -> void:
	# Kept for compatibility; mini-game is created on first open.
	pass


func _ensure_shop_mini_game() -> void:
	if not ENABLE_SHOOT_FOR_CENTS:
		return
	if _shop_mini_game != null and is_instance_valid(_shop_mini_game):
		return
	var packed := ResourceLoader.load(SHOP_MINI_GAME_SCENE_PATH, "PackedScene", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
	if packed == null:
		push_warning("Shop: failed to load ShopMiniGame")
		return
	_shop_mini_game = packed.instantiate()
	add_child(_shop_mini_game)
	if _shop_mini_game.has_method("attach_to_shop"):
		_shop_mini_game.attach_to_shop(self)


func _close_shop_mini_game() -> void:
	if _shop_mini_game and _shop_mini_game.has_method("close") and _shop_mini_game.is_open:
		_shop_mini_game.close()


func _unhandled_input(event: InputEvent) -> void:
	#
	#if event is InputEventKey and event.pressed and not event.echo:
	if not ENABLE_SHOOT_FOR_CENTS:
		return
	if Input.is_action_just_pressed('select_button'):
		if current_state == SkillState.IN_MENU or current_state == SkillState.OPEN_MENU:
			_ensure_shop_mini_game()
			if _shop_mini_game and _shop_mini_game.has_method("toggle"):
				_shop_mini_game.toggle()
				get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if !OS.is_debug_build():
		set_process_input(false)
		return
		
	if Input.is_key_label_pressed(KEY_KP_0):
		%AddMoney.visible = !%AddMoney.visible
		%MaxOutPowers.visible = !%MaxOutPowers.visible
		%ResetMoney.visible = !%ResetMoney.visible
		#%RoundSelector.visible = !%RoundSelector.visible
		

func setup_shop_for_rounds() -> void:
	%RoundSelector.show()
	_hide_round_selector_buttons()


func _hide_round_selector_buttons() -> void:
	var panel := get_node_or_null("CenterContainer/MainPanel/VBoxContainer/RoundSelector/Panel") as CanvasItem
	if panel:
		panel.show()
	var panel3 := get_node_or_null("CenterContainer/MainPanel/VBoxContainer/RoundSelector/Panel3") as CanvasItem
	if panel3:
		panel3.show()
	var round_button_cont := get_node_or_null("CenterContainer/MainPanel/VBoxContainer/RoundSelector/Panel/VBoxContainer/HBoxContainer") as CanvasItem
	if round_button_cont:
		round_button_cont.hide()


func _apply_round_selector_boss_mode(_is_boss: bool) -> void:
	%RoundSelector.show()
	_hide_round_selector_buttons()


## Rebuild round-button states from the restored sequence index for this range.
## sequence_index = next round to play (0-based). Completed rounds are stamped perfect.
func sync_rounds_to_progress(sequence_index: int, total_rounds: int) -> void:
	var is_boss := false
	if round_manager and round_manager.has_method("is_boss_mode"):
		is_boss = bool(round_manager.is_boss_mode())
	elif String(gl_PlayerState.dataset.level_name).to_lower().begins_with("boss"):
		is_boss = true
	if is_boss:
		_apply_round_selector_boss_mode(true)
		return

	_apply_round_selector_boss_mode(false)
	var round_button_cont: HBoxContainer = $CenterContainer/MainPanel/VBoxContainer/RoundSelector/Panel/VBoxContainer/HBoxContainer
	if round_button_cont == null:
		return
	var buttons := round_button_cont.get_children()
	var next_index := maxi(sequence_index, 0)
	for i in buttons.size():
		var btn = buttons[i]
		if btn == null or not btn.has_method("enter_state"):
			continue
		# Hide extra selector slots beyond this range's round count.
		if total_rounds > 0 and i >= total_rounds:
			btn.visible = false
			btn.enter_state(btn.State.LOCKED)
			continue
		btn.visible = true
		if i < next_index:
			btn.enter_state(btn.State.PERFECTED)
		elif i == next_index and (total_rounds <= 0 or next_index < total_rounds):
			btn.enter_state(btn.State.AVAILABLE)
		else:
			btn.enter_state(btn.State.LOCKED)
	_hide_round_selector_buttons()


func mark_round_as_cleared() -> void:
	var round_button_cont : HBoxContainer = 	$CenterContainer/MainPanel/VBoxContainer/RoundSelector/Panel/VBoxContainer/HBoxContainer
	for i in round_button_cont.get_children():
		if i.current_state != i.State.AVAILABLE:
			continue
			
		else:
			if i.current_state != i.State.PERFECTED:
				i.enter_state(i.State.CLEARED)
				break
			else:
				break
	
func mark_round_as_perfect(played_index: int = -1) -> void:
	var round_button_cont : HBoxContainer = 	$CenterContainer/MainPanel/VBoxContainer/RoundSelector/Panel/VBoxContainer/HBoxContainer
	var buttons := round_button_cont.get_children()
	if played_index >= 0 and played_index < buttons.size():
		var btn = buttons[played_index]
		if btn and btn.has_method("enter_state"):
			btn.enter_state(btn.State.PERFECTED)
		return

	for i in buttons:
		if i.current_state == i.State.AVAILABLE: # || i.current_state == i.State.CLEARED:
			i.enter_state(i.State.PERFECTED)
			break
			

func increase_round_available(played_index: int = -1) -> void:
	var round_button_cont : HBoxContainer = 	$CenterContainer/MainPanel/VBoxContainer/RoundSelector/Panel/VBoxContainer/HBoxContainer
	var buttons := round_button_cont.get_children()
	var total_rounds := 0
	if round_manager and "current_rock_sequence" in round_manager:
		total_rounds = int(round_manager.current_rock_sequence.size())
	## Only unlock the round immediately after the one just cleared (never jump ahead on replay).
	if played_index >= 0:
		var next_index := played_index + 1
		if total_rounds > 0 and next_index >= total_rounds:
			return
		if next_index < buttons.size():
			var next_btn = buttons[next_index]
			if next_btn and next_btn.has_method("enter_state") and next_btn.current_state == next_btn.State.LOCKED:
				next_btn.visible = true
				next_btn.enter_state(next_btn.State.AVAILABLE)
		return

	for i in buttons.size():
		var btn = buttons[i]
		if total_rounds > 0 and i >= total_rounds:
			break
		if btn.current_state != btn.State.LOCKED:
			continue
		else:
			btn.visible = true
			btn.enter_state(btn.State.AVAILABLE)
			break
	
func restart() -> void:
	_close_shop_mini_game()
	_set_shop_crate_overlay_visible(false)
	current_state = SkillState.INACTIVE

	current_round = 0
	player_cash = gl_PlayerState.dataset.cash

	price_reroll = 0
	reroll_unlocked = true
	reroll_index = 0
	is_rerolling = false

	clear_available_skills()

	hide()
	modulate.a = 1.0
	scale = default_scale
	position = default_position
	pivot_offset = default_pivot_offset

	#cash_label.modulate.a = 0.0
	cash_label.text = "$0"

	for skill in all_skills:
		skill.new_round = true
		skill.reset_buttons_settings()

	update_shop()
	update_shop_labels()
	update_cost_label()
	enter_state(SkillState.CLOSE_MENU)
	
	
func check_the_amount_of_balloons_in_play() -> int:
	var balloon_container := get_tree().get_first_node_in_group('balloon_container')
	if balloon_container:
		return balloon_container.balloons_in_play
		
	else:
		return 0
	
func update_next_ticket() -> void:
	pass

func update_cash_label_color() -> void:
	pass
	#if gl_PlayerState.dataset.cash < 0:
		#cash_label.modulate = Color("c70102ff")
	#else:
		#cash_label.modulate = Color("ffff")


func reset_cash_label_color() -> void:
	if cash_label == null:
		return
	var alpha := cash_label.modulate.a
	cash_label.modulate = Color(1, 1, 1, alpha)


func _on_buy_ammo_pressed() -> void:
	var player := get_tree().get_first_node_in_group('Player') as Player
	if player == null:
		push_warning('Shop: Player not found for ammo purchase')
		return

	if player.is_ammo_full():
		_show_ammo_full_popup()
		return

	var ammo_price := int(gl_DataSet.get_value('price_max_ammo', gl_PlayerState.dataset.power_max_ammo))
	if player_cash < ammo_price:
		purchase_denied_tween()
		return

	var pack_size := player.get_ammo_pack_size()
	if not gl_PlayerState.log_buy('ammo_packs_bought', ammo_price):
		purchase_denied_tween()
		return

	player.add_ammo(pack_size, true)
	purchase_made('ammo_packs_bought')
	
	shake_shop()
	
func shake_shop() -> void:
	var accepted_tween := create_tween()
		
	accepted_tween.set_trans(Tween.TRANS_SINE)
	accepted_tween.set_ease(Tween.EASE_OUT)
	
	var original_position := position
	
	accepted_tween.tween_property(self, "position:y", original_position.y - 12, 0.05)
	accepted_tween.tween_property(self, "position:y", original_position.y + 12, 0.05)
	accepted_tween.tween_property(self, "position:y", original_position.y, 0.05)
		


func _show_ammo_full_popup() -> void:
	purchase_denied_tween()
	
	var popup := RichTextLabel.new()
	popup.bbcode_enabled = true
	popup.fit_content = true
	popup.scroll_active = false
	popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup.z_index = 1
	popup.theme_type_variation = 'WhiteRichText'
	popup.top_level = true
	popup.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	popup.autowrap_mode = TextServer.AUTOWRAP_OFF
	popup.add_theme_font_size_override('normal_font_size', 42)
	popup.text = "[wave]Full!"
	popup.modulate = Color(0.63, 0.006, 0.017, 0.0)
	add_child(popup)

	await get_tree().process_frame
	var buy_ammo_btn: Control = %BuyAmmo
	var start_pos := buy_ammo_btn.global_position + (buy_ammo_btn.size * buy_ammo_btn.scale * 0.5)
	start_pos.x -= popup.size.x * 0.5
	start_pos.y -= 40.0
	popup.global_position = start_pos

	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, 'modulate:a', 1.0, 0.12)
	tween.parallel().tween_property(popup, 'global_position:y', start_pos.y - 100.0, 0.9)
	tween.parallel().tween_property(popup, 'global_position:x', start_pos.x + 30.0, 0.9)
	tween.tween_property(popup, 'modulate:a', 0.0, 0.35)
	await tween.finished
	popup.queue_free()
	
	
func reveal_random_skills(_dur : float = 0.05, wait_reroll : bool = false) -> void:

	clear_available_skills()
	return
	#var _orig_pitch_scale : float = reveal_skill_sfx.pitch_scale
#
	#var selected_skills := []
#
	## FIRST SHOP OPEN
	#if gl_PlayerState.dataset.round == 0:
		#for skill in all_skills:
			#if skill.name == "AddGun": # replace with your actual gun node name
				#selected_skills.append(skill)
				#break
	#
	## NORMAL BEHAVIOUR
	#else:
		#var max_items_in_shop : int = gl_PlayerState.dataset.power_max_items_in_shop
		#
		#var guaranteed_skills := []
		#var random_pool := []
#
		#for skill in all_skills:
#
			#if skill.remove_from_shop:
				#continue
#
			#if is_skill_maxed(skill):
				#continue
#
			#if skill.guaranteed_until_purchased:
				#guaranteed_skills.append(skill)
			#else:
				#random_pool.append(skill)
#
		#random_pool.shuffle()
#
		#selected_skills = guaranteed_skills.duplicate()
#
		#while selected_skills.size() < max_items_in_shop and random_pool.size() > 0:
			#selected_skills.append(random_pool.pop_front())
#
		#selected_skills = selected_skills.slice(0, 3)
	#
	## Reparent selected skills
	#for skill in selected_skills:
#
		#if skill.get_parent():
			#skill.get_parent().remove_child(skill)
#
		#available_upgrades.add_child(skill)
#
		#skill.reset_buttons_settings()
		#skill.show()
		#skill.modulate.a = 0.01
		#skill.scale = Vector2.ONE * 0.8
		#
	#
	#if wait_reroll:
		#await get_tree().create_timer(0.5, false).timeout
	#
	## Reveal animation
	#for skill in selected_skills:
#
		#var tween := create_tween()
		#tween.set_trans(Tween.TRANS_CUBIC)
		#tween.set_ease(Tween.EASE_OUT)
#
		#reveal_skill_sfx.play()
#
		#tween.parallel().tween_property(skill, "modulate:a", 1.0, _dur)
		#tween.parallel().tween_property(skill, "scale", Vector2.ONE * 1.15, _dur)
		#tween.tween_property(skill, "scale", Vector2.ONE, _dur)
		#
		#await tween.finished
#
		#skill._update_visual_state()
		#skill.purchase_particles()
		##reveal_skill_sfx.pitch_scale += 1.0
#
	#reveal_skill_sfx.pitch_scale = _orig_pitch_scale
	

func clear_available_skills() -> void:
	return
	#for skill in available_upgrades.get_children():
		#
		## Reset visuals
		#skill.reset_buttons_settings()
		#skill.hide()
		#skill.modulate.a = 1.0
		#skill.scale = Vector2.ONE
		#
		## Move back to storage container
		#available_upgrades.remove_child(skill)
		#all_skills_container.add_child(skill)
