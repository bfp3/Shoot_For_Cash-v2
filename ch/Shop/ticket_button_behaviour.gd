extends Button

@export var tooltip_description := ''
@onready var tooltip: Tooltip = $Tooltip

var current_base_color := Color("19191dff")
var current_border_color := Color("404047ff")
var style_tween : Tween

@export var focus_enter_sfx: AudioStreamPlayer
@export var focus_exit_sfx: AudioStreamPlayer
@export var purchase_sfx: AudioStreamPlayer

var wiggle_tween: Tween
var player_cash := 0
var transitioning := false
enum TicketState {
	UNAVAILABLE,
	ON_SALE,
	PURCHASED,
}
@onready var shop_main_menu: Control = $'../../../../../../..'

@onready var transport_tickets: HBoxContainer = $'../../..'
@export var ticket_id := 0
var location_name : String
var ticket_price : int



signal ticket_purchased()

@onready var price_label: RichTextLabel = $RichTextLabel
@onready var purchase_particles: GPUParticles2D = $PurchaseParticles
@onready var purchase_flash: ColorRect = $PurchaseFlash

var current_state: TicketState = TicketState.UNAVAILABLE

var blink_tween : Tween = null
var purchase_tween : Tween = null

func _ready() -> void:
	self.ticket_purchased.connect(_update_tickets)
	
	EventBus.instance.open_shop.connect(check_tickets)
	
	self.pressed.connect(_on_pressed)
	
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP

	mouse_entered.connect(_on_focus_entered)
	mouse_exited.connect(_on_focus_exited)

	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	
	self.pivot_offset_ratio = Vector2(0.5,0.5)
	await get_tree().process_frame
	if purchase_particles:
		purchase_particles.position = size * 0.5
	await get_tree().create_timer(1.0).timeout
	
	_update_tickets()
	
	_update_visual_state()

func check_tickets() -> void:
	
	if text == 'MOSS':
		#if gl_PlayerState.dataset.stage_name == 'redd':
		if gl_PlayerState.dataset.stage_name == 'moss':
			current_state = TicketState.UNAVAILABLE
			self.disabled = true
			self.mouse_filter = Control.MOUSE_FILTER_IGNORE
			#await get_tree().create_timer(1.0).timeout
			#modulate = Color.DARK_GREEN
			#modulate.a = 0.5
			modulate = Color.TRANSPARENT
			#self.hide()
			
	if text == 'REDD':
		#if gl_PlayerState.dataset.stage_name == 'end game':
		if gl_PlayerState.dataset.stage_name == 'redd':
			self.disabled = true
			self.mouse_filter = Control.MOUSE_FILTER_IGNORE
			current_state = TicketState.UNAVAILABLE
			#modulate = Color.DARK_GREEN
			modulate = Color.TRANSPARENT
			modulate.a = 0.5
	
	
	var tickets_bought : int = gl_PlayerState.dataset.tickets

	# Already purchased
	if ticket_id <= tickets_bought:
		enter_state(TicketState.PURCHASED)

	# Next ticket for sale
	elif ticket_id == tickets_bought + 1:
		enter_state(TicketState.ON_SALE)

	# Locked
	else:
		enter_state(TicketState.UNAVAILABLE)
		
	_update_visual_state()
	
func _update_tickets() -> void:
	player_cash = gl_PlayerState.dataset.cash
	match ticket_id:
		1:
			location_name = gl_DataSet.get_string("place_name",0)
			ticket_price = int(gl_DataSet.get_value('price_ticket_moss', 0))
		
		2:
			location_name = gl_DataSet.get_string("place_name",1)
			ticket_price = int(gl_DataSet.get_value('price_ticket_redd', 0))
			
		3:
			location_name = gl_DataSet.get_string("place_name",2)
			ticket_price = int(gl_DataSet.get_value('price_ticket_glory', 0))
			
		4:
			location_name = gl_DataSet.get_string("place_name",3)
			ticket_price = int(gl_DataSet.get_value('price_ticket_backwater', 0))
			
		5:
			location_name = gl_DataSet.get_string("place_name",4)
			ticket_price = int(gl_DataSet.get_value('price_ticket_sodomi', 0))
			
		_:
			location_name = 'NA'
			ticket_price = 10000
		
	
	price_label.text = "$" + str(ticket_price)
	check_tickets()
	
func enter_state(new_state : TicketState) -> void:

	current_state = new_state

	match current_state:

		TicketState.UNAVAILABLE:
			update_unavailable()

		TicketState.ON_SALE:
			update_on_sale()

		TicketState.PURCHASED:
			update_purchased()
		

	_update_visual_state()
			
			
func update_unavailable() -> void:
	disabled = true
	text = "Locked"
	price_label.hide()
	if blink_tween:
		blink_tween.kill()

	self_modulate = Color('696969')
	modulate = Color.TRANSPARENT
	
