extends Node3D
## Handles `bonus-protect` rounds: place player balloon(s), award cash if all survive.

@export var round_manager: RoundManager
## Cash awarded when every protect balloon survives the rock sequence.
@export var reward_cash := 50

const PLAYER_BALLOON_SCENE := preload('res://ch/Rocks/PlayerBalloon.tscn')

const DEFAULT_COLUMN := 4
const DEFAULT_ROW := 2 ## B
const BALLOON_Z_FRONT := 23.0
const BALLOON_COLUMN_1_X := 7.0
const BALLOON_COLUMN_STEP := -2.0
const BALLOON_COLUMN_COUNT := 8
const LANE_Y := {
	1: 6.5,
	2: 3.5,
	3: 0.5,
}

var active := false
var failed := false
var _balloons: Array[StaticBody3D] = []
var _rest_transforms: Dictionary = {} ## StaticBody3D -> Transform3D
var _spawned_extra: Array[StaticBody3D] = [] ## Instantiated when pool is short


func _ready() -> void:
	for child in get_children():
		if child is StaticBody3D:
			_rest_transforms[child] = child.global_transform
			_stow_balloon(child)


func is_active() -> bool:
	return active


func did_fail() -> bool:
	return failed


## `placements` is [{row, column}, ...] from `protect-balloon` lines.
## Empty → one balloon at B4 (legacy default).
func begin_protect_round(placements: Array = []) -> void:
	cleanup_protect_round()
	active = true
	failed = false

	var cells: Array = []
	for entry in placements:
		if entry is Dictionary:
			cells.append({
				'row': int(entry.get('row', DEFAULT_ROW)),
				'column': int(entry.get('column', DEFAULT_COLUMN)),
			})

	if cells.is_empty():
		cells.append({'row': DEFAULT_ROW, 'column': DEFAULT_COLUMN})

	for cell in cells:
		var balloon := _claim_idle_balloon()
		if balloon == null:
			balloon = _spawn_extra_balloon()
		if balloon == null:
			push_warning('ProtectBalloons: could not create protect balloon')
			continue
		var row := int(cell.row)
		var column := int(cell.column)
		if row < 1:
			row = randi_range(1, 3)
		if column < 1:
			column = randi_range(1, BALLOON_COLUMN_COUNT)
		_activate_balloon_at(balloon, row, column)
		_balloons.append(balloon)

	if _balloons.is_empty():
		push_warning('ProtectBalloons: no PlayerBalloon children available')
		failed = true
		if round_manager and round_manager.has_method('on_protect_bonus_failed'):
			round_manager.on_protect_bonus_failed()
		return

	print('ProtectBalloons: placed %d protect balloon(s)' % _balloons.size())


## Called from a protect balloon when a rock/pineapple pops it.
func notify_protect_balloon_popped() -> void:
	if not active or failed:
		return
	failed = true
	print('ProtectBalloons: balloon popped — bonus failed')
	if round_manager and round_manager.has_method('on_protect_bonus_failed'):
		round_manager.on_protect_bonus_failed()


## End-of-round: award cash if every balloon survived, then stow them.
func resolve_protect_round(survived: bool) -> void:
	if not active and _balloons.is_empty():
		return

	var any_alive := false
	for balloon in _balloons:
		if balloon != null and is_instance_valid(balloon):
			any_alive = true
			break

	if survived and not failed and any_alive:
		var amount := reward_cash
		if amount <= 0:
			amount = int(gl_DataSet.get_value('reward_perfect_round'))
		gl_PlayerState.dataset.bonus_cash += amount
		var label_balloon: StaticBody3D = _balloons[0] if _balloons.size() > 0 else null
		if label_balloon and is_instance_valid(label_balloon):
			var label = label_balloon.get('money_label_3d')
			if label and label.has_method('print_text'):
				label.print_text(label_balloon.global_position, '+$%d' % amount)
		print('ProtectBalloons: survived — awarded $%d' % amount)
	else:
		print('ProtectBalloons: no bonus cash')

	cleanup_protect_round()


func cleanup_protect_round() -> void:
	for balloon in _balloons:
		if balloon != null and is_instance_valid(balloon):
			_stow_balloon(balloon)
	_balloons.clear()

	for balloon in _spawned_extra:
		if balloon != null and is_instance_valid(balloon):
			_rest_transforms.erase(balloon)
			balloon.queue_free()
	_spawned_extra.clear()

	active = false


func _activate_balloon_at(balloon: StaticBody3D, row: int, column: int) -> void:
	var target := _cell_position(row, column)
	balloon.top_level = true
	balloon.global_position = target
	balloon.start_pos = target
	balloon.scale = Vector3.ONE * 1.7
	balloon.show()

	balloon.protect_mode = true
	balloon.balloon_type = balloon.BalloonType.BLUE

	_configure_threat_detection(balloon)

	if balloon.has_method('enter_state'):
		balloon.enter_state(balloon.State.ACTIVE)
	elif balloon.has_method('enable_collision'):
		balloon.enable_collision()
		balloon.rock_activated = true

	# Protect balloons are not shot targets — only collisions fail the bonus.
	if balloon.is_in_group('Target'):
		balloon.remove_from_group('Target')

	var row_letter := 'A'
	match row:
		2:
			row_letter = 'B'
		3:
			row_letter = 'C'
	print('ProtectBalloons: protect balloon at %s%d' % [row_letter, column])


func _claim_idle_balloon() -> StaticBody3D:
	for child in get_children():
		if child is StaticBody3D and not _balloons.has(child):
			return child
	return null


func _spawn_extra_balloon() -> StaticBody3D:
	var balloon: StaticBody3D = PLAYER_BALLOON_SCENE.instantiate()
	add_child(balloon)
	_rest_transforms[balloon] = balloon.global_transform
	_spawned_extra.append(balloon)
	_stow_balloon(balloon)
	return balloon


func _stow_balloon(balloon: StaticBody3D) -> void:
	balloon.protect_mode = false
	if balloon.has_method('disable_collision'):
		balloon.disable_collision()
	if balloon.has_method('stop_all_tweens'):
		balloon.stop_all_tweens()
	if _rest_transforms.has(balloon):
		balloon.global_transform = _rest_transforms[balloon]
	balloon.scale = Vector3.ONE
	balloon.hide()
	balloon.rock_activated = false
	if balloon.has_node('Mesh'):
		balloon.get_node('Mesh').show()
		balloon.get_node('Mesh').scale = Vector3.ONE
	if balloon.is_in_group('Target'):
		balloon.remove_from_group('Target')


func _configure_threat_detection(balloon: StaticBody3D) -> void:
	# Rocks live on layer 2; pineapples on layer 9 (256).
	var area: Area3D = balloon.get_node_or_null('balloon_area') as Area3D
	if area == null:
		area = balloon.get_node_or_null('%balloon_area') as Area3D
	if area:
		area.set_collision_mask_value(2, true)
		area.set_collision_mask_value(9, true)
		area.monitoring = true

	var area2: Area3D = balloon.get_node_or_null('Area3D') as Area3D
	if area2:
		area2.set_collision_mask_value(2, true)
		area2.monitoring = true


func _cell_position(row: int, column: int) -> Vector3:
	var clamped_col := clampi(column, 1, BALLOON_COLUMN_COUNT)
	var x := BALLOON_COLUMN_1_X + float(clamped_col - 1) * BALLOON_COLUMN_STEP
	var y: float = LANE_Y.get(row, LANE_Y[2])
	return Vector3(x, y, BALLOON_Z_FRONT)
