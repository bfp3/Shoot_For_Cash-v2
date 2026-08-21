extends Node

class_name parser

var data_set : Array = []
## "island|range" -> boss timer duration in milliseconds (from `boss-timer`).
var boss_timer_ms_by_range: Dictionary = {}

func loadIslandFile(file_name : String) -> bool:
	var file = FileAccess.open(file_name, FileAccess.READ)
	if file == null:
		push_error("parser: could not open level file '%s'" % file_name)
		return false
	var content := file.get_as_text().strip_edges()
	return loadIsland(content)

func loadIsland(data : String) -> bool:
	data_set.clear()
	boss_timer_ms_by_range.clear()
	
	var ary : Array = data.split("\n", false)
	
	var island_name: String = 'none'
	var range_name: String = 'none'
	var round_no: int = 0 
	var token: String
	var token_list: Array
	
	for ptr in range(0, ary.size()):
		token = ary[ptr]
		token = token.replace('\t', '').strip_edges()

		if token.begins_with('#'):
			# if comment
			token = ''
			
		if token.length() == 0:
			continue
			
		token_list = token.split(' ')
		
		match(token_list[0]):
			
			'island':
				island_name = token_list[1]	

			'range':
				range_name = token_list[1]	
				round_no = 0

			'boss':
				## Bare `boss` heading acts like `range boss`.
				range_name = 'boss'
				round_no = 0

			'round':
				round_no += 1
				
			_:
				## Tabs already stripped above; split on spaces for `boss-timer 60000`.
				var tokens: Array = []
				for p in token.split(" ", false):
					var s := String(p).strip_edges()
					if not s.is_empty():
						tokens.append(s)
				if tokens.is_empty():
					continue
				if String(tokens[0]).to_lower() == 'boss-timer' and tokens.size() > 1:
					var ms := int(tokens[1])
					boss_timer_ms_by_range['%s|%s' % [island_name, range_name]] = maxi(ms, 0)
					continue
				if round_no > 0:
					data_set.push_back( [island_name,range_name,round_no,sanitise_token(token)] )
					
				
	return(true)
	
	
func sanitise_token(s: String) -> String:
	var ary:Array = s.split(' ')
	ary = ary.filter( func(_name: String): return _name.length() > 0) 
	return ' '.join(ary)
	
	
func getRound(island_name : String, range_name : String, round_no : int) -> Array:
	var ary: Array
	for i:int in range(0,data_set.size()):
		if data_set[i][0] == island_name:
			if data_set[i][1] == range_name:
				if data_set[i][2] == round_no:
					ary.push_back(data_set[i][3])
	return ary


## Boss survival duration in milliseconds for an island/range (0 if unset).
func get_boss_timer_ms(island_name: String, range_name: String = "boss") -> int:
	return int(boss_timer_ms_by_range.get("%s|%s" % [island_name, range_name], 0))


