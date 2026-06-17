extends Control

var move_speed = 0.5
var timer

signal logo_clicked

func _ready():
	$MainControl.modulate = Color(1, 1, 1, 0)

func _process(delta):
	pass

func _on_timer_timeout():
	pass


func _on_title_timer_timeout():
	$MainControl/AnimationPlayer.play("fadeIn")
	$sfxInsect.play()

func _on_button_pressed():
	logo_clicked.emit()
