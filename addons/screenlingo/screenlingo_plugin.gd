@tool
extends EditorPlugin

## Registers Android plugin YOUR_ID_HERE (v2) in export: attaches AAR from bin/
## and remote ML Kit Maven dependencies to Godot's Gradle build.
## Manifest (permissions, service, activity, plugin meta-data) lives inside the AAR
## and is merged by Gradle automatically.

var _export_plugin: AndroidExportPlugin


func _enter_tree() -> void:
	_export_plugin = AndroidExportPlugin.new()
	add_export_plugin(_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(_export_plugin)
	_export_plugin = null


class AndroidExportPlugin extends EditorExportPlugin:
	const PLUGIN_NAME := "YOUR_ID_HERE"

	# Versions must match android_plugin/plugin/build.gradle.kts (compileOnly).
	const MLKIT_TEXT_RECOGNITION := "16.0.1"
	const MLKIT_LANGUAGE_ID := "17.0.6"
	const MLKIT_TRANSLATE := "17.0.3"

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	# Paths relative to res://addons/
	func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if debug:
			return PackedStringArray(["screenlingo/bin/YOUR_ID_HERE-debug.aar"])
		return PackedStringArray(["screenlingo/bin/YOUR_ID_HERE-release.aar"])

	func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray([
			# OCR (bundled models, work offline). Latin is primary,
			# others handle Chinese / Japanese / Korean text in games.
			"com.google.mlkit:text-recognition:%s" % MLKIT_TEXT_RECOGNITION,
			"com.google.mlkit:text-recognition-chinese:%s" % MLKIT_TEXT_RECOGNITION,
			"com.google.mlkit:text-recognition-japanese:%s" % MLKIT_TEXT_RECOGNITION,
			"com.google.mlkit:text-recognition-korean:%s" % MLKIT_TEXT_RECOGNITION,
			# Language identification and on-device translation.
			"com.google.mlkit:language-id:%s" % MLKIT_LANGUAGE_ID,
			"com.google.mlkit:translate:%s" % MLKIT_TRANSLATE,
		])

	func _get_android_dependencies_maven_repos(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		# ML Kit lives in google() which Godot template already includes, no extra repo needed.
		return PackedStringArray()

	func _get_name() -> String:
		return PLUGIN_NAME
