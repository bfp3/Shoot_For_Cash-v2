extends Node

## Instantiates heavy Main menus on first use so Main.tscn does not pay their cost at load.

const MENU_SCENES := {
	"tally": "res://ch/Tally_card/TallyCard_main.tscn",
	"pause": "res://ch/HUD_components/pause_and_exit_menu.tscn",
	"demo_end": "res://ch/demo_end_screen/Demo_end_screen.tscn",
	"game_over": "res://ch/demo_end_screen/Game_over_screen.tscn",
	"intro": "res://ch/demo_end_screen/Intro_prompt.tscn",
	"game_won": "res://ch/demo_end_screen/game_won_prompt.tscn",
	"grand_total": "res://ch/demo_end_screen/Grand_total_prompt.tscn",
	"ticket_map": "res://ch/Shop/MapIslandSelect.tscn",
	"difficulty_select": "res://ch/canvas_layers/start_menu_difficulty_select.tscn",
	"stage_complete": "res://ch/canvas_layers/stage_complete_screen.tscn",
	"debug_chat": "res://ch/HUD_components/debug_tool_chatbox.tscn",
}

@export var canvas_layer_path: NodePath = ^"../MainGameCanvasLayer"
@export var round_manager_path: NodePath = ^"../Round_manager"
@export var start_menu_path: NodePath = ^"../MainGameCanvasLayer/Start_menu_shop_clone"

var _instances: Dictionary = {} # key -> Node
var _packed_cache: Dictionary = {} # path -> PackedScene


func _ready() -> void:
	add_to_group("deferred_menu_loader")
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.is_debug_build():
		call_deferred("ensure_debug_chat")


func _unhandled_input(_event: InputEvent) -> void:
	# Until pause is instantiated, Escape/Pause would do nothing — bootstrap it here.
	var toggle_pause := Input.is_action_just_pressed("escape") or Input.is_action_just_pressed("pause")
	if not toggle_pause:
		return
	var debug_chat := get_tree().get_first_node_in_group("debug_tool_chatbox")
	if debug_chat and debug_chat.has_method("is_open") and debug_chat.is_open():
		return
	if get_tree().get_first_node_in_group("pause_menu") != null:
		return
	var pause := ensure_pause()
	if pause and pause.has_method("open_menu"):
		pause.open_menu()
		get_viewport().set_input_as_handled()


func ensure(key: String) -> Node:
	if _instances.has(key) and is_instance_valid(_instances[key]):
		return _instances[key]

	if not MENU_SCENES.has(key):
		push_error("DeferredMenuLoader: unknown menu '%s'" % key)
		return null

	var path: String = MENU_SCENES[key]
	var packed := _load_packed(path)
	if packed == null:
		push_error("DeferredMenuLoader: failed to load %s" % path)
		return null

	var inst: Node = packed.instantiate()
	_configure_instance(key, inst)
	_parent_instance(key, inst)
	_instances[key] = inst
	return inst


func ensure_tally() -> Control:
	return ensure("tally") as Control


func ensure_pause() -> Node:
	return ensure("pause")


func ensure_game_over() -> Control:
	return ensure("game_over") as Control


func ensure_ticket_map() -> Control:
	return ensure("ticket_map") as Control


func ensure_difficulty_select() -> Control:
	return ensure("difficulty_select") as Control


func ensure_stage_complete() -> CanvasLayer:
	return ensure("stage_complete") as CanvasLayer


func ensure_debug_chat() -> Node:
	if not OS.is_debug_build():
		return null
	return ensure("debug_chat")


func _load_packed(path: String) -> PackedScene:
	if _packed_cache.has(path):
		return _packed_cache[path] as PackedScene
	var packed := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REUSE) as PackedScene
	if packed:
		_packed_cache[path] = packed
	return packed


func _parent_instance(key: String, inst: Node) -> void:
	if key == "pause" or key == "debug_chat" or key == "stage_complete":
		# Pause / debug chat / stage complete sit beside Main content, not under HUD canvas.
		get_parent().add_child(inst)
		return
	var canvas := get_node_or_null(canvas_layer_path)
	if canvas:
		canvas.add_child(inst)
	else:
		add_child(inst)


func _configure_instance(key: String, inst: Node) -> void:
	var rm := get_node_or_null(round_manager_path)
	var start_menu := get_node_or_null(start_menu_path)

	match key:
		"tally":
			inst.name = "TallyCard"
			if inst is CanvasItem:
				(inst as CanvasItem).visible = false
			if inst is Control:
				(inst as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			inst.set("unique_name_in_owner", true)
			if rm and "round_manager" in inst:
				inst.set("round_manager", rm)
			if rm and "tally_menu" in rm:
				rm.set("tally_menu", inst)
		"pause":
			inst.name = "Settings_pause_menu"
		"debug_chat":
			inst.name = "DebugToolChatbox"
		"demo_end":
			inst.name = "DemoEndScreen"
			if inst is CanvasItem:
				(inst as CanvasItem).visible = false
		"game_over":
			inst.name = "Game_over_screen"
			if inst is CanvasItem:
				(inst as CanvasItem).visible = false
			if not inst.is_in_group("game_over_screen"):
				inst.add_to_group("game_over_screen")
		"intro":
			inst.name = "Intro_Prompt"
			if inst is CanvasItem:
				(inst as CanvasItem).visible = false
			if rm and "round_manager" in inst:
				inst.set("round_manager", rm)
		"game_won":
			inst.name = "Game_Won"
			if inst is CanvasItem:
				(inst as CanvasItem).visible = false
			inst.set("unique_name_in_owner", true)
		"grand_total":
			inst.name = "Grand_total_prompt"
			if inst is CanvasItem:
				(inst as CanvasItem).visible = false
			inst.set("unique_name_in_owner", true)
			if rm and "round_manager" in inst:
				inst.set("round_manager", rm)
		"ticket_map":
			inst.name = "MapIslandSelect"
			if inst is CanvasItem:
				(inst as CanvasItem).visible = false
				(inst as CanvasItem).z_index = 40
			inst.set("unique_name_in_owner", true)
			if start_menu and "game_start_menu" in inst:
				inst.set("game_start_menu", start_menu)
		"difficulty_select":
			inst.name = "StartMenuDifficultySelect"
			if inst is CanvasItem:
				(inst as CanvasItem).visible = false
				(inst as CanvasItem).z_index = 41
			if inst is Control:
				(inst as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		"stage_complete":
			inst.name = "StageCompleteScreen"
			if not inst.is_in_group("stage_complete_screen"):
				inst.add_to_group("stage_complete_screen")
			if inst is CanvasLayer:
				(inst as CanvasLayer).hide()
