extends Control

const SHOP_MINI_GAME_SCENE := preload("res://ch/Shop/ShopMiniGame.tscn")

@export var round_manager : RoundManager
@export var money_control : Node
@export var reveal_skill_sfx: AudioStreamPlayer
@onready var cash_label: RichTextLabel = %CashBalanceLabel
@onready var available_upgrades: HBoxContainer = $CenterContainer/MainPanel/VBoxContainer/TreePanel/AvailableUpgrades
@onready var reroll_button: Button = %Reroll
@onready var all_skills_container: Control = %TreeCanvas

@export var can_appear_when_maxed := false


var default_scale := Vector2.ONE
var default_position := Vector2.ZERO
var default_pivot_offset := Vector2.ZERO

var price_reroll := 0
var reroll_unlocked := false
var reroll_index := 0
var is_rerolling := false

var all_skills : Array

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
var _ammo_popup_tween: Tween
var _ammo_popup_rest_scale := Vector2.ONE
var _ammo_popup_rest_position := Vector2.ZERO
var _shop_mini_game: Control


func _ready() -> void:
	
	EventBus.instance.update_money.connect(update_shop_labels)

	_music_control_call("ensure_shop_music_playing")

	# STORE DEFAULT TRANSFORMS
	default_scale = scale
	default_position = position
	await get_tree().process_frame

	# BOTTOM RIGHT PIVOT
	#default_pivot_offset = size 
	#pivot_offset = default_pivot_offset
	pivot_offset_ratio = Vector2(0.5,1.5)
	cash_label.modulate.a = 0.0
	$CenterContainer/MainPanel/VBoxContainer/UpgradeStats.modulate.a = 0.0
	
	hide()

	all_skills = all_skills_container.get_children()

	EventBus.instance.open_shop.connect(enter_state.bind(SkillState.OPEN_MENU))
	#$NextRound.pressed.connect(enter_state.bind(SkillState.CLOSE_MENU))
	cash_label.hide()
	#update_shop_labels()
	cash_label.text = "$0"
	
	#$CenterContainer/MainPanel/VBoxContainer/Money_control.hide()
	$CenterContainer/MainPanel/VBoxContainer/UpgradeStats.hide()
	
	_setup_ammo_count_popup()
	_setup_shop_mini_game()
	


func ticket_purchased() -> void:
	if gl_PlayerState.dataset.tickets > 0:
		reroll_unlocked = true
		
	update_shop()
	open_map_menu()


## Opens the island map popup (Moss / Redd select) from the shop.
func open_map_menu() -> void:
	var map_menu := get_tree().get_first_node_in_group('map_menu')
	if map_menu and map_menu.has_method('open_pop_up'):
		map_menu.open_pop_up()
	else:
		push_warning('Shop: map menu missing')


func update_place_label() -> void:
	var place_label := get_node_or_null('CenterContainer/MainPanel/VBoxContainer/TopRedPanel/Place_name/PlaceLabel') as RichTextLabel
	if place_label:
		var current_place := String(gl_PlayerState.dataset.level_name).to_upper()
		if current_place == 'START' or current_place.is_empty():
			current_place = 'MOSS'
		place_label.text = current_place


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
	var floating_label := cash_label.duplicate() as RichTextLabel

	# Detach from layout so it can float freely over everything
	floating_label.top_level = true
	floating_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floating_label.z_index = 100

	add_child(floating_label)

	floating_label.global_position = cash_label.global_position
	floating_label.size = cash_label.size
	floating_label.text = "[color=#ff4444]-$" + str(amount) + "[/color]"
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


func update_open_menu() -> void:
	if gl_PlayerState.dataset.round == 1:
		_music_control_call("ensure_shop_music_playing")
	
	reset_cash_label_color()
	sfx_open_shop()
	update_shop()
	update_place_label()
	%Play_round_text.text = "[i][wave][color=]PLAY\n[color=c70102]$" + str(int(gl_DataSet.get_value('price_play_round', 0)))

	
	update_shop_labels()

	# PERFECT RESET
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

	_music_control_call("raise_shop_menu_music")

	await tween.finished
	
	await get_tree().create_timer(0.15, false).timeout
	
	await reveal_random_skills(0.05)

	enter_state(SkillState.IN_MENU)
	
