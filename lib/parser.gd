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
					data_set.push_back( [island_name,range_name,round_no,token] )

	return(true)
	
	
func getRound(island_name : String, range_name : String, round_no : int) -> Array:
	var ary: Array
	for i:int in range(0,data_set.size()):
		if data_set[i][0] == island_name:
			if data_set[i][1] == range_name:
				if data_set[i][2] == round_no:
					ary.push_back(data_set[i][3])
	return ary


## Parses a single spawn line into {cmd, column, param}.
## column is -1 when omitted (random). Third param is stored but unused.
## Returns {} for balloons and anything else we should skip for now.
func parse_spawn_command(token: String) -> Dictionary:
	var parts: PackedStringArray = token.split(' ', false)
	if parts.is_empty():
		return {}

	var cmd: String = parts[0]
	match cmd:
		'rock', 'black':
			pass
		'balloon':
			# Balloons are intentionally ignored for this pipeline step.
			return {}
		_:
			return {}

	var result := {
		'cmd': cmd,
		'column': -1,
		'param': '',
	}

	if parts.size() > 1:
		if parts[1].is_valid_int():
			result.column = int(parts[1])
		else:
			result.param = parts[1]

	if parts.size() > 2:
		result.param = parts[2]

	return result


## Builds one array-per-round of parsed spawn dictionaries, in file order.
## Pass an empty island_name to include every island in the loaded file.
func get_rock_sequences(island_name: String = '') -> Array:
	var rounds: Dictionary = {}
	var order: Array = []

	for entry in data_set:
		if island_name != '' and entry[0] != island_name:
			continue

		var key := '%s|%s|%d' % [entry[0], entry[1], entry[2]]
		if not rounds.has(key):
			rounds[key] = []
			order.append(key)

		var parsed := parse_spawn_command(entry[3])
		if parsed.is_empty():
			continue

		rounds[key].append(parsed)

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
