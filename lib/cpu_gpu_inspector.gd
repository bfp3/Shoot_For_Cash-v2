extends Node

## Toggle with `toggle_cpu_gpu_inspection` (Shift+. / `>`).
## Godot cannot count raw CPU or GPU machine instructions. This logs the closest
## portable workload: CPU time, GPU time, and GPU command volume (draw calls /
## primitives / objects) for the last frame and the last second.
## Inactive cost is input-only. Sampling and GPU timestamps run only while on.
## Debug / editor builds only (`OS.is_debug_build()`).

const ACTION := &"toggle_cpu_gpu_inspection"
const WINDOW_USEC := 1_000_000
const LOG_PREFIX := "[CpuGpu]"


var _active := false
var _viewport_rids: Array[RID] = []
var _window_start_usec := 0
var _frames := 0

var _last_process_ms := 0.0
var _last_physics_ms := 0.0
var _last_submit_ms := 0.0
var _last_gpu_ms := 0.0
var _last_draws := 0
var _last_prims := 0
var _last_objects := 0

var _sum_process_ms := 0.0
var _sum_physics_ms := 0.0
var _sum_submit_ms := 0.0
var _sum_gpu_ms := 0.0
var _sum_draws := 0
var _sum_prims := 0
var _sum_objects := 0

var _min_process_ms := INF
var _max_process_ms := 0.0
var _min_gpu_ms := INF
var _max_gpu_ms := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	if not OS.is_debug_build():
		set_process_input(false)


func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if not event.is_action_pressed(ACTION) or event.is_echo():
		return
	if _is_typing_in_ui():
		return
	_set_active(not _active)
	get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _active:
		return
	_sample_frame()
	if Time.get_ticks_usec() - _window_start_usec >= WINDOW_USEC:
		_print_window(false)
		_reset_window()


func _set_active(value: bool) -> void:
	if _active == value:
		return
	_active = value
	set_process(value)
	_set_measure_render_time(value)
	if value:
		_reset_window()
		print("%s ON — logging once per second. Press the toggle again to stop." % LOG_PREFIX)
		print("%s Godot cannot count raw CPU/GPU instructions. This is time + GPU commands." % LOG_PREFIX)
		print("%s CPU=%s  GPU=%s" % [
			LOG_PREFIX,
			OS.get_processor_name(),
			RenderingServer.get_video_adapter_name(),
		])
	else:
		if _frames > 0:
			_print_window(true)
		print("%s OFF" % LOG_PREFIX)


func _sample_frame() -> void:
	var process_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var submit_ms := RenderingServer.get_frame_setup_time_cpu()
	var gpu_ms := 0.0
	for rid in _viewport_rids:
		if not rid.is_valid():
			continue
		submit_ms += RenderingServer.viewport_get_measured_render_time_cpu(rid)
		gpu_ms += RenderingServer.viewport_get_measured_render_time_gpu(rid)

	var draws := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var prims := int(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME))
	var objects := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))

	_last_process_ms = process_ms
	_last_physics_ms = physics_ms
	_last_submit_ms = submit_ms
	_last_gpu_ms = gpu_ms
	_last_draws = draws
	_last_prims = prims
	_last_objects = objects

	_frames += 1
	_sum_process_ms += process_ms
	_sum_physics_ms += physics_ms
	_sum_submit_ms += submit_ms
	_sum_gpu_ms += gpu_ms
	_sum_draws += draws
	_sum_prims += prims
	_sum_objects += objects

	_min_process_ms = minf(_min_process_ms, process_ms)
	_max_process_ms = maxf(_max_process_ms, process_ms)
	_min_gpu_ms = minf(_min_gpu_ms, gpu_ms)
	_max_gpu_ms = maxf(_max_gpu_ms, gpu_ms)


func _print_window(partial: bool) -> void:
	if _frames <= 0:
		return
	var elapsed_sec := float(Time.get_ticks_usec() - _window_start_usec) / 1000000.0
	var fps := float(_frames) / maxf(elapsed_sec, 0.0001)
	var inv_frames := 1.0 / float(_frames)
	var tag := "partial" if partial else "1s"
	print("%s === %s  %.2fs  %d frames  (%.0f fps) ===" % [LOG_PREFIX, tag, elapsed_sec, _frames, fps])
	print("%s last frame   CPU process=%.2fms physics=%.2fms submit=%.2fms  |  GPU=%.2fms  draws=%d prims=%s objects=%d" % [
		LOG_PREFIX,
		_last_process_ms,
		_last_physics_ms,
		_last_submit_ms,
		_last_gpu_ms,
		_last_draws,
		_format_count(_last_prims),
		_last_objects,
	])
	print("%s %s CPU       process avg=%.2fms (min %.2f max %.2f)  physics avg=%.2fms  submit avg=%.2fms" % [
		LOG_PREFIX,
		tag,
		_sum_process_ms * inv_frames,
		_min_process_ms,
		_max_process_ms,
		_sum_physics_ms * inv_frames,
		_sum_submit_ms * inv_frames,
	])
	print("%s %s GPU       avg=%.2fms (min %.2f max %.2f)  sum=%.1fms  |  draws=%s  prims=%s  objects=%s" % [
		LOG_PREFIX,
		tag,
		_sum_gpu_ms * inv_frames,
		_min_gpu_ms,
		_max_gpu_ms,
		_sum_gpu_ms,
		_format_count(_sum_draws),
		_format_count(_sum_prims),
		_format_count(_sum_objects),
	])


func _reset_window() -> void:
	_window_start_usec = Time.get_ticks_usec()
	_frames = 0
	_sum_process_ms = 0.0
	_sum_physics_ms = 0.0
	_sum_submit_ms = 0.0
	_sum_gpu_ms = 0.0
	_sum_draws = 0
	_sum_prims = 0
	_sum_objects = 0
	_min_process_ms = INF
	_max_process_ms = 0.0
	_min_gpu_ms = INF
	_max_gpu_ms = 0.0
	_refresh_viewport_rids()


func _set_measure_render_time(enabled: bool) -> void:
	_refresh_viewport_rids()
	for rid in _viewport_rids:
		if rid.is_valid():
			RenderingServer.viewport_set_measure_render_time(rid, enabled)
	if not enabled:
		_viewport_rids.clear()


func _refresh_viewport_rids() -> void:
	_viewport_rids.clear()
	var root := get_tree().root if get_tree() else null
	if root == null:
		return
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Viewport:
			var rid: RID = (node as Viewport).get_viewport_rid()
			if rid.is_valid() and not _viewport_rids.has(rid):
				_viewport_rids.append(rid)
				if _active:
					RenderingServer.viewport_set_measure_render_time(rid, true)
		for child in node.get_children():
			stack.append(child)


func _is_typing_in_ui() -> bool:
	var vp := get_viewport()
	var focus := vp.gui_get_focus_owner() if vp else null
	if focus is LineEdit or focus is TextEdit or focus is CodeEdit:
		return true
	var chat := get_tree().get_first_node_in_group("debug_tool_chatbox")
	if chat != null and chat.has_method("is_open") and chat.call("is_open"):
		return true
	return false


func _format_count(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3, 3) + out
		s = s.substr(0, s.length() - 3)
	if n < 0:
		return "-" + s + out
	return s + out
