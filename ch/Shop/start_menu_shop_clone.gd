extends Control

@export var round_manager : RoundManager
@export var reveal_skill_sfx: AudioStreamPlayer

var default_scale := Vector2.ONE
var default_position := Vector2.ZERO
var default_pivot_offset := Vector2.ZERO

enum State {
	INACTIVE,
	OPEN_MENU,
	IN_MENU,
	CLOSE_MENU
}
var current_state : State = State.INACTIVE


func _ready() -> void:
	default_scale = scale
	default_position = position
	await get_tree().process_frame

	pivot_offset_ratio = Vector2(0.5,1.0)

	hide()

func purchase_made(_upgrade_type:String = '') -> void:
	sfx_purchase_made()

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

	
func update_open_menu() -> void:
	
	sfx_open_shop()

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

	await tween.finished
	
	await get_tree().create_timer(0.15).timeout
	
	await reveal_gun(0.05)

	enter_state(State.IN_MENU)
	

	
func update_close_menu() -> void:
	sfx_close_shop()
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
		

func reveal_gun(_dur : float = 0.05, wait_reroll : bool = false) -> void:
	var _orig_pitch_scale : float = reveal_skill_sfx.pitch_scale
	var skill := %AddGun

	skill.reset_buttons_settings()
	skill.show()
	skill.modulate.a = 0.01
	skill.scale = Vector2.ONE * 0.8
		

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.set_ease(Tween.EASE_OUT)

	reveal_skill_sfx.play()

	tween.parallel().tween_property(skill, "modulate:a", 1.0, _dur)
	#tween.parallel().tween_property(skill, "scale", Vector2.ONE * 1.15, _dur)
	tween.tween_property(skill, "scale", Vector2.ONE, _dur)
	
	await tween.finished
	
	if skill.has_method('_update_visual_state'):
		skill._update_visual_state()
	if skill.has_method('purchase_particles'):
		skill.purchase_particles()

func update_in_menu() -> void:
	pass

func open_menu() -> void:
	enter_state(State.OPEN_MENU)
	
func gun_purchased() -> void:
	sfx_purchase_made()
	%TicketPurchasedPopUp.open_pop_up()

func purchase_denied_tween() -> void:
	$SFX/purchase.play()
	var denied_tween := create_tween()
		
	denied_tween.set_trans(Tween.TRANS_SINE)
	denied_tween.set_ease(Tween.EASE_OUT)
	
	var original_position := position
	
	denied_tween.tween_property(self, "position:x", original_position.x - 12, 0.05)
	denied_tween.tween_property(self, "position:x", original_position.x + 12, 0.05)
	denied_tween.tween_property(self, "position:x", original_position.x, 0.05)
		


func sfx_purchase_made() -> void:
	$SFX/shop_purchase_01.play()
	await get_tree().create_timer(0.1).timeout
	$SFX/shop_purchase_02.play()
	$SFX/shop_coin_sfx_01.play()

func sfx_reroll_purchased() -> void:
	$SFX/shop_purchase_02.play()
	$SFX/shop_coin_sfx_01.play()


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

	
func restart() -> void:
	current_state = State.INACTIVE

	hide()
	modulate.a = 1.0
	scale = default_scale
	position = default_position
	pivot_offset = default_pivot_offset

	enter_state(State.CLOSE_MENU)
	
	
func ticket_purchased() -> void:
	$TicketPurchasedPopUp.display_ticket()
