extends Node

# The little helpers that only make sense in a browser.
#
# The desktop build has a real window, so the fullscreen button asks the
# window manager. In a browser the page itself has to go fullscreen, which
# only the page can do, so the request goes through the javascript bridge.

# a new version is up there, the player can update
signal update_available(version: String)

# the file on the server that says which version is up there
const REMOTE_VERSION := "version.txt"
# the file inside the build that says which version this build is
const LOCAL_VERSION := "res://version_embedded.txt"
const SITE_URL := "https://lmt1102011.github.io/MT-Space/"
const WINDOWS_DOWNLOAD := "downloads/mt-space-windows.zip"
const ANDROID_DOWNLOAD := "downloads/mt-space-android.apk"
const ANDROID_UPDATE_MANIFEST := "android-update.json"
const ANDROID_UPDATE_DIRECTORY := "mt_space_updates"
const ANDROID_UPDATE_FILE := "mt-space-android.apk"

# the version that was found on the server, empty when there is no update
var available_version: String = ""
var _manual_update_requested: bool = false
var _windows_download_request: HTTPRequest
var _windows_download_dialog: Node
var _windows_download_file: String = ""
var _android_download_request: HTTPRequest
var _android_download_dialog: Node
var _android_download_file: String = ""
var _android_update_file: String = ""
var _android_update_version: String = ""
var _android_update_sha256: String = ""
var _android_update_size: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	_update_windows_download_progress()
	_update_android_download_progress()


func is_web() -> bool:
	return OS.has_feature("web")


# True when the page was loaded over https. A secure page is not allowed to
# open a plain ws:// connection, only a wss:// one.
func page_is_secure() -> bool:
	if not is_web():
		return false
	if not ClassDB.class_exists("JavaScriptBridge"):
		return false
	return str(JavaScriptBridge.eval("window.location.protocol", true)) == "https:"


# Puts the game in fullscreen, or brings it back out of it.
func toggle_fullscreen() -> void:
	if is_web():
		_toggle_web_fullscreen()
		return
	if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func is_fullscreen() -> bool:
	if is_web():
		return _web_is_fullscreen()
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


# --- the browser -----------------------------------------------------------
func _toggle_web_fullscreen() -> void:
	if not ClassDB.class_exists("JavaScriptBridge"):
		return
	var js := """
	(function() {
		var el = document.documentElement;
		if (!document.fullscreenElement) {
			if (el.requestFullscreen) { el.requestFullscreen(); }
		} else if (document.exitFullscreen) {
			document.exitFullscreen();
		}
	})();
	"""
	JavaScriptBridge.eval(js, true)


func _web_is_fullscreen() -> bool:
	if not ClassDB.class_exists("JavaScriptBridge"):
		return false
	return bool(JavaScriptBridge.eval("document.fullscreenElement !== null", true))


# --- the new version check -------------------------------------------------
# Asks the server which version is up there. When it is newer than the one
# that is running, the page reloads itself and the new one takes over.
func check_for_new_version() -> void:
	var version_url := _version_url()
	if version_url == "":
		return
	var url := version_url + "?t=" + str(Time.get_unix_time_from_system())
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = 8.0
	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			_manual_update_requested = false
			return
		var remote := body.get_string_from_utf8().strip_edges()
		if remote == "":
			_manual_update_requested = false
			return
		_check_version(remote)
		if _manual_update_requested:
			_manual_update_requested = false
			if has_update():
				apply_update()
	)
	http.request(url)


# Called only after the player presses the Update button. There is no
# background update check and discovering a new version never installs it by
# itself.
func request_update() -> void:
	if available_version != "":
		apply_update()
		return
	_manual_update_requested = true
	check_for_new_version()


# The version file sits one folder above the game page (the game lives in
# /game/, the file is at the site root). The browser resolves it, so the
# address also works when the site is hosted in a sub folder.
func _version_url() -> String:
	if not is_web():
		return SITE_URL + REMOTE_VERSION
	if not ClassDB.class_exists("JavaScriptBridge"):
		return ""
	var js := """
	(function() {
		try { return new URL('../version.txt', window.location.href).href; }
		catch (e) { return ''; }
	})();
	"""
	return str(JavaScriptBridge.eval(js, true))


