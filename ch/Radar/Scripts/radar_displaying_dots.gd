extends Control


#@onready var radar_dots: Control = $Radar_dots
#
#@onready var tower_reference: Node3D = get_tree().get_first_node_in_group('Egg_Cage')
#@export var detection_radius := 10.0  # world units #original value 15.0
#@export var radar_radius := 250.0  # pixels #original value 120.0
#@export var tower_color := Color('00000014')
#@export var tower_size := Vector2(40, 40)
#@export var tower_texture: Texture2D
#
#@export var clamp_x := 1.0 #original value 1.0
#@export var clamp_z := 0.3 #original value 1.0
#
#var dot_size := Vector2(12,12)
#var active_dots: Dictionary = {}
#var tower_icon: TextureRect
#
#var t : float = 0.0
#var time_threshold : float = 1.0
#
#
#var faded_in := false
#
#func _ready() -> void:
	#
	##var hostage = get_tree().get_first_node_in_group("Egg_Cage")
	##if hostage:
		##hostage.taken_a_hit_from_a_target.connect(shake_hostage)
		#
#
	#tower_icon = TextureRect.new()
	#tower_icon.texture = tower_texture
	#tower_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	#tower_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	#tower_icon.modulate = tower_color
	#tower_icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	#tower_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	#tower_icon.size = tower_size
	#tower_icon.position = get_center_pos() - tower_size / 2
	#add_child(tower_icon)
#
	#self.modulate = Color('FFFFFF30')
	#
	#EventBus.instance.cannonball_fired.connect(_on_cannonball_fired)
	#EventBus.instance.settle_phase_started.connect(_on_settle_phase)
	#EventBus.instance.egg_taken_damage.connect(_on_egg_taken_damage)
	#_on_cannonball_fired()
#
#func _on_cannonball_fired() -> void:
	#if faded_in:
		#return
	#faded_in = true
	#var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	#tween.tween_property(self, "scale", Vector2.ONE * 1.01, 0.25)
	#tween.tween_property(self, "scale", Vector2.ONE, 0.25)
	#tween.parallel().tween_property(self, "modulate", Color.WHITE, 0.5)
	#tween.parallel().tween_property($'../Radar_arm/TextureRect', "modulate", Color.WHITE,  0.25)
	#await tween.finished
	#
#func _on_settle_phase() -> void:
	#var tween = create_tween()
	#tween.tween_interval(0.25)
	#tween.tween_property($'../Radar_arm/TextureRect', "modulate", Color('FFFFFF00'), 0.5)
	#tween.tween_property(self, "modulate", Color('FFFFFF50'), 0.25)
	#
	#await tween.finished
	#faded_in = false
#
#func _process(delta):
#
	##time_threshold = 0.00
	##t += delta
	##if t > time_threshold:
		##t = 0.0
		### Continue with radar dot updates
	##else:
		##return
	#
	#var current_targets := []
#
	#for target in get_tree().get_nodes_in_group("Moving_target"):
		#if target.moving:
			#current_targets.append(target)
			#update_or_add_dot(target)
#
	## Remove any stale dots for targets no longer active
	#for tracked_target in active_dots.keys():
		#if tracked_target not in current_targets:
			#var dot = active_dots[tracked_target]
			#if is_instance_valid(dot):
				#dot.start_fade_out()
			#active_dots.erase(tracked_target)
#
#
#func update_or_add_dot(target: Node3D):
	#var world_offset = target.global_transform.origin - tower_reference.global_transform.origin
	#var dist = world_offset.length()
#
	#if dist > detection_radius:
		#if target in active_dots:
			#active_dots[target].queue_free()
			#active_dots.erase(target)
		#return
			#
	#
	## CIRCLE RADIUS LOGIC
	#
	##var direction = Vector2(-world_offset.x, -world_offset.z)
	##var distance_ratio = min(direction.length() / detection_radius, 1.0)
	##var angle = direction.angle()
