extends Control

## Picker sheet: full-screen dim and white "paper sheet" sliding from bottom,
## with title, handle and scrollable list of big buttons. One instance per scene
## (picker_sheet group); ChoiceField fields open it via open().
##
## Behavior like system sheets on phone: tap on dim, back button
## or dragging sheet down by header closes it; selected item highlighted and
## scrolled into view; selection confirmed with short animation and sheet goes away.
##
## Expected structure (see scenes/main.tscn):
##   Dim (ColorRect), Sheet (PanelContainer) / VBox / Header (Handle, TitleRow/Title),
##   List (ScrollContainer, touch_scroll.gd) / Items (VBoxContainer).

signal closed

const RADIO_ON := preload("res://assets/icons/radio_on.svg")
const RADIO_OFF := preload("res://assets/icons/radio_off.svg")

## Max screen fraction for list.
const MAX_LIST_FRACTION := 0.56
## How many first items to animate on open (rest just visible).
const STAGGER_COUNT := 10
## Dismiss threshold when dragging down — fraction of sheet height.
const DISMISS_FRACTION := 0.28

@onready var dim: ColorRect = $Dim
@onready var sheet: PanelContainer = $Sheet
@onready var header: Control = $Sheet/VBox/Header
@onready var title_label: Label = $Sheet/VBox/Header/TitleRow/Title
@onready var list: ScrollContainer = $Sheet/VBox/List
@onready var items_box: VBoxContainer = $Sheet/VBox/List/Items

var _on_pick: Callable
var _selected := -1
var _open := false
## Item already selected, confirmation animation playing — ignore repeated taps.
var _picking := false
var _tween: Tween
var _buttons: Array[Button] = []
## Dragging by header.
var _drag_active := false
var _drag_start_y := 0.0
var _drag_offset := 0.0


func _ready() -> void:
	add_to_group("picker_sheet")
	add_to_group("touch_blocker")
	visible = false
	dim.gui_input.connect(_on_dim_input)
	header.gui_input.connect(_on_header_input)


func open(title: String, items: Array[Dictionary], selected: int, on_pick: Callable) -> void:
	_on_pick = on_pick
	_selected = selected
	title_label.text = title
	title_label.get_parent().visible = not title.is_empty()
	_build_items(items)
	_open = true
	_picking = false
	# While list is laying out (two frames), sheet stays beyond bottom edge, no dim.
	dim.modulate.a = 0.0
	sheet.position = Vector2(0.0, size.y)
	visible = true
	await get_tree().process_frame
	if not _open:
		return
	_fit_list()
	await get_tree().process_frame
	if not _open:
		return
	_scroll_to_selected()
	_animate_open()


func close(animate: bool = true) -> void:
	if not _open:
		return
	_open = false
	_drag_active = false
	if _tween:
		_tween.kill()
	if not animate:
		visible = false
		closed.emit()
		return
	var height := sheet.size.y + 40.0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(dim, "modulate:a", 0.0, 0.2)
	_tween.tween_property(sheet, "position:y", _rest_y() + height, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	_tween.chain().tween_callback(func() -> void:
		visible = false
		closed.emit()
	)


func is_open() -> bool:
	return _open


# ---------------------------------------------------------------- building

func _build_items(items: Array[Dictionary]) -> void:
	for child in items_box.get_children():
		child.queue_free()
	_buttons.clear()
	for i in items.size():
		var button := _make_item(items[i], i == _selected)
		button.pressed.connect(_on_item_pressed.bind(i))
		items_box.add_child(button)
		_buttons.append(button)


## Item is button with nested row: radio mark, name and (optionally)
## subtitle, on right — tag ("offline", "free", "key").
func _make_item(item: Dictionary, is_selected: bool) -> Button:
	var button := Button.new()
	button.theme_type_variation = &"PickerItemSelected" if is_selected else &"PickerItem"
	button.custom_minimum_size = Vector2(0, 76)
	button.focus_mode = Control.FOCUS_NONE
	button.set_script(preload("res://scripts/ui/tactile_button.gd"))
	button.set("press_scale", 0.975)

	var row := HBoxContainer.new()
	row.name = "Row"
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 20.0
	row.offset_right = -18.0
	row.offset_top = 8.0
	row.offset_bottom = -8.0
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 16)
	button.add_child(row)

	var radio := TextureRect.new()
	radio.name = "Radio"
	radio.texture = RADIO_ON if is_selected else RADIO_OFF
	radio.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	radio.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	radio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(radio)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 2)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)

	var label := Label.new()
	label.name = "Label"
	label.text = str(item.get("label", ""))
	label.theme_type_variation = &"PickerLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_child(label)

	var subtitle := str(item.get("subtitle", ""))
	if not subtitle.is_empty():
		var sub := Label.new()
		sub.text = subtitle
		sub.theme_type_variation = &"PickerSubtitle"
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text.add_child(sub)

	var tag := str(item.get("tag", ""))
	if not tag.is_empty():
		var chip := Label.new()
		chip.text = tag
		chip.theme_type_variation = &"MintTag" if str(item.get("tag_style", "")) == "mint" else &"SkyTag"
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(chip)
	return button


