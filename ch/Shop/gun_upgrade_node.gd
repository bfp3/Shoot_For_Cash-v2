extends Button

@export var tooltip : Tooltip
@export var upgrade_icon : CompressedTexture2D
@onready var purchase_hold_progress_bar: ProgressBar = %PurchaseHoldProgressBar

@export var guaranteed_until_purchased := false
@export var gun := false
@export var sky_mine := false
@export var balloon_buster := false
var new_round := true
var remove_from_shop := false

enum State {
	UNAVAILABLE,
	AVAILABLE,
	PURCHASED,
	CAPPED
}

var current_state: State = State.UNAVAILABLE

@export var shop_main_menu: Control

@export_group('Hold Button Down Settings')
@export var hold_duration := 0.15
var is_holding := false
var hold_progress := 0.0

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
	button_up.connect(_on_button_up)
	
	mouse_entered.connect(_on_focus_entered)
	mouse_exited.connect(_on_focus_exited)

	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	original_upgrade_name = upgrade_name
	
	_refresh_text()
	_update_visual_state()
	
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
		if sky_mine and gl_PlayerState.dataset.power_sky_mine > 0:
			if cost == 0:
				cost = int(gl_DataSet.get_value('price_sky_mine', gl_PlayerState.dataset.power_sky_mine))
				cost_label.text = "[i][wave]" + str(cost)
			pass
		
		
		else:	
			cost_label.text = "[i][wave]FREE"
		
		if gun:
			cost_label.text = "[i][wave]EQUIP"
		
		
		return
		
	
	var settings = gl_PlayerState.get_all()
	%upgrade_icon_anim.play('idle')
	player_money = settings.cash
	cost = gl_DataSet.get_price(upgrade_type)
	
	#if cost > 0:
		#if upgrade_type == "sky_mine":
			#if new_round:
				#cost += randi_range(1,5)
	
	if shop_main_menu != null:
		if new_round && shop_main_menu.reroll_index > 0: # && visible:
			
			var rand_chance_for_free = randi_range(0, 22)
			if rand_chance_for_free > 22: #22:
				cost = 0
			
	
	new_round = false
	
	if current_state == State.UNAVAILABLE:
		cost_label.text = "[i]$" + str(cost)
		%upgrade_icon_anim.pause()
		
	if cost == 0:
		cost_label.text = "[i][wave]FREE"
		if gun:
			cost_label.text = "[i][wave]EQUIP"

	else:
		cost_label.text = "[i][wave]$" + str(cost)
	
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

	_update_visual_state()
	
func update_available() -> void:
	if array_particles.size() > 0:
		for i in range(min(power_level, array_particles.size())):
			array_particles[i].emitting = true

	set_process(true)
	_update_visual_state()
	
	
func update_purchased() -> void:
	print("purchased the gun")
	var map_menu := get_tree().get_first_node_in_group('map_menu')
	if map_menu:
		print("found the map menu")
		map_menu.open_pop_up()
		
	else:
		print("DID NOT found the map menu")
		
		
	if array_particles.size() > 0:
		for i in array_particles:
			i.emitting = false
	#await get_tree().create_timer(0.1).timeout
	_update_visual_state()
	purchase_particles()
	set_process(false)
	complete_purchase()
	$FreeParticles.emitting = false
	
func update_capped() -> void:
	pass
	
	
func _process(delta: float) -> void:
	if current_state != State.AVAILABLE && cost > 0:
		set_process(false)
		return
	
	if player_money < cost && cost > 0:
		enter_state(State.UNAVAILABLE)
		return

	if is_holding:
		hold_progress += delta / hold_duration
		hold_progress = clamp(hold_progress, 0.0, 1.0)
		
		purchase_hold_progress_bar.value = hold_progress * 100.0
		
		var _button_down := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_button_down.tween_property(self, "scale", Vector2.ONE * 0.9, 0.1)
		
		if hold_progress >= 1.0:
			enter_state(State.PURCHASED)
	
	else:
		# Drain back down
		hold_progress = move_toward(hold_progress, 0.0, delta * 7.5)
		purchase_hold_progress_bar.value = hold_progress * 100.0
		


func reset_buttons_settings() -> void:
	if current_state == State.CAPPED:
		print('CAPPED OUT ITEM')
		$Capped.show()
		return
	
	if sky_mine || balloon_buster:
		_update_power_name()
	
	$FreeParticles.emitting = false
	
	enter_state(State.UNAVAILABLE)
	$VBoxContainer.modulate = Color.WHITE
	$VBoxContainer.scale = Vector2.ONE
	$Purchased.hide()
	purchase_hold_progress_bar.value = 0.0

	is_holding = false
	hold_progress = 0.0
	disabled = false
	z_index = 0
	
	if wiggle_tween:
		wiggle_tween.kill()
	
	scale = Vector2.ONE
	
	update_shop()
	#_update_visual_state()
	
	
	
func configure(config: Dictionary) -> void:
	upgrade_name = config.get("name", "Upgrade")

	#min_cost = config.get("min_cost", 25)
	#max_cost = config.get("max_cost", 250)

	_refresh_text()
	_update_visual_state()


