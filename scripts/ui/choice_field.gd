extends "res://scripts/ui/tactile_button.gd"

## Choice field replacing OptionButton: shows current value and chevron, on press
## opens picker sheet (PickerSheet) over screen — with big buttons and scroll,
## like in phone system settings. Single sheet serves all fields.
##
## Items are dicts {value, label, subtitle?, tag?}; label/subtitle already translated.

signal item_selected(index: int)

const CHEVRON := preload("res://assets/icons/chevron.svg")

## Picker sheet title (translation key; tr() on open).
@export var title := ""

var items: Array[Dictionary] = []
var selected := -1:
	set(value):
		selected = value
		_refresh_text()


func _ready() -> void:
	super()
	pressed.connect(_open)
	_refresh_text()


func _draw() -> void:
	var sb := get_theme_stylebox("normal")
	var size_px := CHEVRON.get_size()
	var pos := Vector2(size.x - sb.content_margin_right - size_px.x, (size.y - size_px.y) * 0.5)
	draw_texture(CHEVRON, pos)


## Replaces list while preserving selected index if it still exists.
func set_items(list: Array[Dictionary]) -> void:
	items = list
	if selected >= items.size():
		selected = -1
	_refresh_text()


func get_item_count() -> int:
	return items.size()


func get_item_text(index: int) -> String:
	if index < 0 or index >= items.size():
		return ""
	return str(items[index].get("label", ""))


func get_value() -> Variant:
	if selected < 0 or selected >= items.size():
		return null
	return items[selected].get("value")


func select(index: int) -> void:
	selected = clampi(index, -1, items.size() - 1)


## Selects item by value; unknown value -> first item.
func select_value(value: Variant) -> void:
	for i in items.size():
		if items[i].get("value") == value:
			selected = i
			return
	selected = 0 if not items.is_empty() else -1


func _refresh_text() -> void:
	text = get_item_text(selected)
	queue_redraw()


func _open() -> void:
	var picker := get_tree().get_first_node_in_group("picker_sheet")
	if picker == null or items.is_empty():
		return
	picker.open(tr(title) if not title.is_empty() else "", items, selected, _on_picked)


func _on_picked(index: int) -> void:
	if index == selected or index < 0 or index >= items.size():
		return
	selected = index
	item_selected.emit(index)