# Compares the version on the server with the one that is running.
func _check_version(remote: String) -> void:
	var mine := _embedded_version()
	if mine == "":
		# the build does not know its own version, so the last one that was
		# seen in the browser is used instead
		mine = _stored_version()
		if mine == "":
			_store_version(remote)
			return
	if remote == mine:
		return
	if available_version == remote:
		return
	# a new version is up there: the button shows up, the player decides
	available_version = remote
	print("[web] a new version is up there: ", remote)
	_show_update_button(remote)
	update_available.emit(remote)


# True when the check found a version that is not the one running.
func has_update() -> bool:
	return available_version != ""


# Shows the button that updates the game.
func _show_update_button(version: String) -> void:
	if not ClassDB.class_exists("JavaScriptBridge"):
		return
	var js := "(function(){ if (window.showUpdateButton) { window.showUpdateButton('%s'); } })();" % version
	JavaScriptBridge.eval(js, true)


# The lobby has no button of its own, so it uses the one on the page.
func show_web_update_button() -> void:
	if available_version != "":
		_show_update_button(available_version)


# A scene with its own update button hides the one on the page, so the same
# update is not offered twice.
func hide_web_update_button() -> void:
	if not ClassDB.class_exists("JavaScriptBridge"):
		return
	JavaScriptBridge.eval("(function(){ if (window.hideUpdateButton) { window.hideUpdateButton(); } })();", true)


# The version of the build that is running, written into the build itself.
func _embedded_version() -> String:
	if not FileAccess.file_exists(LOCAL_VERSION):
		return ""
	var f := FileAccess.open(LOCAL_VERSION, FileAccess.READ)
	if f == null:
		return ""
	var text := f.get_as_text().strip_edges()
	f.close()
	# the file can hold a bit more than the version, only the first line counts
	for line in text.split("\n"):
		var clean := line.strip_edges()
		if clean != "":
			return clean
	return ""


# Public getter so UI can display the embedded version.
func get_embedded_version() -> String:
	return _embedded_version()


# The version that was seen the last time, kept in the browser storage.
func _stored_version() -> String:
	if not ClassDB.class_exists("JavaScriptBridge"):
		return ""
	var js := """
	(function() {
		try { return window.localStorage.getItem('mt_space_version') || ''; }
		catch (e) { return ''; }
	})();
	"""
	return str(JavaScriptBridge.eval(js, true))


func _store_version(version: String) -> void:
	if not ClassDB.class_exists("JavaScriptBridge"):
		return
	var js := """
	(function() {
		try { window.localStorage.setItem('mt_space_version', '%s'); }
		catch (e) { }
	})();
	""" % version
	JavaScriptBridge.eval(js, true)


# Throws the old files away and starts the page again, so the new build is
# used. The player presses the button, so nothing changes while they play.
func apply_update() -> void:
	if not is_web():
		if _is_android():
			_start_android_update()
		else:
			_start_windows_update()
		return
	if not ClassDB.class_exists("JavaScriptBridge"):
		return
	var js := """
	(async function() {
		try {
			if (navigator.serviceWorker) {
				const regs = await navigator.serviceWorker.getRegistrations();
				for (const reg of regs) { await reg.unregister(); }
			}
			if (window.caches) {
				const keys = await caches.keys();
				for (const key of keys) { await caches.delete(key); }
			}
			try { window.localStorage.removeItem('mt_space_version'); } catch (e) { }
		} catch (e) { }
		window.location.replace(window.location.pathname + '?v=' + Date.now());
	})();
	"""
	JavaScriptBridge.eval(js, true)


func _is_android() -> bool:
	return OS.get_name() == "Android"


func _start_android_update() -> void:
	if _android_download_request != null \
			or (_android_download_dialog != null
			and is_instance_valid(_android_download_dialog)):
		return
	_android_update_file = OS.get_user_data_dir().path_join(
		ANDROID_UPDATE_DIRECTORY
	).path_join(ANDROID_UPDATE_FILE)
	var dialog_scene := preload("res://scenes/update_dialog.tscn")
	var dialog := dialog_scene.instantiate()
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene.add_child(dialog)
	_android_download_dialog = dialog
	dialog.cancelled.connect(_cancel_android_download)
	if _load_cached_android_update():
		_show_android_update_ready()
		return
	_remove_android_download_part()
	dialog.show_progress("Đang kiểm tra bản cập nhật...")

	var request := HTTPRequest.new()
	request.process_mode = Node.PROCESS_MODE_ALWAYS
	request.timeout = 30.0
	add_child(request)
	_android_download_request = request
	request.request_completed.connect(_on_android_manifest_received.bind(
		dialog, request
	))
	var error := request.request(SITE_URL + ANDROID_UPDATE_MANIFEST
		+ "?t=" + str(Time.get_unix_time_from_system()))
	if error != OK:
		_finish_android_download_error(
			dialog, request,
			"Không thể kiểm tra bản cập nhật. Hãy kiểm tra kết nối mạng rồi thử lại."
		)


