extends MeshInstance3D

@export var wall_quote_index : String = "wall_quote_moss"
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	self.mesh.text = gl_DataSet.get_string(wall_quote_index, 0)
