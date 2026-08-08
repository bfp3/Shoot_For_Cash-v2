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

var tween_giuseppe : Tween = null
@onready var prompt: RichTextLabel = $CenterContainer/MainPanel/MainPanel/ButtonsHBoxContainer/VBoxContainer/RichTextLabel


func _ready() -> void:


	# STORE DEFAULT TRANSFORMS
	default_scale = scale
	default_position = position

	# BOTTOM RIGHT PIVOT
	default_pivot_offset = Vector2(0, size.y)
	pivot_offset = default_pivot_offset

	#enter_state(State.OPEN_MENU)
	#var price_redd = gl_DataSet.get_value('price_ticket_redd', 0)
	prompt.text = (
		"You[color=#ffc700][wave] WIN[/wave][/color]\n" 
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
	sfx_open_tally()
	show()

	# OPEN ANIMATION
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_OUT)

	tween.parallel().tween_property(self, "scale", default_scale, 0.4)
	tween.parallel().tween_property(self, "modulate:a", 1.0, 0.18)

	await tween.finished
	var retry := find_child("Retry", true, false) as Control
	UiFocus.grab_in(self, retry)
	var balloon = %giuseppeballoon
	tween_giuseppe = create_tween().set_loops()
	tween_giuseppe.set_trans(Tween.TRANS_SINE)

	tween_giuseppe.tween_property(balloon, "rotation", -0.1, 1.0)
	tween_giuseppe.tween_property(balloon, "rotation", 0.1, 1.0)

	await tween_giuseppe.finished
	

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
	
	await get_tree().create_timer(1.0).timeout
	
	if tween_giuseppe:
		tween_giuseppe.stop()
		tween_giuseppe.kill()

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

func start() -> void:
	update_open_menu()

func _on_retry_pressed() -> void:
	var round_manager : RoundManager = get_tree().get_first_node_in_group('round_manager')
	if round_manager:
		round_manager.enter_state(round_manager.RoundState.SHOP_END)
		
	update_close_menu()
