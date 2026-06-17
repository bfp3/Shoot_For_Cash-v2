extends Node3D

var c = 300
var d = 0.0
@onready var staticSFX = $SFX/static


func _ready():
	$player/Head/AudioVisualizer.visible = false
	$targetsAppear.start()

#	openingSequence()
#	openingSequenceMusicVer()
	
#func _process(delta):
#	pass
#	d += delta
#
#	if d > 0.600:
#		d = 0.0
#		c -= 1
#		if c > 0:
#			$targetGenerator.start()
	

func camera_movement():
	var tween = get_tree().create_tween()
	tween.tween_property($openingCamera, "position", Vector3(0, 3.9, 1), 6).from_current()

func _on_timer_timeout():
	$targetGenerator.start()
	
func staticNoise(durationSeconds):
	staticSFX.playing = true
	
	await get_tree().create_timer(durationSeconds).timeout
	
	staticSFX.playing = false
	

func openingSequence():
	var player = $player
	var playerCamera = $player/Head/Camera3D
	var head = $player/Head
	var gun = $player/Head/Camera3D/mockGun
	var gunAnimPullout = $player/Head/Camera3D/mockGun/AnimationPlayer2
	var HUD = $player/Head/HUD
	var crosshair = $player/Head/Camera3D/mockGun/Crosshair
	
	var sonoma = $SFX/SonomaSFX
	var synth = $SFX/synthSong
	var wind_sfx = $SFX/windSFX
	var bgMusic = $SFX/nightTheme
	var Van1 = $SFX/Van1
	var Van2Muddled = $SFX/Van2Muddled
	
	var foggy = $FoggyBlurEffect
	var targetTimer = $targetsAppear

	HUD.visible = false
	gun.visible = false
	crosshair.visible = false
	playerCamera.rotation_degrees.x = 40
	foggy.visible = true
	foggy.modulate = Color(1, 1, 1, 1)
	
	
	
	
	# scene opens with white/grey colour fade in
	var foggyTween = foggy.create_tween() 
	foggyTween.tween_property(foggy, "modulate:a", 0.0, 5)
	
	await get_tree().create_timer(7.5).timeout
#	synth.playing = true
		

	await get_tree().create_timer(14).timeout


	
	
	
	var cameraTween = playerCamera.create_tween()
	cameraTween.tween_property(playerCamera, "rotation_degrees:x", 0, 9)	
	sonoma.playing = true
	
	await get_tree().create_timer(7).timeout
	
	synth.playing = false
	
	await get_tree().create_timer(8).timeout

	
	
	gunAnimPullout.play("pullOut")
	
	await get_tree().create_timer(0.2).timeout

	gun.visible = true
	
	await get_tree().create_timer(3).timeout
	
#	Van1.playing = true
	
	await get_tree().create_timer(2).timeout

	HUD.visible = true
	crosshair.visible = true
	$Counter.visible = true
	$player/Head/AudioVisualizer.visible = true
	
	player.process_mode = Node.PROCESS_MODE_INHERIT
	
	await get_tree().create_timer(5).timeout
	
	targetTimer.start()
	
	await get_tree().create_timer(4).timeout
	
#	bgMusic.playing = true


func openingSequenceMusicVer():
	var player = $player
	var playerCamera = $player/Head/Camera3D
	var head = $player/Head
	var gun = $player/Head/Camera3D/mockGun
	var gunAnimPullout = $player/Head/Camera3D/mockGun/AnimationPlayer2
	var HUD = $player/Head/HUD
	var crosshair = $player/Head/Camera3D/mockGun/Crosshair

	var wind_sfx = $SFX/windSFX
	var clockSFX = $SFX/clockTickingSFX
	var bgMusic = $SFX/nightTheme
	var Van1 = $SFX/Van1
	var Van2Muddled = $SFX/Van2Muddled
	
	var foggy = $FoggyBlurEffect
	var targetTimer = $targetsAppear

	HUD.visible = false
	gun.visible = false
	crosshair.visible = false
	playerCamera.rotation_degrees.x = 40
	foggy.visible = true
	foggy.modulate = Color(1, 1, 1, 1)
