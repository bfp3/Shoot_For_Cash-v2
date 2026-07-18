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
	
	if gl_PlayerState.dataset.cash >= 2000:
		show_win_text()
	else:
		show_lose_text()
	
	
	
	show()

func show_win_text() -> void:
	var text_box := %TextBOX
	var player_cash: int = int(gl_PlayerState.dataset.cash)
	$CenterContainer/FreeParticles.emitting = true
	text_box.text = (
		"Moss Shooting Range: \n[i][pulse][color=#ffc700]ALL CLEAR[/color][/pulse][/i]\n"
		+ "Cash Target [color=#42d100]$2,000[/color]\n"
		+ "Your Cash [color=#42d100]$%s[/color]" % player_cash
	)
	
func show_lose_text() -> void:
	var text_box := %TextBOX
	var player_cash: int = int(gl_PlayerState.dataset.cash)
	$CenterContainer/FreeParticles.emitting = false
	text_box.text = (
		"Moss Shooting Range:\n"
		+ "Cash Target [color=#42d100]$2,000[/color]\n"
		+ "Your Cash [color=#42d100]$%s[/color]\n"
		+ "[i][pulse][color=#ffc700]Try Again?[/color][/pulse][/i]"
	) % player_cash
	
func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed('left'):
		show_lose_text()
	if Input.is_action_just_pressed('right'):
		show_win_text()
	
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
	gl_PlayerState.reset_level()
	gl_PlayerState.round_finished = false
	
	get_tree().call_group("restartable", "restart")
	update_close_menu()
