extends Node3D

@onready var anim = $Door/DoorAnim
@onready var text_box = $TextBox
@onready var area_3d = $EntranceArea
@onready var door_open_SFX = $SFX/DoorOpen
@onready var door_light_red = $Door/OmniLight3D
@onready var door_light_green = $Door/OmniLight3D2
@onready var inside_light_red = $ShelterBody/RedLightInside
@onready var inside_light_red2 = $ShelterBody/RedLightInside2
@onready var inside_light_green = $ShelterBody/GreenLightInside
@onready var inside_light_green2 = $ShelterBody/GreenLightInside2

func _ready():
#	door_light_red.visible = true
#	door_light_green.visible = false
#	inside_light_green.visible = false
#	inside_light_green2.visible = false
	text_box.visible = false
	GameManager.shelterDoorOpen = false

func _on_area_3d_body_entered(body):
	if "player" in body.name and !GameManager.shelterDoorOpen:
		text_box.visible = true

func _on_area_3d_body_exited(body):
	if "player" in body.name:
		text_box.visible = false
		GameManager.shelterDoorOpen = false
#		anim.play("close_slide")
		door_light_red.visible = true
		door_light_green.visible = false
		inside_light_red.visible = true
		inside_light_red2.visible = true
		inside_light_green.visible = false
		inside_light_green2.visible = false
#
func _input(event):

	if event.is_action_pressed("enterButton"):
		for body in area_3d.get_overlapping_bodies():
			if "player-v2" in body.name and !GameManager.shelterDoorOpen:
				anim.play("open_slide")
				door_open_SFX.play()
				door_light_red.visible = false
				door_light_green.visible = true
				GameManager.shelterDoorOpen = true
				inside_light_red.visible = false
				inside_light_red2.visible = false
				inside_light_green.visible = true
				inside_light_green2.visible = true
				
			elif "player-v2" in body.name and GameManager.shelterDoorOpen:
				anim.play("close_slide")
				door_open_SFX.play()
				GameManager.shelterDoorOpen = false
				door_light_red.visible = true
				door_light_green.visible = false
#				inside_light_red.visible = true
#				inside_light_red2.visible = true
#				inside_light_green.visible = false
#				inside_light_green2.visible = false



func _on_shelter_safe_body_entered(body):
	if "player" in body.name:
		GameManager.player_in_shelter = true


func _on_shelter_safe_body_exited(body):
	if "player" in body.name:
		GameManager.player_in_shelter = false
