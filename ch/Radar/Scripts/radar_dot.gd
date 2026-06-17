extends Node2D

@onready var radar_mesh: MeshInstance2D = $RadarDot

var revealed := false
var target_node: Node3D
var confidence_color := Color(1, 1, 1)  # placeholder
var tween: Tween
var dying := false

var delay_before_reveal_duration := 2.0

func _ready() -> void:
	radar_mesh.modulate = Color(0.25, 0.25, 0.25)  # start as grey
	#if GameManager.in_retry_world:
		#delay_before_reveal_duration = 0.05
	#else:
		#delay_before_reveal_duration = 1.0
	#await get_tree().create_timer(delay_before_reveal_duration).timeout
	delay_before_reveal_duration = 0.05
	start_reveal()

func setup(_target: Node3D, _confidence_color: Color):
	target_node = _target
	confidence_color = _confidence_color

func start_reveal() -> void:
	if revealed:
		return
	revealed = true

	# Handle Orange Red suspense case
	if confidence_color == Color.ORANGE:
		radar_mesh.modulate = Color(0.5, 0.5, 0.5)
		tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(radar_mesh, "modulate", confidence_color, randf_range(0.3, 0.5))
		await tween.finished
		close_call_reveal_tween()
		return

	# Regular reveal for all other confidence colors
	tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(radar_mesh, "modulate", confidence_color, randf_range(0.6, 1.6))
	await tween.finished

func close_call_reveal_tween() -> void:
	if target_node != null && target_node.has_meta("intended_color"):
		var real_color = target_node.get_meta("intended_color")
		var _tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		_tween.tween_property(radar_mesh, "modulate", real_color, randf_range(0.3, 0.6))
		await _tween.finished

func on_target_destroyed() -> void:
	hit_by_player()

func hit_by_player() -> void:
	if dying:
		return
	dying = true
	var dur : float = 1.0
	var orig_color = radar_mesh.modulate
	var fade_tween = create_tween()
	fade_tween.tween_property(radar_mesh, "modulate", Color('FFFFFF'), 0.05)
	fade_tween.tween_property(radar_mesh, "modulate", orig_color, 0.1)
	fade_tween.parallel().tween_property(radar_mesh, "modulate:a", 0, dur).set_delay(0.25)
	fade_tween.parallel().tween_property(radar_mesh, "scale", Vector2.ONE * 2, dur).set_ease(Tween.EASE_OUT)
	await fade_tween.finished
	queue_free()

func start_fade_out() -> void:
	if dying:
		return
	var dur : float = 1.0
	var fade_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	fade_tween.tween_property(radar_mesh, "modulate", Color(0, 0, 0, 0), dur)
	fade_tween.parallel().tween_property(radar_mesh, "scale", Vector2.ONE * 2, dur)
	await fade_tween.finished
	queue_free()
