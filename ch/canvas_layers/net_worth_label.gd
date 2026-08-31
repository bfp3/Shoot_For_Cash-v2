extends Control
## Title-menu net worth readout. Font size steps down as the number gets longer.

@onready var _label: RichTextLabel = get_node_or_null("Amount") as RichTextLabel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _label:
		_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	refresh()


func refresh(amount: int = -1) -> void:
	if amount < 0:
		amount = 0
		if gl_PlayerState and gl_PlayerState.has_method("get_net_worth"):
			amount = int(gl_PlayerState.get_net_worth())
	if _label == null:
		return
	if CommonCode and CommonCode.has_method("format_money"):
		_label.text = String(CommonCode.format_money(amount))
	else:
		_label.text = "$" + str(amount)
	_label.add_theme_font_size_override("normal_font_size", font_size_for(amount))


static func font_size_for(amount: int) -> int:
	var n := absi(amount)
	if n < 10000:
		return 82
	if n <= 999999:
		return 72
	return 60
