extends Area3D

@onready var money_label_3d: Label3D = $Money_Label3D
@onready var money_label_3d2: Label3D = $Money_Label3D2

@export var current_multiplier := 2
@export var bonus_colour: Color = Color("ffc700ff")
@export var bonus_duration := 1.0

var default_money_label_3d_colour: Color
var default_money_label_colour: Color

var tower_tween: Tween = null
var tower_tween_end : Tween = null


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	default_money_label_3d_colour = money_label_3d.modulate
	default_money_label_colour = money_label_3d2.modulate

	#EventBus.instance.egg_pulsed.connect(update_text)

func _on_body_entered(body: Node3D) -> void:
	if not body is RockInstance:
		return

	body.went_through_cash_multi_zone()
	body.current_cash_multiplier = current_multiplier

func update_text() -> void:
	money_label_3d.text = "x" + str(current_multiplier)

func start() -> void:
	if tower_tween:
		tower_tween.kill()
	if tower_tween_end:
		tower_tween_end.kill()

	#if self.name == 'ZoneA':
		#self.get_node('QuadMeshA').start()
			#
	#if self.name == 'ZoneB':
		#self.get_node('QuadMeshB').start()
		
	tower_tween = create_tween()

	tower_tween.set_parallel(true)
	tower_tween.tween_property(money_label_3d, "modulate", bonus_colour, 0.1)
	tower_tween.tween_property(money_label_3d2, "modulate", bonus_colour, 0.1)
	tower_tween.tween_interval(2.0)
	await tower_tween.finished
	end()
	
func end() -> void:
	tower_tween_end = create_tween()
	tower_tween_end.set_parallel(true)
	tower_tween_end.tween_property(money_label_3d, "modulate", default_money_label_3d_colour, bonus_duration)
	tower_tween_end.tween_property(money_label_3d2, "modulate", default_money_label_colour, bonus_duration)
