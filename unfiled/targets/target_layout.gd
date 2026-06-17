extends Node3D

func _ready():
#	layoutTargets(8)
	pass
			

func addTarget(model, n, x, z):
	
	var node = Node3D.new()
	
	add_child(node)
	
	#child.position.x += x
	#child.position.z += z

func layoutTargets(n):
	
	var t1		# base target to use

	for t in get_children():
		if t.name == 'target1':
			t1 = t


	#addTarget(t1, 1, 2, 4 )
	#return

	var x = 0
	var z = 0
	var i = 0
	
	for t in get_children():
		
		if t.name != 'target1':
			
			t.position = t1.position
			
			i = i + 1
			
			if i == 4:
				x = 0
				z = z + 10
			else:
				x = x + 2
				
			t.position.x += x
			t.position.z += z
