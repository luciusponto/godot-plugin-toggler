@tool
extends EditorPlugin
var dock: Control

const DEFAULT_TARGET_PLUGIN = "scene_task_tracker"
const DEFAULT_TARGET_PLUGIN_SETTING = "plugin/plugin_toggler/default_target_plugin"
const REFRESH_TIMEOUT_MSEC = 2000
var _plugin_name_button: OptionButton
var _currently_selected_plugin: String
var _restart_button: Button
var _toggle_button: Button
var _plugin_list: Array[String]
var _is_dirty: bool = false
var _next_update_time_ms := 0

func _enter_tree():
	dock = Control.new()
	dock.name = "Plugin Toggler"
	dock.set_anchors_preset(Control.PRESET_FULL_RECT)
	var main_vbox = VBoxContainer.new()
	main_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	dock.add_child(main_vbox)
	var buttons_hbox = HBoxContainer.new()
	buttons_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_hbox = HBoxContainer.new()
	name_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	_toggle_button = Button.new()
	_toggle_button.text = "Toggle"
	_toggle_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_toggle_button.pressed.connect(_on_toggle_pressed)
	buttons_hbox.add_child(_toggle_button)
	_restart_button = Button.new()
	_restart_button.text = "Restart"
	_restart_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_restart_button.pressed.connect(_on_restart_pressed)
	buttons_hbox.add_child(_restart_button)
	
	_plugin_name_button = OptionButton.new()
	_plugin_name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_plugin_name_button.item_selected.connect(_on_plugin_selected)
	
	name_hbox.add_child(_plugin_name_button)
	main_vbox.add_child(buttons_hbox)
	main_vbox.add_child(name_hbox)	
	
	_refresh_plugin_list.call_deferred()
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_on_filesystem_changed)
	
	add_control_to_dock(EditorPlugin.DOCK_SLOT_RIGHT_BL, dock)
	set_process(true)

func _exit_tree():
	set_process(false)
	if is_instance_valid(dock):
		remove_control_from_docks(dock)
		dock.queue_free()
		dock = null

func _process(_delta):
	if _is_dirty and Time.get_ticks_msec() >= _next_update_time_ms:
		_is_dirty = false
		_next_update_time_ms = Time.get_ticks_msec() + REFRESH_TIMEOUT_MSEC
		_refresh_plugin_list()

func _get_default_target_plugin():
	var editor_settings = EditorInterface.get_editor_settings()
	if editor_settings.has_setting(DEFAULT_TARGET_PLUGIN_SETTING):
		return editor_settings.get_setting(DEFAULT_TARGET_PLUGIN_SETTING)
	else:
		editor_settings.set_setting(DEFAULT_TARGET_PLUGIN_SETTING, DEFAULT_TARGET_PLUGIN)
		return DEFAULT_TARGET_PLUGIN

func _has_plugin_list_changed(new_plugin_list: Array[String]):
	if new_plugin_list.size() != _plugin_list.size():
		return true
	for i in range(new_plugin_list.size()):
		if new_plugin_list[i] != _plugin_list[i]:
			return true
	return false
	
func _on_filesystem_changed():
	_is_dirty = true
		
func _get_default_selection_index():
	if _plugin_list.size() == 0:
		return -1
	var curr_index = _plugin_list.find(_currently_selected_plugin)
	if curr_index > -1:
		return curr_index
	var default_index = _plugin_list.find(_get_default_target_plugin())
	if default_index > -1:
		return default_index
	return 0

func _refresh_plugin_list():
	var new_plugin_list := _list_plugins()
	if _has_plugin_list_changed(new_plugin_list):
		_plugin_list = new_plugin_list
	else:
		return
	_plugin_name_button.clear()
	for plugin_name in _plugin_list:
		_plugin_name_button.add_item(plugin_name)
	var select_index = _get_default_selection_index()
	_plugin_name_button.select(select_index)
	_on_plugin_selected(select_index)

func _on_plugin_selected(index):
	_restart_button.disabled = index < 0
	_toggle_button.disabled = index < 0
	if index > -1:
		_currently_selected_plugin = _plugin_name_button.get_item_text(index)

func _list_plugins() -> Array[String]:
	var result = [] as Array[String]
	var filesystem = EditorInterface.get_resource_filesystem()
	var addons = filesystem.get_filesystem_path("res://addons")
	if is_instance_valid(addons):
		for i in range(addons.get_subdir_count()):
			result.append(addons.get_subdir(i).get_name())
	return result

func _plugin_exists(plugin_name: String):
	return _list_plugins().has(plugin_name)

func _on_toggle_pressed():
	var is_enabled = EditorInterface.is_plugin_enabled(_currently_selected_plugin)
	EditorInterface.set_plugin_enabled(_currently_selected_plugin, not is_enabled)
	
func _on_restart_pressed():
	EditorInterface.set_plugin_enabled(_currently_selected_plugin, false)
	EditorInterface.set_plugin_enabled.call_deferred(_currently_selected_plugin, true)
