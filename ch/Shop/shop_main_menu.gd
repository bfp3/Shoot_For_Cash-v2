extends Control

@export var round_manager : RoundManager
@export var money_control : Node
@export var reveal_skill_sfx: AudioStreamPlayer
@onready var cash_label: RichTextLabel = %MoneyLabel
@onready var available_upgrades: HBoxContainer = $CenterContainer/MainPanel/VBoxContainer/TreePanel/AvailableUpgrades
@onready var reroll_button: Button = %Reroll
@onready var all_skills_container: Control = %TreeCanvas
@onready var bg_music: AudioStreamPlayer = $SFX/BG_Music
@onready var transport_tickets: HBoxContainer = $CenterContainer/MainPanel/VBoxContainer/Transport_Tickets

@export var can_appear_when_maxed := false

var reroll_unlocked := false

var default_scale := Vector2.ONE
var default_position := Vector2.ZERO
var default_pivot_offset := Vector2.ZERO

var price_reroll := 0
var rerolls_this_round := 1
var is_rerolling := false

var all_skills : Array

enum SkillState {
	INACTIVE,
	OPEN_MENU,
	IN_MENU,
	CLOSE_MENU
}

var current_state : SkillState = SkillState.INACTIVE

@export var test_mode := false

var current_round := 0
var player_cash := 0


func _ready() -> void:
	
	EventBus.instance.update_money.connect(update_shop_labels)
	
	transport_tickets.modulate.a = 0.0
	
	bg_music.volume_db = -80.0
	#bg_music.play()

	# STORE DEFAULT TRANSFORMS
	default_scale = scale
	default_position = position
	await get_tree().process_frame

	# BOTTOM RIGHT PIVOT
	#default_pivot_offset = size 
	#pivot_offset = default_pivot_offset
	pivot_offset_ratio = Vector2(0.5,1.0)
	cash_label.modulate.a = 0.0
	$CenterContainer/MainPanel/VBoxContainer/UpgradeStats.modulate.a = 0.0
	hide()

	all_skills = all_skills_container.get_children()

	EventBus.instance.open_shop.connect(enter_state.bind(SkillState.OPEN_MENU))
	#$NextRound.pressed.connect(enter_state.bind(SkillState.CLOSE_MENU))
	
	update_shop_labels()
	cash_label.text = "$0"
	update_cost_label()
	if test_mode:
		EventBus.instance.open_shop.emit()

	if !money_control:
		print("using test money control")
	


func ticket_purchased() -> void:
	if gl_PlayerState.dataset.tickets > 0:
		reroll_unlocked = true
		

	update_shop()
	

func purchase_made(_upgrade_type:String = '') -> void:
	sfx_purchase_made()
	update_shop()
	transport_tickets.check_tickets()
	EventBus.instance.player_update_stats_visually.emit()
	
	for i in all_skills:
		if i.has_method("update_cost"):
			i.update_cost()
	
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
	
	
	price_reroll = gl_DataSet.dataset_float.price_reroll
	if rerolls_this_round == 1:
		price_reroll = gl_DataSet.dataset_float.price_reroll
	else:
		price_reroll = price_reroll * rerolls_this_round
	
	update_shop_labels()
	
func update_open_menu() -> void:
	if gl_PlayerState.dataset.round == 1:
		print('first round play music')
		bg_music.play()
	
	sfx_open_shop()
	update_shop()
	
	
	
	if reroll_unlocked:
		%Reroll.show()
		%NextRound.show()
	else:
		%Reroll.hide()
		%NextRound.hide()

	
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

	shop_music_raise_volume()

	await tween.finished
	
	await get_tree().create_timer(0.15).timeout
	
	await reveal_random_skills(0.05)

	enter_state(SkillState.IN_MENU)
	

func update_close_menu() -> void:
	
	EventBus.instance.close_shop.emit()
	sfx_close_shop()
	

	
	clear_available_skills()

	shop_music_lower_volume()
	rerolls_this_round = 1
	
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

	hide()

	
	if round_manager:
		round_manager.enter_state(round_manager.RoundState.SHOP_END)
				
	for i in all_skills:
		i.new_round = true
	
func roll_up_cash_first_round() -> void:
	
	var duration :float = clamp(player_cash / 1000.0, 0.5, 3.0)
	cash_label.text = "$0"
	update_cost_label()
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(cash_label, "modulate:a", 1.0, 0.2)
	tween.tween_method(
		func(value: float):
			cash_label.text = "[wave amp=2.0 freq=20.0 connected=1][pulse freq=1 color=#42d100 ease=-2.0]$" + str(int(value)),
		0.0,
		float(player_cash),
		duration
	)
	update_cost_label()
	 
