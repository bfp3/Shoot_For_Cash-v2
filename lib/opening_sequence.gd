extends Node

@export var sequence_1 : Node
@export var sequence_2 : Node
@export var sequence_3 : Node
@export var sequence_4 : Node
@export var sequence_5 : Node

@export var play_opening_sequence := true

func _ready() -> void:
	if play_opening_sequence:
		await sequence_1.play_sequence()
		await sequence_2.play_sequence()
		await sequence_3.play_sequence()
		await sequence_4.play_sequence()
		await sequence_5.play_sequence()
	
	else:
		return
