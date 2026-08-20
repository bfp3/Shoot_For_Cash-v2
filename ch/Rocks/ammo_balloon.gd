extends "res://ch/Rocks/checkpoint.gd"
## Scripted ammo balloon: shoot to buy ammo. `clear ammo` pops it with no reward.

var ammo_amount := 99
var ammo_price := 0
var _grant_on_pop := true

@onready var _amount_label: Label3D = %AmmoAmountLabel
@onready var _price_label: Label3D = %AmmoPriceLabel


func _ready() -> void:
	super._ready()
	if is_in_group("checkpoint"):
		remove_from_group("checkpoint")
	add_to_group("ammo_balloon")
	add_to_group("ammo_reload_target")
	_refresh_labels()


func configure_from_entry(entry: Dictionary) -> void:
	var amount := int(entry.get("amount", -1))
	if amount < 0:
		amount = int(gl_DataSet.get_value("power_ammo", 0))
		if amount < 0:
			amount = 99
	ammo_amount = maxi(amount, 0)
	
	var balloon_mesh : MeshInstance3D = $Mesh/small_rock2
	match balloon_type:
		BalloonType.WHITE:

			balloon_mesh.material_override = BALLOON_RED_MAT
	balloon_mesh.scale
	var price := int(entry.get("price", -1))
	if price < 0:
		price = int(gl_DataSet.get_value("price_ammo", 0))
		if price < 0:
			price = 0
	ammo_price = maxi(price, 0)

	var row := int(entry.get("row", 3))
	var column := int(entry.get("column", 6))
	occupy_row = row
	occupy_column = column
	_refresh_labels()


func is_blocking_sky() -> bool:
	return false


func hit_by_player(damage: int, _screen_offset: Vector2 = Vector2.ZERO) -> void:
	if _consumed or not rock_activated:
		return
	if not visible and has_node("Mesh") and $Mesh.visible == false:
		return
	if not _player_can_buy_ammo():
		return
	if _grant_on_pop and not _can_afford():
		_play_reject()
		return
	health -= damage
	_consume_by_player()


func _player_can_buy_ammo() -> bool:
	var rm = get_tree().get_first_node_in_group("round_manager")
	if rm and rm.has_method("is_checkpoint_ceremony") and bool(rm.is_checkpoint_ceremony()):
		return false
	var player = get_tree().get_first_node_in_group("Player")
	if player and "current_state" in player and "State" in player:
		if player.current_state != player.State.ACTIVE:
			return false
	return true


func _can_afford() -> bool:
	if ammo_price <= 0:
		return true
	return int(gl_PlayerState.dataset.cash) >= ammo_price


func _play_reject() -> void:
	if has_node("hitSound"):
		$hitSound.play()


func pop_without_reward() -> void:
	_grant_on_pop = false
	_consume_by_player()


func _consume_by_player() -> void:
	if _consumed:
		return
	_consumed = true
	rock_activated = false
	_stop_bob()
	if has_node("AnimationPlayer"):
		$AnimationPlayer.stop()
	enter_state(State.HIT)
	disable_collision()
	if is_in_group("Target"):
		remove_from_group("Target")
	if is_in_group("ammo_reload_target"):
		remove_from_group("ammo_reload_target")
	is_deactivated = true
	_hide_labels()

	if _grant_on_pop:
		_grant_ammo_purchase()
		if has_node("Checkpoint"):
			$Checkpoint.play()
	if has_node("pop_balloon"):
		$pop_balloon.pitch_scale = randf_range(0.95, 1.1)
		$pop_balloon.play()
	play_destroy_sfx()
	_keep_playing_audio_after_free()
	await was_hit_tween()
	if is_instance_valid(self):
		queue_free()


func _grant_ammo_purchase() -> void:
	if ammo_price > 0:
		if int(gl_PlayerState.dataset.cash) < ammo_price:
			return
		gl_PlayerState.dataset.cash = int(gl_PlayerState.dataset.cash) - ammo_price
		if EventBus.instance and EventBus.instance.has_signal("purchase_made"):
			EventBus.instance.purchase_made.emit("ammo")

	var player = get_tree().get_first_node_in_group("Player")
	if player and player.has_method("add_ammo") and ammo_amount > 0:
		player.add_ammo(ammo_amount, true)

	var rm = get_tree().get_first_node_in_group("round_manager")
	var wave_feedback = null
	if rm:
		wave_feedback = rm.get("wave_progress_feedback")
	if wave_feedback and wave_feedback.has_method("start_reloading"):
		wave_feedback.start_reloading()


func _refresh_labels() -> void:
	if _amount_label:
		_amount_label.text = str(ammo_amount)
		_amount_label.show()
	if _price_label:
		_price_label.text = CommonCode.format_money(ammo_price)
		_price_label.show()


func _hide_labels() -> void:
	if _amount_label:
		_amount_label.hide()
	if _price_label:
		_price_label.hide()
