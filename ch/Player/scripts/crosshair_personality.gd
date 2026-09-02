class_name CrosshairPersonality
extends Resource
## Data-driven face for the living crosshair. Swap Resources to change character.

@export_group("Identity")
@export var display_name := "Happy"

@export_group("Appearance")
@export_range(0.4, 2.0, 0.05) var face_scale := 1.0
@export_range(0.5, 4.0, 0.1) var line_width := 1.4
@export var line_color := Color(1, 1, 1, 0.92)
@export_range(2.0, 14.0, 0.5) var eye_spacing := 5.5
@export_range(0.4, 3.0, 0.05) var eye_size_left := 1.15
@export_range(0.4, 3.0, 0.05) var eye_size_right := 1.35
@export_range(-4.0, 4.0, 0.1) var eye_height := -0.4
@export_range(-2.0, 2.0, 0.05) var eye_y_asymmetry := 0.25
@export_range(3.0, 16.0, 0.5) var mouth_width := 6.5
@export_range(0.5, 6.0, 0.1) var mouth_height := 2.2
@export_range(-2.0, 2.0, 0.05) var mouth_curvature := 1.0
@export_range(0.0, 3.0, 0.1) var mouth_y := 2.4
@export var draw_brows := false
@export_range(-40.0, 40.0, 1.0) var brow_angle_deg := 8.0
@export var draw_cheeks := true

@export_group("Sine / Idle")
@export_range(0.2, 6.0, 0.05) var idle_frequency := 1.35
@export_range(0.0, 3.0, 0.05) var idle_amplitude := 0.85
@export_range(0.0, 2.0, 0.05) var breathing_amount := 0.35
@export_range(0.2, 6.0, 0.05) var mouth_frequency := 1.1
@export_range(0.0, 2.0, 0.05) var mouth_amplitude := 0.45
@export_range(0.0, 6.28, 0.05) var left_eye_phase := 0.35
@export_range(0.0, 6.28, 0.05) var right_eye_phase := 2.1
@export_range(0.0, 6.28, 0.05) var mouth_phase := 4.2

@export_group("Eye Look")
@export var eye_look_enabled := true
@export_range(0.0, 20.0, 0.5) var eye_look_strength := 8.0
@export_range(0.5, 20.0, 0.5) var eye_look_max := 10.0
@export_range(0.5, 12.0, 0.1) var eye_look_speed := 3.2
@export_range(20.0, 400.0, 5.0) var eye_look_radius_px := 140.0
@export_range(0.2, 3.0, 0.05) var eye_look_persist_sec := 1.0
@export_range(2.0, 20.0, 0.5) var look_poll_hz := 8.0
@export_range(0.0, 6.0, 0.1) var eye_wander_amount := 1.6
@export_range(0.05, 2.0, 0.05) var eye_wander_frequency := 0.22

@export_group("Expressions")
@export_range(1.0, 20.0, 0.5) var expression_transition_speed := 8.0
@export_range(0.05, 1.0, 0.01) var shoot_hold_sec := 0.14
@export_range(0.05, 1.5, 0.01) var hurt_hold_sec := 0.4
@export_range(0.1, 2.5, 0.05) var happy_hold_sec := 0.85
@export_range(0.0, 0.4, 0.01) var shoot_squash := 0.12
@export_range(0, 5, 1) var low_health_strikes_remaining := 1
@export_range(2.0, 20.0, 0.5) var excited_shots_per_sec := 6.0

@export_group("Future hooks")
## Reserved for later gun-behavior characters (Idiot / Prince). Unused in Happy v1.
@export var behavior_id := "happy"
@export_range(0.0, 1.0, 0.05) var scared_vanish_opacity := 0.15
