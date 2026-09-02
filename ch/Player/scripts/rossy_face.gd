extends Control
## Tiny living face at the center of the crosshair (Rossy / the gun).
## Swap textures under res://res/rossy/ — keep them small pixel-art PNGs.

enum FaceState { IDLE, SHOOTING, HURT, LOW_HEALTH, HAPPY }

@export_group("Textures")
@export var face_idle: Texture2D
@export var face_happy: Texture2D
@export var face_hurt: Texture2D
@export var face_sad: Texture2D

@export_group("Layout")
## Uniform display size of the face (pixels). Keep tiny so aiming stays clear.
@export_range(4.0, 48.0, 1.0) var face_display_size := 12.0:
	set(value):
		face_display_size = value
		_apply_layout()
## Extra offset from exact crosshair center (pixels).
@export var face_offset := Vector2.ZERO:
	set(value):
		face_offset = value
		_apply_layout()
@export_range(0.0, 1.0, 0.05) var face_alpha := 0.92:
	set(value):
		face_alpha = value
		if face_rect:
			face_rect.modulate.a = face_alpha

@export_group("Timing")
@export_range(0.05, 1.0, 0.01) var shoot_hold_sec := 0.12
@export_range(0.05, 1.5, 0.01) var hurt_hold_sec := 0.35
@export_range(0.1, 2.0, 0.05) var happy_hold_sec := 0.7
## Strikes remaining at or below this keep the sad face (e.g. 1 of 3 → low health).
@export_range(0, 5, 1) var low_health_strikes_remaining := 1

@export_group("Motion")
@export_range(0.0, 0.35, 0.01) var shoot_squash := 0.12
@export_range(0.02, 0.25, 0.01) var shoot_squash_sec := 0.08

@onready var face_rect: TextureRect = $Face

var _state: FaceState = FaceState.IDLE
var _token := 0
var _anim_tween: Tween
var _rest_scale := Vector2.ONE


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if face_rect == null:
		face_rect = TextureRect.new()
		face_rect.name = "Face"
		add_child(face_rect)
	face_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	face_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	face_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	face_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_layout()
	_set_texture_for(FaceState.IDLE)
	_rest_scale = face_rect.scale
	_connect_signals()
	_refresh_low_health_baseline()


func _apply_layout() -> void:
	if face_rect == null:
		return
	var half := face_display_size * 0.5
	face_rect.set_anchors_preset(Control.PRESET_CENTER)
	face_rect.offset_left = -half + face_offset.x
	face_rect.offset_top = -half + face_offset.y
	face_rect.offset_right = half + face_offset.x
	face_rect.offset_bottom = half + face_offset.y
	face_rect.pivot_offset = Vector2(half, half)
	face_rect.modulate.a = face_alpha


func _connect_signals() -> void:
	var bus := EventBus.instance
	if bus == null:
		return
	if not bus.add_strike.is_connected(_on_damage):
		bus.add_strike.connect(_on_damage)
	if not bus.hazard_hit.is_connected(_on_damage):
		bus.hazard_hit.connect(_on_damage)
	if not bus.has_hit_three_strikes.is_connected(_on_damage):
		bus.has_hit_three_strikes.connect(_on_damage)
	if not bus.all_rocks_destroyed.is_connected(_on_perfect):
		bus.all_rocks_destroyed.connect(_on_perfect)
	if not bus.checkpoint_shot.is_connected(_on_happy_moment):
		bus.checkpoint_shot.connect(_on_happy_moment)
	if not bus.next_round.is_connected(_on_round_reset):
		bus.next_round.connect(_on_round_reset)
	if not bus.level_restarted.is_connected(_on_round_reset):
		bus.level_restarted.connect(_on_round_reset)
	if not bus.open_shop.is_connected(_on_round_reset):
		bus.open_shop.connect(_on_round_reset)


## Called from Player_Crosshair when a shot fires (all shoot paths hit crosshair_shake).
func notify_shot() -> void:
	_flash(FaceState.SHOOTING, shoot_hold_sec, true)


func _on_damage() -> void:
	_refresh_low_health_baseline()
	if _is_low_health():
		_enter_persistent(FaceState.LOW_HEALTH)
		_nudge_hurt()
		return
	_flash(FaceState.HURT, hurt_hold_sec, false)


func _on_perfect() -> void:
	_flash(FaceState.HAPPY, happy_hold_sec, false)


func _on_happy_moment() -> void:
	if _is_low_health():
		return
	_flash(FaceState.HAPPY, happy_hold_sec * 0.75, false)


func _on_round_reset() -> void:
	_token += 1
	_kill_anim()
	_enter_persistent(FaceState.IDLE if not _is_low_health() else FaceState.LOW_HEALTH)


func _is_low_health() -> bool:
	if gl_PlayerState == null:
		return false
	var strikes := int(gl_PlayerState.dataset.get("total_current_strikes", 0))
	var max_strikes := 3
	if gl_PlayerState.has_method("get_max_strikes"):
		max_strikes = gl_PlayerState.get_max_strikes()
	var remaining := maxi(max_strikes - strikes, 0)
	return remaining <= low_health_strikes_remaining and strikes > 0


func _refresh_low_health_baseline() -> void:
	if _is_low_health():
		if _state != FaceState.SHOOTING and _state != FaceState.HURT and _state != FaceState.HAPPY:
			_enter_persistent(FaceState.LOW_HEALTH)
	elif _state == FaceState.LOW_HEALTH:
		_enter_persistent(FaceState.IDLE)


func _baseline_state() -> FaceState:
	return FaceState.LOW_HEALTH if _is_low_health() else FaceState.IDLE


func _flash(temp_state: FaceState, hold_sec: float, squash: bool) -> void:
	_token += 1
	var token := _token
	_state = temp_state
	_set_texture_for(temp_state)
	if squash:
		_play_shoot_squash()
	elif temp_state == FaceState.HURT:
		_nudge_hurt()
	await get_tree().create_timer(hold_sec, false).timeout
	if token != _token:
		return
	_enter_persistent(_baseline_state())


func _enter_persistent(state: FaceState) -> void:
	_state = state
	_set_texture_for(state)
	if face_rect:
		face_rect.scale = _rest_scale


func _set_texture_for(state: FaceState) -> void:
	if face_rect == null:
		return
	var tex: Texture2D = face_idle
	match state:
		FaceState.IDLE:
			tex = face_idle
		FaceState.SHOOTING, FaceState.HURT:
			tex = face_hurt if face_hurt else face_idle
		FaceState.LOW_HEALTH:
			tex = face_sad if face_sad else face_hurt
		FaceState.HAPPY:
			tex = face_happy if face_happy else face_idle
	face_rect.texture = tex


func _play_shoot_squash() -> void:
	if face_rect == null:
		return
	_kill_anim()
	var s := maxf(1.0 - shoot_squash, 0.5)
	_anim_tween = create_tween()
	_anim_tween.tween_property(face_rect, "scale", Vector2(s * 1.15, s * 0.85), shoot_squash_sec * 0.45)
	_anim_tween.tween_property(face_rect, "scale", _rest_scale, shoot_squash_sec * 0.55)


func _nudge_hurt() -> void:
	if face_rect == null:
		return
	_kill_anim()
	_anim_tween = create_tween()
	_anim_tween.tween_property(face_rect, "scale", Vector2(1.08, 0.9), 0.05)
	_anim_tween.tween_property(face_rect, "scale", _rest_scale, 0.08)


func _kill_anim() -> void:
	if _anim_tween != null and is_instance_valid(_anim_tween):
		_anim_tween.kill()
	_anim_tween = null
