extends Node

@export var player : Player

@export var shot_cooldown_upgrade_ui: Upgrade_Display
@export var bullet_speed_upgrade_ui: Upgrade_Display
@export var targeting_circle_upgrade_ui: Upgrade_Display
@export var scope_move_speed_upgrade_ui: Upgrade_Display
@export var bullet_strength_upgrade_ui: Upgrade_Display
@export var delay_between_bullets_upgrade_ui: Upgrade_Display
@export var bullet_amount_upgrade_ui: BulletAmountDisplay


# Upgrade indices
var targ_circle_index := 0
var bullet_speed_index := 0
var bullet_strength_index := 0
var shot_cooldown_index := 0
var delay_between_bullets_index := 0

# Upgrade stages
@export var upgrade_stage_targ_circle := [
	60.0,100.0,200.0,300.0,400.0,500.0,600.0,700.0,800.0
]

@export var upgrade_stage_bullet_speed := [
	150.0,200.0,250.0,325.0,400.0,500.0,650.0,800.0,1000.0
]

@export var upgrade_stage_bullet_strength := [
	2,3,5,8,12,18,25,35,50
]

@export var upgrade_stage_shot_cooldown := [
	1.50,1.25,1.00,0.80,0.65,0.50,0.35,0.20,0.10
]

@export var upgrade_stage_delay_between_bullets := [
	0.40,0.32,0.25,0.18,0.12,0.08,0.05,0.02, 0.005
]


func player_upgrade_requested(_upgrade_ID : String) -> void:
	return
	match _upgrade_ID:
		'0':
			upgrade_shot_cooldown()
			shot_cooldown_upgrade_ui.upgrade()

		'1':
			upgrade_bullet_speed()
			bullet_speed_upgrade_ui.upgrade()

		'2':
			upgrade_target_circle_size()
			targeting_circle_upgrade_ui.upgrade()

		'3':
			upgrade_scope_move_speed()
			scope_move_speed_upgrade_ui.upgrade()

		'4':
			upgrade_bullet_strength()
			bullet_strength_upgrade_ui.upgrade()

		'5':
			upgrade_bullet_amount()

		'6':
			upgrade_delay_between_bullets()
			delay_between_bullets_upgrade_ui.upgrade()


func upgrade_shot_cooldown() -> void:
	if player:
		player.shot_cooldown = upgrade_stage_shot_cooldown[shot_cooldown_index]

	if shot_cooldown_index < upgrade_stage_shot_cooldown.size() - 1:
		shot_cooldown_index += 1


func upgrade_bullet_speed() -> void:
	if player:
		player.bullet_speed = upgrade_stage_bullet_speed[bullet_speed_index]

	if bullet_speed_index < upgrade_stage_bullet_speed.size() - 1:
		bullet_speed_index += 1


func upgrade_target_circle_size() -> void:
	if player:
		player.targeting_circle = upgrade_stage_targ_circle[targ_circle_index]

	if targ_circle_index < upgrade_stage_targ_circle.size() - 1:
		targ_circle_index += 1
	
	player.max_targeting_circle = player.targeting_circle
	
	if player:
		player.player_apply_upgrades()


func upgrade_scope_move_speed() -> void:
	if player:
		player.crosshair_lag_speed = clamp(
			player.crosshair_lag_speed + 0.5,
			5.0,
			30.0
		)


func upgrade_bullet_strength() -> void:
	if player:
		player.current_damage_output = upgrade_stage_bullet_strength[bullet_strength_index]
	
	if bullet_strength_index < upgrade_stage_bullet_strength.size() - 1:
		bullet_strength_index += 1
		
	if bullet_strength_index >= 1:
		#player.red_bullet_activated = true
		player.red_bullet_glow_amount += 25.0

func upgrade_bullet_amount() -> void:
	#if player:
		#player.max_bullets = clamp(
			#player.max_bullets + 1,
			#1,
			#200
		#)
		
	if player:
		player.additional_bullets = clamp(
			player.additional_bullets + 1,
			1,
			200
		)

	bullet_amount_upgrade_ui.update_bullet_amount()

func upgrade_delay_between_bullets() -> void:
	if player:
		player.delay_between_shots = upgrade_stage_delay_between_bullets[
				delay_between_bullets_index
			]

	if delay_between_bullets_index < upgrade_stage_delay_between_bullets.size() - 1:
		delay_between_bullets_index += 1
