extends "res://ch/Rocks/rest_balloon.gd"
## Yellow-rock bonus balloon: shoot to drop a cash crate, or let a collector take it.

const CASH_CRATE_DROP_SCENE := preload("res://ch/Rocks/CashCrateDrop.tscn")

@export_group("Cash Balloon")
@export var cash_min := 4
@export var cash_max := 16
## Hits needed to break open. 1 for now; raise later for multi-shot crates.
@export var balloon_health := 1
## After hanging in the air, the crate value ticks down.
@export var value_decays := true
@export_range(0.0, 30.0, 0.1) var decay_delay_sec := 3.0
@export_range(0.1, 30.0, 0.1) var decay_interval_sec := 2.0
@export var decay_amount := 2

var _grant_on_pop := true
## Survives balloon `reset_stats()`, which zeros `cash_value` on activate.
var _payout := 0
var _air_time := 0.0
var _decay_armed := false
var _decay_tick_left := 0.0


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
	_reset_decay()
	arrive_from_below(pos)
	## `update_active()` / `reset_stats()` wipe health and cash_value.
	_apply_health()
	_restore_payout()
	_refresh_labels()


func is_blocking_sky() -> bool:
	return false


func _process(delta: float) -> void:
	super._process(delta)
	_tick_value_decay(delta)


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


## Collector walked into the hanging crate — bank it, do not drop a falling crate.
func try_collect_by_collector(_collector: Node = null) -> bool:
	if _consumed:
		return false
	if not visible:
		return false
	_grant_on_pop = false
	var amount := _payout
	var pos := global_position
	var crate := get_node_or_null("Crate") as Node3D
	if crate:
		pos = crate.global_position
	if amount != 0:
		gl_PlayerState.add_to_cash_pool(amount, pos)
	_consume_by_player()
	return true


func _roll_cash_value() -> void:
	var lo := mini(cash_min, cash_max)
	var hi := maxi(cash_min, cash_max)
	_set_payout(randi_range(lo, hi))


func _set_payout(amount: int) -> void:
	_payout = amount
	cash_value = _payout


func _reset_decay() -> void:
	_air_time = 0.0
	_decay_armed = false
	_decay_tick_left = 0.0


func _tick_value_decay(delta: float) -> void:
	if not value_decays or _consumed or not visible:
		return
	if not _arrived:
		_reset_decay()
		return
	_air_time += delta
	if _air_time < decay_delay_sec:
		return
	if not _decay_armed:
		_decay_armed = true
		_decay_tick_left = decay_interval_sec
		_apply_decay()
		return
	_decay_tick_left -= delta
	while _decay_tick_left <= 0.0:
		_decay_tick_left += maxf(decay_interval_sec, 0.1)
		_apply_decay()


func _apply_decay() -> void:
	if _consumed:
		return
	_set_payout(_payout - decay_amount)
	_refresh_labels()


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
		_release_falling_crate(payout)
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


func _release_falling_crate(amount: int) -> void:
	var xform := global_transform
	var crate := get_node_or_null("Crate") as Node3D
	if crate:
		xform = crate.global_transform
	var host: Node = get_parent()
	if host == null:
		host = get_tree().current_scene
	if host == null:
		return
	var drop: Node = CASH_CRATE_DROP_SCENE.instantiate()
	host.add_child(drop)
	if drop.has_method("setup"):
		drop.setup(amount, xform, global_position.z)


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
