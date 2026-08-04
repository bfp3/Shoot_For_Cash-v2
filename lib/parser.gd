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
## rock / rock-black / rock-pigeon: {cmd, column, aim_row, aim_column, param}
##   column -1 means random. Aim cell (e.g. A8) is optional; 0/0 means none.
##   If only an aim cell is given (`rock A8`), spawn column defaults to 1.
##   rock-pigeon → RockSize.SMALL_2 (launches away from camera).
## balloon: {cmd, row, column, param} — row 1=A, 2=B, 3=C; defaults to A1.
## wait: {cmd, ms} — delay before the next rock; defaults to 100ms.
## repeat: {cmd, count} — wave count for the round; defaults to 3.
## Commands and row letters are case-insensitive.
func parse_spawn_command(token: String) -> Dictionary:
	var parts: PackedStringArray = token.split(' ', false)
	if parts.is_empty():
		return {}

	var cmd: String = String(parts[0]).to_lower()
	match cmd:
		'rock', 'rock-black', 'rock-pigeon':
			print(parts)
			return _parse_rock_command(cmd, parts)

		'balloon':
			return _parse_balloon_command(parts)

		'wait':
			return _parse_wait_command(parts)

		'repeat':
			return _parse_repeat_command(parts)

		_:
			print(parts)
			return _parse_rock_command('rock', ["rock", "1", "c1"])


const DEFAULT_ROUND_REPEAT := 1
const DEFAULT_WAIT_MS := 100


## rock / rock-black / rock-pigeon / rock 1 A8 / rock A8 (column defaults to 1 when only aim is given).
func _parse_rock_command(cmd: String, parts: PackedStringArray) -> Dictionary:
	var result := {
		'cmd': cmd,
		'column': -1,
		'aim_row': 0,
		'aim_column': 0,
		'param': '',
	}

	if parts.size() <= 1:
		return result

	var token1 := String(parts[1]).strip_edges()
	if token1.is_valid_int():
		result.column = int(token1)
	else:
		var aim_only := _parse_balloon_cell(token1)
		if not aim_only.is_empty():
			# `rock A8` — aim only, spawn defaults to column 1.
			result.column = 1
			result.aim_row = aim_only.row
			result.aim_column = aim_only.column
			if parts.size() > 2:
				result.param = parts[2]
			return result
		result.param = token1

	if parts.size() > 2:
		var token2 := String(parts[2]).strip_edges()
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


## repeat → 3. repeat 2 → 2 waves. Count is clamped to at least 1.
func _parse_repeat_command(parts: PackedStringArray) -> Dictionary:
	var count := DEFAULT_ROUND_REPEAT
	if parts.size() > 1 and String(parts[1]).is_valid_int():
		count = maxi(int(parts[1]), 1)
	return {
		'cmd': 'repeat',
		'count': count,
	}


## balloon → A1. balloon A1 / a1 → that cell. balloon A 1 also works.
## Extra trailing params are stored on 'param' and ignored by gameplay.
func _parse_balloon_command(parts: PackedStringArray) -> Dictionary:
	var result := {
		'cmd': 'balloon',
		'row': 1,       # A
		'column': 1,    # first column — old code 311
		'param': '',
	}

	if parts.size() <= 1:
		return result

	var cell := String(parts[1]).strip_edges()
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
		if _balloon_row_letter_to_index(row_token) > 0 and col_token.is_valid_int():
			result.row = _balloon_row_letter_to_index(row_token)
			result.column = clampi(int(col_token), 1, 8)
			if parts.size() > 3:
				result.param = parts[3]
			return result

	# Unrecognised placement — keep A1 default, stash text for later.
	result.param = cell
	if parts.size() > 2:
		result.param = ' '.join(parts.slice(1))
	push_warning("parser: could not parse balloon placement '%s', defaulting to A1" % cell)
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
		}
	return sequences[0]


## Builds one round dict per round, in file order:
## { "spawns": [spawn dicts...], "repeat": wave_count }
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
			}
			order.append(key)

		var parsed := parse_spawn_command(entry[3])
		if parsed.is_empty():
			continue

		if String(parsed.get('cmd', '')) == 'repeat':
			rounds[key].repeat = int(parsed.get('count', DEFAULT_ROUND_REPEAT))
			continue

		rounds[key].spawns.append(parsed)

	var sequences: Array = []
	for key in order:
		sequences.append(rounds[key])
	return sequences


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
