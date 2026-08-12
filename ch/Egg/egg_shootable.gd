extends StaticBody3D
## Distant shootable egg — always active, no rock-round activation needed.

const MONEY_LABEL_SCRIPT = preload("res://ch/Money/money_in_world_3D_label.gd")

var rock_activated := true
var destroyed := false
@export var health := 1
@export var destroy_cleanup_delay := 2.2
@onready var main_col: CollisionShape3D = $main_col

func _ready() -> void:
	add_to_group("Target")
	if has_node("AoE"):
		$AoE.hide()

func start_bullet_to_target() -> void:
	print('empty thing ')

func hit_by_player(damage: int, _screen_offset: Vector2 = Vector2.ZERO) -> void:
	if destroyed:
		return
	health -= maxi(damage, 1)
	if health <= 0:
		start_destroyed_process()


func start_destroyed_process() -> void:
	if destroyed:
		return
	destroyed = true
	remove_from_group("Target")

	if has_node("Egg_shape"):
		$Egg_shape.hide()
	if has_node("Mesh"):
		$Mesh.hide()

	if has_node("main_col"):
		$main_col.disabled = true

	if has_node("hitSound"):
		$hitSound.play()

	_award_egg_cash()

	if has_node("AoE"):
		$AoE.show()
		$AoE.global_position = global_position
		$AoE.play_particles = true

	await get_tree().create_timer(destroy_cleanup_delay).timeout
	queue_free()


func _award_egg_cash() -> void:
	var amount := int(gl_DataSet.get_value("reward_egg", 0))
	if amount <= 0:
		amount = 300
	gl_PlayerState.add_bonus(amount)
	_show_egg_cash_popup(amount)


func _show_egg_cash_popup(amount: int) -> void:
	## Prefer an existing world money label so fonts/materials match pineapple rewards.
	var template: Label3D = null
	for node in get_tree().get_nodes_in_group("Target"):
		if node == null or not is_instance_valid(node):
			continue
		var money := node.get_node_or_null("Money_Label3D") as Label3D
		if money and money.has_method("show_big_reward_popup"):
			template = money
			break
	if template:
		template.show_big_reward_popup(amount)
		return

	var label := Label3D.new()
	label.set_script(MONEY_LABEL_SCRIPT)
	get_tree().get_current_scene().add_child(label)
	if label.has_method("show_big_reward_popup"):
		await label.show_big_reward_popup(amount)
	label.queue_free()
