extends HBoxContainer

@export var tally_card_main : TallyCard
@export var tooltip: Tooltip
@export var item_description : RichTextLabel
@export var item_number : RichTextLabel
@export var achieved_checkbox : CheckBox
@export var cash_reward_label : RichTextLabel
var cash_reward := 0
#
#func update_round_statistics(_stats :int) -> void:
	#item_description.text = self.name
	#item_number.text = str(_stats).pad_zeros(2)
	#
	#cash_reward_label.text = "$" + str(cash_reward).pad_zeros(2)
	#
 #
	#tally_card_main.total_cash_earned = tally_card_main.total_cash_earned #+ cash_reward