#func set_state(new_state: UpgradeState, is_affordable: bool) -> void:
	#state = new_state
	#can_afford = is_affordable
#
	#disabled = (
		#state == UpgradeState.LOCKED
		#or state == UpgradeState.PURCHASED
		#or not can_afford
	#)
#
	#_update_visual_state()



func _on_button_down() -> void:
	
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

	set_process(true)
	is_holding = true
	


func _on_button_up() -> void:
	is_holding = false
	
	

func complete_purchase() -> void:
	if current_state != State.PURCHASED:
		return
	
	guaranteed_until_purchased = false
	#shop_main_menu.ticket_purchased()



	var _upgrade_name : String = "power_" + upgrade_type
	gl_PlayerState.log_buy(_upgrade_name, cost)
		
	shop_main_menu.purchase_made(upgrade_type)
	
	hold_duration = 0.15
	
	var unpurchased_cont: VBoxContainer = $VBoxContainer
	disabled = true
	await get_tree().create_timer(0.1).timeout
	$Purchased.show()
	
	var _button_down := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_button_down.tween_property(self, "scale", Vector2.ONE, 0.1)
		
	
	var _orig_scale : Vector2 = unpurchased_cont.scale
	var tween = create_tween()
	tween.tween_property(unpurchased_cont, "scale", scale * 1.3, 0.1)
	tween.parallel().tween_property(unpurchased_cont, "modulate", Color('42d100'), 0.1)
	tween.tween_property(unpurchased_cont, "scale", 0.8, 0.1)
	tween.parallel().tween_property(unpurchased_cont, "modulate", Color("80808050"), 0.1)
	await tween.finished
	
	#await get_tree().create_timer(0.2).timeout
	
	#var main_shop = get_tree().get_first_node_in_group('shop_main_menu')
	#if main_shop:
		#main_shop.gun_purchased()
	

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
	remove_from_shop = true
	
	

func _on_focus_entered() -> void:
	#var bbcode_des : String = "[rainbow][shake]" + description + "[/shake][/rainbow]"
	var bbcode_des : String = "" + tooltip_description
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


func _update_visual_state() -> void:
	if not is_node_ready():
		return

	var base := Color(0.22, 0.23, 0.26, 0.95)
	var border := Color(0.40, 0.42, 0.47, 1.0)
	
	match current_state:
		State.UNAVAILABLE:
			base = Color(0.28, 0.28, 0.28, 0.196) #.darkened(0.7)
			border = Color(0.249, 0.249, 0.28, 0.196)
			self.modulate = Color("ffffffff")

		State.AVAILABLE:
			base = Color(0.078, 0.09, 0.11, 1.0)
			border = Color(0.251, 0.275, 0.314, 1.0)
			self.modulate = Color('FFFFFF')
			##if item_free:
			#if cost == 0:
				#base = Color(0.254, 0.337, 0.47, 1.0)
				#border = Color(1.0, 0.8, 0.0, 1.0)

				
		State.PURCHASED:
			#base = Color(0.15, 0.35, 0.22, 0.98)
			#border = Color(0.40, 0.88, 0.52, 1.0)
			base = Color(0.078, 0.09, 0.11, 1.0)
			border = Color(0.251, 0.275, 0.314, 1.0)
			self.modulate = Color('FFFFFF')

	var hover_boost := is_hovered() or has_focus()

	var normal_style := _make_style(base, border, 2)
	var hover_style := _make_style(base.lightened(0.10), border.lightened(0.15), 3)
	var pressed_style := _make_style(base.darkened(0.07), border, 3)
	var focus_style := _make_style(base.lightened(0.15), Color(0.95, 0.95, 1.0, 1.0), 3)
	var disabled_style := _make_style(base.darkened(0.20), border.darkened(0.25), 2)

	#add_theme_stylebox_override("normal", hover_style if hover_boost else normal_style)
	#add_theme_stylebox_override("hover", hover_style)
	#add_theme_stylebox_override("pressed", pressed_style)
	#add_theme_stylebox_override("focus", focus_style)
	#add_theme_stylebox_override("disabled", disabled_style)

	var text_color := Color(1, 1, 1, 0.95)

	if current_state == State.UNAVAILABLE:
		text_color = Color(0.75, 0.75, 0.75, 0.80)

	elif current_state == State.AVAILABLE:
		text_color = Color(1.0, 0.85, 0.85, 0.90)

	add_theme_color_override("font_color", text_color)

	name_label.modulate = text_color
	#cost_label.modulate = text_color
	
	
func purchase_particles() -> void:
	
	
	await get_tree().create_timer(0.1).timeout
	$PurchaseParticles.emitting = true
	if cost == 0 && !gun:
		await get_tree().create_timer(0.1).timeout
		#$Free_sfx.play()
		$FreeParticles.emitting = true
	
#func _physics_process(delta: float) -> void:
	#_update_visual_state()


func _make_style(bg: Color, border: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()

	style.bg_color = bg
	style.border_color = border

	style.set_border_width_all(width)
	style.set_corner_radius_all(10)

	style.content_margin_left = 10
	style.content_margin_top = 0
	style.content_margin_right = 10
	style.content_margin_bottom = 0

	return style