##
	##var screen_pos = Vector2(
		##cos(angle), sin(angle)
	##) * distance_ratio * radar_radius
#
#
	## SQUARE LOGIC 
	#var normalized_offset = Vector2(
	#clamp(-world_offset.x / detection_radius, -clamp_x, clamp_x),
	#clamp(world_offset.z / detection_radius, -clamp_z, clamp_z)
	#)
#
	## Flip x to mirror as needed (optional), and invert z if needed for radar convention
	#var screen_pos = Vector2(
		#normalized_offset.x * radar_radius,
		#-normalized_offset.y * radar_radius
	#)
#
	#
	#var dot_pos = get_center_pos() + screen_pos
#
	#if not active_dots.has(target):
		#var dot = DOT_SCENE.instantiate()
		#dot.position = dot_pos - dot_size / 2
#
		#var color := get_confidence_color(target)
		#dot.setup(target, color)
		#
		#radar_dots.add_child(dot)
		#target.target_destroyed.connect(dot.on_target_destroyed)
		#active_dots[target] = dot
	#else:
		#var dot = active_dots[target]
		#if is_instance_valid(dot):
			#dot.position = dot_pos - dot_size / 2
#
#
#func get_center_pos() -> Vector2:
	#return Vector2(size.x, size.y) / 2
#
##func clear_dots():
	##for child in radar_dots.get_children():
		##child.queue_free()
#
#func get_confidence_color(target: Node3D) -> Color:
	#if not target.has_meta("type"):
		#return Color(0.5, 0.5, 0.5)  # fallback grey if shot type is unknown
#
	#var shot_type: String = target.get_meta("type")
#
	#match shot_type:
		#"RED":
			#return Color("ad3636")  # Threat
		#"ORANGE":
			#return Color("ffa32b")  # Maybe bd4520
		#"GREY":
			#return Color(0.5, 0.5, 0.5)  # Not a threat
		#_:
			#return Color(0.25, 0.25, 0.25)  # Unknown shot type (dark grey)
##
##
	##var is_close_call = target.target_is_going_to_hit_cage or dist <= 5.0
##
	##if is_close_call and randi() % 5 == 0:
		##target.set_meta("intended_color", intended_color)
		###return Color.ORANGE_RED
		##return Color('bd4520')
##
	##return intended_color
#
#
##func get_confidence_color(target: Node3D) -> Color:
	##
	##if target.target_is_going_to_hit_cage:
		##return Color(1.0, 0.0, 0.0)  # red = high risk
	##
	##var hostage_cage = get_tree().get_first_node_in_group("Bunny_Cage_physical")
	##var dist = target.target_position.distance_to(hostage_cage.global_position)
##
	##if dist < 2.0:
		##return Color.ORANGE_RED  # red = high risk
	##elif dist < 4.0:
		##return Color.YELLOW  # yellow = maybe
		##
	###elif dist < 5.0:
		###return Color.ORANGEc_RED
	##else:
		##return Color(0.0, 1.0, 0.0)  # fallback green
#
#func _on_egg_taken_damage() -> void:
	#increase_red_modulation()
	#
#func increase_red_modulation() -> void:
	#return
	##var inner : TextureRect = $Inner/Inner2
	##var inner_2 : TextureRect = $Middle/Inner2
	##var dur : float = 0.5
	##
	##var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	##tween.tween_property(inner, "modulate", Color(0,0,0,0.2), dur).as_relative()
	##tween.parallel().tween_property(inner_2, "modulate", Color(0,0,0,0.2), dur).as_relative()
#
#func shake_hostage() -> void:
	#var dur : float = 0.15
	#var intensity : float = 0.04
#
	#var tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	#tween.tween_interval(0.25)
	#tween.tween_property(get_parent(), "rotation", -0.06, 0.1)
	#tween.tween_property(get_parent(), "rotation", intensity, dur)
	#tween.tween_interval(0.25)
	#tween.tween_property(get_parent(), "rotation", 0.0, 0.35)
	#await tween.finished
