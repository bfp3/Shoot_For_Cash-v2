extends Node

class_name parser

var data_set : Array = []

func loadIslandFile(file_name : String) -> bool:
	var file = FileAccess.open(file_name, FileAccess.READ)
	if file == null:
		push_error("parser: could not open level file '%s'" % file_name)
		return false
	var content := file.get_as_text().strip_edges()
	return loadIsland(content)

func loadIsland(data : String) -> bool:
	data_set.clear()
	
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

			'round':
				round_no += 1
				
			_:
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


## Parses a single spawn line into a spawn dictionary.
## Targets — rock / rock-black / rock-pigeon / smokecan / pineapple / red_rock_error:
##   {cmd, column, aim_row, aim_column, param}. `?` or omit = random (RANDOM_SLOT / -1).
##   `rock` = `rock ? ?`. `rock 2` = `rock 2 ?`. `rock ? A4` / `rock A4` = random col + aim A4.
## balloon: {cmd, row, column, param} — bare / `?` → random cell; `balloon A1` → fixed.
## wait: {cmd, ms} — delay before the next rock; defaults to 1000ms.
## repeat: {cmd, count} — closes a section that plays `count` times inside one wave.
##   Bare `repeat` / `repeat 1` / `repeat 2` → count 2. `repeat N` (N ≥ 2) → N.
##   Compat: a single trailing `repeat` with nothing after still means wave count
##   (same as `wave-repeat`), matching existing island-shipper rounds.
## wave-repeat: {cmd, count} — how many times the whole wave (after section expands) plays.
##   Bare `wave-repeat` → 2. `wave-repeat N` → max(1, N).
## no-lives: {cmd} — this round only; missed rocks do not award strikes.
## shuffle: {cmd} — this round only; later waves randomise rock columns.
## surprise-me: {cmd} — replace this round's spawns with a random generated sequence.
## bonus-protect / bonus protect: marks the round as a protect bonus (no strikes).
## protect-balloon / protect-balloon A4: place a protect balloon (bonus-protect only).
##   Bare `protect-balloon` defaults to B4. `protect-balloon ?` → random. Multiple lines OK.
## Unknown commands become red_rock_error so bad editor lines are visible in-game.
## Commands and row letters are case-insensitive.
func parse_spawn_command(token: String) -> Dictionary:
	var parts: PackedStringArray = token.split(' ', false)
	if parts.is_empty():
		return {}

	var cmd: String = String(parts[0]).to_lower()
	match cmd:
		'rock', 'rock-black', 'rock-pigeon', 'red_rock_error', 'smokecan':
			return _parse_rock_command(cmd, parts)

		'pineapple':
			# Same `?` / default-random rules as other targets (no forced column 1).
			return _parse_rock_command(cmd, parts)

		'balloon':
			return _parse_balloon_command(parts)

		'protect-balloon':
			return _parse_protect_balloon_command(parts)

		'wait':
			return _parse_wait_command(parts)

		'repeat':
			return _parse_repeat_command(parts)

		'wave-repeat':
			return _parse_wave_repeat_command(parts)

		'no-lives':
			return {'cmd': 'no-lives'}

		'shuffle':
			return {'cmd': 'shuffle'}

		'surprise-me':
			return {'cmd': 'surprise-me'}

		'bonus-protect':
			return {'cmd': 'bonus-protect'}

		'bonus':
			# `bonus protect` → same as `bonus-protect` (subtype after bonus).
			if parts.size() > 1:
				var subtype := String(parts[1]).strip_edges().to_lower()
				if subtype.begins_with('bonus-'):
					subtype = subtype.substr(6)
				return {'cmd': 'bonus-%s' % subtype}
			push_warning("parser: 'bonus' needs a subtype (e.g. bonus-protect) — using red_rock_error")
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


## rock / rock-black / rock-pigeon / smokecan / pineapple / red_rock_error
##   rock          → rock ? ?   (random column, random aim)
##   rock 2        → rock 2 ?   (column 2, random aim)
##   rock ? A4     → random column, aim A4
##   rock 2 A4     → column 2, aim A4
##   rock A4       → rock ? A4  (random column, aim A4)
##   rock ? ?      → explicit both-random
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
		var aim_only := _parse_balloon_cell(token1)
		if not aim_only.is_empty():
			# `rock A8` — aim only, spawn column random (same as `rock ? A8`).
			result.column = RANDOM_SLOT
			result.aim_row = aim_only.row
			result.aim_column = aim_only.column
			if parts.size() > 2:
				result.param = parts[2]
			return result
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


