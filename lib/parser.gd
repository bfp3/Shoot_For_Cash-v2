extends Node

class_name parser

func loadFrames(file_name : String) -> Array:
	
	var file = FileAccess.open(file_name, FileAccess.READ)
	var content := file.get_as_text().strip_edges()

	var ary1 : Array = content.split("\n", false)

	# find --start directive
	if ary1.has('--start'):
		for i in range(0, ary1.size()):
			if ary1[i] == '--start':
				ary1[i] = ''
				break
				
			if ary1[i].strip_edges().begins_with('until'):
				ary1[i] = 'next'

	# remove comments
	ary1 = ary1.filter (func(i): return not i.strip_edges().begins_with('#'))
	
	content = '\n'.join( PackedStringArray(ary1) )

	return content.split("frame", false)
	
func loadFrame(content : String) -> Array:
	content = content.replace('\t', '')
	return content.split("\n", false)

func getCommand(_str : String) -> Dictionary:
	
	var result = {'cmd':'', 'target':'', 'params':''}
	
	var ary = _str.split(' ', false)
	result.cmd = ary[0]
	if ary.size() > 1:
		result.target = ary[1]
	
	if ary.size() > 2:
		result.params = ary[2]
			
	return result
	