func play_round_button_pressed() -> void:
	shake_shop()
	reroll_button.hide()
	%PlayButton.disabled = true
	$CenterContainer/MainPanel/VBoxContainer/TreePanel/AvailableUpgrades.modulate.a = 0.0
	$CenterContainer/MainPanel/VBoxContainer/UpgradeStats.modulate.a = 0.0
	var play_round_cost = int(gl_DataSet.get_value('price_play_round', 0))
	gl_PlayerState.log_buy('debug_add_cash', play_round_cost)
	
	var tween := create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	tween.tween_callback(purchase_made.bind('debug_add_cash'))
	tween.tween_interval(0.4)
	tween.tween_property(%RoundSelector, "modulate:a", 0.0, 0.15)

	tween.tween_interval(0.8)
	await tween.finished
	
	#purchase_made('debug_add_cash')
	
	
	#await get_tree().create_timer(1.0, false).timeout
	update_close_menu()
	await get_tree().create_timer(0.1, false).timeout
	%PlayButton.disabled = false
	%RoundSelector.modulate.a = 1.0


## Hide shop for the debug level editor without firing CLOSE_MENU / SHOP_END.
func soft_hide_for_level_editor() -> void:
	reset_cash_label_color()
	_close_shop_mini_game()
	current_state = SkillState.INACTIVE
	hide()
	_music_control_call("lower_shop_menu_music")


## Re-open shop after leaving the level editor (BACK).
func soft_show_from_level_editor() -> void:
	enter_state(SkillState.OPEN_MENU)
	
func update_close_menu() -> void:
	reset_cash_label_color()
	sfx_close_shop()
	_force_hide_ammo_count_popup()
	_close_shop_mini_game()
	
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
	cash_label.hide()
	cash_label.text = ''
	reset_cash_label_color()
	EventBus.instance.close_shop.emit()

	#reroll_button.show()
	$CenterContainer/MainPanel/VBoxContainer/TreePanel/AvailableUpgrades.modulate.a = 1.0
	
	$CenterContainer/MainPanel/VBoxContainer/UpgradeStats.modulate.a = 1.0
	%PlayButton.modulate.a = 1.0
	
	if round_manager:
		round_manager.enter_state(round_manager.RoundState.SHOP_END)
				
	for i in all_skills:
		i.new_round = true
		
		
		
func roll_up_cash_first_round() -> void:
	if gl_PlayerState.dataset.power_gun < 1:
		return

	var target_cash: int = gl_PlayerState.dataset.cash

	# Show "0" immediately, invisible, then fade in
	cash_label.text = "[wave amp=2.0 freq=20.0 connected=1]$0"
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
			cash_label.text = "[wave amp=2.0 freq=20.0 connected=1]$" + str(int(value)),
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

func reveal_random_skills(_dur : float = 0.05, wait_reroll : bool = false) -> void:

	clear_available_skills()
	return
	var _orig_pitch_scale : float = reveal_skill_sfx.pitch_scale

	var selected_skills := []

	# FIRST SHOP OPEN
	if gl_PlayerState.dataset.round == 0:
		for skill in all_skills:
			if skill.name == "AddGun": # replace with your actual gun node name
				selected_skills.append(skill)
				break
	
	# NORMAL BEHAVIOUR
	else:
		var max_items_in_shop : int = gl_PlayerState.dataset.power_max_items_in_shop
		
		var guaranteed_skills := []
		var random_pool := []

		for skill in all_skills:

			if skill.remove_from_shop:
				continue

			if is_skill_maxed(skill):
				continue

			if skill.guaranteed_until_purchased:
				guaranteed_skills.append(skill)
			else:
				random_pool.append(skill)

		random_pool.shuffle()

		selected_skills = guaranteed_skills.duplicate()

		while selected_skills.size() < max_items_in_shop and random_pool.size() > 0:
			selected_skills.append(random_pool.pop_front())

		selected_skills = selected_skills.slice(0, 3)
	
	# Reparent selected skills
	for skill in selected_skills:

		if skill.get_parent():
			skill.get_parent().remove_child(skill)

		available_upgrades.add_child(skill)

		skill.reset_buttons_settings()
		skill.show()
		skill.modulate.a = 0.01
		skill.scale = Vector2.ONE * 0.8
		
	
	if wait_reroll:
		await get_tree().create_timer(0.5, false).timeout
	
	# Reveal animation
	for skill in selected_skills:

		var tween := create_tween()
		tween.set_trans(Tween.TRANS_CUBIC)
		tween.set_ease(Tween.EASE_OUT)

		reveal_skill_sfx.play()

		tween.parallel().tween_property(skill, "modulate:a", 1.0, _dur)
		tween.parallel().tween_property(skill, "scale", Vector2.ONE * 1.15, _dur)
		tween.tween_property(skill, "scale", Vector2.ONE, _dur)
		
		await tween.finished

		skill._update_visual_state()
		skill.purchase_particles()
		#reveal_skill_sfx.pitch_scale += 1.0

	reveal_skill_sfx.pitch_scale = _orig_pitch_scale

