extends Control

@export var balloon_1_speed: float = 180.0
@export var balloon_2_speed: float = 150.0
@export var balloon_3_speed: float = 220.0

@export var loop_top_y: float = -540.0
@export var loop_bottom_offset: float = -300.0


@onready var balloons: TextureRect = $Balloons
@onready var balloons_2: TextureRect = $Balloons2
@onready var balloons_3: TextureRect = $Balloons3

var rotation_amount := 0.1
var rotation_direction := true
var start := false

func _process(delta: float) -> void:
	if !start:
		return

	rotation_amount = 0.1
	if rotation_direction:
		self.rotation += rotation_amount * delta
		if rotation >= 0.2:
			rotation_direction = false
	else:
		self.rotation -= rotation_amount * delta
		if rotation <= -0.2:
			rotation_direction = true

	move_balloon(balloons, balloon_1_speed, delta)
	move_balloon(balloons_2, balloon_2_speed, delta)
	move_balloon(balloons_3, balloon_3_speed, delta)

func move_balloon(balloon: TextureRect, speed: float, delta: float) -> void:
	balloon.position.y -= speed * delta

	if balloon.position.y < loop_top_y:
		balloon.position.y = get_viewport_rect().size.y + loop_bottom_offset
