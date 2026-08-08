extends Control


enum State {
	INACTIVE,
	OPEN_MENU,
	CLOSE_MENU
}
var current_state : State = State.INACTIVE

var default_scale := Vector2.ONE
var default_position := Vector2.ZERO
var default_pivot_offset := Vector2.ZERO



func _ready() -> void:


	# STORE DEFAULT TRANSFORMS
	default_scale = scale
	default_position = position

	# BOTTOM RIGHT PIVOT
	default_pivot_offset = Vector2(0, size.y)
	pivot_offset = default_pivot_offset

	#enter_state(State.OPEN_MENU)



func show_end_screen():
	
	#if gl_PlayerState.dataset.cash >= 2000:
	show_win_text()
	#else:
		#show_lose_text()
	
	
	
	show()

func show_win_text() -> void:
	var text_box := %TextBOX
	var place := gl_DataSet.resolve_place_name(String(gl_PlayerState.dataset.level_name)).to_upper()
	if place.is_empty() or place == "START":
		place = "THE LEVEL"
	$CenterContainer/FreeParticles.emitting = true
	text_box.text = (
		"\n\n[i][pulse][color=#a10204]GREAT![/color][/pulse][/i]\n"
		+ "You've completed [color=#a10204]%s[/color]" % place
	)

	
	
func enter_state(new_state: State) -> void:
	current_state = new_state
	
	match new_state:
		State.INACTIVE:
			update_inactive()
		
		State.OPEN_MENU:
			update_open_menu()
		
		State.CLOSE_MENU:
			update_close_menu()
		_:
			print("No State Exists - Skill Menu Script")


func update_inactive() -> void:
	pass



func update_open_menu() -> void:

	show()
	show_end_screen()
	# OPEN ANIMATION
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_OUT)

	tween.parallel().tween_property(self, "scale", default_scale, 0.4)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.18)

	await tween.finished
	var close_btn := find_child("Retry", true, false) as Control
	UiFocus.grab_in(self, close_btn)
	

func update_close_menu() -> void:
	sfx_close_tally()

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


func play_cash_sfx() -> void:
	$SFX/shop_purchase_01.play()
	$SFX/shop_purchase_02.play()
	$SFX/shop_purchase_03.play()


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


func _on_retry_pressed() -> void:
	var place := gl_DataSet.resolve_place_name(String(gl_PlayerState.dataset.level_name))
	# Completion is already saved in start_game_over; keep stamp / shop flow.
	if not gl_PlayerState.is_place_completed(place):
		gl_PlayerState.mark_place_completed(place)

	await update_close_menu()

	var round_manager := get_tree().get_first_node_in_group("round_manager")
	if round_manager:
		round_manager.game_over_triggered = false
		round_manager.enter_state(round_manager.RoundState.SHOP_START)

	# Let the shop finish opening, then stamp like a perfect-round tally card.
	await get_tree().create_timer(0.55, false).timeout
	var shop := get_tree().get_first_node_in_group("shop_main_menu")
	if shop and shop.has_method("play_level_complete_stamp"):
		await shop.play_level_complete_stamp(place)

	var map_menu := get_tree().get_first_node_in_group("map_menu")
	if map_menu and map_menu.has_method("mark_place_completed"):
		await map_menu.mark_place_completed(place, false)