func _on_android_manifest_received(result: int, response_code: int,
		_headers: PackedStringArray, body: PackedByteArray,
		dialog: Node, request: HTTPRequest) -> void:
	if request != _android_download_request:
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_finish_android_download_error(
			dialog, request,
			"Không thể kiểm tra bản cập nhật. Hãy kiểm tra kết nối mạng rồi thử lại."
		)
		return
	var manifest_text := body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(manifest_text)
	if not _is_valid_android_manifest(parsed, manifest_text):
		_finish_android_download_error(
			dialog, request, "Thông tin bản cập nhật không hợp lệ."
		)
		return
	var manifest: Dictionary = parsed
	_android_update_version = str(parsed["version"])
	_android_update_sha256 = str(parsed["sha256"]).to_lower()
	_android_update_size = _android_manifest_size(manifest, manifest_text)
	manifest["size"] = _android_update_size
	if _verify_android_update_file():
		_android_download_request = null
		request.queue_free()
		_show_android_update_ready()
		return
	var part_path := _android_update_file + ".part"
	var directory_error := DirAccess.make_dir_recursive_absolute(
		_android_update_file.get_base_dir()
	)
	if directory_error != OK and directory_error != ERR_ALREADY_EXISTS:
		_finish_android_download_error(
			dialog, request, "Không thể lưu bản cập nhật trên thiết bị."
		)
		return
	var manifest_file := FileAccess.open(
		_android_update_manifest_path(), FileAccess.WRITE
	)
	if manifest_file == null:
		_finish_android_download_error(
			dialog, request, "Không thể lưu thông tin xác minh bản cập nhật."
		)
		return
	manifest_file.store_string(JSON.stringify(manifest))
	manifest_file.close()
	if FileAccess.file_exists(_android_update_file):
		DirAccess.remove_absolute(_android_update_file)
	dialog.set_progress(0.0, "Đang tải bản cập nhật...")
	_android_download_request = null
	request.queue_free()
	_start_android_apk_download(dialog, part_path)


func _is_valid_android_manifest(value: Variant, raw_json: String = "") -> bool:
	if not value is Dictionary:
		return false
	var manifest: Dictionary = value
	var version := str(manifest.get("version", ""))
	var digest := str(manifest.get("sha256", "")).to_lower()
	if version.is_empty() or _android_manifest_size(manifest, raw_json) <= 0:
		return false
	if digest.length() != 64:
		return false
	for character in digest:
		if not "0123456789abcdef".contains(character):
			return false
	return true


func _android_manifest_size(manifest: Dictionary, raw_json: String = "") -> int:
	var size_value: Variant = manifest.get("size", 0)
	if size_value is int:
		return int(size_value)
	if size_value is String:
		var size_text := str(size_value)
		return size_text.to_int() if size_text.is_valid_int() else -1
	if not size_value is float or not is_finite(float(size_value)) \
			or float(size_value) <= 0.0:
		return -1
	var size_pattern := RegEx.new()
	var compile_error := size_pattern.compile("\"size\"\\s*:\\s*([0-9]+)")
	if compile_error != OK:
		push_error("Unable to compile Android manifest size pattern")
		return -1
	var size_match := size_pattern.search(raw_json)
	if size_match == null:
		return -1
	var exact_size_text := size_match.get_string(1)
	if not exact_size_text.is_valid_int() \
			or float(exact_size_text) != float(size_value):
		return -1
	return exact_size_text.to_int()


func _start_android_apk_download(dialog: Node, part_path: String) -> void:
	var request := HTTPRequest.new()
	request.process_mode = Node.PROCESS_MODE_ALWAYS
	request.timeout = 300.0
	request.download_file = part_path
	add_child(request)
	_android_download_request = request
	request.request_completed.connect(_on_android_apk_downloaded.bind(
		dialog, request, part_path
	))
	var error := request.request(SITE_URL + ANDROID_DOWNLOAD
		+ "?t=" + str(Time.get_unix_time_from_system()))
	if error != OK:
		_finish_android_download_error(
			dialog, request,
			"Không thể tải bản cập nhật. Hãy kiểm tra kết nối mạng rồi thử lại."
		)


