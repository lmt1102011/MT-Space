@tool
extends EditorPlugin

var _export_plugin: AndroidExportPlugin


func _enter_tree() -> void:
	_export_plugin = AndroidExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


class AndroidExportPlugin extends EditorExportPlugin:
	const PLUGIN_NAME := "MTSpaceAndroidUpdater"
	const ANDROIDX_CORE := "androidx.core:core:1.15.0"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(
			_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		var build_type := "debug" if debug else "release"
		return PackedStringArray([
			"mt_space_android_updater/bin/%s/%s-%s.aar" % [
				build_type, PLUGIN_NAME, build_type
			]
		])

	func _get_android_dependencies(
			_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
		return PackedStringArray([ANDROIDX_CORE])

	func _get_name() -> String:
		return PLUGIN_NAME
