extends Node

## Desktop UI check: renders main scene and saves PNG.
##   godot --path . --resolution 720x1500 res://tools/ui_snapshot.tscn
## SNAPSHOT_PATH — where to write (default user://ui_snapshot.png);
## SNAPSHOT_FRAMES — comma-separated frame list, e.g. "20,45,140":
## for each frame file saved with suffix _<frame> — handy to see
## splash phases. Without var, single frame 160 is taken.
## SNAPSHOT_SCROLL — scroll open page by that many px before snapshot.
## SNAPSHOT_RUNNING=1 — show "overlay running" state without plugin.
## SNAPSHOT_TAB=0..3 — open tab (Home / Help / Settings / More).
## SNAPSHOT_LOCALE=en — switch UI language.
## SNAPSHOT_THEME=light|dark|system — switch UI theme.
## SNAPSHOT_ENGINE=<id> — pick translation engine (e.g. claude) — key/model fields visible.
## SNAPSHOT_PICKER=<field name> — open picker for that field (TargetLanguage, Engine, …).
## SNAPSHOT_DRAG=x,y,dy[,frame] — from given frame (default 40) "grab" screen
## at point (x,y) — window coords — and drag by dy px over 14 frames; console prints page scroll and number of triggered buttons
## (check touch_scroll.gd: gesture over button should scroll, not press).

var _frames := 0
var _drag: PackedFloat64Array = []
var _button_presses := 0
var _targets: Array[int] = []
var _path := ""


func _ready() -> void:
	var window := get_window()
	window.content_scale_size = Vector2i(720, 1500)
	_path = OS.get_environment("SNAPSHOT_PATH")
	if _path.is_empty():
		_path = "user://ui_snapshot.png"
	var frames := OS.get_environment("SNAPSHOT_FRAMES")
	if frames.is_empty():
		_targets.append(160)
	else:
		for part in frames.split(","):
			_targets.append(int(part.strip_edges()))
	_targets.sort()
	add_child(load("res://scenes/main.tscn").instantiate())


func _process(_delta: float) -> void:
	_frames += 1
	if _frames == 2 and not OS.get_environment("SNAPSHOT_LOCALE").is_empty():
		var main := get_child(0)
		main._apply_locale(OS.get_environment("SNAPSHOT_LOCALE"))
		main._retranslate()
	if _frames == 2 and not OS.get_environment("SNAPSHOT_THEME").is_empty():
		get_child(0)._apply_theme(OS.get_environment("SNAPSHOT_THEME"))
	if _frames == 2 and not OS.get_environment("SNAPSHOT_TAB").is_empty():
		get_child(0)._go_to(int(OS.get_environment("SNAPSHOT_TAB")))
	if _frames == 2 and not OS.get_environment("SNAPSHOT_SCROLL").is_empty():
		var pages: Control = get_child(0).get_node("%Pages")
		var page: ScrollContainer = pages.get_child(pages.current)
		page.scroll_vertical = int(OS.get_environment("SNAPSHOT_SCROLL"))
	if _frames == 2 and OS.get_environment("SNAPSHOT_RUNNING") == "1":
		var main := get_child(0)
		main._running = true
		main._refresh_ui()
	if _frames == 2 and not OS.get_environment("SNAPSHOT_ENGINE").is_empty():
		var main := get_child(0)
		main.engine_option.select_value(OS.get_environment("SNAPSHOT_ENGINE"))
		main._on_engine_selected(main.engine_option.selected)
	if not OS.get_environment("SNAPSHOT_DRAG").is_empty():
		_drag_step()
	if _frames == 4 and not OS.get_environment("SNAPSHOT_PICKER").is_empty():
		var field: Control = get_child(0).get_node("%" + OS.get_environment("SNAPSHOT_PICKER"))
		field.pressed.emit()
	if _targets.is_empty() or _frames != _targets[0]:
		return
	_targets.pop_front()
	var path := _path
	if not _targets.is_empty() or OS.get_environment("SNAPSHOT_FRAMES").contains(","):
		path = _path.get_basename() + "_%d." % _frames + _path.get_extension()
	var image := get_viewport().get_texture().get_image()
	print("snapshot saved: ", error_string(image.save_png(path)), " -> ", path, " ", image.get_size())
	if _targets.is_empty():
		get_tree().quit()


func _drag_step() -> void:
	if _drag.is_empty():
		for part in OS.get_environment("SNAPSHOT_DRAG").split(","):
			_drag.append(float(part))
		_count_presses(get_child(0))
	var start := Vector2(_drag[0], _drag[1])
	var steps := 14
	var first := int(_drag[3]) if _drag.size() > 3 else 40
	var t := _frames - first
	if t == 0:
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_LEFT
		press.pressed = true
		press.position = start
		press.global_position = start
		Input.parse_input_event(press)
	elif t > 0 and t <= steps:
		var move := InputEventMouseMotion.new()
		move.position = start + Vector2(0, _drag[2] * t / steps)
		move.global_position = move.position
		move.button_mask = MOUSE_BUTTON_MASK_LEFT
		Input.parse_input_event(move)
	elif t == steps + 1:
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_LEFT
		release.pressed = false
		release.position = start + Vector2(0, _drag[2])
		release.global_position = release.position
		Input.parse_input_event(release)
	elif t == steps + 2 or t == steps + 40:
		var pages: Control = get_child(0).get_node("%Pages")
		var page: ScrollContainer = pages.get_child(pages.current)
		var list: ScrollContainer = get_child(0).get_node("%Picker/Sheet/VBox/List")
		print("drag frame %d: scroll=%d picker_scroll=%d presses=%d" % [_frames, page.scroll_vertical, list.scroll_vertical, _button_presses])


func _count_presses(node: Node) -> void:
	if node is BaseButton:
		node.pressed.connect(func() -> void: _button_presses += 1)
		node.button_down.connect(func() -> void: print("button_down: ", node.name))
		node.button_up.connect(func() -> void: print("button_up: ", node.name, " inside=", node.is_hovered()))
	for child in node.get_children():
		_count_presses(child)
