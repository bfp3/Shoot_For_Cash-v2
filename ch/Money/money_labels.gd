extends Control
@export var money_label_3d: Label3D
@export var confetti_cannon : Node3D
var money_earned := 0
const rock_money := 2.0
const cannonball_money := 2.0
const popper_money := 2.0


#func _ready() -> void:
	#EventBus.rock_destroyed.connect(_on_rock_destroyed)
	#EventBus.cannonball_destroyed.connect(_on_cannonball_destroyed)
	#EventBus.popper_has_died.connect(_on_popper_destroyed)
	#EventBus.instance.update_money.connect(update_money_after_shop)
	#update_money(0)
	
func update_money(_money_added : int) -> void:
	GlobalPlayerMoney.gl_player_money += _money_added
	$Label3D.text = "$" + str(GlobalPlayerMoney.gl_player_money).pad_zeros(2)
	#$"../UpgradeTreeMenu".add_player_money(_money_added)
	#check_money_level_up()

func update_money_after_shop() -> void:
	$Label3D.text = "$" + str(GlobalPlayerMoney.gl_player_money).pad_zeros(2)
	
	
func _on_rock_destroyed(pos : Vector3, _money_value:int) -> void:
	var money_yield := _money_value
	update_money(money_yield)
	money_label_3d.money_is_money(pos, money_yield)
	
#func _on_cannonball_destroyed() -> void:
	#var money_yield := 20
	#update_money(money_yield)
	#money_label_3d.money_is_money(pos, money_yield)
	
func _on_popper_destroyed(pos : Vector3) -> void:
	var money_yield := 100
	update_money(money_yield)
	money_label_3d.money_is_money(pos, money_yield)
