extends CharacterBody3D

@export var gravity = 35	#9.8
var speed
const WALK_SPEED = 30.0
const SPRINT_SPEED = 60.0
const JUMP_VELOCITY = 8.0
const FLY_SPEED = 0.8

#bob variables
const BOB_FREQ = 0.5
const BOB_AMP = 0.1
var t_bob = 0.0
var time_elapsed = 3

#fov variables
#const BASE_FOV = 75.0
#const FOV_CHANGE = 0.25

var rotation_speed = 2.0			#camera rotation speed
var max_rotation_mouse = 70
var sensitivity = 0.001

var is_game_paused = false

# pick up var's
var picked_object
var pull_power = 70
var rotation_power = 0.05
var locked = false

# sensor
var is_sensor_affected = false


var newBullet = load("res://200_assets/weapons/bullet-glow.tscn")

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var gun_anim = $Head/Camera3D/gun/animations
@onready var gun_sound = $SFX/gunsfx
@onready var cam_move_sfx = $SFX/cameraMovement
@onready var gun_particles = $Head/Camera3D/GunBarrel/MuzzleParticles
@onready var gun_barrel = $Head/Camera3D/GunBarrel
@onready var interaction = $Head/Camera3D/interaction
@onready var hand = $Head/Camera3D/hand
@onready var torch = $Head/Camera3D/Torch

#func _ready():
#	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

#func set_sensor_affected(affected: bool):
#
#	is_sensor_affected = affected

func _physics_process(delta):
	
	

	#$Battery/MarkdownLabel.text = str(int(GameManager.battery))
	
	if Input.is_action_pressed("lightSwitch"):
#		torch.light_energy = 8
		
		if GameManager.battery >= 0.1:
			$Goggles.visible = true
			$Head/Camera3D.cull_mask = 2
			GameManager.battery -= 0.3 * delta
#		$Head/Camera3D.cull_mask = 1
	else:
#		torch.light_energy = 0
		if $Goggles:
			$Goggles.visible = false
		$Head/Camera3D.cull_mask = 1
	
	if not is_on_floor():
		velocity.y -= gravity * delta
		
	if Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
#		$SFX/jetPack.play()

	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	var input_dir = Input.get_vector("right", "left", "backward", "forward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if is_on_floor():
		if direction:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 1.5)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 1.5)

		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 6.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 6.0)
			
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 6.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 6.0)

	if Input.is_action_pressed("cam_left"):
		rotate_y(rotation_speed * delta)
		cam_move_sfx.playing = true
#		$Head/Camera3D.rotate_y(rotation_speed * delta)
	
	if Input.is_action_pressed("cam_right"):
		rotate_y(-rotation_speed * delta)
		cam_move_sfx.playing = true
#		$Head/Camera3D.rotate_y(-rotation_speed * delta)

	else:
		time_elapsed = 0
		cam_move_sfx.playing = false


	if Input.is_action_pressed("cam_up"):
		camera.rotate_x(rotation_speed * delta)
#		$Head/Camera3D.rotate_x(rotation_speed * delta)
		
	elif Input.is_action_pressed("cam_down"):
		camera.rotate_x(-rotation_speed * delta)
#		$Head/Camera3D.rotate_x(-rotation_speed * delta)

	camera.rotation_degrees.x = clamp(camera.rotation_degrees.x, -max_rotation_mouse, max_rotation_mouse)
	camera.rotation_degrees.z = 0 

	if Input.is_action_pressed("zoomIn"):
		camera.fov += 1
		camera.fov = clamp(camera.fov, 40, 75)

	if Input.is_action_pressed("zoomOut"):
		camera.fov -=1
		camera.fov = clamp(camera.fov, 40, 75)

	if Input.is_action_pressed("flyUp"):
		position.y += FLY_SPEED
		velocity.y = 0

	if Input.is_action_pressed("flyDown"):
		position.y += -FLY_SPEED
		velocity.y = 0
		
	if Input.is_action_just_pressed("shootWeapon"):
		spawn_bullet()

	if Input.is_action_just_released("cam_left"):
		cam_move_sfx.stop()

	if Input.is_action_just_released("cam_right"):
		cam_move_sfx.stop()

	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()
		
	gun_particles.global_transform.origin = gun_barrel.global_transform.origin
	
#	t_bob += delta * velocity.length() * float(is_on_floor())
#	camera.position = _headbob(t_bob)

	# FOV
#	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
#	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
#	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)

	if GameManager.is_sensor_affected:
		velocity.x *= 0.80
		velocity.z *= 0.80
		$Control/ColorRect.visible = true
		
	else:
		$Control/ColorRect.visible = false
	
	move_and_slide()

#	if picked_object != null:
#		var a = picked_object.global_transform.origin
#		var b = hand.global_transform.origin
#		picked_object.set_linear_velocity((b-a) * pull_power)
#
#	if interaction.is_colliding() and is_in_group("grabable"):
#		$CrossHair/InputText.visible = true
#		$CrossHair/InputText.text = str("Grab    [R2]")
#		$CrossHair/Reticle/Top.default_color = Color(Color.RED)
#	else:
#		$CrossHair/InputText.visible = false
#		$CrossHair/Reticle/Top.default_color = Color(Color.WHITE)
	
#func _headbob(time) -> Vector3:
#	var pos = Vector3.ZERO
#	pos.y = sin(time * BOB_FREQ) * BOB_AMP
#	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
#	return pos
#
#
#func pick_object():
#	var collider = interaction.get_collider()
#	if collider != null and collider is RigidBody3D:
#		picked_object = collider
#
#func remove_object():
#	if picked_object != null:
#		picked_object = null

func _input(event):
	
#	if event is InputEventMouseMotion:
#		rotate_object_local(Vector3.RIGHT, -event.relative.y * -sensitivity)
#		rotate(Vector3.UP, -event.relative.x * sensitivity)
	
	if Input.is_action_just_pressed("lightSwitch"):
		$SFX/goggles_sfx.play()
	
#	if Input.is_action_just_pressed("throw"):
#		if picked_object != null:
#			var knockback = picked_object.position - position
#			picked_object.apply_central_impulse(knockback * 4)
#			remove_object()
#
#	if Input.is_action_just_pressed("grab"):
#		if picked_object == null:
#			pick_object()
#		elif picked_object != null:
#			remove_object()
			
#	if Input.is_action_pressed("lightSwitch"):
##		torch.light_energy = 8
#		$Goggles.visible = true
#		$Head/Camera3D.cull_mask = 2
#		GameManager.battery -= 0.1
##		$Head/Camera3D.cull_mask = 1
#	else:
##		torch.light_energy = 0
#		$Goggles.visible = false
#		$Head/Camera3D.cull_mask = 1

	if Input.is_action_pressed("pause"):
		if is_game_paused:
			unpause_game()
		else:
			pause_game()
		
	if Input.is_action_just_pressed("escape"):
		get_tree().quit()
		
	if Input.is_physical_key_pressed(KEY_I):
		$ControlsInstructions.visible = false
		


func spawn_bullet():
	
	if !gun_anim.is_playing():
		
		gun_anim.play("shoot")
		gun_sound.play()
		
		var bullet = newBullet.instantiate()
		bullet.shoot(camera.global_transform) # used to be transform, had to change it.

		get_parent().add_child(bullet)
		gun_particles.emitting = true
		
	
func pause_game():
	get_tree().paused = true
	is_game_paused = true
	$PausedText.visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
		
func unpause_game():
	get_tree().paused = false
	is_game_paused = false
	$PausedText.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