## Parses a single spawn line into a spawn dictionary.
## Targets — rock / rock-black / rock-pigeon / rock-avoider / rock-chaser / smokecan / pineapple / red_rock_error:
##   {cmd, column, aim_row, aim_column, param}. `?` or omit = random slot (RANDOM_SLOT / -1).
##   Unspecified aim row defaults to A; unspecified aim column stays random.
##   `rock` = `rock ? ?`. `rock 2` = `rock 2 ?`. `rock ? A4` / `rock 2 A4` OK.
##   `rock A4` is invalid — column must be a number or `?` before the aim cell.
## balloon: {cmd, row, column, param} — bare / `?` → random cell; `balloon A1` → fixed.
## wait: {cmd} — hold until the sky is clear (same as old `wait until clear`).
## wait 0 / wait 600: {cmd, ms} — delay that many milliseconds before the next rock.
## wait until clear / wait-until-clear: still accepted as an alias of bare `wait`.
##   Hold the next command until live rocks / pineapples / smokecans / balloon-checks
##   / bonus targets are gone. Oranges and regular balloons are ignored. A miss
##   does not skip this wait. Objects count as gone as soon as their destroy
##   process starts (do not wait for pop tweens).
## balloon-check / balloon check / balloon-check A4: {cmd, row, column}.
##   Bare command uses the default centre rest pose. A cell parks it on the balloon grid.
##   Shooting it saves this script cursor as the resume point after a strike-out.
##   It does not jump rounds, reset strikes, or send leftover balloons away.
##   `checkpoint` is accepted as an alias.
##   If no balloon-check has been shot, fail restarts the range from the beginning.
## ammo / ammo 16 / ammo 69 $100 / ammo C8 / ammo C8 16 99:
##   {cmd, row, column, amount, price}. Bare parks at C6.
##   Amount omitted → power_ammo. Price omitted → price_ammo.
##   `$N` or a second number is the cash cost. Distinct from `clear ammo`.
## clear: {cmd} — send all live round balloons away (+$10 each). Does not pop
##   a balloon-check. `wait clear` is still wait-until-clear, not this command.
## clear balloon A4: {cmd: clear-balloon, row, column} — same drift/pay for one cell.
## clear ammo: {cmd: clear-ammo} — pop leftover ammo balloons with no ammo and no charge.
## repeat: {cmd, count} — closes a wave section that plays as `count` separate waves.
##   Bare `repeat` / `repeat 1` / `repeat 2` → 2 waves. `repeat N` (N ≥ 2) → N waves.
##   Commands after a `repeat` start the next section / next set of waves.
##   Example: `rock 2` / `repeat 3` / `rock 4` / `repeat 2` → 5 waves total.
## no-lives: {cmd} — this round only; missed rocks do not award strikes.
## pineapples: {cmd} — this round only; if you still have no strikes when the
##   last rock is shot, a pineapple bonus round starts before balloon-check.
##   Distinct from the `pineapple` spawn command.
## strikes N: {cmd, count} — this round only; player can take N strikes (default 3).
##   Example: `strikes 5`.
## music-start Name / music-stop Name: {cmd, name} — play or fade-out (3s) a child
##   AudioStreamPlayer under the main scene `$Music` node (e.g. `Opening_song`).
## difficulty-easy / difficulty-normal / difficulty-hard / difficulty-expert:
##   stored on the range as `difficulty`. Gravity: easy 0.5, normal 1.0, hard 1.5, expert 2.25.
##   hard / expert also set bullet travel to 0.1. `difficulty hard` form is accepted.
## shuffle: {cmd} — this round only; later waves randomise rock columns.
## surprise-me: {cmd} — replace this round's spawns with a random generated sequence.
## bonus-type1 / bonus type1: marks the round as bonus type 1 (no strikes).
## bonus-target / bonus-target a4 a8 c1: each line is one bonus target with its own path.
##   Bare `bonus-target` → stay still at B4. Cells listed → that target loops those cells.
##   Multiple `bonus-target` lines → multiple active targets in the same round.
## Unknown commands become red_rock_error so bad editor lines are visible in-game.
## Commands and row letters are case-insensitive.
func parse_spawn_command(token: String) -> Dictionary:
	var parts: PackedStringArray = token.split(' ', false)
	if parts.is_empty():
		return {}

	var cmd: String = String(parts[0]).to_lower()
	match cmd:
		'rock', 'rock-black', 'rock-pigeon', 'rock-avoider', 'rock-chaser', 'red_rock_error', 'smokecan':
			return _parse_rock_command(cmd, parts)

		'pineapple':
			# Same `?` / default-random rules as other targets (no forced column 1).
			return _parse_rock_command(cmd, parts)

		'balloon':
			if parts.size() > 1 and String(parts[1]).strip_edges().to_lower() == 'check':
				return _parse_balloon_check_command(parts)
			return _parse_balloon_command(parts)

		'balloon-check':
			return _parse_balloon_check_command(parts)

		'ammo':
			return _parse_ammo_command(parts)

		'clear':
			return _parse_clear_command(parts)

		'bonus-target':
			return _parse_bonus_target_command(parts)

		'wait':
			return _parse_wait_command(parts)

		'wait-until-clear':
			return {'cmd': 'wait-until-clear'}

		'checkpoint':
			return _parse_balloon_check_command(parts)

		'boss-timer':
			## Duration for boss survival rounds (milliseconds). Handled while loading the file.
			return {'cmd': 'boss-timer', 'ms': int(parts[1]) if parts.size() > 1 else 0}

		'repeat':
			return _parse_repeat_command(parts)

		'no-lives':
			return {'cmd': 'no-lives'}

		'pineapples':
			return {'cmd': 'pineapples'}

		'strikes':
			var strike_count := 3
			if parts.size() > 1:
				strike_count = maxi(int(parts[1]), 1)
			return {'cmd': 'strikes', 'count': strike_count}

		'music-start':
			var start_name := String(parts[1]).strip_edges() if parts.size() > 1 else ''
			return {'cmd': 'music-start', 'name': start_name}

		'music-stop':
			var stop_name := String(parts[1]).strip_edges() if parts.size() > 1 else ''
			return {'cmd': 'music-stop', 'name': stop_name}
		
		'difficulty-easy':
			return {'cmd': 'difficulty-easy'}
		
		'difficulty-normal':
			return {'cmd': 'difficulty-normal'}
		
		'difficulty-hard':
			return {'cmd': 'difficulty-hard'}

		'difficulty-expert':
			return {'cmd': 'difficulty-expert'}

		'difficulty':
			if parts.size() > 1:
				var level := String(parts[1]).strip_edges().to_lower()
				if level.begins_with('difficulty-'):
					level = level.substr(11)
				return {'cmd': 'difficulty-%s' % level}
			push_warning("parser: 'difficulty' needs easy, normal, hard, or expert")
			return {'cmd': 'difficulty-hard'}

		'shuffle':
			return {'cmd': 'shuffle'}

		'surprise-me':
			return {'cmd': 'surprise-me'}

		'bonus-type1':
			return {'cmd': 'bonus-type1'}

		'bonus':
			# `bonus type1` → same as `bonus-type1` (subtype after bonus).
			if parts.size() > 1:
				var subtype := String(parts[1]).strip_edges().to_lower()
				if subtype.begins_with('bonus-'):
					subtype = subtype.substr(6)
				return {'cmd': 'bonus-%s' % subtype}
			push_warning("parser: 'bonus' needs a subtype (e.g. bonus-type1) — using red_rock_error")
			return {
				'cmd': 'red_rock_error',
				'column': 3,
				'aim_row': 3,
				'aim_column': 3,
				'param': token,
			}

		_:
			# Future `bonus-<type>` keywords are round markers, not spawns.
			if cmd.begins_with('bonus-') and cmd.length() > 6:
				return {'cmd': cmd}

			push_warning("parser: unknown spawn command '%s' — using red_rock_error" % token)
			return {
				'cmd': 'red_rock_error',
				'column': 3,
				'aim_row': 3,
				'aim_column': 3,
				'param': token,
			}


