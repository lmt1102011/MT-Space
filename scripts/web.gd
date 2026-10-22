extends Node

# The little helpers that only make sense in a browser.
#
# The desktop build has a real window, so the fullscreen button asks the
# window manager. In a browser the page itself has to go fullscreen, which
# only the page can do, so the request goes through the javascript bridge.

# the file on the server that says which version is up there
const REMOTE_VERSION := "version.txt"
# the file inside the build that says which version this build is
const LOCAL_VERSION := "res://version_embedded.txt"

var _last_check: float = 0.0
# how many times the server was asked already
var _checks: int = 0
# how often the game asks the server whether there is a new version
const CHECK_EVERY := 60.0
# the version is checked a little after the game starts
const FIRST_CHECK := 8.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func is_web() -> bool:
	return OS.has_feature("web")


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
	if not is_web():
		return
	var url := REMOTE_VERSION + "?t=" + str(Time.get_unix_time_from_system())
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = 8.0
	http.request_completed.connect(func(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		if result != HTTPRequest.RESULT_SUCCESS or code != 200:
			return
		var remote := body.get_string_from_utf8().strip_edges()
		if remote == "":
			return
		_check_version(remote)
	)
	http.request(url)


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
	print("[web] a new version is up there: ", remote, " - reloading")
	_reload_page()


func _process(delta: float) -> void:
	_last_check += delta
	# the first check comes a little after the start, the next ones every
	# CHECK_EVERY seconds
	var limit := FIRST_CHECK if _checks == 0 else CHECK_EVERY
	if _last_check < limit:
		return
	_last_check = 0.0
	_checks += 1
	check_for_new_version()


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


func _reload_page() -> void:
	if not ClassDB.class_exists("JavaScriptBridge"):
		return
	# the old files have to go, otherwise the page starts the old build again
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
		window.location.reload(true);
	})();
	"""
	JavaScriptBridge.eval(js, true)
