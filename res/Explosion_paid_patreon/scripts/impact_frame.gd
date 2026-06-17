extends Node

@onready var texture_rect = $"../Control/TextureRect"

var capture_next_frame : bool
var impact_frame_timer : float

@export var show_impact_frame : bool = true
@export var impact_frame_duration : float

func _ready():
	texture_rect.hide()
	capture_next_frame = false

func _process(_delta):
	if capture_next_frame:
		capture_screen()
		texture_rect.show()
		impact_frame_timer = impact_frame_duration
		capture_next_frame = false
	elif texture_rect.is_visible_in_tree():
		if impact_frame_timer > 0:
			impact_frame_timer -= get_process_delta_time()
		else:
			texture_rect.hide()
	
	pass

func queue_capture():
	if show_impact_frame:
		capture_next_frame = true

func capture_screen():
	var img = get_viewport().get_texture().get_image()

	# Create a texture for it.
	var tex = ImageTexture.create_from_image(img)

	# Set the texture to the captured image node.
	texture_rect.set_texture(tex)
