#@tool
extends Node3D

#@export_tool_button("Start Coins") var coin_tool = tween_coins
#@export_tool_button("Stop Coins") var coin_tool_2 = stop_reset

@export var height_distance := 0.1
@export var duration := 1.0


var coins_collected := 0
var target_still_active := true

var tween : Tween = null


func tween_coins() -> void:
	
	$MeshInstance3D.scale = Vector3.ZERO
	#$Sfx_1.play()
	$Sfx_2.play()
	tween = create_tween()
	tween.tween_property($MeshInstance3D, "position:y", height_distance, duration).as_relative()
	tween.parallel().tween_property($MeshInstance3D, "scale", Vector3.ONE, duration)
	tween.parallel().tween_property($MeshInstance3D, "rotation_degrees:y", -180.0, duration).as_relative()
	tween.tween_property($MeshInstance3D, "position:y", height_distance, duration).as_relative()
	tween.parallel().tween_property($MeshInstance3D, "scale", Vector3.ZERO, duration)
	await tween.finished
	coins_collected += 1
	$Label3D.text = str(coins_collected)
	
	finished_tween()
	
func finished_tween() -> void:
	show()
	if target_still_active:
		$MeshInstance3D.position.y = 0.0
		$MeshInstance3D.scale = Vector3.ZERO
		#duration -= 0.05
		duration = clamp(duration - 0.01, 0.3, 3.0)
		tween_coins()
	else:
		return


func stop_reset() -> void:
	var coins_tracker = get_tree().get_first_node_in_group('coins_tracker')
	if coins_tracker:
		coins_tracker.coins_secured += coins_collected
	if tween:
		tween.kill()
	hide()
	target_still_active = false
	coins_collected = 0
	await get_tree().create_timer(0.1).timeout
	$Label3D.text = str(coins_collected)
	target_still_active = true
