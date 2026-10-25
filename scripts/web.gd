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

# the version that was found on the server, empty when there is no update
var available_version: String = ""
var _manual_update_requested: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


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
		if OS.has_feature("mobile"):
			# Android will always ask the user to confirm an APK installation.
			# Opening the APK URL lets Android/the browser hand that flow to the
			# package installer instead of opening the website homepage.
			OS.shell_open(SITE_URL + ANDROID_DOWNLOAD)
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


# Downloads the new Windows archive after this process exits, replaces the
# executable and PCK, then starts the updated game again. A running Windows
# executable cannot overwrite itself, so a short PowerShell helper performs
# the replacement after the game has closed.
func _start_windows_update() -> void:
	var executable := OS.get_executable_path()
	var install_dir := executable.get_base_dir()
	var script_path := OS.get_user_data_dir().path_join("mt_space_updater.ps1")
	var zip_path := OS.get_user_data_dir().path_join("mt_space_update.zip")
	var stage_dir := OS.get_user_data_dir().path_join("mt_space_update_stage")
	var dialog_scene := preload("res://scenes/update_dialog.tscn")
	var dialog := dialog_scene.instantiate()
	get_tree().current_scene.add_child(dialog)
	if dialog.has_method("show_progress"):
		dialog.show_progress("Đang tải bản cập nhật...")
	var q := func(value: String) -> String:
		return "'" + value.replace("'", "''") + "'"
	var script := """
$ErrorActionPreference = 'Stop'
$root = %s
$zip = %s
$stage = %s
$exe = %s
$url = %s
Start-Sleep -Milliseconds 500
while (Get-Process -Id %d -ErrorAction SilentlyContinue) { Start-Sleep -Milliseconds 250 }
try {
    Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    $ProgressPreference = 'SilentlyContinue'
    Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing
    Expand-Archive -LiteralPath $zip -DestinationPath $stage -Force
    Copy-Item -LiteralPath (Join-Path $stage 'mt-space.exe') -Destination (Join-Path $root 'mt-space.exe') -Force
    Copy-Item -LiteralPath (Join-Path $stage 'mt-space.pck') -Destination (Join-Path $root 'mt-space.pck') -Force
    Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
    $marker = Join-Path $root 'mt_space_update_ready.flag'
    New-Item -ItemType File -Path $marker -Force | Out-Null
} catch {
}
Remove-Item -LiteralPath $PSCommandPath -Force -ErrorAction SilentlyContinue
""" % [q.call(install_dir), q.call(zip_path), q.call(stage_dir),
		q.call(executable), q.call(SITE_URL + WINDOWS_DOWNLOAD), OS.get_process_id()]
	var file := FileAccess.open(script_path, FileAccess.WRITE)
	if file == null:
		OS.shell_open(SITE_URL + WINDOWS_DOWNLOAD)
		if dialog and is_instance_valid(dialog):
			dialog.queue_free()
		return
	file.store_string(script)
	file.close()
	OS.create_process("powershell.exe", ["-NoProfile", "-ExecutionPolicy", "Bypass", "-WindowStyle", "Hidden", "-File", script_path])
	_start_update_monitor(dialog, install_dir)


func _start_update_monitor(dialog: Node, install_dir: String) -> void:
	var t := Timer.new()
	t.wait_time = 0.5
	t.one_shot = false
	var executable := OS.get_executable_path()
	var marker_path := install_dir.path_join("mt_space_update_ready.flag")
	add_child(t)
	t.timeout.connect(func():
		if FileAccess.file_exists(marker_path):
			t.stop()
			t.queue_free()
			if dialog and is_instance_valid(dialog):
				if dialog.has_method("show_ready_to_launch"):
					dialog.show_ready_to_launch()
				dialog.confirmed_launch.connect(func():
					_launch_updated_game(executable)
				)
				dialog.cancelled.connect(func():
					pass
				)
	)
	t.start()


func _launch_updated_game(executable: String) -> void:
	get_tree().quit()
	OS.create_process(executable, [])
