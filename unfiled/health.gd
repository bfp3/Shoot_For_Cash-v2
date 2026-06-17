extends Control
@onready var rich_text_label = $RichTextLabel

#func _ready():
	#GameManager.resetScore()

func _process(delta):
	rich_text_label.text = str(GameManager.health)
