extends Control

@export var round_manager : RoundManager

enum State {
	START,
	INACTIVE,
	OPEN_MENU,
	IN_MENU,
	CLOSE_MENU
}

@onready var game_name: Control = $GameName

var current_state : State = State.INACTIVE
var menu_in_display := false

var default_scale := Vector2.ONE
var default_position := Vector2.ZERO
var default_pivot_offset := Vector2.ZERO

#
#func _ready() -> void:
	#EventBus.instance.open_tally_card.connect(enter_state.bind(State.OPEN_MENU))
#
	## STORE DEFAULT TRANSFORMS
	#default_scale = scale
	#default_position = position
#
	## BOTTOM RIGHT PIVOT
	#default_pivot_offset = Vector2(0, size.y)
	#pivot_offset = default_pivot_offset
#
	#hide()
#
	#
#func enter_state(new_state: State) -> void:
	#current_state = new_state
	#
	#match new_state:
		#State.START:
			#update_start()
		#
		#State.INACTIVE:
			#update_inactive()
		#
		#State.OPEN_MENU:
			#update_open_menu()
		#
		#State.IN_MENU:
			#update_in_menu()
		#
		#State.CLOSE_MENU:
			#update_close_menu()
		#_:
			#print("No State Exists - Skill Menu Script")
#
#
#func update_start() -> void:
	#show()
	#copyright.modulate.a = 0.0
	#game_name.modulate.a = 0.0
	#$TempLogo.modulate.a = 0.0
	#$CenterContainer.modulate.a = 0.0
	#brand_name.modulate.a = 0.0
	#black_screen.hide()
	#brand_name.show()
	#
	#
	#var tween = create_tween()
	#tween.tween_property(brand_name, "modulate:a", 1.0, 0.5)
	#tween.tween_interval(1.0)
	#
	#tween.tween_callback($'../../Music'.start_opening_song)
	#tween.tween_interval(1.0)
	#tween.tween_property(black_screen, "modulate:a", 0.0, 1.0)
	#tween.parallel().tween_property(brand_name, "modulate:a", 0.0, 1.0)
	#
	#tween.tween_interval(0.5)
	#tween.tween_property(game_name, "modulate:a", 1.0, 0.15)
	#tween.parallel().tween_property(game_name, "scale", Vector2.ONE * 1.25, 0.15)
	#tween.parallel().tween_callback(opening_sfx)
	#
	#tween.parallel().tween_property($CenterContainer, "modulate:a", 1.0, 0.15)
	#tween.parallel().tween_property($TempLogo, "modulate:a", 1.0, 0.15)
	#
	#tween.tween_property(game_name, "scale", Vector2.ONE * 1.0, 0.15)
	#
	#tween.tween_interval(2.0)
	#tween.tween_property(copyright, "modulate:a", 1.0, 1.5)
	#
		#
#func opening_sfx() -> void:
	#$SFX/hud_click_1.play()
	#$SFX/shop_close_sfx_01.play()
	#$SFX/hud_click_1.play()
	#$SFX/hud_click_2.play()
	#$SFX/hud_click_3.play()
	#$SFX/start_sfx.play()
	#
#func update_inactive() -> void:
	#pass
#
#
	#
#func update_open_menu() -> void:
	#if menu_in_display:
		#return
	#
	#menu_in_display = true
#
	#modulate.a = 0.0
	#scale = Vector2.ONE * 0.01
	#position = default_position
	#pivot_offset = default_pivot_offset
#
	#show()
#
	## OPEN ANIMATION
	#var tween := create_tween()
	#tween.set_trans(Tween.TRANS_LINEAR)
	#tween.set_ease(Tween.EASE_OUT)
#
	#tween.parallel().tween_property(self, "scale", default_scale, 0.4)
	#tween.parallel().tween_property(self, "modulate:a", 1.0, 0.18)
#
	#await tween.finished
	#
	#enter_state(State.IN_MENU)
	#
#
#func update_close_menu() -> void:
	#$'../..'.start_game()
#
	#pivot_offset = default_pivot_offset
#
	#var tween := create_tween()
#
	#tween.set_trans(Tween.TRANS_LINEAR)
	#tween.set_ease(Tween.EASE_IN)
#
	#tween.parallel().tween_property(self, "scale", Vector2.ONE * 0.01, 0.4)
	#tween.parallel().tween_property(self, "modulate:a", 0.0, 0.16)
#
	#await tween.finished
#
	## PERFECT RESET AFTER CLOSE
	#scale = default_scale
	#modulate.a = 1.0
	#position = default_position
	#menu_in_display = false
	#
	#hide()
#
#
#func notify_round_manager() -> void:
	#if !round_manager:
		#var _round_manager : RoundManager = get_tree().get_first_node_in_group('round_manager')
		#if _round_manager:
			#_round_manager.enter_state(_round_manager.RoundState.TALLY_END)
			#
	#else:
		#round_manager.enter_state(round_manager.RoundState.TALLY_END)
#
#
#func update_in_menu() -> void:
	#pass
#
#
	#
#func play_cash_sfx() -> void:
	#$SFX/shop_purchase_01.play()
	#$SFX/shop_purchase_02.play()
	#$SFX/shop_purchase_03.play()
#
#
#func sfx_purchase_made() -> void:
	#$SFX/shop_purchase_01.play()
	##$SFX/shop_purchase_02.play()
	#await get_tree().create_timer(0.1).timeout
	#$SFX/shop_purchase_02.play()
	#$SFX/shop_coin_sfx_01.play()
	#
#
#func _on_next_round_pressed() -> void:
	#enter_state(State.CLOSE_MENU)
	#round_manager.enter_state(round_manager.RoundState.SHOP_END)
#
#
#func _on_start_game_pressed() -> void:
	#var prog_bar : ProgressBar = %Start_button_progressBar
	#
	#var tween = create_tween()
#
	#tween.tween_property(prog_bar, "value", 100.0, 0.3)
	#await get_tree().create_timer(0.29).timeout
	#prog_bar.value = 0.0
	#
	#$'../../Music'._on_start_button_pressed()
	#
	#$SFX/hud_click_1.play()
	#$SFX/shop_close_sfx_01.play()
	#$SFX/hud_click_1.play()
	#$SFX/hud_click_2.play()
	#$SFX/hud_click_3.play()
	#$SFX/start_sfx.play()
	#enter_state(State.CLOSE_MENU)