const DEFAULT_ROUND_REPEAT := 1
const DEFAULT_WAIT_MS := 1000
## Sentinel: leave spawn column / aim cell / balloon cell to the game at launch time.
const RANDOM_SLOT := -1


func _is_random_token(token: String) -> bool:
	return token.strip_edges() == '?'


## rock / rock-black / rock-pigeon / rock-avoider / rock-chaser / smokecan / pineapple / red_rock_error
##   rock          → rock ? ?   (random column, aim row A + random aim column)
##   rock 2        → rock 2 ?   (column 2, aim row A + random aim column)
##   rock ? A4     → random column, aim A4
##   rock 2 A4     → column 2, aim A4
##   rock ? ?      → explicit both-random
##   rock A4       → red_rock_error (must write `rock ? A4`)
func _parse_rock_command(cmd: String, parts: PackedStringArray) -> Dictionary:
	var result := {
		'cmd': cmd,
		'column': RANDOM_SLOT,
		'aim_row': RANDOM_SLOT,
		'aim_column': RANDOM_SLOT,
		'param': '',
	}

	if parts.size() <= 1:
		return result

	var token1 := String(parts[1]).strip_edges()
	if _is_random_token(token1):
		result.column = RANDOM_SLOT
	elif token1.is_valid_int():
		result.column = int(token1)
	else:
		# Aim cell as first arg (`rock A4`) is invalid — require `rock ? A4`.
		if not _parse_balloon_cell(token1).is_empty():
			push_warning("parser: '%s' needs column or '?' before aim (use '%s ? %s')" % [
				' '.join(parts), cmd, token1,
			])
			return {
				'cmd': 'red_rock_error',
				'column': 3,
				'aim_row': 3,
				'aim_column': 3,
				'param': ' '.join(parts),
			}
		result.param = token1
		return result

	if parts.size() <= 2:
		# `rock 2` / `rock ?` — aim stays random.
		return result

	var token2 := String(parts[2]).strip_edges()
	if _is_random_token(token2):
		result.aim_row = RANDOM_SLOT
		result.aim_column = RANDOM_SLOT
	else:
		var aim := _parse_balloon_cell(token2)
		if not aim.is_empty():
			result.aim_row = aim.row
			result.aim_column = aim.column
		else:
			result.param = token2

	return result


## Bare `wait` → wait until clear. `wait 600` → 600ms. `wait until` still works.
## Values below 0 clamp to 0.
func _parse_wait_command(parts: PackedStringArray) -> Dictionary:
	if parts.size() <= 1:
		return {'cmd': 'wait-until-clear'}
	var token := String(parts[1]).strip_edges().to_lower()
	if token == 'until' or token == 'until-clear' or token == 'clear':
		return {'cmd': 'wait-until-clear'}
	if token.is_valid_int():
		return {
			'cmd': 'wait',
			'ms': maxi(int(token), 0),
		}
	return {'cmd': 'wait-until-clear'}


## Wave-section count. Bare / 1 / 2 → 2 waves of that section. `repeat N` (N ≥ 2) → N waves.
func _parse_repeat_command(parts: PackedStringArray) -> Dictionary:
	var count := 2
	if parts.size() > 1 and String(parts[1]).is_valid_int():
		count = maxi(int(parts[1]), 2)
	return {
		'cmd': 'repeat',
		'count': count,
	}


## clear / clear balloon A4 / clear ammo. Bare `clear` = all live round balloons.
## `clear balloon A4` = only that cell (no-op if empty). Does not pop a balloon-check.
## `clear ammo` = pop leftover ammo balloons with no ammo and no charge.
func _parse_clear_command(parts: PackedStringArray) -> Dictionary:
	var result := {
		'cmd': 'clear',
		'row': RANDOM_SLOT,
		'column': RANDOM_SLOT,
	}
	var i := 1
	if i < parts.size():
		var next := String(parts[i]).strip_edges().to_lower()
		if next == 'ammo':
			return {'cmd': 'clear-ammo'}
		if next == 'balloon':
			result.cmd = 'clear-balloon'
			i += 1
	if i < parts.size():
		var parsed_cell := _parse_balloon_cell(String(parts[i]).strip_edges())
		if not parsed_cell.is_empty():
			result.cmd = 'clear-balloon'
			result.row = parsed_cell.row
			result.column = parsed_cell.column
	return result


## balloon-check / balloon check / checkpoint, optional cell (A4). Bare = default rest pose.
func _parse_balloon_check_command(parts: PackedStringArray) -> Dictionary:
	var result := {
		'cmd': 'balloon-check',
		'row': RANDOM_SLOT,
		'column': RANDOM_SLOT,
	}
	for i in range(1, parts.size()):
		var token := String(parts[i]).strip_edges()
		if token.to_lower() == 'check':
			continue
		var parsed_cell := _parse_balloon_cell(token)
		if not parsed_cell.is_empty():
			result.row = parsed_cell.row
			result.column = parsed_cell.column
			break
	return result


const DEFAULT_AMMO_ROW := 3
const DEFAULT_AMMO_COLUMN := 6


## ammo / ammo 16 / ammo 69 $100 / ammo C8 / ammo C8 16 99
## Default cell C6. First integer = ammo amount. `$N` or second integer = price.
## Omitted amount/price stay -1 so gameplay uses power_ammo / price_ammo.
func _parse_ammo_command(parts: PackedStringArray) -> Dictionary:
	var result := {
		'cmd': 'ammo',
		'row': DEFAULT_AMMO_ROW,
		'column': DEFAULT_AMMO_COLUMN,
		'amount': -1,
		'price': -1,
	}
	for i in range(1, parts.size()):
		var token := String(parts[i]).strip_edges()
		if token.is_empty():
			continue
		var cell := _parse_balloon_cell(token)
		if not cell.is_empty():
			result.row = cell.row
			result.column = cell.column
			continue
		var price := _parse_money_token(token)
		if price >= 0:
			result.price = price
			continue
		if token.is_valid_int():
			var value := int(token)
			if int(result.amount) < 0:
				result.amount = value
			elif int(result.price) < 0:
				result.price = value
	return result


