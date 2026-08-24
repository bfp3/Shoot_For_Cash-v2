extends Node

signal health_changed(new_health)
signal game_won()
signal game_beaten()
signal game_lost()
signal cannonball_fired()
signal player_has_hit_winning_score()
signal pineapple_round_started()
signal level_restarted()
signal next_round()

signal oranges_start_falling()
signal has_hit_three_strikes()
signal add_strike()
signal hazard_hit()
signal bonus_oranges()
signal all_white_compulsory_rocks_destroyed()
signal all_rocks_destroyed()
signal rocks_cleared_end_wave()
signal checkpoint_shot()
signal end_round_rock_missed()
signal open_tally_card()
signal close_tally_card()
signal detonate_sky_mines()

signal open_shop()
signal close_shop()
signal purchase_made(power_name)
signal player_update_stats_visually()
signal update_money()
signal cash_pool_changed(new_amount)
signal cash_pool_banked(amount, previous_cash, new_total_cash)
signal cash_pool_forfeited(amount)
signal cash_multiplier_changed(new_multiplier)

signal actor_event()


#Projectiles
signal rock_destroyed()
signal rock_created()

#EGG 
signal egg_pulse_activated()
signal egg_pulsed()
signal egg_taken_damage()
signal main_egg_destroyed()

#ENEMY POP OUTS
signal enemy_present()
signal enemy_popper_shot()
signal popper_has_died()


#PINEAPPLES
signal pineapple_round_bought()
signal pineapple_round_used()
signal pineapple_shot()
signal pineapple_hit_ground()
signal pineapple_launched()


#PLAYER
signal player_shot_weapon()


#TOOLS
signal in_dev_mode()


#SEQUENCING
signal zoom_out_finished()
signal settle_phase_started()
signal wrapping_up_a_level()


#CANNONBALLS
signal cannonball_destroyed()
signal red_cannonball_destroyed()
signal standard_cannonball_destroyed()
signal standard_cannonball_destroyed_astray()
signal special_cannonball_destroyed_astray()


#HOSTAGEGGS
signal release_hostages_start()

#AMMO
signal free_ammo_mode_started()
signal free_ammo_mode_finished()
signal finished_standard_reload()


#LEVEL SELECT MENU
signal button_pushed_in_level_select()


# Multiplier signals
signal mult_increase()
signal mult_decrease()
signal mult_reset()


# Singleton pattern - autoload this script in Project Settings
static var instance: EventBus

func _init():
	instance = self


# Do not call this function ever, Blake...
func XXemit_all_signals() -> void:
	
	all_white_compulsory_rocks_destroyed.emit()
	oranges_start_falling.emit()
	has_hit_three_strikes.emit()
	add_strike.emit()
	hazard_hit.emit()
	bonus_oranges.emit()
	health_changed.emit(100) # Example value
	game_won.emit()
	game_beaten.emit()
	game_lost.emit()
	cannonball_fired.emit()
	player_has_hit_winning_score.emit()
	pineapple_round_started.emit()
	level_restarted.emit()
	next_round.emit()
	
	pineapple_round_bought.emit()
	
	player_update_stats_visually.emit()
	rocks_cleared_end_wave.emit()
	all_rocks_destroyed.emit()
	end_round_rock_missed.emit()
	open_tally_card.emit()
	close_tally_card.emit()
	detonate_sky_mines.emit()
	
	open_shop.emit()
	close_shop.emit()
	purchase_made.emit()
	update_money.emit()

	actor_event.emit()

	# Projectiles
	rock_destroyed.emit()
	rock_created.emit()

	# EGG
	egg_pulse_activated.emit()
	egg_pulsed.emit()
	egg_taken_damage.emit()
	main_egg_destroyed.emit()

	# ENEMY POP OUTS
	enemy_present.emit()
	enemy_popper_shot.emit()
	popper_has_died.emit()

	# PINEAPPLES
	pineapple_round_used.emit()
	pineapple_shot.emit()
	pineapple_hit_ground.emit()
	pineapple_launched.emit()

	# PLAYER
	player_shot_weapon.emit()

	# TOOLS
	in_dev_mode.emit()

	# SEQUENCING
	zoom_out_finished.emit()
	settle_phase_started.emit()
	wrapping_up_a_level.emit()

	# CANNONBALLS
	cannonball_destroyed.emit()
	red_cannonball_destroyed.emit()
	standard_cannonball_destroyed.emit()
	standard_cannonball_destroyed_astray.emit()
	special_cannonball_destroyed_astray.emit()

	# HOSTAGEGGS
	release_hostages_start.emit()

	# AMMO
	free_ammo_mode_started.emit()
	free_ammo_mode_finished.emit()
	finished_standard_reload.emit()

	# LEVEL SELECT MENU
	button_pushed_in_level_select.emit()

	# Multiplier signals
	mult_increase.emit()
	mult_decrease.emit()
	mult_reset.emit()
