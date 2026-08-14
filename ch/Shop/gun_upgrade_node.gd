extends Button

@export var tooltip : Tooltip
@export var upgrade_icon : CompressedTexture2D
@onready var purchase_hold_progress_bar: ProgressBar = %PurchaseHoldProgressBar

@export var guaranteed_until_purchased := false

var new_round := true

enum State {
	UNAVAILABLE,
	AVAILABLE,
	PURCHASED,
	CAPPED
}

var current_state: State = State.UNAVAILABLE

@export var shop_main_menu: Control

@export_group('Hold Button Down Settings')
var hold_duration := 0.15
var purchase_tween: Tween

@export_group('Upgrade Costs')
@export var upgrade_type := ""
@export var upgrade_name := "Upgrade"
var original_upgrade_name := ""
var tooltip_description := ""

var player_money := 0
var cost := 1
var power_level := 0

@onready var name_label: RichTextLabel = %NameLabel
@onready var cost_label: RichTextLabel = %CostLabel


@export var focus_enter_sfx: AudioStreamPlayer
@export var focus_exit_sfx: AudioStreamPlayer
@export var purchase_sfx: AudioStreamPlayer

var wiggle_tween: Tween

@onready var anim_play: AnimationPlayer = %upgrade_icon_anim
@onready var upgrade_icon_textureRect: TextureRect = %Upgrade_Icon
@onready var upgrade_icon_shadow: TextureRect = %Upgrade_Icon_shadow

@onready var particles_1: GPUParticles2D = $VBoxContainer/UpgradePanel/GPUParticles2D2
@onready var particles_2: GPUParticles2D = $VBoxContainer/UpgradePanel/GPUParticles2D
@onready var particles_3: GPUParticles2D = $VBoxContainer/UpgradePanel/GPUParticles2D3

var array_particles : Array = []

func _ready() -> void:
	#randomize()
	original_upgrade_name = upgrade_name
	array_particles = [particles_1, particles_2, particles_3]
	EventBus.instance.open_shop.connect(reset_buttons_settings)
	
	if upgrade_icon:
		upgrade_icon_textureRect.texture = upgrade_icon
		upgrade_icon_shadow.texture = upgrade_icon
		%Upgrade_Icon_shadow2.texture = upgrade_icon
		
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	shop_main_menu = get_tree().get_first_node_in_group('shop_main_menu')

	#pressed.connect(_on_pressed)
	
	button_down.connect(_on_button_down)
	
	mouse_entered.connect(_on_focus_entered)
	mouse_exited.connect(_on_focus_exited)

	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	original_upgrade_name = upgrade_name
	
	_refresh_text()

	
	await get_tree().process_frame
	update_shop()
			
		
func update_shop(_power_name : String = "") -> void:
	update_cost()
		
	if current_state == State.PURCHASED:
		return
	
	
	if cost > player_money:
		enter_state(State.UNAVAILABLE)
	else:
		enter_state(State.AVAILABLE)




func update_cost() -> void:
	
	if cost == 0:
		cost_label.text = "[wave]EQUIP"
		
		return
		
	
	var settings = gl_PlayerState.get_all()
	%upgrade_icon_anim.play('idle')
	player_money = settings.cash
	cost = gl_DataSet.get_price(upgrade_type)

	
	if shop_main_menu != null:
		if new_round && shop_main_menu.reroll_index > 0: # && visible:
			
			var rand_chance_for_free = randi_range(0, 22)
			if rand_chance_for_free > 22: #22:
				cost = 0
			
	
	new_round = false
	
	if current_state == State.UNAVAILABLE:
		cost_label.text = "$" + str(cost)
		%upgrade_icon_anim.pause()
		
	if cost == 0:
		cost_label.text = "[wave]EQUIP"

	else:
		cost_label.text = "[wave]$" + str(cost)
	
	power_level = gl_PlayerState.get_power_level("power_" + upgrade_type)
	tooltip_description = gl_DataSet.get_string("tooltip_" + upgrade_type, 0)
	
	
	
	update_particles_array()
	