func _update_android_download_progress() -> void:
	var request := _android_download_request
	var dialog := _android_download_dialog
	if request == null or not is_instance_valid(request) \
			or dialog == null or not is_instance_valid(dialog):
		return
	var downloaded := request.get_downloaded_bytes()
	var total := request.get_body_size()
	var locale := get_node_or_null("/root/Locale")
	var is_vietnamese: bool = locale != null \
		and str(locale.call("get_locale")) == "vi"
	var downloaded_mb := float(downloaded) / 1048576.0
	var text: String
	if total > 0:
		var total_mb := float(total) / 1048576.0
		var template := "Đang tải bản cập nhật: %.1f / %.1f MB" if is_vietnamese \
			else "Downloading update: %.1f / %.1f MB"
		text = template % [downloaded_mb, total_mb]
		dialog.set_progress(float(downloaded) * 100.0 / float(total), text)
	else:
		var template := "Đang tải bản cập nhật: %.1f MB" if is_vietnamese \
			else "Downloading update: %.1f MB"
		text = template % downloaded_mb
		var pulse := absf(fposmod(float(Time.get_ticks_msec()) / 12.0, 180.0) - 90.0) + 5.0
		dialog.set_progress(pulse, text, false)


func _on_android_apk_downloaded(result: int, response_code: int,
		_headers: PackedStringArray, _body: PackedByteArray,
		dialog: Node, request: HTTPRequest, part_path: String) -> void:
	if request != _android_download_request:
		return
	_android_download_request = null
	request.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("Android update download failed (result=%d, HTTP=%d)" % [
			result, response_code
		])
		_remove_android_download_part()
		_show_android_download_error(
			dialog,
			"Không thể tải bản cập nhật. Hãy kiểm tra kết nối mạng rồi thử lại."
		)
		return
	if not _verify_android_update_file(part_path):
		_remove_android_download_part()
		_show_android_download_error(
			dialog, "Bản tải về bị thiếu hoặc không hợp lệ. Hãy thử tải lại."
		)
		return
	var rename_error := DirAccess.rename_absolute(part_path, _android_update_file)
	if rename_error != OK:
		_remove_android_download_part()
		_show_android_download_error(
			dialog, "Không thể hoàn tất lưu bản cập nhật trên thiết bị."
		)
		return
	_show_android_update_ready()


func _verify_android_update_file(path: String = "") -> bool:
	var file_path := path if path != "" else _android_update_file
	if file_path == "" or not FileAccess.file_exists(file_path):
		return false
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return false
	if file.get_length() != _android_update_size:
		file.close()
		return false
	var hashing := HashingContext.new()
	var error := hashing.start(HashingContext.HASH_SHA256)
	if error != OK:
		file.close()
		return false
	while file.get_position() < file.get_length():
		var chunk := file.get_buffer(65536)
		if chunk.is_empty():
			file.close()
			return false
		hashing.update(chunk)
	file.close()
	return hashing.finish().hex_encode().to_lower() == _android_update_sha256


func _android_update_manifest_path() -> String:
	return _android_update_file.get_base_dir().path_join("manifest.json")


func _load_cached_android_update() -> bool:
	var manifest_path := _android_update_manifest_path()
	if not FileAccess.file_exists(manifest_path):
		return false
	var file := FileAccess.open(manifest_path, FileAccess.READ)
	if file == null:
		return false
	var manifest_text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(manifest_text)
	if not _is_valid_android_manifest(parsed, manifest_text):
		return false
	if available_version != "" and str(parsed["version"]) != available_version:
		return false
	_android_update_version = str(parsed["version"])
	_android_update_sha256 = str(parsed["sha256"]).to_lower()
	_android_update_size = _android_manifest_size(parsed, manifest_text)
	return _verify_android_update_file()


func _show_android_update_ready() -> void:
	var dialog := _android_download_dialog
	if dialog == null or not is_instance_valid(dialog):
		return
	_android_download_dialog = null
	dialog.confirmed_launch.connect(_install_android_update.bind(dialog))
	dialog.show_ready_to_launch(
		"Đã tải và xác minh APK. Android sẽ yêu cầu bạn xác nhận cài đặt."
	)


