@tool
extends EditorPlugin

const FacebookExportPlatform = preload("res://addons/facebook_instant_export/editor/facebook_export_platform.gd")

var export_platform: EditorExportPlatformExtension


func _enter_tree() -> void:
	export_platform = FacebookExportPlatform.new()
	add_export_platform(export_platform)
	print("Facebook Instant Export: platform registered")


func _exit_tree() -> void:
	if export_platform:
		remove_export_platform(export_platform)
		export_platform = null
		print("Facebook Instant Export: platform removed")
