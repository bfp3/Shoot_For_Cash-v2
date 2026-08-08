extends MeshInstance3D

@export var wall_quote_index : String = "wall_quote_moss"

func _ready() -> void:
	_refresh_quote()


func _refresh_quote() -> void:
	var key := gl_DataSet.get_wall_quote_key()
	if not gl_DataSet.dataset_string.has(key):
		key = wall_quote_index
	self.mesh.text = gl_DataSet.get_string(key, 0).to_upper()
