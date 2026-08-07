extends Node
## Early boot probe for export crashes at/near the Godot splash.
## Keep this autoload first so it runs before heavier systems.
func _ready() -> void:
	# #region agent log
	var screen_count := DisplayServer.get_screen_count()
	var initial_screen_setting := 1  # mirrors project.godot window/size/initial_screen
	var adapter := RenderingServer.get_video_adapter_name()
	var vendor := RenderingServer.get_video_adapter_vendor()
	var rendering_method := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "?"))
	var rendering_driver := str(ProjectSettings.get_setting(
		"rendering/rendering_device/driver." + OS.get_name().to_lower(),
		ProjectSettings.get_setting("rendering/rendering_device/driver", "?")
	))
	var data := {
		"os_name": OS.get_name(),
		"os_version": OS.get_version(),
		"video_adapter": adapter,
		"video_vendor": vendor,
		"rendering_method": rendering_method,
		"rendering_driver": rendering_driver,
		"screen_count": screen_count,
		"initial_screen_setting": initial_screen_setting,
		"initial_screen_out_of_range": initial_screen_setting >= screen_count,
		"window_mode": DisplayServer.window_get_mode(),
		"feature_vulkan": OS.has_feature("vulkan"),
		"feature_d3d12": OS.has_feature("d3d12"),
		"feature_opengl": OS.has_feature("opengl"),
		"executable_path": OS.get_executable_path(),
	}
	var payload := {
		"sessionId": "cfbf59",
		"runId": "boot-diag",
		"hypothesisId": "A-E",
		"location": "boot_diagnostics.gd:_ready",
		"message": "Boot reached GDScript (past engine/GPU init)",
		"data": data,
		"timestamp": Time.get_unix_time_from_system() * 1000.0,
	}
	var line := JSON.stringify(payload)
	print("[BootDiagnostics] ", line)
	var f := FileAccess.open("user://boot_diagnostics.ndjson", FileAccess.WRITE_READ)
	if f:
		f.seek_end()
		f.store_line(line)
		f.close()

	# HTTPRequest-based POST, replacing the invalid fetch(...) call.
	var http_request := HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(
		func(_result, _response_code, _headers, _body):
			http_request.queue_free()  # clean up after the request finishes, success or not
	)
	var headers := [
		"Content-Type: application/json",
		"X-Debug-Session-Id: cfbf59",
	]
	var error := http_request.request(
		"http://127.0.0.1:7811/ingest/df7a4400-5964-42bf-955d-caace07a39cd",
		headers,
		HTTPClient.METHOD_POST,
		line
	)
	if error != OK:
		http_request.queue_free()  # request() failed synchronously (e.g. bad URL), so no signal will fire
	# #endregion
