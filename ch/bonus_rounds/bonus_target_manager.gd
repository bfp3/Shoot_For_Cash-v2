extends Node3D
## Handles `bonus-type1` rounds: one or more bonus targets that stay still or patrol waypoints.

@export var round_manager: RoundManager
## Cash awarded when every bonus target survives the rock sequence.
@export var reward_cash := 50
## Seconds to travel between consecutive waypoint cells.
@export var patrol_seconds_per_leg := 1.25

const BONUS_TARGET_SCENE := preload('res://ch/bonus_rounds/bonus_target.tscn')

const DEFAULT_COLUMN := 4
const DEFAULT_ROW := 2 ## B
const TARGET_Z_FRONT := 23.5
const COLUMN_1_X := 7.0
const COLUMN_STEP := -2.0
const COLUMN_COUNT := 8
const LANE_Y := {
	1: 6.5,
	2: 3.5,
	3: 0.5,
}

var active := false
var failed := false
var _rest_transforms: Dictionary = {} ## StaticBody3D -> Transform3D
var _spawned_extra: Array[StaticBody3D] = []
## Active patrol slots: { target, positions: Array[Vector3], index: int, tween: Tween }
var _slots: Array = []


func _ready() -> void:
	for child in get_children():
		if child is StaticBody3D:
			_rest_transforms[child] = child.global_transform
			_stow_target(child)


func is_active() -> bool:
	return active


func did_fail() -> bool:
	return failed


## `targets` is [{waypoints: [{row, column}, ...]}, ...] — one entry per `bonus-target` line.
## Empty array → one stationary target at B4.
func begin_bonus_round(targets: Array = []) -> void:
	cleanup_bonus_round()
	active = true
	failed = false

	var specs: Array = targets
	if specs.is_empty():
		specs = [{'waypoints': []}]

	for spec in specs:
		var waypoints: Array = []
		if spec is Dictionary:
			waypoints = spec.get('waypoints', [])
		elif spec is Array:
			# Legacy: a flat waypoint list was passed.
			waypoints = spec

		var cells := _normalize_cells(waypoints)
		var target := _claim_idle_target()
		if target == null:
			target = _spawn_extra_target()
		if target == null:
			push_warning('BonusTargetManager: could not create bonus target')
			continue

		_activate_target_at(target, int(cells[0].row), int(cells[0].column))

		var slot := {
			'target': target,
			'positions': [],
			'index': 0,
			'tween': null,
		}
		if cells.size() >= 2:
			for cell in cells:
				slot.positions.append(_cell_position(int(cell.row), int(cell.column)))
			_slots.append(slot)
			_start_next_patrol_leg(slot)
			print('BonusTargetManager: patrol %d waypoints' % slot.positions.size())
		else:
			_slots.append(slot)
			print('BonusTargetManager: stationary target')

	if _slots.is_empty():
		failed = true
		if round_manager and round_manager.has_method('on_bonus_type1_failed'):
			round_manager.on_bonus_type1_failed()
		return

	print('BonusTargetManager: %d target(s) active' % _slots.size())


func _normalize_cells(waypoints: Array) -> Array:
	var cells: Array = []
	for entry in waypoints:
		if entry is Dictionary:
			var row := int(entry.get('row', DEFAULT_ROW))
			var column := int(entry.get('column', DEFAULT_COLUMN))
			if row < 1 or column < 1:
				continue
			cells.append({'row': row, 'column': column})
	if cells.is_empty():
		cells.append({'row': DEFAULT_ROW, 'column': DEFAULT_COLUMN})
	return cells


## Called from a bonus target when a rock/pineapple (or shot) destroys it.
func notify_bonus_target_destroyed() -> void:
	if not active or failed:
		return
	failed = true
	_stop_all_patrols()
	print('BonusTargetManager: target destroyed — bonus failed')
	if round_manager and round_manager.has_method('on_bonus_type1_failed'):
		round_manager.on_bonus_type1_failed()


## End-of-round: award cash if every target survived, then stow them.
func resolve_bonus_round(survived: bool) -> void:
	if not active and _slots.is_empty():
		return

	var any_alive := false
	for slot in _slots:
		var target: StaticBody3D = slot.get('target')
		if target != null and is_instance_valid(target):
			any_alive = true
			break

	if survived and not failed and any_alive:
		var amount := reward_cash
		if amount <= 0:
			amount = int(gl_DataSet.get_value('reward_perfect_round'))
		gl_PlayerState.dataset.bonus_cash += amount
		var label_target: StaticBody3D = _slots[0].get('target') if _slots.size() > 0 else null
		if label_target and is_instance_valid(label_target):
			var label = label_target.get('money_label_3d')
			if label and label.has_method('print_text'):
				label.print_text(label_target.global_position, '+$%d' % amount)
		print('BonusTargetManager: survived — awarded $%d' % amount)
	else:
		print('BonusTargetManager: no bonus cash')

	cleanup_bonus_round()


