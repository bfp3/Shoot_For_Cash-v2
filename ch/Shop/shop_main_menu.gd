extends Control

@export var round_manager : RoundManager
@export var money_control : Node
@export var reveal_skill_sfx: AudioStreamPlayer
@onready var cash_label: RichTextLabel = %MoneyLabel
@onready var available_upgrades: HBoxContainer = $CenterContainer/MainPanel/VBoxContainer/TreePanel/AvailableUpgrades
@onready var reroll_button: Button = %Reroll
@onready var all_skills_container: Control = %TreeCanvas
@onready var bg_music: AudioStreamPlayer = $SFX/BG_Music

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


func _ready() -> void:
	
	EventBus.instance.update_money.connect(update_shop_labels)


	
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
	cash_label.hide()
	#update_shop_labels()
	cash_label.text = "$0"
	
	#$CenterContainer/MainPanel/VBoxContainer/Money_control.hide()
	$CenterContainer/MainPanel/VBoxContainer/UpgradeStats.hide()
	
		
	


func ticket_purchased() -> void:
	if gl_PlayerState.dataset.tickets > 0:
		reroll_unlocked = true
		
	update_shop()
	$TicketPurchasedPopUp.display_ticket()

	


func purchase_made(_upgrade_type:String = '') -> void:
	
	update_cash_label_color()
	var current_color = cash_label.modulate
	var old_cash := player_cash
	
	var reroll_colour_tween := create_tween().set_trans(Tween.TRANS_SINE)
	reroll_colour_tween.tween_property(cash_label, "modulate", Color('FF0000'), 0.1)
	reroll_colour_tween.tween_callback(update_shop)
	reroll_colour_tween.tween_property(cash_label, "modulate", current_color, 0.2)
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
	
	update_shop_labels()
	
func update_open_menu() -> void:
	if gl_PlayerState.dataset.round == 1:
		bg_music.play()
	
	sfx_open_shop()
	update_shop()
	%Play_round_text.text = "[i][wave][color=]PLAY\n[color=c70102]$" + str(int(gl_DataSet.get_value('price_play_round', 0)))
	
	#%Reroll.show()
	#%NextRound.show()
	#if reroll_unlocked:
		#%Reroll.show()
		#%NextRound.show()
	#else:
		#%Reroll.hide()
		#%NextRound.hide()

	
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
	
	await get_tree().create_timer(0.15, false).timeout
	
	await reveal_random_skills(0.05)

	enter_state(SkillState.IN_MENU)
	
func play_round_button_pressed() -> void:
	reroll_button.hide()
	%NextRound.disabled = true
	$CenterContainer/MainPanel/VBoxContainer/TreePanel/AvailableUpgrades.modulate.a = 0.0
	$CenterContainer/MainPanel/VBoxContainer/UpgradeStats.modulate.a = 0.0
	var play_round_cost = int(gl_DataSet.get_value('price_play_round', 0))
	gl_PlayerState.log_buy('debug_add_cash', play_round_cost)
	var tween := create_tween().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)

	tween.tween_property(%NextRound, "modulate:a", 0.0, 0.15)
	await tween.finished
	purchase_made('debug_add_cash')
	
	
	await get_tree().create_timer(1.0, false).timeout
	%NextRound.disabled = false
	update_close_menu()
	
func update_close_menu() -> void:
	sfx_close_shop()
	
	$CenterContainer/MainPanel/VBoxContainer/Money_control.show()
	#$CenterContainer/MainPanel/VBoxContainer/UpgradeStats.show()
	%QuitMenu.hide()
	
	clear_available_skills()

	shop_music_lower_volume()
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
	EventBus.instance.close_shop.emit()

	reroll_button.show()
	$CenterContainer/MainPanel/VBoxContainer/TreePanel/AvailableUpgrades.modulate.a = 1.0
	
	$CenterContainer/MainPanel/VBoxContainer/UpgradeStats.modulate.a = 1.0
	%NextRound.modulate.a = 1.0
	
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


	
func shop_music_raise_volume() -> void:
	var tween := create_tween()
	tween.tween_property(bg_music, "volume_db", -80.0, 0.25)
	
	#tween.tween_property(bg_music, "volume_db", -20.0, 0.25)
	#tween.tween_property(bg_music, "volume_db", 4.0, 1.0)
	
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
	update_cash_label_color()
	await get_tree().process_frame

	cash_label.pivot_offset.x = cash_label.size.x * 0.5
	
func _input(event: InputEvent) -> void:
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
	if gl_PlayerState.dataset.cash < 0:
		cash_label.modulate = Color("c70102ff")
	else:
		cash_label.modulate = Color("ebe0d8ff")
