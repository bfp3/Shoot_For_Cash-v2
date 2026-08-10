extends Button

@export var upgrade_icon : CompressedTexture2D
@onready var purchase_hold_progress_bar: ProgressBar = %PurchaseHoldProgressBar

var new_round := true
var remove_from_shop := false

enum State {
	UNAVAILABLE,
	AVAILABLE,
	PURCHASED,
	CAPPED
}

var current_state: State = State.AVAILABLE

@export_group('Hold Button Down Settings')
@export var hold_duration := 0.5
var is_holding := false
var hold_progress := 0.0

@export_group('Upgrade Costs')
@export var upgrade_type := ""
@export var upgrade_name := "Upgrade"
var tooltip_description := ""

var player_money := 0
var cost := 0
var power_level := 0

@onready var name_label: Label = %NameLabel
@onready var cost_label: RichTextLabel = %CostLabel
@onready var description_label: Label = %DescriptionLabel

@export var focus_enter_sfx: AudioStreamPlayer
@export var focus_exit_sfx: AudioStreamPlayer
@export var purchase_sfx: AudioStreamPlayer

var wiggle_tween: Tween

@onready var upgrade_icon_textureRect: TextureRect = %Upgrade_Icon

var array_particles : Array = []

func _ready() -> void:
	EventBus.instance.open_shop.connect(reset_buttons_settings)
		
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP

	#pressed.connect(_on_pressed)
	
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	
	mouse_entered.connect(_on_focus_entered)
	mouse_exited.connect(_on_focus_exited)

	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	enter_state(State.AVAILABLE)
	_refresh_text()
	_update_visual_state()
	
			


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
	if current_state != State.AVAILABLE:
		set_process(false)
		return
	
	if player_money < cost:
		enter_state(State.UNAVAILABLE)
		return

	if is_holding:
		hold_progress += delta / hold_duration
		hold_progress = clamp(hold_progress, 0.0, 1.0)
		
		purchase_hold_progress_bar.value = hold_progress * 100.0
		
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
		
	$FreeParticles.emitting = false
	
	enter_state(State.AVAILABLE)
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
	is_holding = true
	
	


func _on_button_up() -> void:
	is_holding = false
	
	

func complete_purchase() -> void:
	if current_state != State.PURCHASED:
		return
	
	var menus := get_tree().get_first_node_in_group("deferred_menu_loader")
	var map_menu: Node = null
	if menus and menus.has_method("ensure_ticket_map"):
		map_menu = menus.ensure_ticket_map()
	else:
		map_menu = get_tree().get_first_node_in_group("map_menu")
	if map_menu and map_menu.has_method("ticket_used"):
		map_menu.ticket_used()
	
	var unpurchased_cont: VBoxContainer = $VBoxContainer
	#purchase_sfx.play()
	#disabled = true
	await get_tree().create_timer(0.1).timeout
	$Purchased.show()
	
	var _orig_scale : Vector2 = unpurchased_cont.scale
	var tween = create_tween()
	tween.tween_property(unpurchased_cont, "scale", scale * 1.3, 0.1)
	tween.parallel().tween_property(unpurchased_cont, "modulate", Color('42d100'), 0.1)
	tween.tween_property(unpurchased_cont, "scale", _orig_scale, 0.1)
	tween.parallel().tween_property(unpurchased_cont, "modulate", Color("80808050"), 0.1)
	await tween.finished



func _on_focus_entered() -> void:
	#fade_tween(upgrade_icon_textureRect, false)
	if current_state != State.AVAILABLE:
		return
	

	if focus_enter_sfx:
		focus_enter_sfx.play()
		
	z_index = 1
	_play_wiggle(1.5)

func _on_focus_exited() -> void:

	#fade_tween(upgrade_icon_textureRect, true)
	
	if current_state != State.AVAILABLE:
		return
	
	#_update_visual_state()

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

	name_label.text = upgrade_name
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
			self.modulate = Color('FFFFFF99')

		State.AVAILABLE:
			base = Color(0.078, 0.09, 0.11, 1.0)
			border = Color(0.251, 0.275, 0.314, 1.0)
			self.modulate = Color('FFFFFF')
			
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

	add_theme_stylebox_override("normal", hover_style if hover_boost else normal_style)
	add_theme_stylebox_override("hover", hover_style)
	add_theme_stylebox_override("pressed", pressed_style)
	add_theme_stylebox_override("focus", focus_style)
	add_theme_stylebox_override("disabled", disabled_style)

	var text_color := Color(1, 1, 1, 0.95)

	if current_state == State.UNAVAILABLE:
		text_color = Color(0.75, 0.75, 0.75, 0.80)

	elif current_state == State.AVAILABLE:
		text_color = Color(1.0, 0.85, 0.85, 0.90)

	add_theme_color_override("font_color", text_color)

	name_label.modulate = text_color
	#cost_label.modulate = text_color
	description_label.modulate = text_color
	
	
func purchase_particles() -> void:
	await get_tree().create_timer(0.1).timeout
	$PurchaseParticles.emitting = true

	


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