func _parse_money_token(token: String) -> int:
	var t := token.strip_edges()
	if t.begins_with('$'):
		t = t.substr(1).strip_edges()
		if t.is_valid_int():
			return maxi(int(t), 0)
	return -1


## balloon → balloon ? (random cell). balloon A1 / a1 → that cell. balloon ? → random.
## Extra trailing params are stored on 'param' and ignored by gameplay.
func _parse_balloon_command(parts: PackedStringArray) -> Dictionary:
	var result := {
		'cmd': 'balloon',
		'row': RANDOM_SLOT,
		'column': RANDOM_SLOT,
		'param': '',
	}

	if parts.size() <= 1:
		return result

	var cell := String(parts[1]).strip_edges()
	if _is_random_token(cell):
		return result

	var parsed_cell := _parse_balloon_cell(cell)
	if not parsed_cell.is_empty():
		result.row = parsed_cell.row
		result.column = parsed_cell.column
		if parts.size() > 2:
			result.param = parts[2]
		return result

	# Separate tokens: balloon A 1
	if parts.size() > 2:
		var row_token := String(parts[1]).strip_edges().to_upper()
		var col_token := String(parts[2]).strip_edges()
		if _is_random_token(row_token) or _is_random_token(col_token):
			# Partial wildcards → whole cell random.
			return result
		if _balloon_row_letter_to_index(row_token) > 0 and col_token.is_valid_int():
			result.row = _balloon_row_letter_to_index(row_token)
			result.column = clampi(int(col_token), 1, 8)
			if parts.size() > 3:
				result.param = parts[3]
			return result

	# Unrecognised placement — keep random default, stash text for later.
	result.param = cell
	if parts.size() > 2:
		result.param = ' '.join(parts.slice(1))
	push_warning("parser: could not parse balloon placement '%s', defaulting to random" % cell)
	return result


## bonus-target → stay still (empty waypoints). bonus-target a4 a8 c1 → patrol those cells.
func _parse_bonus_target_command(parts: PackedStringArray) -> Dictionary:
	var result := {
		'cmd': 'bonus-target',
		'waypoints': [],
	}

	for i in range(1, parts.size()):
		var token := String(parts[i]).strip_edges()
		if token.is_empty() or _is_random_token(token):
			continue
		var cell := _parse_balloon_cell(token)
		if cell.is_empty():
			push_warning("parser: bonus-target ignored invalid cell '%s'" % token)
			continue
		result.waypoints.append(cell)

	return result


## Parses "A1", "b3", "C8" into {row, column}. Returns {} on failure.
func _parse_balloon_cell(cell: String) -> Dictionary:
	if cell.length() < 2:
		return {}

	var row := _balloon_row_letter_to_index(cell.substr(0, 1))
	if row <= 0:
		return {}

	var col_str := cell.substr(1)
	if not col_str.is_valid_int():
		return {}

	var column := int(col_str)
	if column < 1 or column > 8:
		return {}

	return {'row': row, 'column': column}


func _balloon_row_letter_to_index(letter: String) -> int:
	match letter.to_upper():
		'A':
			return 1
		'B':
			return 2
		'C':
			return 3
		_:
			return 0


## Parse freeform level-editor text as a single round under island/range `test`.
## Caller text is the body of the round (rock, wait, repeat, etc.).
## Returns { "spawns": [...], "repeat": int }. Empty spawns if nothing parsed.
func parse_round_text(text: String) -> Dictionary:
	var body := text.strip_edges()
	var wrapped := "island test\nrange test\nround\n"
	if body != "":
		wrapped += body + "\n"

	# Don't clobber the live island-shipper dataset.
	var backup: Array = data_set.duplicate(true)
	loadIsland(wrapped)
	var sequences: Array = get_rock_sequences("test")
	data_set = backup

	if sequences.is_empty():
		return {
			"spawns": [],
			"repeat": DEFAULT_ROUND_REPEAT,
			"no_lives": false,
			"bonus": "",
			"bonus_targets": [],
			"shuffle": false,
			"pineapples": false,
			"difficulty": "",
			"max_strikes": 3,
		}
	return sequences[0]


