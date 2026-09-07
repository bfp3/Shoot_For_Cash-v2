extends "res://ch/Rocks/rest_balloon.gd"
## Yellow-rock bonus balloon: shoot to bank a rolled cash amount into the round pool.

@export_group("Cash Balloon")
@export var cash_min := 4
@export var cash_max := 16
## Hits needed to break open. 1 for now; raise later for multi-shot crates.
@export var balloon_health := 1

var _grant_on_pop := true
## Survives balloon `reset_stats()`, which zeros `cash_value` on activate.
var _payout := 0


func _ready() -> void:
	super._ready()
	if is_in_group("rest_balloon"):
		remove_from_group("rest_balloon")
	if is_in_group("health_balloon"):
		remove_from_group("health_balloon")
	if is_in_group("checkpoint"):
		remove_from_group("checkpoint")
	if is_in_group("ammo_balloon"):
		remove_from_group("ammo_balloon")
	if is_in_group("ammo_reload_target"):
		remove_from_group("ammo_reload_target")
	add_to_group("cash_balloon")
	_roll_cash_value()
	_apply_cash_look()
	_refresh_labels()


func spawn_at_world(pos: Vector3, amount: Variant = null) -> void:
	occupy_row = -1
	occupy_column = -1
	if amount is int:
		_set_payout(int(amount))
	else:
		_roll_cash_value()
	_apply_health()
	_apply_cash_look()
	arrive_from_below(pos)
	## `update_active()` / `reset_stats()` wipe health and cash_value.
	_apply_health()
	_restore_payout()
	_refresh_labels()


func is_blocking_sky() -> bool:
	return false


func hit_by_player(damage: int, _screen_offset: Vector2 = Vector2.ZERO) -> void:
	if _consumed or not rock_activated:
		return
	if not visible and has_node("Mesh") and $Mesh.visible == false:
		return
	health -= maxi(damage, 1)
	if health > 0:
		_play_hit_feedback()
		return
	_consume_by_player()


func pop_without_reward() -> void:
	_grant_on_pop = false
	_consume_by_player()


func _roll_cash_value() -> void:
	var lo := mini(cash_min, cash_max)
	var hi := maxi(cash_min, cash_max)
	_set_payout(randi_range(lo, hi))


func _set_payout(amount: int) -> void:
	_payout = amount
	cash_value = _payout


func _restore_payout() -> void:
	cash_value = _payout


func _apply_health() -> void:
	health = maxi(balloon_health, 1)
	max_health = health


func _apply_cash_look() -> void:
	var balloon_mesh := get_node_or_null("Mesh/small_rock2") as MeshInstance3D
	if balloon_mesh and BALLOON_YELLOW_MAT:
		balloon_mesh.material_override = BALLOON_YELLOW_MAT
	var crate := get_node_or_null("Crate") as Node3D
	if crate:
		crate.show()
	var ammo_label := get_node_or_null("%AmmoAmountLabel") as Label3D
	if ammo_label:
		ammo_label.hide()
	var price_label := get_node_or_null("%AmmoPriceLabel") as Label3D
	if price_label:
		price_label.hide()


func _play_hit_feedback() -> void:
	if has_node("hitSound"):
		$hitSound.play()


func _consume_by_player() -> void:
	if _consumed:
		return
	var payout := _payout
	_consumed = true
	rock_activated = false
	_stop_bob()
	if has_node("AnimationPlayer"):
		$AnimationPlayer.stop()
	if _grant_on_pop:
		_grant_cash(payout)
	enter_state(State.HIT)
	disable_collision()
	if is_in_group("Target"):
		remove_from_group("Target")
	is_deactivated = true
	_hide_labels()

	if has_node("AoE"):
		$AoE.top_level = true
		$AoE.global_position = global_position + Vector3.UP
		$AoE.play_particles = true
	var balloon := get_node_or_null("hot_air_balloon") as Node3D
	if balloon:
		balloon.hide()
	var crate := get_node_or_null("Crate") as Node3D
	if crate:
		crate.hide()
	var crate2 := get_node_or_null("Crate2") as Node3D
	if crate2:
		crate2.hide()
	if has_node("pop_balloon"):
		$pop_balloon.pitch_scale = randf_range(0.95, 1.1)
		$pop_balloon.play()
	play_destroy_sfx()
	_keep_playing_audio_after_free()
	await was_hit_tween()
	if is_instance_valid(self):
		await get_tree().create_timer(3.0, false).timeout
		queue_free()


func _grant_cash(amount: int) -> void:
	if amount == 0:
		return
	gl_PlayerState.add_to_cash_pool(amount, global_position)
	var money_label := get_node_or_null("Money_Label3D")
	if money_label and money_label.has_method("money_is_money"):
		money_label.money_is_money(global_position + Vector3.UP, amount)


func _crate_value_label() -> Label3D:
	var crate := get_node_or_null("Crate") as Node3D
	if crate:
		var label := crate.get_node_or_null("Label3D") as Label3D
		if label:
			return label
	var crate2 := get_node_or_null("Crate2") as Node3D
	if crate2:
		return crate2.get_node_or_null("Label3D") as Label3D
	return null


func _refresh_labels() -> void:
	var amount := _payout
	var text := CommonCode.format_money(amount)
	var positive := Color(0.96, 0.83, 0.7, 1)
	var negative := Color(0.63, 0.01, 0.02, 1)
	var color := negative if amount < 0 else positive
	var crate := get_node_or_null("Crate") as Node3D
	if crate:
		crate.show()
		var crate_label := crate.get_node_or_null("Label3D") as Label3D
		if crate_label:
			crate_label.text = text
			crate_label.modulate = color
			crate_label.show()
	var crate2 := get_node_or_null("Crate2") as Node3D
	if crate2:
		var crate2_label := crate2.get_node_or_null("Label3D") as Label3D
		if crate2_label:
			crate2_label.text = text
			crate2_label.modulate = color
			crate2_label.show()
	var ammo_label := get_node_or_null("%AmmoAmountLabel") as Label3D
	if ammo_label:
		ammo_label.hide()
	var price_label := get_node_or_null("%AmmoPriceLabel") as Label3D
	if price_label:
		price_label.hide()


func _hide_labels() -> void:
	var crate_label := _crate_value_label()
	if crate_label:
		crate_label.hide()
	var crate2 := get_node_or_null("Crate2") as Node3D
	if crate2:
		var crate2_label := crate2.get_node_or_null("Label3D") as Label3D
		if crate2_label:
			crate2_label.hide()
