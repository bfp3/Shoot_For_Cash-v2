extends HBoxContainer

@export var area_1: ProgressBar
@export var area_2: ProgressBar
@export var area_3: ProgressBar
@export var area_4: ProgressBar
@export var area_5: ProgressBar
#
#@export var tally_main : TallyCard
#
#signal area_completed()
#var bar_tweens : Dictionary = {}
#
#var stage_totals = {}
#
#const AREA_COUNT := 5
#
#func _ready():
	#area_completed.connect(tally_main._on_area_completed)
	#update_original_stage_totals()
	#update_game_progress()
#
#func _area_bars() -> Array[ProgressBar]:
	#return [area_1, area_2, area_3, area_4, area_5]
#
#func get_active_stage() -> int:
	#var stage: int = gl_PlayerState.dataset.stage
	#if stage >= 1 and stage <= AREA_COUNT:
		#return stage
#
	#var current_place := str(gl_PlayerState.dataset.stage_name).to_lower()
	#var location_names: Array = gl_DataSet.dataset_string["place_name"]
	#var place_index := location_names.find(current_place)
#
	#if place_index >= 0 and place_index < AREA_COUNT:
		#return place_index + 1
#
	#return 1
#
#func update_original_stage_totals() -> void:
	#for stage in range(1, AREA_COUNT + 1):
		#var key = "total_rocks_area_" + str(stage)
		#stage_totals[stage] = gl_DataSet.get_value(key)
#
#func update_game_progress() -> void:
	#await get_tree().create_timer(1.0).timeout
#
	#var bars := _area_bars()
	#var active_stage := get_active_stage()
#
	#for i in AREA_COUNT:
		#var bar: ProgressBar = bars[i]
		#bar.get_child(0).text = "[i]" + gl_DataSet.get_string("place_name", i).capitalize()
#
		#var stage := i + 1
		#var is_active := stage == active_stage
#
		#bar.visible = is_active
		#bar.show_percentage = is_active
#
		#if is_active:
			#update_bar(bar, stage)
		#elif bar_tweens.has(bar):
			#bar_tweens[bar].kill()
			#bar_tweens.erase(bar)
#
#func update_bar(bar: ProgressBar, stage: int) -> void:
	#var key = "total_rocks_area_" + str(stage)
	#var remaining : float = gl_DataSet.get_value(key)
	#var total : float = stage_totals[stage]
#
	#var completion : float = 0.0
	#if total > 0.0:
		#completion = clamp(
			#((total - remaining) / total) * 100.0,
			#0.0,
			#100.0
		#)
#
	#if bar_tweens.has(bar):
		#bar_tweens[bar].kill()
#
	#var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	#bar_tweens[bar] = tween
	#tween.tween_property(bar, "value", completion, 0.75)
#
	#bar.modulate = Color.WHITE if completion >= 100.0 else Color.GRAY
#
	#if completion >= 100.0:
		#area_completed.emit()
