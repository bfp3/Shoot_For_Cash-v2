class_name BulletAmountDisplay extends Control

@export var upgrade_name_label: Label
@export var icon: TextureRect
@export var progress_bar_container: HBoxContainer 
@export var purchase_progress_bar : ProgressBar

@export var upgrade_panel : Button
@export var tooltip : Tooltip
@export var description : String

@export var focus_enter_sfx: AudioStreamPlayer
@export var focus_exit_sfx: AudioStreamPlayer

var current_upgrade_level := 0
var max_upgrade_level := 10
var current_bullet_amount := 1

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	rename_self()
	reset_progress_bars()

func rename_self() -> void:
	if upgrade_name_label:
		upgrade_name_label.text = self.name



func reset_progress_bars() -> void:
	if !progress_bar_container:
		return
	
	for bar in progress_bar_container.get_children():
		bar.value = 0


func upgrade() -> void:
	if current_upgrade_level >= max_upgrade_level:
		return
	
	await start_upgrade_tween()
	current_upgrade_level += 1
	
	
func start_upgrade_tween() -> void:
	var bar: ProgressBar = progress_bar_container.get_child(current_upgrade_level)
	
	var tween := create_tween()
	tween.tween_property($Control/UpgradePanel, "modulate", GlobalColorPalet.Global_color_money, 0.2)
	tween.tween_interval(0.3)
	tween.tween_property(bar, "value", 100, 0.3)
	tween.tween_interval(0.2)
	tween.tween_property($Control/UpgradePanel, "modulate", GlobalColorPalet.Global_color_white, 1.0)

	await tween.finished
	return