func _install_android_update(dialog: Node) -> void:
	if not _verify_android_update_file():
		_android_update_version = ""
		_android_update_sha256 = ""
		_android_update_size = 0
		if is_instance_valid(dialog):
			dialog.queue_free()
		_start_android_update()
		return
	if not Engine.has_singleton("MTSpaceAndroidUpdater"):
		dialog.show_download_error(
			"Không thể mở trình cài đặt Android. Hãy tải bản cập nhật từ trang web."
		)
		return
	var updater: Object = Engine.get_singleton("MTSpaceAndroidUpdater")
	if not bool(updater.call("canRequestInstallPackages")):
		updater.call("openInstallPermissionSettings")
		dialog.show_download_error(
			"Android yêu cầu cho phép MT Space cài ứng dụng. Bật quyền này trong Cài đặt, quay lại game rồi bấm cập nhật lần nữa."
		)
		return
	var install_error: Variant = updater.call("installApk", _android_update_file)
	if str(install_error) != "":
		dialog.show_download_error(
			"Không thể mở trình cài đặt Android: " + str(install_error)
		)
		return
	dialog.queue_free()
	_android_download_dialog = null


func _finish_android_download_error(
		dialog: Node, request: HTTPRequest, message: String) -> void:
	if request == _android_download_request:
		_android_download_request = null
	if is_instance_valid(request):
		request.queue_free()
	_show_android_download_error(dialog, message)


func _show_android_download_error(dialog: Node, message: String) -> void:
	_android_download_dialog = null
	if is_instance_valid(dialog):
		dialog.show_download_error(message)


func _cancel_android_download() -> void:
	var request := _android_download_request
	_android_download_request = null
	_android_download_dialog = null
	if request != null and is_instance_valid(request):
		request.cancel_request()
		request.queue_free()
	_remove_android_download_part()


func _remove_android_download_part() -> void:
	var part_path := _android_update_file + ".part"
	if _android_update_file != "" and FileAccess.file_exists(part_path):
		DirAccess.remove_absolute(part_path)


# Download the update while the game is running. The helper only replaces the
# executable after the player confirms and this process exits.
func _start_windows_update() -> void:
	if _windows_download_request != null:
		return
	var install_dir := OS.get_executable_path().get_base_dir()
	_windows_download_file = OS.get_user_data_dir().path_join("mt_space_update.zip")
	var dialog_scene := preload("res://scenes/update_dialog.tscn")
	var dialog := dialog_scene.instantiate()
	dialog.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().current_scene.add_child(dialog)
	_windows_download_dialog = dialog
	if dialog.has_method("show_progress"):
		dialog.show_progress("Đang tải bản cập nhật...")
	dialog.cancelled.connect(_cancel_windows_download)

	if FileAccess.file_exists(_windows_download_file):
		DirAccess.remove_absolute(_windows_download_file)
	var request := HTTPRequest.new()
	request.process_mode = Node.PROCESS_MODE_ALWAYS
	request.timeout = 180.0
	request.download_file = _windows_download_file
	add_child(request)
	_windows_download_request = request
	request.request_completed.connect(_on_windows_archive_downloaded.bind(
		dialog, request, install_dir
	))
	var error := request.request(SITE_URL + WINDOWS_DOWNLOAD)
	if error != OK:
		_windows_download_request = null
		request.queue_free()
		_show_windows_download_error(dialog,
			"Không thể tải bản cập nhật. Hãy kiểm tra kết nối mạng rồi thử lại.")


func _update_windows_download_progress() -> void:
	var request := _windows_download_request
	var dialog := _windows_download_dialog
	if request == null or not is_instance_valid(request) \
			or dialog == null or not is_instance_valid(dialog):
		return
	var downloaded := request.get_downloaded_bytes()
	var total := request.get_body_size()
	var locale := get_node_or_null("/root/Locale")
	var is_vietnamese: bool = locale != null \
		and str(locale.call("get_locale")) == "vi"
	var text: String
	if total > 0:
		var downloaded_mb := float(downloaded) / 1048576.0
		var total_mb := float(total) / 1048576.0
		var template := "Đang tải bản cập nhật: %.1f / %.1f MB" if is_vietnamese \
			else "Downloading update: %.1f / %.1f MB"
		text = template % [downloaded_mb, total_mb]
		dialog.set_progress(float(downloaded) * 100.0 / float(total), text)
	else:
		var downloaded_mb := float(downloaded) / 1048576.0
		var template := "Đang tải bản cập nhật: %.1f MB" if is_vietnamese \
			else "Downloading update: %.1f MB"
		text = template % downloaded_mb
		var pulse := absf(fposmod(float(Time.get_ticks_msec()) / 12.0, 180.0) - 90.0) + 5.0
		dialog.set_progress(pulse, text, false)


