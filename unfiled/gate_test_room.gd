extends Node3D

@onready var laser_container = $LaserContainer
@onready var target_spinning_pole = $TargetSpinningPole
@onready var t3 = $targetCreator/targetLoadPoint
@onready var left_spotlight = $PoleContainer/postL/LeftSpotlight
@onready var right_spotlight = $PoleContainer/postR/RightSpotlight
@onready var targetTimer = $TargetTimer
@onready var poleL = $PoleContainer/postL/LeftSpotlight
@onready var poleR = $PoleContainer/postR/RightSpotlight
@onready var songTimer = $SFX/Gate1_track/Timer
@onready var hole_in_the_wall = $Gate1/wallContainer
@onready var gate1 = $Gate1
@onready var points_sfx = $SFX/Points_added

var rotation_speed = 15
var rotation_direction = 1 
var rotation_limit = 45
var rotation_accumulator = 0

var hole_movement_speed = 1.5
var hole_direction = 1
var hole_movement_limit = 6
var hole_movement_accumulator = 0

var firstPlay = false
var starter = true
var sequence_started = false

var target_count = 0
var newTarget #= preload("res://200_assets/targets/target_rolling.tscn")


func _ready():
	$LaserContainer.visible = true
	poleL.visible = false
	poleR.visible = false
	

func _process(delta):
	
	if GameManager.powerPoints > 30:
		gate1.visible = false
	
	hole_in_the_wall.position.x += hole_movement_speed * hole_direction * delta

	hole_movement_accumulator += hole_movement_speed * delta

	if hole_movement_accumulator >= hole_movement_limit or hole_movement_accumulator <= -hole_movement_limit:

		hole_direction *= -1
		hole_movement_accumulator = 0
	
	left_spotlight.rotation_degrees.x += rotation_speed * rotation_direction * delta
	right_spotlight.rotation_degrees.x += rotation_speed * rotation_direction * delta
	rotation_accumulator += rotation_speed * delta
	if rotation_accumulator >= rotation_limit or rotation_accumulator <= -rotation_limit:
		rotation_direction *= -1
		rotation_accumulator = 0
		
	
	if GameManager.score == 1 and !sequence_started and starter:
		startSequence()

	else:
		return
		
		
func startSequence():
	sequence_started = true
	targetTimer.autostart = true
	$SFX/Electricity.play()
	await get_tree().create_timer(2.75).timeout
	laserOff()
	await get_tree().create_timer(2.0).timeout
	$SFX/SearchLightOn.play()
	poleL.visible = true
	poleR.visible = true
	await get_tree().create_timer(3.0).timeout
	targetTimer.start()
	
	if !firstPlay:
		firstPlay = true
		songTimer.start()

func target():
	target_count += 1
	var nextTarget = newTarget.instantiate()
	nextTarget.position = t3.position
	nextTarget.name = "target_rolling" + str(target_count)
	add_child(nextTarget)
	
func _on_target_timer_timeout():
	starter = false
	target()


func _on_song_timer_timeout():
	if firstPlay:
		$SFX/Gate1_track.playing = true
		await get_tree().create_timer(7.0).timeout
		$SFX/ClockCountdown.playing = true


func _on_area_3d_body_entered(body):
	if "target_rolling" in body.name:
		points_sfx.play()
		GameManager.powerPoints += 3
		#PowerCounter.updatePower()


func laserOff():
	laser_container.visible = false
	$LaserContainer/Laser/LaserSound.playing = false
	$LaserContainer/Laser2/LaserSound.playing = false
	$LaserContainer/Laser3/LaserSound.playing = false
	$LaserContainer/Laser4/LaserSound.playing = false
	$LaserContainer/Laser5/LaserSound.playing = false
	$LaserContainer/Laser6/LaserSound.playing = false
	$LaserContainer/Laser7/LaserSound.playing = false
	$LaserContainer/Laser8/LaserSound.playing = false