## List not taller than screen fraction; short lists sized to content. Sheet without anchors:
## width full screen, height minimal for content (size clamped to min).
func _fit_list() -> void:
	var max_height := size.y * MAX_LIST_FRACTION
	var content := items_box.get_combined_minimum_size().y
	list.custom_minimum_size.y = minf(content, max_height)
	sheet.size = Vector2(size.x, 0.0)
	sheet.pivot_offset = Vector2(sheet.size.x * 0.5, sheet.size.y)


func _scroll_to_selected() -> void:
	if _selected < 0 or _selected >= _buttons.size():
		list.scroll_vertical = 0
		return
	var button := _buttons[_selected]
	var center := button.position.y + button.size.y * 0.5 - list.size.y * 0.5
	list.scroll_vertical = int(maxf(center, 0.0))


# ---------------------------------------------------------------- motion

func _rest_y() -> float:
	return size.y - sheet.size.y


func _animate_open() -> void:
	if _tween:
		_tween.kill()
	dim.modulate.a = 0.0
	var rest := _rest_y()
	sheet.position.y = rest + sheet.size.y + 40.0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(dim, "modulate:a", 1.0, 0.24)
	_tween.tween_property(sheet, "position:y", rest, 0.46).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	# Visible items "unfold" in cascade; rest just in place.
	var delay := 0.08
	var animated := 0
	var top := float(list.scroll_vertical)
	var bottom := top + list.size.y
	for button in _buttons:
		button.modulate.a = 1.0
		var in_view := button.position.y + button.size.y > top and button.position.y < bottom
		if not in_view or animated >= STAGGER_COUNT:
			continue
		animated += 1
		var origin := button.position.y
		button.modulate.a = 0.0
		button.position.y = origin + 14.0
		_tween.tween_property(button, "modulate:a", 1.0, 0.22).set_delay(delay)
		_tween.tween_property(button, "position:y", origin, 0.34).set_delay(delay).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		delay += 0.03


## Selection: radio mark switches instantly, button "bounces", sheet goes away.
func _on_item_pressed(index: int) -> void:
	if not _open or _picking:
		return
	_picking = true
	for i in _buttons.size():
		var button := _buttons[i]
		button.theme_type_variation = &"PickerItemSelected" if i == index else &"PickerItem"
		(button.get_node("Row/Radio") as TextureRect).texture = RADIO_ON if i == index else RADIO_OFF
	var chosen := _buttons[index]
	chosen.pivot_offset = chosen.size * 0.5
	var bump := create_tween()
	bump.tween_property(chosen, "scale", Vector2(1.03, 1.03), 0.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	bump.tween_property(chosen, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	bump.tween_callback(func() -> void:
		close()
		if _on_pick.is_valid():
			_on_pick.call(index)
	)


func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		close()


## Dragging by header: sheet follows finger, released below threshold — closed,
## otherwise springs back.
func _on_header_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_drag_active = true
			_drag_start_y = event.global_position.y
			_drag_offset = 0.0
			if _tween:
				_tween.kill()
		elif _drag_active:
			_drag_active = false
			if _drag_offset > sheet.size.y * DISMISS_FRACTION:
				close()
			else:
				_tween = create_tween()
				_tween.tween_property(sheet, "position:y", _rest_y(), 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				_tween.parallel().tween_property(dim, "modulate:a", 1.0, 0.2)
	elif event is InputEventMouseMotion and _drag_active:
		_drag_offset = maxf(event.global_position.y - _drag_start_y, 0.0)
		sheet.position.y = _rest_y() + _drag_offset
		dim.modulate.a = 1.0 - clampf(_drag_offset / sheet.size.y, 0.0, 0.8)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _open and not _drag_active:
		_fit_list()
		sheet.position.y = _rest_y()
