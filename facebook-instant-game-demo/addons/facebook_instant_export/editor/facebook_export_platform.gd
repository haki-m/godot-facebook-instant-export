@tool
extends EditorExportPlatformExtension

const PLATFORM_LOGO = preload("res://addons/facebook_instant_export/assets/icon.png")
const HTML_TEMPLATE_PATH = "res://addons/facebook_instant_export/web/index.template.html"

var _zip: ZIPPacker = null
var _export_failed: Error = OK


func _get_name() -> String:
	return "Facebook Instant Game"


func _get_os_name() -> String:
	return "Web"


func _get_logo() -> Texture2D:
	return PLATFORM_LOGO


func _get_binary_extensions(preset: EditorExportPreset) -> PackedStringArray:
	return PackedStringArray(["zip"])


func _get_platform_features() -> PackedStringArray:
	return PackedStringArray(["web", "facebook_instant"])


func _get_preset_features(preset: EditorExportPreset) -> PackedStringArray:
	return PackedStringArray(["web", "facebook_instant"])

func _build_fbapp_config_json() -> String:
	return JSON.stringify({
		"instant_games": {
			"platform_version": "RICH_GAMEPLAY",
			"navigation_menu_version": "NAV_BAR"
		}
	}, "\t")



func _get_export_options() -> Array[Dictionary]:
	return [
		{
			"name": "facebook/app_id",
			"type": TYPE_STRING,
			"default_value": "",
			"usage": PROPERTY_USAGE_DEFAULT,
			"required": false
		},
		{
			"name": "web/output_basename",
			"type": TYPE_STRING,
			"default_value": "game",
			"usage": PROPERTY_USAGE_DEFAULT,
			"required": true
		}
	]
func _get_string_option(preset: EditorExportPreset, name: String, fallback: String = "") -> String:
	var value = preset.get(name)
	if value == null:
		return fallback
	return str(value)

func _get_export_option_visibility(preset: EditorExportPreset, option: String) -> bool:
	return true


func _get_export_option_warning(preset: EditorExportPreset, option: StringName) -> String:
	return ""


func _has_valid_export_configuration(preset: EditorExportPreset, debug: bool) -> bool:
	if not FileAccess.file_exists(HTML_TEMPLATE_PATH):
		set_config_error("Missing HTML template: " + HTML_TEMPLATE_PATH)
		return false

	return true


func _has_valid_project_configuration(preset: EditorExportPreset) -> bool:
	return true


func _export_project(
	preset: EditorExportPreset,
	debug: bool,
	path: String,
	flags: int
) -> Error:
	_zip = ZIPPacker.new()

	var err := _zip.open(path)
	if err != OK:
		push_error("Facebook Instant Export: failed to open ZIP: " + str(err))
		return err

	var basename := _get_string_option(preset, "web/output_basename", "game")

	var html_template := _load_html_template()
	if html_template == "":
		_close_zip_safely()
		return ERR_FILE_CANT_READ

	var html := _apply_template_variables(html_template, _build_template_values(preset))

	err = _write_text_file("index.html", html)
	if err != OK:
		_close_zip_safely()
		return err
	err = _write_text_file("fbapp-config.json", _build_fbapp_config_json())
	if err != OK:
		_close_zip_safely()
		return err
	err = _add_web_runtime_files_to_zip(debug, basename)
	if err != OK:
		_close_zip_safely()
		return err

	err = _add_pck_to_zip(preset, debug, basename)
	if err != OK:
		_close_zip_safely()
		return err

	err = _write_text_file("README.txt", _build_readme_text())
	if err != OK:
		_close_zip_safely()
		return err

	err = _zip.close()
	if err != OK:
		push_error("Facebook Instant Export: failed to finalize ZIP: " + str(err))
		return err

	print("Facebook Instant Export: ZIP created at ", path)
	return OK
func _get_web_template_name(debug: bool) -> String:
	if debug:
		return "web_nothreads_debug.zip"
	return "web_nothreads_release.zip"


func _add_web_runtime_files_to_zip(debug: bool, basename: String) -> Error:
	var template_name := _get_web_template_name(debug)
	var template_info: Dictionary = find_export_template(template_name)
	var template_path := str(template_info.get("path", ""))
	var template_error := str(template_info.get("error", ""))

	if template_path == "":
		push_error("Facebook Instant Export: missing export template " + template_name + " | " + template_error)
		return ERR_FILE_NOT_FOUND

	var reader := ZIPReader.new()
	var err := reader.open(template_path)
	if err != OK:
		push_error("Facebook Instant Export: failed to open template ZIP: " + template_path + " | " + str(err))
		return err

	var files := reader.get_files()
	var js_entry := ""
	var wasm_entry := ""
	var audio_worklet_entry := ""

	for file_path in files:
		if file_path.ends_with(".wasm") and wasm_entry == "":
			wasm_entry = file_path
			continue

		if file_path.ends_with(".audio.worklet.js") and audio_worklet_entry == "":
			audio_worklet_entry = file_path
			continue

		if file_path.ends_with(".js") and not file_path.ends_with(".audio.worklet.js") and not file_path.ends_with(".worker.js") and js_entry == "":
			js_entry = file_path

	if js_entry == "" or wasm_entry == "":
		reader.close()
		push_error("Facebook Instant Export: could not find JS/WASM inside " + template_name)
		return ERR_FILE_NOT_FOUND

	err = _write_binary_file(basename + ".js", reader.read_file(js_entry))
	if err != OK:
		reader.close()
		return err

	err = _write_binary_file(basename + ".wasm", reader.read_file(wasm_entry))
	if err != OK:
		reader.close()
		return err

	if audio_worklet_entry != "":
		err = _write_binary_file(basename + ".audio.worklet.js", reader.read_file(audio_worklet_entry))
		if err != OK:
			reader.close()
			return err

	reader.close()
	return OK