func cleanup_bonus_round() -> void:
	_stop_all_patrols()

	for slot in _slots:
		var target: StaticBody3D = slot.get('target')
		if target != null and is_instance_valid(target):
			_stow_target(target)
	_slots.clear()

	for extra in _spawned_extra:
		if extra != null and is_instance_valid(extra):
			_rest_transforms.erase(extra)
			extra.queue_free()
	_spawned_extra.clear()

	active = false


func _start_next_patrol_leg(slot: Dictionary) -> void:
	if not active or failed:
		return
	var target: StaticBody3D = slot.get('target')
	if target == null or not is_instance_valid(target):
		return
	var positions: Array = slot.get('positions', [])
	if positions.size() < 2:
		return

	slot.index = int(slot.get('index', 0) + 1) % positions.size()
	var dest: Vector3 = positions[slot.index]
	target.start_pos = dest

	var old_tween: Tween = slot.get('tween')
	if old_tween and old_tween.is_valid():
		old_tween.kill()

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(target, 'global_position', dest, patrol_seconds_per_leg)
	tween.finished.connect(_on_patrol_leg_finished.bind(slot), CONNECT_ONE_SHOT)
	slot.tween = tween


func _on_patrol_leg_finished(slot: Dictionary) -> void:
	_start_next_patrol_leg(slot)


func _stop_all_patrols() -> void:
	for slot in _slots:
		var tween: Tween = slot.get('tween')
		if tween and tween.is_valid():
			tween.kill()
		slot.tween = null


func _activate_target_at(target: StaticBody3D, row: int, column: int) -> void:
	var pos := _cell_position(row, column)
	target.top_level = true
	target.global_position = pos
	target.start_pos = pos
	target.scale = Vector3.ONE * 1.7
	target.show()

	target.protect_mode = true

	_configure_threat_detection(target)

	if target.has_method('enter_state'):
		target.enter_state(target.State.ACTIVE)
	elif target.has_method('enable_collision'):
		target.enable_collision()
		target.rock_activated = true
	else:
		target.rock_activated = true

	# Bonus target is not a shot-to-score Target — collisions / hits fail the bonus.
	if target.is_in_group('Target'):
		target.remove_from_group('Target')

	var row_letter := 'A'
	match row:
		2:
			row_letter = 'B'
		3:
			row_letter = 'C'
	print('BonusTargetManager: target at %s%d' % [row_letter, column])


func _claim_idle_target() -> StaticBody3D:
	for child in get_children():
		if child is StaticBody3D and not _is_target_in_use(child):
			return child
	return null


func _is_target_in_use(target: StaticBody3D) -> bool:
	for slot in _slots:
		if slot.get('target') == target:
			return true
	return false


func _spawn_extra_target() -> StaticBody3D:
	var target: StaticBody3D = BONUS_TARGET_SCENE.instantiate()
	add_child(target)
	_rest_transforms[target] = target.global_transform
	_spawned_extra.append(target)
	_stow_target(target)
	return target


func _stow_target(target: StaticBody3D) -> void:
	target.protect_mode = false
	if target.has_method('disable_collision'):
		target.disable_collision()
	if target.has_method('stop_all_tweens'):
		target.stop_all_tweens()
	if target.has_method('stop_gentle_pan'):
		target.stop_gentle_pan()
	if _rest_transforms.has(target):
		target.global_transform = _rest_transforms[target]
	target.scale = Vector3.ONE
	target.hide()
	target.rock_activated = false
	if target.has_node('Mesh'):
		target.get_node('Mesh').show()
		target.get_node('Mesh').scale = Vector3.ONE
	if target.is_in_group('Target'):
		target.remove_from_group('Target')


func _configure_threat_detection(target: StaticBody3D) -> void:
	# Rocks live on layer 2; pineapples on layer 9 (256).
	for area_name in ['balloon_area', 'Area3D']:
		var area: Area3D = target.get_node_or_null(area_name) as Area3D
		if area == null and area_name == 'balloon_area':
			area = target.get_node_or_null('%balloon_area') as Area3D
		if area:
			area.set_collision_mask_value(2, true)
			area.set_collision_mask_value(9, true)
			area.monitoring = true


func _cell_position(row: int, column: int) -> Vector3:
	var clamped_col := clampi(column, 1, COLUMN_COUNT)
	var x := COLUMN_1_X + float(clamped_col - 1) * COLUMN_STEP
	var y: float = LANE_Y.get(row, LANE_Y[2])
	return Vector3(x, y, TARGET_Z_FRONT)
