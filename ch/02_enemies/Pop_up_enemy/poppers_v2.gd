extends StaticBody3D

const ARROW_AREA_3D = preload("res://200_characters/weapons/bullet_area3D.tscn")

@onready var looking_over_wall_sequence = $Looking_over_wall_sequence
@onready var flipping_the_bird_sequence = $Flipping_the_bird_sequence
@onready var throwing_sequence = $Throwing_sequence
@onready var relocating_sequence = $Relocating_sequence
@onready var stunned_sequence = $Stunned_sequence
@onready var dying_sequence = $Dying_sequence

@export var in_actual_level := false
@export var arrow_speed := 40.0
@export var randf := 1.0
@export var walk_speed := 1.5
@export var bob_amount := 0.2
@export var bob_speed := 8.0
@export var peeker := false
@export var dev_mode := false
@export var full_sequence_chance := 0.5

@export_group("Popping Up variables", "")
@export var up_dist := 1.0
@export var first_up_dist := 0.8
@export var second_up_dist := 0.2
@export var z_movement := 5.0
@export var z_dur := 0.25
@export var trans_popping_up : Tween.TransitionType
@export var ease_popping_up : Tween.EaseType
@export var spotter_reveal_dur := 0.5
@export var spotter_exposed_time := 1.0
@export var staying_around_time := 0.4
@export var spotter_hiding_dur := 0.5

@export_group("Crosshair variables", "")
@export var crosshair_touching_me_threshold := 0.02
@export var crosshair_timer_allowance := 0.25

@onready var player : Player = get_tree().get_first_node_in_group("Player")
@onready var anim: AnimationPlayer = $Mesh/AnimationPlayer
@onready var anim_wobble: AnimationPlayer = $Mesh/AnimationPlayer2

var spawned_arrows: Array[Area3D] = []
var tween_peaking_head : Tween = null
var tween_ducking_cover : Tween = null
var tween_corner : Tween = null
var tween_rotate_head : Tween = null

var hit_able := false
var health := 2

var start_pos : Vector3
var orig_pos : Vector3
var current_marker : Marker3D = null

var taken_cover := true
var going_to_get_hit := false
var can_throw_projectiles := false
var stunned := false
var projectile_throw_cancelled := false
var currently_peeking := false
var crosshair_touching_me := false
var crosshair_on_me_count := 0.0
var peeking_timer := 0.0
var peeking_timer_threshold := 1.5
var dying := false

func _ready() -> void:
	await get_tree().create_timer(0.1).timeout
	relocating_sequence.attach_self_to_nearest_marker()
	
	EventBus.instance.egg_pulsed.connect(stunned_sequence.stunned_by_egg_pulse)
	EventBus.instance.enemy_present.emit()

	start_pos = global_position

	if !in_actual_level:
		looking_over_wall_sequence.peeking_over_wall_sequence()

	await get_tree().create_timer(5.0).timeout
	can_throw_projectiles = true

func spawn_my_arrow() -> void:
	if !hit_able:
		looking_over_wall_sequence.take_cover_behind_wall()
		
		var new_arrow = ARROW_AREA_3D.instantiate()
		var player_gun = get_tree().get_first_node_in_group("player_gun")
		
		new_arrow.global_position = player_gun.get_barrel_position()
		get_tree().get_current_scene().add_child(new_arrow)
		
		spawned_arrows.append(new_arrow)
		return
	
	for i in range(2):
		var new_arrow = ARROW_AREA_3D.instantiate()
		var player_gun = get_tree().get_first_node_in_group("player_gun")
		
		
		get_tree().get_current_scene().add_child(new_arrow)
		new_arrow.global_position = player_gun.get_barrel_position()
		going_to_get_hit = true
		spawned_arrows.append(new_arrow)
		await get_tree().create_timer(0.15).timeout



func _physics_process(delta: float) -> void:
	if going_to_get_hit:
		hit_able = true

	if currently_peeking and !stunned:
		peeking_timer += delta
		if peeking_timer >= peeking_timer_threshold:
			peeking_timer = 0.0
			throwing_sequence.throw_rock_at_the_egg()
	else:
		peeking_timer = 0.0

	var target : Vector3 = %Unique_marker.global_position
	if !hit_able:
		target += Vector3(0, 0.5, 5)

	if stunned:
		for arrow in spawned_arrows.duplicate():
			if tween_peaking_head and hit_able:
				tween_peaking_head.kill()

			if !is_instance_valid(arrow):
				spawned_arrows.erase(arrow)
				continue

			var dir = (target - arrow.global_position).normalized()
			arrow.global_position += dir * arrow_speed * delta
			arrow.look_at(target, Vector3.UP, true)

			if arrow.global_position.distance_to(target) < 0.5:
				arrow.cleanUp()
				if spawned_arrows.has(arrow):
					health -= 1
					if health <= 0:
						dying_sequence.die()
					else:
						CommonCode.play_sound_duplicate_instance($SFX/Poking_sfx2, 0.0, -30.0)
					spawned_arrows.erase(arrow)



func crosshair_spotted_me() -> void:
	flipping_the_bird_sequence.crosshair_spotted_me()


func reset_crosshair_on_me_timer() -> void:
	flipping_the_bird_sequence.reset_crosshair_on_me_timer()


func _on_crosshair_timer_timeout() -> void:
	flipping_the_bird_sequence._on_crosshair_timer_timeout()


func walk_to_position() -> void:
	relocating_sequence.walk_to_position()