## Builds one sequence dict per shooting range (all `round` headings in that range
## are merged). File order is kept.
## { "spawns": [...], "repeat": wave_count, "no_lives": bool, "bonus": ""|"type1"|...,
##   "bonus_targets": [{ "waypoints": [{row, column}, ...] }, ...], "shuffle": bool,
##   "pineapples": bool }
## Pass an empty island_name to include every island in the loaded file.
## Pass range_name (e.g. "moss", "redd") to only include that shooting range.
func get_rock_sequences(island_name: String = '', range_name: String = '') -> Array:
	var rounds: Dictionary = {}
	var order: Array = []

	for entry in data_set:
		if island_name != '' and entry[0] != island_name:
			continue
		if range_name != '' and entry[1] != range_name:
			continue

		var key := '%s|%s' % [entry[0], entry[1]]
		if not rounds.has(key):
			rounds[key] = {
				'spawns': [],
				'repeat': DEFAULT_ROUND_REPEAT,
				'no_lives': false,
				'bonus': '',
				'bonus_targets': [],
				'shuffle': false,
				'pineapples': false,
				'surprise': false,
				'difficulty': '',
				'max_strikes': 3,
				# Temporary while parsing — removed by `_finalize_round_repeats`.
				'_pending': [],
				'_sections': [],
			}
			order.append(key)

		var parsed := parse_spawn_command(entry[3])
		if parsed.is_empty():
			continue

		var parsed_cmd := String(parsed.get('cmd', ''))
		if parsed_cmd == 'repeat':
			var section_spawns: Array = rounds[key]._pending
			rounds[key]._sections.append({
				'spawns': section_spawns,
				'count': int(parsed.get('count', DEFAULT_ROUND_REPEAT)),
			})
			rounds[key]._pending = []
			continue

		if parsed_cmd == 'no-lives':
			rounds[key].no_lives = true
			continue

		if parsed_cmd == 'strikes':
			rounds[key].max_strikes = maxi(int(parsed.get('count', 3)), 1)
			continue

		if parsed_cmd == 'pineapples':
			rounds[key].pineapples = true
			rounds[key]._pending.append(parsed)
			continue

		if parsed_cmd == 'music-start' or parsed_cmd == 'music-stop':
			# Mid-round cues — stay in the spawn timeline like ammo / pineapples.
			rounds[key]._pending.append(parsed)
			continue

		if parsed_cmd == 'difficulty-hard':
			if String(rounds[key].get('difficulty', '')) != 'expert':
				rounds[key].difficulty = 'hard'
			continue

		if parsed_cmd == 'difficulty-expert':
			rounds[key].difficulty = 'expert'
			continue

		if parsed_cmd.begins_with('difficulty-') and parsed_cmd.length() > 11:
			var level := parsed_cmd.substr(11)
			if level == 'expert' or String(rounds[key].get('difficulty', '')) != 'expert':
				rounds[key].difficulty = level
			continue

		if parsed_cmd == 'boss-timer':
			var ms := int(parsed.get('ms', 0))
			boss_timer_ms_by_range['%s|%s' % [entry[0], entry[1]]] = maxi(ms, 0)
			continue

		if parsed_cmd == 'shuffle':
			rounds[key].shuffle = true
			continue

		if parsed_cmd == 'surprise-me':
			rounds[key].surprise = true
			continue

		if parsed_cmd == 'bonus-target':
			var waypoints: Array = parsed.get('waypoints', [])
			# Each `bonus-target` line is its own target with its own path.
			rounds[key].bonus_targets.append({
				'waypoints': waypoints.duplicate(true),
			})
			continue

		# Round markers like `bonus-type1` — must not catch `bonus-target` (handled above).
		if parsed_cmd.begins_with('bonus-') and parsed_cmd.length() > 6 and parsed_cmd != 'bonus-target':
			var bonus_type := parsed_cmd.substr(6)
			rounds[key].bonus = bonus_type
			rounds[key].no_lives = true
			continue

		rounds[key]._pending.append(parsed)

	var sequences: Array = []
	for key in order:
		_finalize_round_repeats(rounds[key])
		if bool(rounds[key].get('surprise', false)):
			_apply_surprise_me(rounds[key])
		_finalize_bonus_round(rounds[key])
		sequences.append(rounds[key])
	return sequences


## Resolves `repeat` markers into a per-wave spawn list.
## Each `repeat N` closes a section: that section's commands play as N separate waves.
## Trailing commands with no closing `repeat` play as 1 wave.
## Example: rock 2 / repeat 3 / rock 4 / repeat 2 → 5 waves.
func _finalize_round_repeats(round_data: Dictionary) -> void:
	var sections: Array = round_data.get('_sections', [])
	var pending: Array = round_data.get('_pending', [])
	round_data.erase('_sections')
	round_data.erase('_pending')
	round_data.erase('_wave_repeat')

	if not pending.is_empty():
		sections.append({
			'spawns': pending,
			'count': 1,
		})

	if sections.is_empty():
		round_data.waves = []
		round_data.spawns = []
		round_data.repeat = DEFAULT_ROUND_REPEAT
		return

	var waves: Array = []
	for section in sections:
		var body: Array = section.get('spawns', [])
		var times := maxi(int(section.get('count', 1)), 1)
		for _i in times:
			var wave_copy: Array = []
			for entry in body:
				if entry is Dictionary:
					wave_copy.append(entry.duplicate(true))
				else:
					wave_copy.append(entry)
			waves.append(wave_copy)

	round_data.waves = waves
	round_data.repeat = maxi(waves.size(), 1)
	# Compat: code that still reads `spawns` gets wave 1's content.
	round_data.spawns = waves[0].duplicate(true) if not waves.is_empty() else []


## Rebuild `waves` from flat `spawns` × `repeat` (used after surprise-me).
func _rebuild_waves_from_flat_spawns(round_data: Dictionary) -> void:
	var spawns: Array = round_data.get('spawns', [])
	var times := maxi(int(round_data.get('repeat', DEFAULT_ROUND_REPEAT)), 1)
	var waves: Array = []
	for _i in times:
		var wave_copy: Array = []
		for entry in spawns:
			if entry is Dictionary:
				wave_copy.append(entry.duplicate(true))
			else:
				wave_copy.append(entry)
		waves.append(wave_copy)
	round_data.waves = waves
	round_data.repeat = times