func update_on_sale() -> void:
	
	disabled = false

	text = "to " + location_name.to_upper()

	price_label.show()# green #42d100
	price_label.text = "[color=FFFFFF]$" + str(ticket_price)
	self_modulate = Color('999999')
	blinking_mode()


func update_purchased() -> void:
	disabled = false
	
	price_label.hide()
	
	if blink_tween:
		blink_tween.kill()
	
	var new_text = location_name.to_upper()
	
	var tween = create_tween()
	tween.tween_property(self, "text", new_text, 0.15)
	
	
func blinking_mode() -> void:
	if blink_tween:
		blink_tween.stop()
		blink_tween.kill()

	if current_state == TicketState.PURCHASED:
		self_modulate = Color.WHITE
		return
	
	var dur := 1.0
	player_cash = gl_PlayerState.dataset.cash
	if player_cash >= ticket_price:
		dur = 0.2
	
	blink_tween = create_tween()
	blink_tween.tween_property(self, "self_modulate:a", 0.6, dur)
	blink_tween.tween_property(self, "self_modulate:a", 1.0, dur)
	await blink_tween.finished
	
	if current_state == TicketState.ON_SALE && visible:
		blinking_mode()

func _on_pressed() -> void:
	player_cash = gl_PlayerState.dataset.cash
	match current_state:

		TicketState.UNAVAILABLE:
			pass

		TicketState.ON_SALE:
			if player_cash < ticket_price:
				cannot_purchase()
				return
				
			if gl_PlayerState.log_buy('power_ticket_moss', ticket_price):
				gl_PlayerState.dataset.tickets += 1
				purchase_ticket_special_effects()
				
				await get_tree().create_timer(0.5).timeout
				
				shop_main_menu.purchase_made()
				return

		TicketState.PURCHASED:
			#ticket_travel_requested.emit(self)
			
			%TicketPurchasedPopUp.display_ticket()
			
			
func purchase_ticket_special_effects() -> void:
	shop_main_menu.sfx_purchase_made()
	_play_purchase_effect()
	shop_main_menu.ticket_purchased()
	await get_tree().create_timer(0.15).timeout
	enter_state(TicketState.PURCHASED)
	
	await get_tree().create_timer(1.0).timeout
	purchase_sfx.play()
	transport_tickets.update_tickets()
	


func _play_purchase_effect() -> void:
	transitioning = true
	if blink_tween:
		blink_tween.kill()
		blink_tween = null

	if purchase_tween:
		purchase_tween.kill()
		purchase_tween = null

	if purchase_sfx:
		purchase_sfx.play()

	disabled = true

	var orig_scale := scale
	var orig_rotation := rotation
	var golden_flash := Color(1.0, 0.84, 0.1, 1.0)
	var golden_hold := Color(0.88, 0.68, 0.0, 1.0)

	if purchase_particles:
		purchase_particles.emitting = false
		purchase_particles.restart()
		purchase_particles.emitting = true

	_animate_price_label_purchase()

	if purchase_flash:
		purchase_flash.show()
		purchase_flash.self_modulate = Color(1, 0.92, 0.45, 0.75)
		purchase_flash.scale = Vector2(0.02, 1.15)
		purchase_flash.rotation = deg_to_rad(-8.0)

		var flash_tween := create_tween()
		flash_tween.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
		flash_tween.tween_property(purchase_flash, "scale:x", 2.2, 0.28)
		flash_tween.parallel().tween_property(purchase_flash, "self_modulate:a", 0.0, 0.38).set_delay(0.04)
		flash_tween.parallel().tween_property(purchase_flash, "rotation", deg_to_rad(8.0), 0.28)

	var punch := create_tween()
	punch.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	punch.tween_property(self, "scale", orig_scale * 1.42, 0.22)
	punch.parallel().tween_property(self, "self_modulate", golden_flash, 0.14)
	await punch.finished

	var settle := create_tween()
	settle.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	settle.tween_property(self, "scale", orig_scale * 1.1, 0.38)
	await settle.finished


	
	var wiggle := create_tween()
	wiggle.tween_property(self, "rotation", deg_to_rad(5.0), 0.07)
	wiggle.tween_property(self, "rotation", deg_to_rad(-4.0), 0.09)
	wiggle.tween_property(self, "rotation", deg_to_rad(2.0), 0.08)
	wiggle.tween_property(self, "rotation", orig_rotation, 0.1)

	price_label.text = "[shake rate=14.0 level=5 connected=1]" + "Purchased"

	purchase_tween = create_tween()
	purchase_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	purchase_tween.tween_property(self, "self_modulate", golden_hold, 0.45)
	purchase_tween.parallel().tween_property(self, "scale", orig_scale, 0.55)

	if purchase_flash:
		purchase_flash.hide()
		purchase_flash.self_modulate = Color(1, 0.92, 0.45, 0.75)
		purchase_flash.scale = Vector2(0.02, 1.15)
		purchase_flash.rotation = deg_to_rad(-8.0)
	
	await purchase_tween.finished



