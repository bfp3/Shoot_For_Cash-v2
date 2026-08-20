extends Control
@onready var ring_texture: TextureRect = $RingTexture

const ring_count := 1
const ring_stagger_sec := 0.33
const ring_end_scale := 1.85
const ring_expand_sec := 1.5

var _burst_token := 0
var _live_rings: Array[TextureRect] = []


func start() -> void:
	return
	stop()
	if ring_texture == null:
		return
	ring_texture.visible = false
	_burst_token += 1
	var token := _burst_token
	_play_rings(token)


func _ready() -> void:
	if ring_texture:
		ring_texture.visible = false


func stop() -> void:
	_burst_token += 1
	_free_live_rings()


func _play_rings(token: int) -> void:
	var host := ring_texture.get_parent()
	if host == null:
		host = self
	for i in range(maxi(ring_count, 1)):
		if token != _burst_token:
			return
		_spawn_ring(host, token)
		if i < ring_count - 1 and ring_stagger_sec > 0.0:
			await get_tree().create_timer(ring_stagger_sec, false).timeout


func _spawn_ring(host: Node, token: int) -> void:
	if token != _burst_token or ring_texture == null:
		return
	var ring := ring_texture.duplicate() as TextureRect
	if ring == null:
		return
	host.add_child(ring)
	_live_rings.append(ring)
	ring.visible = true
	ring.modulate.a = 1.0
	ring.scale = ring_texture.scale
	ring.global_position = ring_texture.global_position
	var tween := ring.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * ring_end_scale, ring_expand_sec)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, ring_expand_sec)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)
	tween.tween_callback(_free_ring.bind(ring, token))


func _free_ring(ring: TextureRect, token: int) -> void:
	_live_rings.erase(ring)
	if is_instance_valid(ring):
		ring.queue_free()
	if token != _burst_token:
		return


func _free_live_rings() -> void:
	for ring in _live_rings:
		if is_instance_valid(ring):
			ring.queue_free()
	_live_rings.clear()


func _exit_tree() -> void:
	stop()
