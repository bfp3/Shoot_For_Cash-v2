extends Node

class_name parser

var data_set : Array = []

func loadIslandFile(file_name : String) -> bool:

	var file = FileAccess.open(file_name, FileAccess.READ)
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


func getWaves():
	var cmd_list:Array = Parser.getRound('shipper', 'moss', 1)
	
	var cmd:String = cmd_list[0]
	
	var d:Dictionary = {"t":'', "p1":'', "p2":''}
	
	var l = cmd.split(' ')
	
	if l[0] == 'rock':
		d.t = 'rock'
		if l.size() > 1:
			d.p1 = l[1]
		if l.size() > 2:
			d.p2 = l[2]
		

		return d
		










func getCommand(_str : String) -> Dictionary:
	
	var result = {'cmd':'', 'target':'', 'params':''}
	
	var ary = _str.split(' ', false)
	result.cmd = ary[0]
	if ary.size() > 1:
		result.target = ary[1]
	
	if ary.size() > 2:
		result.params = ary[2]
			
	return result
	