func _animate_price_label_purchase() -> void:
	if not price_label.visible:
		return

	var orig_pos := price_label.position
	var orig_modulate := price_label.self_modulate
	var orig_scale := price_label.scale

	price_label.text = "[color=#ffc700][i]-$" + str(ticket_price) + "[/i][/color]"

	var price_tween := create_tween().set_parallel(true)
	price_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	price_tween.tween_property(price_label, "position:y", orig_pos.y - 36.0, 0.65)
	price_tween.parallel().tween_property(price_label, "self_modulate:a", 0.0, 0.55)
	price_tween.parallel().tween_property(price_label, "scale", orig_scale * 1.25, 0.3)

	await price_tween.finished

	price_label.position = orig_pos
	price_label.self_modulate = orig_modulate
	price_label.scale = orig_scale


func cannot_purchase() -> void:
	shop_main_menu.purchase_denied_tween()
	var _orig_scale : Vector2 = scale
	var tween = create_tween()
	tween.tween_property(self, "scale", scale * 0.8, 0.1)
	#tween.parallel().tween_property(self, "modulate", Color.RED, 0.05)
	tween.tween_property(self, "scale", _orig_scale, 0.1)
	#tween.parallel().tween_property(self, "modulate", Color.WHITE, 0.15)
	return

func _on_focus_entered() -> void:
	if current_state == TicketState.UNAVAILABLE:
		return
		
	if disabled:
		return
	
	var bbcode_des : String = "[pulse freq=2.0 color=#ffc70099 ease=-2.0]" + tooltip_description + "[/pulse]"
	
	if current_state == TicketState.PURCHASED:
		if tooltip:
			tooltip._toggle_tooltip(true, bbcode_des)
	
	z_index = 1
	# Focus enter sound
	if focus_enter_sfx:
		focus_enter_sfx.play()

	_play_wiggle(1.1)


func _on_focus_exited() -> void:
	if current_state == TicketState.UNAVAILABLE:
		return
	
	if disabled:
		return
	
	if tooltip:
		tooltip._toggle_tooltip(false, tooltip_description)

	
	z_index = 0
	# Focus exit sound
	if focus_exit_sfx:
		focus_exit_sfx.play()

	_play_wiggle(1.0, 0.04)


func _play_wiggle(target_scale: float, _scale_dur : float = 0.08) -> void:
	if wiggle_tween:
		wiggle_tween.kill()

	wiggle_tween = create_tween()

	#wiggle_tween.set_trans(Tween.TRANS_SINE)
	wiggle_tween.set_ease(Tween.EASE_OUT)

	wiggle_tween.tween_property(self, "scale", Vector2(target_scale, target_scale), _scale_dur)


func _update_visual_state() -> void:
	
	if transitioning:
		return
	
	if not is_node_ready():
		return

	var base := Color(0.22, 0.23, 0.26, 0.95)
	var border := Color(0.40, 0.42, 0.47, 1.0)

	match current_state:
		TicketState.UNAVAILABLE:
			$Button.hide()
			base = Color("19191dff")
			border = Color("404047ff")

		TicketState.ON_SALE:
			$Button.show()
			self.modulate = Color.WHITE
			base = Color("19191dff")
			border = Color("404047ff")
			border = Color("858585ff")

		TicketState.PURCHASED:
			return
			#border = Color(0.5, 0.276, 0.08, 1.0)
			#base = Color(0.55, 0.431, 0.0, 1.0)

	var hover_boost := is_hovered() or has_focus()

	var normal_style := _make_style(base, border, 2)
	var hover_style := _make_style(base.lightened(0.10), border.lightened(0.15), 3)
	var pressed_style := _make_style(base.darkened(0.07), border, 3)
	var focus_style := _make_style(base.lightened(0.15), Color(0.95, 0.95, 1.0, 1.0), 3)
	var disabled_style := _make_style(base.darkened(0.20), border.darkened(0.25), 2)

	add_theme_stylebox_override("normal", hover_style if hover_boost else normal_style)
	add_theme_stylebox_override("hover", hover_style)
	add_theme_stylebox_override("pressed", pressed_style)
	add_theme_stylebox_override("focus", focus_style)
	add_theme_stylebox_override("disabled", disabled_style)



func _make_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = bg
	style.border_color = border

	style.set_border_width_all(width)
	style.set_corner_radius_all(10)

	style.content_margin_left = 10
	style.content_margin_top = 8
	style.content_margin_right = 10
	style.content_margin_bottom = 8

	return style