func update_particles_array() -> void:
	if upgrade_type != '':
		

		# First disable everything
		for p in array_particles:
			p.emitting = false

		# Enable particles up to current power level
		for i in range(min(power_level, array_particles.size())):
			array_particles[i].emitting = true

func enter_state(new_state : State) -> void:

	current_state = new_state
	match new_state:
		State.UNAVAILABLE:
			update_unavailable()

		State.AVAILABLE:
			update_available()

		State.PURCHASED:
			update_purchased()
			
		State.CAPPED:
			update_capped()
			
func update_unavailable() -> void:
	if array_particles.size() > 0:
		for i in array_particles:
			i.emitting = false

	
func update_available() -> void:
	if array_particles.size() > 0:
		for i in range(min(power_level, array_particles.size())):
			array_particles[i].emitting = true

	
	
func update_purchased() -> void:
		
	if array_particles.size() > 0:
		for i in array_particles:
			i.emitting = false

	purchase_particles()
	complete_purchase()
	$FreeParticles.emitting = false
	
	var map_menu := _ensure_ticket_map()
	if map_menu and map_menu.has_method("open_pop_up"):
		await get_tree().create_timer(0.85).timeout
		map_menu.open_pop_up()
	else:
		print("DID NOT found the map menu")


func _ensure_ticket_map() -> Node:
	var menus := get_tree().get_first_node_in_group("deferred_menu_loader")
	if menus and menus.has_method("ensure_ticket_map"):
		return menus.ensure_ticket_map()
	return get_tree().get_first_node_in_group("map_menu")
		
		
func update_capped() -> void:
	pass
	
	
func reset_buttons_settings() -> void:
	if current_state == State.CAPPED:
		print('CAPPED OUT ITEM')
		$Capped.show()
		return
	
	$FreeParticles.emitting = false
	
	enter_state(State.UNAVAILABLE)
	$VBoxContainer.modulate = Color.WHITE
	$VBoxContainer.scale = Vector2.ONE
	%Purchased.hide()
	purchase_hold_progress_bar.value = 0.0

	if purchase_tween:
		purchase_tween.kill()
	disabled = false
	z_index = 0
	
	if wiggle_tween:
		wiggle_tween.kill()
	
	scale = Vector2.ONE
	
	update_shop()

	
