extends Node3D

@onready var timer: Timer = $Timer

var frame_settings: Dictionary
var frame_index : int
var frame_array : Array = []
var frame_until_array : Array = []
var frame_define_array: Array = []
var frame_sfx : Node3D

func _ready() -> void:
	var scene_name := get_parent().name
	frame_array = Parser.loadFrames('res://100_levels/000-All-Levels/Scene-Storyboards/' + scene_name + ".txt")
	
	frame_sfx = Node3D.new()
	frame_sfx.name = '_sfx'
	add_child(frame_sfx)
	
	EventBus.instance.actor_event.connect(_on_actor_event)
	frame_index = -1
	frameNext()

func frameNext() -> void:
	
	frame_index += 1
	if frame_index > frame_array.size() - 1:
		return
	
	frameUntilClearAll()
	
	for i in Parser.loadFrame(frame_array[frame_index]):
		
		var item = Parser.getCommand(i)
		
		match item.cmd:
			'next':
				frameNext()
			
			'set':
				frameTargetSet(item.target, item.params)
				
			'play':
				frameTargetPlay(item.target, item.params)
				
			'until':
				frameUntilSet(item.target, item.params)
				
			'end':
				sceneEnd()
				
			'define':
				frameDefineAdd(item.target, item.params)
				
			
	
func frameDefineAdd(target : String, param : String) -> void:
	
	var item = { "name": target, "value": param }
	
	frame_define_array.push_back(item)

func frameParamsSet(val:String) -> String:

	var str:String = val
	
	for i in frame_define_array:
		str = str.replace(i.name, i.value)
		
	var ary1: Array = str.split('-')
	var ary2: Array
	
	for i in ary1:
		var c = frameParamGetRepeat(i) 
		if c > 0:
			for j in range(0, c):
				ary2.push_back( frameParamGetRepeatStrip(i,c) )
		else:
			ary2.push_back(i)
	
	return '-'.join(PackedStringArray(ary2))

func frameParamGetRepeatStrip(str:String, count:int) -> String:
	
	var i:int = str(count).length()
	
	return str.left(str.length()-i)

func frameParamGetRepeat(str:String) -> int:
	
	var ptr: int = str.length()-1
	
	while ptr > -1 && str[ptr].is_valid_int():
		ptr -= 1
		
	if ptr == str.length() - 1:
		return 0
	else:
		return str.right(str.length() -1 -ptr).to_int()
	
func frameUntilSet(action : String, param : String) -> void:

	if action == 'time':
		frameUntilTimerSet(param)
		return

	if action.is_valid_int():
		frameUntilTimerSet(action)
		return
	
	frame_until_array.push_back( { 'action' : action, 'target' : param } )
	return
	
func frameUntilTimerSet(param : String) -> void:

	frameUntilTimerClear()
	if param == '':
		return
	
	timer.start( int(param) )

func frameUntilTimerClear() -> void:
	timer.stop()

func _on_timer_timeout() -> void:
	frameNext()

func frameUntilClearAll() -> void:
	frameUntilTimerClear()
	frame_until_array.clear()

func frameTargetSet(target : String, param : String) -> void:
	
	if target == 'scene-next':
		frame_settings['scene-next'] = param
		return
		
	if target == 'scene-tempo':
		frame_settings['scene-tempo'] = param
		Engine.time_scale = float(param)
		return
		
		
	
	var node = get_tree().get_root().find_child(target, true, false)
	if node == null:
		return
	
	param = frameParamsSet(param)
	
	node.bh_Activate(self, param)

	

func frameTargetPlay(target : String, param : String) -> void:

	var f = frame_sfx.find_child(target, true, false)
	if not f:
		frameTargetPlayLoad(target, param)
		f = frame_sfx.find_child(target, true, false)
		if not f:
				return

	f.disconnect('finished',frameTargetPlayFinished)

	param = frameParamsSet(param)
	var param_array: Array  = param.split('-')

	if param_array.has('stop'):
		f.stop()
		return
		
	for i in param_array:
		match i:
			'left':
				f.global_position.x += 5
			'right':
				f.global_position.y -= 5
			'ppp':
				f.volume_db -= 5
			'fff':
				f.volume_db += 5

	if not param_array.has('continue'):
		f.play()
		
	if param_array.has('loop'):
		f.finished.connect(frameTargetPlayFinished.bind(f))
	
func frameTargetPlayFinished(target : Node) -> void:

	frameTargetPlay(target.name, 'loop')

func frameTargetPlayLoad(target : String, param:String) -> void:
	
	var fn = 'res://400_sounds/00_sound_files/' + target

	if FileAccess.file_exists(fn + '.wav'):
		fn = fn + '.wav'
	elif FileAccess. file_exists(fn + '.mp3'):
		fn = fn + '.mp3'
	else:
		fn = null
		
	if fn == null:
		print('file not found ' + target)
		return
		
	var audio_player = null

	if hasParam(param, '3d'):
		audio_player = AudioStreamPlayer3D.new()

	else:
		audio_player = AudioStreamPlayer.new()
		param = param.replace('left','')
		param = param.replace('right','')

	audio_player.name = target
	audio_player.stream = load(fn)
	audio_player.volume_db = -20.0
	frame_sfx.add_child(audio_player)
	




func sceneEnd() -> void:
	EventBus.instance.player_has_hit_winning_score.emit()
	await get_tree().create_timer(1.0).timeout # Timer gives a time for Poppers to finish die process
	
	get_tree().change_scene_to_file('res://100_levels/000-All-Levels/' + frame_settings['scene-next'] + '.tscn')



func _on_actor_event(name : String, action : String) -> void:
	#print(name, " ", action)
	
	var next = false
	for item in frame_until_array:
		if item.target == name:
			if item.action == action:
				next = true
		
	if next:
		frameNext()
	
func hasParam(str:String, p:String)-> bool:
	return str.split('-').has(p)
	
	