## wait → 100ms. wait 600 → 600ms. Values below 0 clamp to 0.
func _parse_wait_command(parts: PackedStringArray) -> Dictionary:
	var ms := DEFAULT_WAIT_MS
	if parts.size() > 1 and String(parts[1]).is_valid_int():
		ms = maxi(int(parts[1]), 0)
	return {
		'cmd': 'wait',
		'ms': ms,
	}


## Section play count. Bare / 1 / 2 → 2. `repeat N` (N ≥ 2) → N.
func _parse_repeat_command(parts: PackedStringArray) -> Dictionary:
	var count := 2
	if parts.size() > 1 and String(parts[1]).is_valid_int():
		count = maxi(int(parts[1]), 2)
	return {
		'cmd': 'repeat',
		'count': count,
	}


## Whole-wave count. Bare → 2. `wave-repeat N` → max(1, N).
func _parse_wave_repeat_command(parts: PackedStringArray) -> Dictionary:
	var count := 2
	if parts.size() > 1 and String(parts[1]).is_valid_int():
		count = maxi(int(parts[1]), 1)
	return {
		'cmd': 'wave-repeat',
		'count': count,
	}


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


## protect-balloon → B4 (bonus-protect default). protect-balloon A4 / ? → that cell / random.
func _parse_protect_balloon_command(parts: PackedStringArray) -> Dictionary:
	var result := {
		'cmd': 'protect-balloon',
		'row': 2,       # B — same default as bonus-protect
		'column': 4,
		'param': '',
	}

	if parts.size() <= 1:
		return result

	var cell := String(parts[1]).strip_edges()
	if _is_random_token(cell):
		result.row = RANDOM_SLOT
		result.column = RANDOM_SLOT
		return result

	var as_balloon := _parse_balloon_command(parts)
	result.row = int(as_balloon.get('row', 2))
	result.column = int(as_balloon.get('column', 4))
	result.param = String(as_balloon.get('param', ''))
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
			"protect_placements": [],
			"shuffle": false,
		}
	return sequences[0]