func update_in_menu() -> void:
	roll_up_cash_first_round()
	

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
	
	%TicketPurchasedPopUp.open_pop_up()

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
	await reveal_random_skills(0.05, true)
	

	
	is_rerolling = false

func purchase_denied_tween() -> void:
	$SFX/purchase.play()
	var denied_tween := create_tween()
		
	denied_tween.set_trans(Tween.TRANS_SINE)
	denied_tween.set_ease(Tween.EASE_OUT)
	
	var original_position := position
	
	denied_tween.tween_property(self, "position:x", original_position.x - 12, 0.05)
	denied_tween.tween_property(self, "position:x", original_position.x + 12, 0.05)
	denied_tween.tween_property(self, "position:x", original_position.x, 0.05)
		

func clear_available_skills() -> void:
	
	for skill in available_upgrades.get_children():
		
		# Reset visuals
		skill.reset_buttons_settings()
		skill.hide()
		skill.modulate.a = 1.0
		skill.scale = Vector2.ONE
		
		# Move back to storage container
		available_upgrades.remove_child(skill)
		all_skills_container.add_child(skill)


func update_shop_labels() -> void:
	
	cash_label.text = "[wave amp=2.0 freq=20.0 connected=1]$" + str(player_cash)
	update_cash_label_color()
	update_cost_label()
	
	if price_reroll == 0:
		reroll_button.get_child(0).text = "REROLL\n[wave][color=#c70102]FREE[/color]"

	else:
		reroll_button.get_child(0).text = "[wave]REROLL\n[color=#c70102]$" + str(price_reroll) + "[/color]"

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
	cash_label.text = "$" + str(player_cash)
	update_cash_label_color()
	await get_tree().process_frame

	cash_label.pivot_offset.x = cash_label.size.x * 0.5
	
func _setup_shop_mini_game() -> void:
	var main_panel := get_node_or_null("CenterContainer/MainPanel") as Control
	if main_panel == null:
		push_warning("Shop: MainPanel missing — mini-game overlay skipped")
		return
	_shop_mini_game = SHOP_MINI_GAME_SCENE.instantiate()
	add_child(_shop_mini_game)
	if _shop_mini_game.has_method("attach_to_shop"):
		_shop_mini_game.attach_to_shop(self, main_panel, 120.0)


func _close_shop_mini_game() -> void:
	if _shop_mini_game and _shop_mini_game.has_method("close") and _shop_mini_game.is_open:
		_shop_mini_game.close()


func _unhandled_input(event: InputEvent) -> void:
	#
	#if event is InputEventKey and event.pressed and not event.echo:
	if Input.is_action_just_pressed('select_button'):
		if current_state == SkillState.IN_MENU or current_state == SkillState.OPEN_MENU:
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
	
func mark_round_as_perfect() -> void:
	var round_button_cont : HBoxContainer = 	$CenterContainer/MainPanel/VBoxContainer/RoundSelector/Panel/VBoxContainer/HBoxContainer

	%ScoreTotal.add_to_total()
	
	for i in round_button_cont.get_children():
		
		if i.current_state == i.State.AVAILABLE: # || i.current_state == i.State.CLEARED:
			i.enter_state(i.State.PERFECTED)
			

func increase_round_available() -> void:
	var round_button_cont : HBoxContainer = 	$CenterContainer/MainPanel/VBoxContainer/RoundSelector/Panel/VBoxContainer/HBoxContainer	
	for i in round_button_cont.get_children():
		if i.current_state != i.State.LOCKED:
			continue
		else:
			i.enter_state(i.State.AVAILABLE)
			break
	
func restart() -> void:
	_close_shop_mini_game()
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
	popup.text = "[wave]Ammo is full"
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
