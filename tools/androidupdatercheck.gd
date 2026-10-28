extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var web := root.get_node("Web")
	var manifest := {
		"version": "test-build",
		"size": 3,
		"sha256": "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
	}
	_check(web.call("_is_valid_android_manifest", manifest),
		"accepts a well-formed Android update manifest")
	var published_manifest_text := \
		"{\"version\":\"0f4b49298327969cc01ada647ac74e13ff306104\"," \
		+ "\"version_code\":96,\"size\":153176721," \
		+ "\"sha256\":\"a9aa6ce5d284a91105ce26b8c6183291fd062572b9b27b430e5449e8cc39cffc\"}"
	var published_manifest: Variant = JSON.parse_string(published_manifest_text)
	_check(published_manifest is Dictionary
		and published_manifest.get("size") is float
		and web.call("_is_valid_android_manifest",
			published_manifest, published_manifest_text)
		and int(web.call("_android_manifest_size",
			published_manifest, published_manifest_text)) == 153176721,
		"accepts and exactly parses the published large APK size despite Godot JSON precision loss")
	published_manifest["size"] = "153176721"
	_check(web.call("_is_valid_android_manifest", published_manifest)
		and int(web.call("_android_manifest_size", published_manifest)) == 153176721,
		"accepts an exact decimal string APK size for future update manifests")
	manifest["sha256"] = "not-a-sha256"
	_check(not web.call("_is_valid_android_manifest", manifest),
		"rejects malformed Android update hashes")
	manifest["sha256"] = "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
	manifest["size"] = 0
	_check(not web.call("_is_valid_android_manifest", manifest),
		"rejects empty Android APK sizes")

	var test_path := OS.get_user_data_dir().path_join(
		"android-update-check-%d.apk" % Time.get_ticks_usec()
	)
	var test_file := FileAccess.open(test_path, FileAccess.WRITE)
	if test_file == null:
		_check(false, "creates a temporary APK hash test file")
	else:
		test_file.store_buffer(PackedByteArray([97, 98, 99]))
		test_file.close()
		web.set("_android_update_size", 3)
		web.set(
			"_android_update_sha256",
			"ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
		)
		web.set("_android_update_file", test_path)
		_check(web.call("_verify_android_update_file", test_path),
			"accepts an APK matching the manifest size and SHA-256")
		test_file = FileAccess.open(test_path, FileAccess.WRITE)
		test_file.store_buffer(PackedByteArray([97, 98, 100]))
		test_file.close()
		_check(not web.call("_verify_android_update_file", test_path),
			"rejects a modified APK before installation")
		DirAccess.remove_absolute(test_path)

	print("Android updater checks: ", _failures, " failure(s)")
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		_failures += 1
		push_error("FAIL: " + description)