func _add_pck_to_zip(preset: EditorExportPreset, debug: bool, basename: String) -> Error:
	var temp_dir := "user://facebook_instant_export_temp"
	var temp_pck_path := temp_dir.path_join(basename + ".pck")
	var abs_temp_pck_path := ProjectSettings.globalize_path(temp_pck_path)

	DirAccess.make_dir_absolute(temp_dir)

	var pack_result: Dictionary = save_pack(preset, debug, abs_temp_pck_path)
	var result_code := int(pack_result.get("result", FAILED))
	if result_code != OK:
		push_error("Facebook Instant Export: save_pack failed: " + str(result_code))
		return result_code

	var file := FileAccess.open(abs_temp_pck_path, FileAccess.READ)
	if file == null:
		push_error("Facebook Instant Export: failed to open generated PCK: " + abs_temp_pck_path)
		return ERR_FILE_CANT_READ

	var pck_data := file.get_buffer(file.get_length())
	file.close()

	return _write_binary_file(basename + ".pck", pck_data)


func _write_binary_file(zip_path: String, data: PackedByteArray) -> Error:
	var err := _zip.start_file(zip_path)
	if err != OK:
		push_error("Facebook Instant Export: failed to start " + zip_path + ": " + str(err))
		return err

	err = _zip.write_file(data)
	if err != OK:
		_zip.close_file()
		push_error("Facebook Instant Export: failed to write " + zip_path + ": " + str(err))
		return err

	err = _zip.close_file()
	if err != OK:
		push_error("Facebook Instant Export: failed to close " + zip_path + ": " + str(err))
		return err

	return OK

	





func _save_exported_file(
	file_path: String,
	file_data: PackedByteArray,
	file_index: int,
	file_count: int,
	encryption_include_filters: PackedStringArray,
	encryption_exclude_filters: PackedStringArray,
	encryption_key: PackedByteArray
) -> void:
	if _export_failed != OK:
		return

	if _should_skip_file(file_path):
		return

	var relative_path := file_path
	if relative_path.begins_with("res://"):
		relative_path = relative_path.substr(6)

	var zip_path := "game/" + relative_path

	var err := _zip.start_file(zip_path)
	if err != OK:
		_export_failed = err
		return

	err = _zip.write_file(file_data)
	if err != OK:
		_zip.close_file()
		_export_failed = err
		return

	err = _zip.close_file()
	if err != OK:
		_export_failed = err
		return

	if file_count > 0 and file_index % 25 == 0:
		print("Facebook Instant Export: packed ", file_index, " / ", file_count, " files")


func _should_skip_file(file_path: String) -> bool:
	if file_path == "res://addons/facebook_instant_export/plugin.cfg":
		return true

	if file_path == "res://addons/facebook_instant_export/plugin.gd":
		return true

	if file_path.begins_with("res://addons/facebook_instant_export/editor/"):
		return true

	if file_path.begins_with("res://addons/facebook_instant_export/assets/"):
		return true

	if file_path.begins_with("res://addons/facebook_instant_export/web/"):
		return true

	return false


func _load_html_template() -> String:
	if not FileAccess.file_exists(HTML_TEMPLATE_PATH):
		push_error("Facebook Instant Export: HTML template not found: " + HTML_TEMPLATE_PATH)
		return ""

	var file := FileAccess.open(HTML_TEMPLATE_PATH, FileAccess.READ)
	if file == null:
		push_error(
			"Facebook Instant Export: failed to open HTML template: "
			+ HTML_TEMPLATE_PATH
			+ " | open_error="
			+ str(FileAccess.get_open_error())
		)
		return ""

	return file.get_as_text()

func _build_template_values(preset: EditorExportPreset) -> Dictionary:
	var game_title := str(ProjectSettings.get_setting("application/config/name", "Godot Game"))
	var basename := _get_string_option(preset, "web/output_basename", "game")

	return {
		"{{GAME_TITLE}}": game_title,
		"{{BASENAME}}": basename,
		"{{JS_NAME}}": basename + ".js",
		"{{WASM_NAME}}": basename + ".wasm",
		"{{PCK_NAME}}": basename + ".pck",
		"{{APP_ID}}": _get_string_option(preset, "facebook/app_id", "")
	}

func _apply_template_variables(template_text: String, values: Dictionary) -> String:
	var result := template_text

	for key in values.keys():
		result = result.replace(str(key), str(values[key]))

	return result


func _write_text_file(zip_path: String, content: String) -> Error:
	var err := _zip.start_file(zip_path)
	if err != OK:
		push_error("Facebook Instant Export: failed to start " + zip_path + ": " + str(err))
		return err

	err = _zip.write_file(content.to_utf8_buffer())
	if err != OK:
		_zip.close_file()
		push_error("Facebook Instant Export: failed to write " + zip_path + ": " + str(err))
		return err

	err = _zip.close_file()
	if err != OK:
		push_error("Facebook Instant Export: failed to close " + zip_path + ": " + str(err))
		return err

	return OK


func _close_zip_safely() -> void:
	if _zip:
		_zip.close()


func _build_readme_text() -> String:
	return """Facebook Instant Export Test

This ZIP was generated by the custom Godot export platform.

Current status:
- Export platform registration works
- Export button creates a ZIP
- index.html is generated from web/index.template.html
- Exported project files are packed under game/
- Editor-side addon files are skipped
- Template variables are replaced at export time

Next step:
- Add a real Godot Web startup shell
- Add Web runtime files needed to boot the game
- Later add FBInstant startup integration
"""