## Fills a round with a random rock/wait/balloon mix for testing.
func _apply_surprise_me(round_data: Dictionary) -> void:
	var spawns: Array = []
	var rock_count := randi_range(5, 12)

	# Optional intro balloon(s).
	if randf() < 0.35:
		var balloon_count := randi_range(1, 3)
		for _i in balloon_count:
			spawns.append({
				'cmd': 'balloon',
				'row': randi_range(1, 3),
				'column': randi_range(1, 8),
				'param': '',
			})

	for i in rock_count:
		if i > 0 and randf() < 0.5:
			spawns.append({
				'cmd': 'wait',
				'ms': [100, 200, 300, 400, 500, 750, 1000][randi() % 7],
			})

		var roll := randf()
		var cmd := 'rock'
		if roll < 0.55:
			cmd = 'rock'
		elif roll < 0.72:
			cmd = 'rock-black'
		elif roll < 0.88:
			cmd = 'rock-pigeon'
		elif roll < 0.95:
			cmd = 'smokecan'
		else:
			cmd = 'pineapple'

		var entry := {
			'cmd': cmd,
			'column': RANDOM_SLOT,
			'aim_row': RANDOM_SLOT,
			'aim_column': RANDOM_SLOT,
			'param': '',
		}

		if cmd == 'pineapple':
			if randf() < 0.55:
				entry.column = randi_range(1, 8)
			if randf() < 0.45:
				entry.aim_row = 1
				entry.aim_column = randi_range(1, 8)
		elif randf() < 0.55:
			entry.column = randi_range(1, 8)
			if randf() < 0.55:
				entry.aim_row = 1
				entry.aim_column = randi_range(1, 8)
		elif randf() < 0.35:
			# Aim with random column (`rock ? A8`).
			entry.aim_row = 1
			entry.aim_column = randi_range(1, 8)

		spawns.append(entry)

		# Occasional mid-round balloon after a rock.
		if cmd != 'pineapple' and randf() < 0.08:
			spawns.append({
				'cmd': 'balloon',
				'row': randi_range(1, 3),
				'column': randi_range(1, 8),
				'param': '',
			})

	round_data.spawns = spawns

	# Keep an explicit `repeat` if the author set one; otherwise sometimes add extras.
	if int(round_data.get('repeat', DEFAULT_ROUND_REPEAT)) == DEFAULT_ROUND_REPEAT and randf() < 0.7:
		round_data.repeat = randi_range(1, 4)

	if randf() < 0.35:
		round_data.shuffle = true
	if randf() < 0.25:
		round_data.no_lives = true

	_rebuild_waves_from_flat_spawns(round_data)
	print('parser: surprise-me generated:\n%s' % surprise_round_to_text(round_data))


## Pretty-print a round dict back to level-script lines (for console / debugging).
func surprise_round_to_text(round_data: Dictionary) -> String:
	var lines: PackedStringArray = []
	if bool(round_data.get('no_lives', false)):
		lines.append('no-lives')
	if bool(round_data.get('shuffle', false)):
		lines.append('shuffle')
	var max_strikes := int(round_data.get('max_strikes', 3))
	if max_strikes != 3:
		lines.append('strikes %d' % max_strikes)
	var difficulty := String(round_data.get('difficulty', ''))
	if not difficulty.is_empty():
		lines.append('difficulty-%s' % difficulty)

	# Prefer structured waves when present (multi-section rounds).
	var waves: Array = round_data.get('waves', [])
	if waves is Array and waves.size() > 1:
		# Collapse identical consecutive waves into `… / repeat N`.
		var i := 0
		while i < waves.size():
			var body: Array = waves[i]
			var run := 1
			while i + run < waves.size() and _wave_bodies_equal(body, waves[i + run]):
				run += 1
			for entry in body:
				if entry is Dictionary:
					lines.append(_spawn_entry_to_line(entry))
			if run == 2:
				lines.append('repeat')
			elif run > 2:
				lines.append('repeat %d' % run)
			i += run
		return '\n'.join(lines)

	var wave_count := int(round_data.get('repeat', DEFAULT_ROUND_REPEAT))
	for entry in round_data.get('spawns', []):
		if entry is Dictionary:
			lines.append(_spawn_entry_to_line(entry))
	if wave_count >= 2:
		if wave_count == 2:
			lines.append('repeat')
		else:
			lines.append('repeat %d' % wave_count)
	return '\n'.join(lines)


