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

	# Keep disabled mode buttons out of controller/keyboard focus.
	for path in [
		"CenterContainer/MainPanel/VBoxContainer/GridContainer/Button2",
		"CenterContainer/MainPanel/VBoxContainer/GridContainer/Button4",
	]:
		var locked_btn := get_node_or_null(path) as Control
		if locked_btn:
			locked_btn.focus_mode = Control.FOCUS_NONE

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
	#skill.scale = Vector2.ONE * 0.8
		

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
	var solo := get_node_or_null("CenterContainer/MainPanel/VBoxContainer/GridContainer/Button") as Control
	var free_play := get_node_or_null("CenterContainer/MainPanel/VBoxContainer/GridContainer/Button3") as Control
	# Multiplayer / Battle stay disabled — skip them in the focus chain.
	if solo and free_play:
		solo.focus_neighbor_right = free_play.get_path()
		solo.focus_neighbor_bottom = free_play.get_path()
		free_play.focus_neighbor_left = solo.get_path()
		free_play.focus_neighbor_top = solo.get_path()
		free_play.focus_neighbor_right = solo.get_path()
		free_play.focus_neighbor_bottom = solo.get_path()
	UiFocus.grab_in(self, solo)


func open_menu() -> void:
	enter_state(State.OPEN_MENU)
	

func _on_solo_pressed() -> void:
	# Solo opens the island map. Hide start menu first so the map is not covered.
	_ensure_gun_equipped()
	if has_method("sfx_close_shop"):
		sfx_close_shop()
	hide()
	current_state = State.INACTIVE

	var map_menu := _ensure_ticket_map()
	if map_menu == null:
		push_warning("Start menu Solo: MapIslandSelect failed to load")
		return
	if map_menu is CanvasItem:
		(map_menu as CanvasItem).z_index = 40
	if map_menu.has_method("open_pop_up"):
		map_menu.open_pop_up()
	else:
		push_warning("Start menu Solo: MapIslandSelect missing open_pop_up()")


func _on_free_play_pressed() -> void:
	# Soft-close start menu, then jump straight to the testing room.
	if has_method("sfx_close_shop"):
		sfx_close_shop()
	hide()
	current_state = State.INACTIVE

	_ensure_gun_equipped()

	var test_room := gl_DataSet.get_testing_place_name()
	var current := String(gl_PlayerState.dataset.level_name).to_lower()
	if gl_DataSet.is_testing_place(current):
		return

	gl_PlayerState.change_location(test_room)


func _ensure_gun_equipped() -> void:
	if int(gl_PlayerState.dataset.get("power_gun", 0)) < 1:
		gl_PlayerState.dataset.power_gun = 1
	var rm := get_tree().get_first_node_in_group("round_manager")
	if rm and rm.get("player"):
		var p = rm.player
		if p and p.get("player_gun") and p.player_gun.has_method("update_guns"):
			p.player_gun.update_guns()


func gun_purchased() -> void:
	sfx_purchase_made()
	if has_method("sfx_close_shop"):
		sfx_close_shop()
	hide()
	current_state = State.INACTIVE
	var map_menu := _ensure_ticket_map()
	if map_menu and map_menu is CanvasItem:
		(map_menu as CanvasItem).z_index = 40
	if map_menu and map_menu.has_method("open_pop_up"):
		map_menu.open_pop_up()

func _ensure_ticket_map() -> Node:
	var menus := get_tree().get_first_node_in_group("deferred_menu_loader")
	if menus and menus.has_method("ensure_ticket_map"):
		return menus.ensure_ticket_map()
	return get_tree().get_first_node_in_group("map_menu")

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
	var map_menu := _ensure_ticket_map()
	if map_menu and map_menu.has_method("display_ticket"):
		map_menu.display_ticket()