func _on_windows_archive_downloaded(result: int, response_code: int,
		_headers: PackedStringArray, _body: PackedByteArray,
		dialog: Node, request: HTTPRequest, install_dir: String) -> void:
	if request != _windows_download_request:
		return
	_windows_download_request = null
	request.queue_free()
	if not is_instance_valid(dialog):
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		push_warning("Windows update download failed (result=%d, HTTP=%d)" % [
			result, response_code
		])
		_remove_windows_download_file()
		_show_windows_download_error(dialog,
			"Không thể tải bản cập nhật. Hãy kiểm tra kết nối mạng rồi thử lại.")
		return
	var archive := FileAccess.open(_windows_download_file, FileAccess.READ)
	if archive == null or archive.get_length() <= 0:
		if archive != null:
			archive.close()
		_remove_windows_download_file()
		_show_windows_download_error(dialog,
			"Không thể tải bản cập nhật. Hãy kiểm tra kết nối mạng rồi thử lại.")
		return
	archive.close()

	var script_path := OS.get_user_data_dir().path_join("mt_space_updater.ps1")
	var script := _make_windows_update_script(
		install_dir, _windows_download_file, script_path
	)
	var script_file := FileAccess.open(script_path, FileAccess.WRITE)
	if script_file == null:
		_show_windows_download_error(dialog,
			"Không thể khởi chạy trình cập nhật. Bạn có thể tải bản Windows trực tiếp từ trang web.")
		return
	script_file.store_string(script)
	script_file.close()
	dialog.confirmed_launch.connect(_launch_updated_game.bind(script_path, dialog))
	_windows_download_dialog = null
	dialog.show_ready_to_launch()


func _show_windows_download_error(dialog: Node, message: String) -> void:
	_windows_download_dialog = null
	if is_instance_valid(dialog) and dialog.has_method("show_download_error"):
		dialog.show_download_error(message)


func _cancel_windows_download() -> void:
	var request := _windows_download_request
	_windows_download_request = null
	_windows_download_dialog = null
	if request != null and is_instance_valid(request):
		request.cancel_request()
		request.queue_free()
		_remove_windows_download_file()


func _remove_windows_download_file() -> void:
	if _windows_download_file != "" and FileAccess.file_exists(_windows_download_file):
		DirAccess.remove_absolute(_windows_download_file)


func _make_windows_update_script(install_dir: String, zip_path: String,
		script_path: String) -> String:
	var q := func(value: String) -> String:
		return "'" + value.replace("'", "''") + "'"
	var script := """
$ErrorActionPreference = 'Stop'
$root = %s
$zip = %s
$stage = Join-Path $env:TEMP 'mt_space_update_stage'
$url = %s
Start-Sleep -Milliseconds 700
while (Get-Process -Id %d -ErrorAction SilentlyContinue) {
    Start-Sleep -Milliseconds 250
}
try {
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    Expand-Archive -LiteralPath $zip -DestinationPath $stage -Force
    $newExe = Join-Path $stage 'mt-space.exe'
    $newPack = Join-Path $stage 'mt-space.pck'
    if (!(Test-Path -LiteralPath $newExe) -or !(Test-Path -LiteralPath $newPack)) {
        throw 'The downloaded archive is missing game files.'
    }
    Copy-Item -LiteralPath $newPack -Destination (Join-Path $root 'mt-space.pck') -Force
    Copy-Item -LiteralPath $newExe -Destination (Join-Path $root 'mt-space.exe') -Force
    Start-Process -FilePath (Join-Path $root 'mt-space.exe')
    Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath %s -Force -ErrorAction SilentlyContinue
} catch {
    $message = "MT Space could not install the update.`n" +
        $_.Exception.Message + "`nThe downloaded archive is here:`n" + $zip
    try {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show($message, 'MT Space updater') | Out-Null
    } catch {
        Start-Process -FilePath $url
    }
}
""" % [q.call(install_dir), q.call(zip_path),
		q.call(SITE_URL + WINDOWS_DOWNLOAD), OS.get_process_id(),
		q.call(script_path)]
	return script


func _launch_updated_game(script_path: String, dialog: Node) -> void:
	var process_id := OS.create_process("powershell.exe", [
		"-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden",
		"-File", script_path,
	])
	if process_id <= 0:
		dialog.show_download_error(
			"Không thể khởi chạy trình cập nhật. Bạn có thể tải bản Windows trực tiếp từ trang web."
		)
		return
	if is_instance_valid(dialog):
		dialog.queue_free()
	get_tree().quit()
