extends CharacterBody3D

var speed
const WALK_SPEED = 10.0
const SPRINT_SPEED = 80.0
const JUMP_VELOCITY = 4.8
const SENSITIVITY = 0.202
const FLY_SPEED = 1.0

#bob variables
const BOB_FREQ = 2.4
const BOB_AMP = 0.08
var t_bob = 0.0

#camera lerp
var camera_rotation_start = 0.02
var camera_rotation_end = 0.04

#fov variables
const BASE_FOV = 40.0
const FOV_CHANGE = 0.25

@export var RECOIL_RIGHT = 100
@export var RECOIL_RIGHT_SPEED = 50
@export var RECOIL_RIGHT_PAUSE = 14
@export var RECOIL_LEFT = 80
@export var RECOIL_LEFT_SPEED = 2

var gf_recoilCounter = 0
var gf_recoilPause = 0

var rotation_speed = 0.5
var is_game_paused = false


var max_rotation_mouse = 70

#var newBullet = load("res://200_assets/weapons/bullet-glow.tscn")
var newBullet = load("res://200_characters/weapons/bullet.tscn")

@onready var head = $Head
@onready var camera = $Head/Camera3D
@onready var gun_anim = $Head/Camera3D/gun/animations
@onready var gun_sound = $Head/Camera3D/gun/gunsfx

var gravity = 9.8


func _physics_process(delta):
	
	if not is_on_floor():
		velocity.y -= gravity * delta
		
		
	if Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		

	if Input.is_action_pressed("sprint"):
		speed = SPRINT_SPEED
	else:
		speed = WALK_SPEED

	var input_dir = Input.get_vector("right", "left", "backward", "forward")
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	

	if is_on_floor():
		if direction:
			velocity.x = direction.x * speed
			velocity.z = direction.z * speed
		else:
			velocity.x = lerp(velocity.x, direction.x * speed, delta * 7.0)
			velocity.z = lerp(velocity.z, direction.z * speed, delta * 7.0)
	else:
		velocity.x = lerp(velocity.x, direction.x * speed, delta * 3.0)
		velocity.z = lerp(velocity.z, direction.z * speed, delta * 3.0)
#
#	# Head bob
#	t_bob += delta * velocity.length() * 1
#	head.transform.origin = _headbob(t_bob)
##	print(float(is_on_floor()))
	
	# FOV
#	var velocity_clamped = clamp(velocity.length(), 0.5, SPRINT_SPEED * 2)
#	var target_fov = BASE_FOV + FOV_CHANGE * velocity_clamped
#	camera.fov = lerp(camera.fov, target_fov, delta * 8.0)
	
	move_and_slide()
	

	if Input.is_action_pressed("cam_left"):
		rotate_y(rotation_speed * delta)
#		rotate_y(lerp(camera_rotation_start, camera_rotation_end, delta * 0.1))
		$cameraMovement.play()

	if Input.is_action_pressed("cam_right"):
		rotate_y(-rotation_speed * delta)
		$cameraMovement.play()
		
	
	if gf_recoilCounter != 0:
		
		if gf_recoilPause > 0:
			gf_recoilPause -= 1
		
		elif gf_recoilCounter > 0:
			camera.rotation.y -= (RECOIL_RIGHT_SPEED / 10000.0)
			gf_recoilCounter -= RECOIL_RIGHT_SPEED
			
			if gf_recoilCounter <= 0:
				gf_recoilPause = RECOIL_RIGHT_PAUSE
				gf_recoilCounter = RECOIL_LEFT * -1
			
		else:
			camera.rotation.y += (RECOIL_LEFT_SPEED / 10000.0)
			gf_recoilCounter += RECOIL_LEFT_SPEED
		
			if gf_recoilCounter >= 0:
				gf_recoilCounter = 0
			
		return

	if Input.is_action_pressed("flyUp") and not is_on_floor():
		position.y += FLY_SPEED
		velocity.y = 0


	if Input.is_action_pressed("flyDown") and not is_on_floor():
		position.y += -FLY_SPEED
		velocity.y = 0
		
		
	if Input.is_action_just_pressed("shootWeapon"):
		spawn_bullet()

	if Input.is_action_pressed("cam_up"):
		$Head/Camera3D.rotate_x(rotation_speed * delta)
		$Head/Camera3D.rotation_degrees.x = clamp($Head/Camera3D.rotation_degrees.x, -max_rotation_mouse, max_rotation_mouse)
		$Head/Camera3D.rotation_degrees.z = 0 

	if Input.is_action_pressed("cam_down"):
		$Head/Camera3D.rotate_x(-rotation_speed * delta)
		$Head/Camera3D.rotation_degrees.x = clamp($Head/Camera3D.rotation_degrees.x, -max_rotation_mouse, max_rotation_mouse)
		$Head/Camera3D.rotation_degrees.z = 0  

	if Input.is_action_just_released("cam_left"):
		$cameraMovement.stop()

	if Input.is_action_just_released("cam_right"):
		$cameraMovement.stop()
		
	if Input.is_action_pressed("zoomIn"):
		$Head/Camera3D.fov += 1
		$Head/Camera3D.fov = clamp($Head/Camera3D.fov, 30, 47)
		$cameraMovement.play()

	if Input.is_action_pressed("zoomOut"):
		$Head/Camera3D.fov -=1
		$Head/Camera3D.fov = clamp($Head/Camera3D.fov, 30, 47)
		$cameraMovement.play()
#
	if Input.is_action_just_released("zoomIn"):
		$cameraMovement.stop()

	if Input.is_action_just_released("zoomOut"):
		$cameraMovement.stop()
		

	
#func _headbob(time) -> Vector3:
#	var pos = Vector3.ZERO
#	pos.y = sin(time * BOB_FREQ) * BOB_AMP
#	pos.x = cos(time * BOB_FREQ / 2) * BOB_AMP
#	return pos


func _input(event):
	
	if Input.is_action_pressed("pause"):
		if is_game_paused:
			unpause_game()
		else:
			pause_game()
		
	if Input.is_action_just_pressed("escape"):
		get_tree().quit()


	

func spawn_bullet():
	
	if !gun_anim.is_playing():
		
		gun_anim.play("shoot")
		gun_sound.play()
		
		var bullet = newBullet.instantiate()
		bullet.shoot(camera.global_transform)		#used to just be transform, had to change it.

		get_parent().add_child(bullet)		
#
#		$Head/Camera3D/Ammo_counter.bulletShot()	#reduces the bullet
#		gf_recoilCounter = RECOIL_RIGHT
	
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
	