func is_skill_maxed(skill) -> bool:
	
	if can_appear_when_maxed:
		return false
	# Always allow Sky Mine to appear
	#if skill.upgrade_type == "sky_mine":
		#return false

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
	
	var _orig_pitch_scale : float = reveal_skill_sfx.pitch_scale

	var selected_skills := []

	# FIRST SHOP OPEN
	if gl_PlayerState.dataset.round == 0:
		roll_up_cash_first_round()
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
		await get_tree().create_timer(0.5).timeout
	
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
	pass
	

func gun_purchased() -> void:
	reroll_unlocked = true
	transport_tickets.modulate.a = 0.0
	transport_tickets.show()
	
	sfx_purchase_made()
	update_shop()

	var tween = create_tween()
	tween.tween_property(transport_tickets, "modulate:a", 1.0, 0.5)
	tween.parallel().tween_property($CenterContainer/MainPanel/VBoxContainer/UpgradeStats, "modulate:a", 1.0, 0.5)
	


func _on_re_roll_pressed() -> void:
		
	if is_rerolling:
		return
		
	var button_down := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	button_down.tween_property(reroll_button, "position:y", 5.0, 0.1).as_relative()
	button_down.tween_property(reroll_button, "position:y", -5.0, 0.1).as_relative()
	# Not enough money

	if player_cash < price_reroll:
		purchase_denied_tween()
		return
	
	is_rerolling = true
	
	for i in all_skills:
		i.new_round = true
	
	sfx_reroll_purchased()
	# Remove money
	var reroll_current_price = gl_DataSet.dataset_float.price_reroll * rerolls_this_round
	if reroll_current_price == 0 && rerolls_this_round > 0:
		reroll_current_price = rerolls_this_round * 2
		price_reroll = reroll_current_price
	gl_PlayerState.log_buy("reroll", reroll_current_price)
	rerolls_this_round += 1
	await get_tree().create_timer(0.1).timeout
	#EventBus.instance.update_money.emit()
	
	var reroll_colour_tween := create_tween().set_trans(Tween.TRANS_SINE)
	reroll_colour_tween.tween_property(cash_label, "modulate", Color('FF0000'), 0.1)
	reroll_colour_tween.tween_callback(update_shop)
	reroll_colour_tween.tween_property(cash_label, "modulate", Color('42d100'), 0.2)
	

	
	# Hide current buttons quickly
	# Hide current displayed skills
	for skill in available_upgrades.get_children():
		
		var hide_tween := create_tween()
		hide_tween.set_trans(Tween.TRANS_SINE)
		hide_tween.set_ease(Tween.EASE_IN)
		
		hide_tween.parallel().tween_property(skill, "modulate:a", 0.0, 0.12)
		hide_tween.parallel().tween_property(skill, "scale", Vector2(0.8, 0.8), 0.12)

	await get_tree().create_timer(0.05).timeout
	
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
	
	cash_label.text = "[wave amp=2.0 freq=20.0 connected=1][pulse freq=1 color=#42d100 ease=-2.0]$" + str(player_cash)
	update_cost_label()
	reroll_button.get_child(0).text = "[rainbow]Reroll[/rainbow]\n[color=#42d100]$" + str(price_reroll) + "[/color]"

func sfx_purchase_made() -> void:
	$SFX/shop_purchase_01.play()
	#$SFX/shop_purchase_02.play()
	await get_tree().create_timer(0.1).timeout
	$SFX/shop_purchase_02.play()
	$SFX/shop_coin_sfx_01.play()

func sfx_reroll_purchased() -> void:
	#$SFX/shop_purchase_01.play()
	##$SFX/shop_purchase_02.play()
	#await get_tree().create_timer(0.1).timeout
	$SFX/shop_purchase_02.play()
	$SFX/shop_coin_sfx_01.play()


	
func shop_music_raise_volume() -> void:
	var tween := create_tween()
	
	tween.tween_property(bg_music, "volume_db", -20.0, 0.25)
	tween.tween_property(bg_music, "volume_db", 4.0, 1.0)
	
	# Original song was played at this level
	#tween.tween_property(bg_music, "volume_db", -60.0, 0.25)
	#tween.tween_property(bg_music, "volume_db", -54.0, 1.0)
	
	
	
	
func shop_music_lower_volume() -> void:
	var tween := create_tween()
	tween.tween_property(bg_music, "volume_db", -80.0, 3.0)

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

	await get_tree().process_frame

	cash_label.pivot_offset.x = cash_label.size.x * 0.5