## Builds one round dict per round, in file order:
## { "spawns": [...], "repeat": wave_count, "no_lives": bool, "bonus": ""|"protect"|...,
##   "protect_placements": [{row, column}, ...], "shuffle": bool }
## Pass an empty island_name to include every island in the loaded file.
func get_rock_sequences(island_name: String = '') -> Array:
	var rounds: Dictionary = {}
	var order: Array = []

	for entry in data_set:
		if island_name != '' and entry[0] != island_name:
			continue

		var key := '%s|%s|%d' % [entry[0], entry[1], entry[2]]
		if not rounds.has(key):
			rounds[key] = {
				'spawns': [],
				'repeat': DEFAULT_ROUND_REPEAT,
				'no_lives': false,
				'bonus': '',
				'protect_placements': [],
				'shuffle': false,
				'surprise': false,
				# Temporary while parsing — removed by `_finalize_round_repeats`.
				'_pending': [],
				'_sections': [],
				'_wave_repeat': -1,
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

		if parsed_cmd == 'wave-repeat':
			rounds[key]._wave_repeat = int(parsed.get('count', 2))
			continue

		if parsed_cmd == 'no-lives':
			rounds[key].no_lives = true
			continue

		if parsed_cmd == 'shuffle':
			rounds[key].shuffle = true
			continue

		if parsed_cmd == 'surprise-me':
			rounds[key].surprise = true
			continue

		if parsed_cmd.begins_with('bonus-') and parsed_cmd.length() > 6:
			var bonus_type := parsed_cmd.substr(6)
			rounds[key].bonus = bonus_type
			rounds[key].no_lives = true
			continue

		if parsed_cmd == 'protect-balloon':
			rounds[key].protect_placements.append({
				'row': int(parsed.get('row', 2)),
				'column': int(parsed.get('column', 4)),
			})
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


## Resolves `repeat` / `wave-repeat` collected while parsing.
## - No `repeat` → spawns = pending body; waves from `wave-repeat` or 1.
## - One trailing `repeat`, nothing after, no `wave-repeat` → classic wave count
##   (existing island-shipper rounds).
## - Otherwise expand each section `count` times into one wave's spawn list;
##   wave count from `wave-repeat` (default 1).
func _finalize_round_repeats(round_data: Dictionary) -> void:
	var sections: Array = round_data.get('_sections', [])
	var pending: Array = round_data.get('_pending', [])
	var wave_repeat := int(round_data.get('_wave_repeat', -1))
	round_data.erase('_sections')
	round_data.erase('_pending')
	round_data.erase('_wave_repeat')

	if sections.is_empty():
		round_data.spawns = pending
		round_data.repeat = wave_repeat if wave_repeat > 0 else DEFAULT_ROUND_REPEAT
		return

	# Classic: single trailing `repeat` and no `wave-repeat` → that count is waves.
	if wave_repeat < 0 and pending.is_empty() and sections.size() == 1:
		round_data.spawns = sections[0].get('spawns', [])
		round_data.repeat = maxi(int(sections[0].get('count', DEFAULT_ROUND_REPEAT)), 1)
		return

	# Sectional expand — trailing body without a closing `repeat` plays once.
	if not pending.is_empty():
		sections.append({
			'spawns': pending,
			'count': 1,
		})

	var expanded: Array = []
	for section in sections:
		var body: Array = section.get('spawns', [])
		var times := maxi(int(section.get('count', 1)), 1)
		for _i in times:
			for entry in body:
				if entry is Dictionary:
					expanded.append(entry.duplicate(true))
				else:
					expanded.append(entry)

	round_data.spawns = expanded
	round_data.repeat = wave_repeat if wave_repeat > 0 else 1


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
				entry.aim_row = randi_range(1, 3)
				entry.aim_column = randi_range(1, 8)
		elif randf() < 0.55:
			entry.column = randi_range(1, 8)
			if randf() < 0.55:
				entry.aim_row = randi_range(1, 3)
				entry.aim_column = randi_range(1, 8)
		elif randf() < 0.35:
			# Aim-only (`rock A8`) — random spawn column.
			entry.aim_row = randi_range(1, 3)
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

	print('parser: surprise-me generated:\n%s' % surprise_round_to_text(round_data))


## Pretty-print a round dict back to level-script lines (for console / debugging).
func surprise_round_to_text(round_data: Dictionary) -> String:
	var lines: PackedStringArray = []
	if bool(round_data.get('no_lives', false)):
		lines.append('no-lives')
	if bool(round_data.get('shuffle', false)):
		lines.append('shuffle')
	var wave_count := int(round_data.get('repeat', DEFAULT_ROUND_REPEAT))
	if wave_count >= 2:
		if wave_count == 2:
			lines.append('wave-repeat')
		else:
			lines.append('wave-repeat %d' % wave_count)

	for entry in round_data.get('spawns', []):
		if not (entry is Dictionary):
			continue
		var cmd := String(entry.get('cmd', ''))
		match cmd:
			'wait':
				lines.append('wait %d' % int(entry.get('ms', DEFAULT_WAIT_MS)))
			'balloon':
				var brow := int(entry.get('row', RANDOM_SLOT))
				var bcol := int(entry.get('column', RANDOM_SLOT))
				if brow < 1 or bcol < 1:
					lines.append('balloon ?')
				else:
					var row_letter = ['', 'A', 'B', 'C'][clampi(brow, 1, 3)]
					lines.append('balloon %s%d' % [row_letter, bcol])
			'pineapple', 'rock', 'rock-black', 'rock-pigeon', 'smokecan', 'red_rock_error':
				var col := int(entry.get('column', RANDOM_SLOT))
				var ar := int(entry.get('aim_row', RANDOM_SLOT))
				var ac := int(entry.get('aim_column', RANDOM_SLOT))
				var col_token := '?' if col < 1 else str(col)
				if ar > 0 and ac > 0:
					var aim := '%s%d' % [['', 'A', 'B', 'C'][clampi(ar, 1, 3)], ac]
					lines.append('%s %s %s' % [cmd, col_token, aim])
				elif ar < 1 or ac < 1:
					# Random aim — omit trailing `?` when both slots random (`rock`).
					if col < 1:
						lines.append(cmd)
					else:
						lines.append('%s %s' % [cmd, col_token])
				else:
					lines.append('%s %s' % [cmd, col_token])
			_:
				lines.append(cmd)
	return '\n'.join(lines)


## Bonus rounds with parse errors (or no rock instructions) become a single red_rock_error.
func _finalize_bonus_round(round_data: Dictionary) -> void:
	var bonus := String(round_data.get('bonus', ''))
	if bonus == '':
		# protect-balloon outside a bonus-protect round is an error marker.
		if not round_data.get('protect_placements', []).is_empty():
			round_data.protect_placements = []
			round_data.spawns = [_make_bonus_error_spawn('protect-balloon without bonus-protect')]
		return

	# Unknown bonus subtypes are treated as errors until implemented.
	if bonus != 'protect':
		round_data.spawns = [_make_bonus_error_spawn('bonus-%s' % bonus)]
		round_data.protect_placements = []
		return

	var spawns: Array = round_data.get('spawns', [])
	if spawns.is_empty():
		round_data.spawns = [_make_bonus_error_spawn('bonus-%s empty' % bonus)]
		return

	for entry in spawns:
		if entry is Dictionary and String(entry.get('cmd', '')).to_lower() == 'red_rock_error':
			round_data.spawns = [_make_bonus_error_spawn(String(entry.get('param', 'bonus-%s' % bonus)))]
			round_data.protect_placements = []
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
