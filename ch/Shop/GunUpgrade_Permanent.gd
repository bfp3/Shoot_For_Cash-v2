class_name Upgrade_Display extends Button


@export var upgrade_name_label: RichTextLabel
@export var upgrade_icon_display: TextureRect
@export var progress_bar_container: HBoxContainer 
@export var purchase_progress_bar : ProgressBar


@export var upgrade_type := 'power_target_circle'

@export var is_locked := false
@export var tooltip : Tooltip
@export var description : String

@export var focus_enter_sfx: AudioStreamPlayer
@export var focus_exit_sfx: AudioStreamPlayer

var current_upgrade_level := 0
var max_upgrade_level := 10
var current_bullet_amount := 1

@export var upgrade_icon : CompressedTexture2D
@export var cost_label : Label
@onready var purchase_hold_progress_bar: ProgressBar = %PurchaseHoldProgressBar

var player_upgrading_script : Node

var upgrade_value := 0
var cost := 0

@export var purchase_sfx: AudioStreamPlayer
var wiggle_tween: Tween



func set_power(settings:Dictionary, setting_name:String) -> float:
	return gl_DataSet.get_value(setting_name, settings[setting_name])

func update_power() -> void:

	if upgrade_type == "":
		return

	#var settings : Dictionary = gl_PlayerState.get_all()
	#var new_level : int = settings.get(upgrade_type,0)
#
	#var power_level_label : Label = $Upgrade_Permanent_button/Control/UpgradePanel/PowerLevel_label
	#power_level_label.text = str(new_level)
	
	
	var upgrade_type_string  : String = "power_" + upgrade_type
	var price_power : String =  "price_" + upgrade_type
	
	
	#var settings : Dictionary = gl_PlayerState.get_all()
	var new_level := gl_DataSet.get_value(price_power, gl_PlayerState.dataset[upgrade_type_string])

	var power_level_label : Label = $Upgrade_Permanent_button/Control/UpgradePanel/PowerLevel_label
	power_level_label.text = "$" + str(int(new_level))
	
	
	
	var settings2 : Dictionary = gl_PlayerState.get_all()
	var new_level2 : int = settings2.get(upgrade_type_string,0)


	await update_power_label_position()
	
	
	# Already synced
	if new_level == current_upgrade_level:
		return

	await update_progress_bar(new_level2)
	#tween_label_colour()
	#
#func tween_label_colour() -> void:
	#
	#var _node : Panel = $Upgrade_Permanent_button/Control/UpgradePanel
	#var tween := create_tween()
	#tween.tween_property(_node,"modulate", Color('42d100'), 0.1)
	#tween.tween_interval(1.25)
	#tween.tween_property(_node,"modulate", Color('FFFFFF'), 0.5)
	
func update_progress_bar(new_level : int) -> void:
	var _node : Panel = $Upgrade_Permanent_button/Control/UpgradePanel

	var tween2 := create_tween()
	tween2.tween_property(_node, "modulate", Color("42d100"), 0.1)
	tween2.tween_interval(0.5)

	await tween2.finished

	while current_upgrade_level < new_level:

		var bar : ProgressBar = progress_bar_container.get_child(current_upgrade_level)

		var tween := create_tween()
		tween.tween_property(bar, "value", 100, 0.25)

		current_upgrade_level += 1

		await tween.finished

		await update_power_label_position()

	# Return panel to normal color
	var tween3 := create_tween()
	tween3.tween_property(_node, "modulate", Color.WHITE, 0.5)

	await tween3.finished
	
	
	
func _ready() -> void:
	EventBus.instance.purchase_made.connect(update_shop)
	EventBus.instance.open_shop.connect(reset_buttons_settings)

	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	rename_self()
	reset_progress_bars()
		

	
	await get_tree().process_frame
	update_shop()


func update_shop(purchased_upgrade:String = "") -> void:

	# Ignore unrelated upgrades
	if purchased_upgrade != "power_" + upgrade_type:
		return

	update_power()

func reset_buttons_settings() -> void:
	scale = Vector2.ONE
	update_shop()


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

func rename_self() -> void:
	if upgrade_name_label:
		upgrade_name_label.text = "[i]" + self.name + "[/i]"


func reset_progress_bars() -> void:
	if !progress_bar_container:
		return
	
	for bar in progress_bar_container.get_children():
		bar.value = 0


func upgrade() -> void:
	if current_upgrade_level >= max_upgrade_level:
		return
	
	await start_upgrade_tween()
	current_upgrade_level += 1
	
	
func start_upgrade_tween() -> void:
	var bar: ProgressBar = progress_bar_container.get_child(current_upgrade_level)
	
	var tween := create_tween()
	#tween.tween_property($Control/UpgradePanel, "modulate", GlobalColorPalet.Global_color_money, 0.2)
	tween.tween_interval(0.3)
	tween.tween_property(bar, "value", 100, 0.3)
	tween.tween_interval(0.2)
	#tween.tween_property($Control/UpgradePanel, "modulate", GlobalColorPalet.Global_color_white, 1.0)

	await tween.finished
	return
	


func update_power_label_position() -> void:
	var power_level_label : Label = $Upgrade_Permanent_button/Control/UpgradePanel/PowerLevel_label

	var total_bars := progress_bar_container.get_child_count()

	# Maxed out
	if current_upgrade_level >= total_bars:
		power_level_label.text = "MAX"

		var last_bar : ProgressBar = progress_bar_container.get_child(total_bars - 1)

		await get_tree().process_frame

		var _bar_center : Vector2 = last_bar.position + (last_bar.size * 0.5)

		power_level_label.position = Vector2(
			_bar_center.x - power_level_label.size.x * 0.5,
			_bar_center.y - power_level_label.size.y * -1.3
		)

		return

	# Position over NEXT upgrade
	var bar : ProgressBar = progress_bar_container.get_child(current_upgrade_level)

	await get_tree().process_frame

	var bar_center : Vector2 = bar.position + (bar.size * 0.5)

	power_level_label.position = Vector2(
		bar_center.x - power_level_label.size.x * 0.5,
		bar_center.y - power_level_label.size.y * -1.3
	)

func restart() -> void:
	print('should be restarting the progress bars')
	current_upgrade_level = 0
	current_bullet_amount = 1

	upgrade_value = 0
	cost = 0

	if wiggle_tween:
		wiggle_tween.kill()
		wiggle_tween = null

	scale = Vector2.ONE
	modulate = Color.WHITE
	
	purchase_progress_bar.value = 0
	purchase_hold_progress_bar.value = 0

	reset_progress_bars()
	reset_buttons_settings()
	print('should be restarting the progress bars 2')
	await get_tree().process_frame
	update_shop("power_" + upgrade_type)
	await update_power_label_position()