func _wave_bodies_equal(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for idx in a.size():
		if str(a[idx]) != str(b[idx]):
			return false
	return true


func _spawn_entry_to_line(entry: Dictionary) -> String:
	var cmd := String(entry.get('cmd', ''))
	match cmd:
		'wait':
			return 'wait %d' % int(entry.get('ms', DEFAULT_WAIT_MS))
		'wait-until-clear':
			return 'wait'
		'pineapples':
			return 'pineapples'
		'balloon-check', 'checkpoint':
			var crow := int(entry.get('row', RANDOM_SLOT))
			var ccol := int(entry.get('column', RANDOM_SLOT))
			if crow < 1 or ccol < 1:
				return 'balloon-check'
			var check_letter = ['', 'A', 'B', 'C'][clampi(crow, 1, 3)]
			return 'balloon-check %s%d' % [check_letter, ccol]
		'ammo':
			var bits: PackedStringArray = ['ammo']
			var arow := int(entry.get('row', DEFAULT_AMMO_ROW))
			var acol := int(entry.get('column', DEFAULT_AMMO_COLUMN))
			if arow != DEFAULT_AMMO_ROW or acol != DEFAULT_AMMO_COLUMN:
				var ammo_letter = ['', 'A', 'B', 'C'][clampi(arow, 1, 3)]
				bits.append('%s%d' % [ammo_letter, acol])
			var ammo_amount := int(entry.get('amount', -1))
			if ammo_amount >= 0:
				bits.append(str(ammo_amount))
			var ammo_price := int(entry.get('price', -1))
			if ammo_price >= 0:
				bits.append('$%d' % ammo_price)
			return ' '.join(bits)
		'clear':
			return 'clear'
		'clear-ammo':
			return 'clear ammo'
		'clear-balloon':
			var clrow := int(entry.get('row', RANDOM_SLOT))
			var clcol := int(entry.get('column', RANDOM_SLOT))
			if clrow < 1 or clcol < 1:
				return 'clear balloon'
			var clear_letter = ['', 'A', 'B', 'C'][clampi(clrow, 1, 3)]
			return 'clear balloon %s%d' % [clear_letter, clcol]
		'balloon':
			var brow := int(entry.get('row', RANDOM_SLOT))
			var bcol := int(entry.get('column', RANDOM_SLOT))
			if brow < 1 or bcol < 1:
				return 'balloon ?'
			var row_letter = ['', 'A', 'B', 'C'][clampi(brow, 1, 3)]
			return 'balloon %s%d' % [row_letter, bcol]
		'pineapple', 'rock', 'rock-black', 'rock-pigeon', 'rock-avoider', 'rock-chaser', 'smokecan', 'red_rock_error':
			var col := int(entry.get('column', RANDOM_SLOT))
			var ar := int(entry.get('aim_row', RANDOM_SLOT))
			var ac := int(entry.get('aim_column', RANDOM_SLOT))
			var col_token := '?' if col < 1 else str(col)
			if ar > 0 and ac > 0:
				var aim := '%s%d' % [['', 'A', 'B', 'C'][clampi(ar, 1, 3)], ac]
				return '%s %s %s' % [cmd, col_token, aim]
			if col < 1:
				return cmd
			return '%s %s' % [cmd, col_token]
		_:
			return cmd


## Bonus rounds with parse errors become a single red_rock_error.
## `bonus-type1` may have zero rock spawns (target-only rounds are valid).
func _finalize_bonus_round(round_data: Dictionary) -> void:
	var bonus := String(round_data.get('bonus', ''))
	var has_targets = not round_data.get('bonus_targets', []).is_empty()
	if bonus == '':
		# bonus-target outside a bonus-type1 round is an error marker.
		if has_targets:
			round_data.bonus_targets = []
			round_data.spawns = [_make_bonus_error_spawn('bonus-target without bonus-type1')]
		return

	# Unknown bonus subtypes are treated as errors until implemented.
	if bonus != 'type1':
		round_data.spawns = [_make_bonus_error_spawn('bonus-%s' % bonus)]
		round_data.bonus_targets = []
		return

	# Target-only rounds (no rocks) are allowed — bonus targets still patrol.
	var spawns: Array = round_data.get('spawns', [])
	for entry in spawns:
		if entry is Dictionary and String(entry.get('cmd', '')).to_lower() == 'red_rock_error':
			round_data.spawns = [_make_bonus_error_spawn(String(entry.get('param', 'bonus-%s' % bonus)))]
			round_data.bonus_targets = []
			return


func _make_bonus_error_spawn(param: String) -> Dictionary:
	return {
		'cmd': 'red_rock_error',
		'column': 3,
		'aim_row': 3,
		'aim_column': 3,
		'param': param,
	}


func getWaves():
	var cmd_list: Array = getRound('shipper', 'moss', 1)
	if cmd_list.is_empty():
		return {}

	return parse_spawn_command(cmd_list[0])


func getCommand(_str : String) -> Dictionary:
	var result = {'cmd':'', 'target':'', 'params':''}
	
	var ary = _str.split(' ', false)
	result.cmd = ary[0]
	if ary.size() > 1:
		result.target = ary[1]
	
	if ary.size() > 2:
		result.params = ary[2]
			
	return result


# --- Round editor file helpers (island-shipper.txt surgical edit) ---------------

func _file_line_token(line: String) -> String:
	return line.replace("\t", "").strip_edges()


func _is_range_header(token: String, range_name: String = "") -> bool:
	if token == "boss" or token.begins_with("boss "):
		return range_name.is_empty() or range_name == "boss"
	if token.begins_with("range "):
		var parts := token.split(" ", false)
		if parts.size() < 2:
			return false
		return range_name.is_empty() or String(parts[1]).to_lower() == range_name.to_lower()
	return false


func _range_name_from_header(token: String) -> String:
	if token == "boss" or token.begins_with("boss "):
		return "boss"
	if token.begins_with("range "):
		var parts := token.split(" ", false)
		if parts.size() >= 2:
			return String(parts[1]).to_lower()
	return ""


## Ordered range names found in a level file (e.g. moss, redd, …).
func list_ranges_in_file(file_path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return out
	var lines := file.get_as_text().split("\n")
	for raw in lines:
		var token := _file_line_token(String(raw))
		if token.is_empty() or token.begins_with("#"):
			continue
		if _is_range_header(token):
			var name := _range_name_from_header(token)
			if not name.is_empty() and not out.has(name):
				out.append(name)
	return out


func file_has_range(file_path: String, range_name: String) -> bool:
	range_name = range_name.to_lower()
	for name in list_ranges_in_file(file_path):
		if String(name).to_lower() == range_name:
			return true
	return false


## How many `round` headings exist under a range in the file.
func count_rounds_in_file(file_path: String, range_name: String) -> int:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return 0
	var lines := file.get_as_text().split("\n")
	var in_range := false
	var count := 0
	range_name = range_name.to_lower()
	for raw in lines:
		var token := _file_line_token(String(raw))
		if token.is_empty():
			continue
		if token.begins_with("island "):
			in_range = false
			continue
		if _is_range_header(token):
			in_range = _range_name_from_header(token) == range_name
			continue
		if not in_range:
			continue
		if token == "round":
			count += 1
	return count


## Inclusive header index + exclusive end index for a round body inside `lines`.
## Returns Vector2i(-1, -1) if missing.
func _find_round_span(lines: PackedStringArray, range_name: String, round_no: int) -> Vector2i:
	range_name = range_name.to_lower()
	var in_range := false
	var seen := 0
	var header := -1
	for i in lines.size():
		var token := _file_line_token(String(lines[i]))
		if token.begins_with("island "):
			if header >= 0:
				return Vector2i(header, i)
			in_range = false
			continue
		if _is_range_header(token):
			if header >= 0:
				return Vector2i(header, i)
			in_range = _range_name_from_header(token) == range_name
			continue
		if not in_range:
			continue
		if token == "round":
			seen += 1
			if header >= 0:
				return Vector2i(header, i)
			if seen == round_no:
				header = i
	if header >= 0:
		return Vector2i(header, lines.size())
	return Vector2i(-1, -1)


## Raw round body for the TextEdit (tabs stripped from each line; blanks kept).
func get_raw_round_body(file_path: String, range_name: String, round_no: int) -> String:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return ""
	var lines := file.get_as_text().split("\n")
	var span := _find_round_span(lines, range_name, round_no)
	if span.x < 0:
		return ""
	var body_lines: PackedStringArray = []
	for i in range(span.x + 1, span.y):
		var raw := String(lines[i])
		var token := _file_line_token(raw)
		## Stop early if a new range somehow appears without matching end logic.
		if _is_range_header(token) or token.begins_with("island "):
			break
		## Preserve blank lines; strip leading tabs from commands/comments.
		if raw.strip_edges().is_empty():
			body_lines.append("")
		else:
			body_lines.append(raw.lstrip("\t"))
	## Trim trailing blank lines for a cleaner editor default.
	while body_lines.size() > 0 and String(body_lines[body_lines.size() - 1]).strip_edges().is_empty():
		body_lines.remove_at(body_lines.size() - 1)
	return "\n".join(body_lines)


## Apply many round body edits in one write.
## `edits`: Array of { "range": String, "round": int, "body": String }
func write_round_edits(file_path: String, edits: Array) -> bool:
	if edits.is_empty():
		return true
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("parser: could not open '%s' for round edit" % file_path)
		return false
	var text := file.get_as_text()
	## Preserve whether the original ended with a trailing newline.
	var had_trailing_nl := text.ends_with("\n")
	var lines: PackedStringArray = text.split("\n")
	## split() keeps a trailing empty element when text ends with \n — drop it for editing.
	if had_trailing_nl and lines.size() > 0 and String(lines[lines.size() - 1]).is_empty():
		lines.remove_at(lines.size() - 1)

	## Sort by span start descending so earlier indices stay valid.
	var jobs: Array = []
	for edit in edits:
		if typeof(edit) != TYPE_DICTIONARY:
			continue
		var range_name := String(edit.get("range", "")).to_lower()
		var round_no := int(edit.get("round", 0))
		var body := String(edit.get("body", ""))
		if range_name.is_empty() or round_no <= 0:
			continue
		var span := _find_round_span(lines, range_name, round_no)
		if span.x < 0:
			push_error("parser: missing range '%s' round %d in %s" % [range_name, round_no, file_path])
			continue
		jobs.append({"span": span, "body": body})
	jobs.sort_custom(func(a, b): return int(a.span.x) > int(b.span.x))

	for job in jobs:
		var span: Vector2i = job.span
		var body_text: String = String(job.body)
		var new_body: PackedStringArray = []
		for raw_line in body_text.replace("\r\n", "\n").replace("\r", "\n").split("\n"):
			var line := String(raw_line)
			if line.strip_edges().is_empty():
				new_body.append("")
			else:
				## Body commands use two tabs under `\tround`.
				new_body.append("\t\t" + line.lstrip("\t"))
		## If body ended with \n, split leaves a trailing "" — keep one trailing blank max.
		while new_body.size() > 1 and String(new_body[new_body.size() - 1]).is_empty() and String(new_body[new_body.size() - 2]).is_empty():
			new_body.remove_at(new_body.size() - 1)
		## Rebuild: keep header at span.x, replace body, keep from span.y onward.
		var rebuilt: PackedStringArray = []
		for i in range(0, span.x + 1):
			rebuilt.append(String(lines[i]))
		for bl in new_body:
			rebuilt.append(bl)
		for i in range(span.y, lines.size()):
			rebuilt.append(String(lines[i]))
		lines = rebuilt

	var out := "\n".join(lines)
	if had_trailing_nl and not out.ends_with("\n"):
		out += "\n"
	var abs_path := ProjectSettings.globalize_path(file_path)
	var write := FileAccess.open(abs_path, FileAccess.WRITE)
	if write == null:
		## Fallback: try res path directly (editor often allows it).
		write = FileAccess.open(file_path, FileAccess.WRITE)
	if write == null:
		push_error("parser: could not write '%s'" % file_path)
		return false
	write.store_string(out)
	return true