func _on_button_down() -> void:
	# Gun already owned: reopen the map instead of silently no-oping.
	if current_state == State.PURCHASED and upgrade_type == "gun":
		var map_menu := _ensure_ticket_map()
		if map_menu and map_menu.has_method("open_pop_up"):
			map_menu.open_pop_up()
		return

	if current_state != State.AVAILABLE && cost > 0:
		shop_main_menu.purchase_denied_tween()
		
		var _orig_modulate : Color = self.modulate
		var _orig_scale : Vector2 = scale
		var tween = create_tween()
		#tween.tween_property(self, "scale", scale * 0.8, 0.1)
		tween.tween_property(self, "modulate", Color('FFFFFF30'), 0.1)
		#tween.tween_property(self, "scale", _orig_scale, 0.1)
		tween.tween_property(self, "modulate", _orig_modulate, 0.1)
		return

	if purchase_tween:
		purchase_tween.kill()

	purchase_hold_progress_bar.value = 0.0

	purchase_tween = create_tween()
	purchase_tween.tween_property(purchase_hold_progress_bar, "value", 100.0, hold_duration)
	purchase_tween.parallel().tween_property(self, "scale", Vector2.ONE * 0.9, 0.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	purchase_tween.tween_callback(_on_purchase_hold_complete)


func _on_purchase_hold_complete() -> void:
	if current_state != State.AVAILABLE:
		return
	enter_state(State.PURCHASED)
	


func complete_purchase() -> void:
	if current_state != State.PURCHASED:
		return
	
	guaranteed_until_purchased = false
	#shop_main_menu.ticket_purchased()



	var _upgrade_name : String = "power_" + upgrade_type
	gl_PlayerState.log_buy(_upgrade_name, cost)
		
	shop_main_menu.purchase_made(upgrade_type)
	
	hold_duration = 0.15

	disabled = true
	await get_tree().create_timer(0.1).timeout
	%Purchased.modulate.a = 0.0
	%Purchased.show()
	
	var _button_down := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_button_down.tween_property(self, "scale", Vector2.ONE, 0.1)
		
	var tween = create_tween()
	tween.tween_property(%Purchased, "modulate:a", 100.0, 0.15)
	

	

func _update_power_name() -> void:
	upgrade_name = original_upgrade_name
	match power_level:
		0:
			upgrade_name = original_upgrade_name
		1:
			upgrade_name = upgrade_name + "+"
		2:
			upgrade_name = upgrade_name + "++"
			
		3:
			upgrade_name = upgrade_name + "+++"
			
		4:
			upgrade_name = upgrade_name + "++++"
		_:
			upgrade_name = upgrade_name + "+++++"
	_refresh_text()

func remove_gun() -> void:
	var _upgrade_name : String = "power_" + upgrade_type
	gl_PlayerState.log_buy(_upgrade_name, cost)

	
	

func _on_focus_entered() -> void:
	#var bbcode_des : String = "[rainbow][shake]" + description + "[/shake][/rainbow]"
	#var _bbcode_des : String = "" + tooltip_description
	#var bbcode_des : String = "[shake rate=5.0 level=5 connected=1]" + description + "[/shake]"
	#if tooltip:
		#tooltip._toggle_tooltip(true, bbcode_des)
#
	#fade_tween(upgrade_icon_textureRect, false)
	
	if current_state != State.AVAILABLE:
		return
	
	
	#_update_visual_state()
	anim_play.play('idle')

	if focus_enter_sfx:
		focus_enter_sfx.play()
		
	z_index = 1
	_play_wiggle(1.1)

func _on_focus_exited() -> void:
	if tooltip:
		tooltip._toggle_tooltip(false, tooltip_description)
	
	fade_tween(upgrade_icon_textureRect, true)
	
	if current_state != State.AVAILABLE:
		return
	
	#_update_visual_state()
	anim_play.play('idle')
	# Focus exit sound
	if focus_exit_sfx:
		focus_exit_sfx.play()
	z_index = 0
	_play_wiggle(1.0, 0.02)

func fade_tween(_node : Node, fade : bool = false) -> void:
	var target_modulate : float = 0.3
	if fade:
		target_modulate = 1.0
		
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(_node, "modulate:a", target_modulate, 0.25)

func _play_wiggle(target_scale: float, _scale_dur : float = 0.08) -> void:
	if wiggle_tween:
		wiggle_tween.kill()
	
	var _scale_node := $VBoxContainer/UpgradePanel/Upgrade_Icon
	wiggle_tween = create_tween()

	#wiggle_tween.set_trans(Tween.TRANS_SINE)
	wiggle_tween.set_ease(Tween.EASE_OUT)

	wiggle_tween.tween_property(_scale_node, "scale", Vector2(target_scale, target_scale), _scale_dur)
	wiggle_tween.tween_property(_scale_node, "rotation_degrees", -2.0, 0.04)
	wiggle_tween.tween_property(_scale_node, "rotation_degrees", 3.0, 0.08)
	wiggle_tween.tween_property(_scale_node, "rotation_degrees", 0.0, 0.04)


func _refresh_text() -> void:
	if not is_node_ready():
		return

	name_label.text = upgrade_name.to_upper()
	cost_label.text = "$%d" % cost

	
func purchase_particles() -> void:
	await get_tree().create_timer(0.1, false).timeout
	$PurchaseParticles.emitting = true
