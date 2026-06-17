extends HBoxContainer

@export var item_icon : TextureRect
@export var icon_texture : CompressedTexture2D
@export var item_name : RichTextLabel
@export var item_value : RichTextLabel
@export var value := 1
@export var item_destroyed : RichTextLabel
@export var item_cash_reward : RichTextLabel
var tally_card_main : TallyCard
@export var icon_modulate : Color = Color.WHITE

#@export var tooltip: Tooltip
#@export var item_number : RichTextLabel
#@export var achieved_checkbox : CheckBox
#@export var cash_reward := 0

var temporary_count := 0
var permanent_count := 0

func _ready() -> void:
	
	tally_card_main = get_tree().get_first_node_in_group('tally_card_menu') 
	EventBus.instance.egg_pulsed.connect(reset_temporary_values)
	EventBus.instance.open_tally_card.connect(tally_up)
	await get_tree().create_timer(0.2).timeout
	update_name()
	
	
	
func reset_temporary_values() -> void:
	temporary_count = 0
	update_name()
	

func update_name() -> void:
	item_icon.texture = icon_texture
	item_icon.modulate = icon_modulate
	#item_name.text = (
		#"[color=#42d100]$" + str(value).pad_zeros(2) + "[/color] " + 
		#self.name 
	#)
	
	item_name.text = self.name
	item_value.text = "$" + str(value).pad_zeros(2)
	item_destroyed.text =  "[color=#ffc700]" + str(temporary_count).pad_zeros(2) + "[/color] (" + str(permanent_count).pad_zeros(2) + ")"
	var cash_earned = value * temporary_count

	if temporary_count > 0:
		item_cash_reward.text = (

		"[color=#ffc700]" + str(temporary_count).pad_zeros(2) + "[/color]" +
		" X " +
		"$" + str(value).pad_zeros(2) +
		" = " +
		"[color=#42d100]$" + str(cash_earned).pad_zeros(2) + "[/color]"
	)

	else:
		item_cash_reward.text = ""
	
func tally_up() -> void:
	print("do this")
	tally_card_main.total_cash_earned += value * temporary_count
	
