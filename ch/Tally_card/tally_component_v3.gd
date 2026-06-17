extends Button

@export var tooltip : Tooltip

@export_group('Item Details')
@export var description := "UNNAMED"
@export var rock_type = 'rock_type_1'
var base_value := 0

@onready var name_label: RichTextLabel = %NameLabel

@export var focus_enter_sfx: AudioStreamPlayer
@export var focus_exit_sfx: AudioStreamPlayer

var wiggle_tween: Tween

@onready var item_icon: TextureRect = %ItemIcon
@export var icon_texture : CompressedTexture2D

var value := 1
@export var item_destroyed : RichTextLabel
@export var item_cash_reward : RichTextLabel
@export var icon_modulate : Color = Color.WHITE
var tally_card_main : TallyCard
var cash_earned := 0

var temporary_count := 0
var permanent_count := 0

func reset_temporary_values() -> void:
	temporary_count = 0
	cash_earned = 0
	hide()
	#update_name()
	

func _ready() -> void:
	value = base_value
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	mouse_entered.connect(_on_focus_entered)
	mouse_exited.connect(_on_focus_exited)

	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)

	#_update_visual_state()
	

	tally_card_main = get_tree().get_first_node_in_group('tally_card_menu') 
	EventBus.instance.egg_pulsed.connect(reset_temporary_values)
	EventBus.instance.open_tally_card.connect(tally_up)
	
	hide()
	#await get_tree().create_timer(0.2).timeout
	#update_name()
	

func update_nothing() -> void:
	description = self.name
	
	$Panel/VBoxContainer/UpgradePanel/GPUParticles2D.emitting = false
	name_label.text = "Nothing..."
	item_icon.hide()
	#item_icon.texture = icon_texture
	#item_icon.modulate = icon_modulate
	item_destroyed.text = "..."
	
func update_name() -> void:
	show()
	description = self.name
	item_icon.texture = icon_texture
	item_icon.modulate = icon_modulate
	base_value = int(gl_DataSet.get_value(rock_type, 0))
	cash_earned = base_value * temporary_count
	name_label.text = self.name # + " [color=#42d100]$" + str(base_value).pad_zeros(2) +"[/color]"
	#item_name.text = (
		#"[color=#42d100]$" + str(value).pad_zeros(2) + "[/color] " + 
		#self.name 
	#)

	item_destroyed.text =  "[wave amp=10.0 freq=6.0 connected=1][i][color=#ffc700]x" + str(temporary_count).pad_zeros(2) + "[/color][/i][/wave]"
	
	if temporary_count > 0:
		%DestroyedLabel2.text = "[color=#ffc700]$" + str(cash_earned) + "[/color]"
		item_cash_reward.text = (
		
		"[color=#ffc700]" + str(temporary_count).pad_zeros(2) + "[/color]" +
		" X " +
		"$" + str(value).pad_zeros(2) +
		" = " +
		"[color=#42d100]$" + str(cash_earned).pad_zeros(2) + "[/color]"
	)

	else:
		#item_cash_reward.text = ""
		item_cash_reward.text = (
			"[color=#ffc700]" + str(temporary_count).pad_zeros(2) + "[/color]" +
			" X " +
			"$" + str(value).pad_zeros(2) +
			" = " +
			"[color=#42d100]$" + str(cash_earned).pad_zeros(2) + "[/color]"
	)
	
func tally_up() -> void:
	tally_card_main.total_cash_earned += value * temporary_count


func _on_focus_entered() -> void:
	update_name()
	var tooltip_display : String = "Total Cash Earned: [color=#42d100]" + "\n" + "$" + str(cash_earned) + "[/color]"
	
	if tooltip:
		tooltip._toggle_tooltip(true, str(tooltip_display))

	if focus_enter_sfx:
		focus_enter_sfx.play()
		
	z_index = 1
	_play_wiggle(1.02)

func _on_focus_exited() -> void:
	if tooltip:
		tooltip._toggle_tooltip(false, description)
	
	if focus_exit_sfx:
		focus_exit_sfx.play()
		
	z_index = 0
	_play_wiggle(1.0, 0.02)


func _play_wiggle(target_scale: float, _scale_dur : float = 0.08) -> void:
	if wiggle_tween:
		wiggle_tween.kill()
	
	var _scale_node := self
	wiggle_tween = create_tween()

	#wiggle_tween.set_trans(Tween.TRANS_SINE)
	wiggle_tween.set_ease(Tween.EASE_OUT)

	wiggle_tween.tween_property(_scale_node, "scale", Vector2(target_scale, target_scale), _scale_dur)
	#wiggle_tween.tween_property(_scale_node, "rotation_degrees", -2.0, 0.04)
	#wiggle_tween.tween_property(_scale_node, "rotation_degrees", 3.0, 0.08)
	#wiggle_tween.tween_property(_scale_node, "rotation_degrees", 0.0, 0.04)
