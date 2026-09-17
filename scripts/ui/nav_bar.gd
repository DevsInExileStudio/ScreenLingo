extends PanelContainer

## Bottom navigation bar — paper strip with tabs. Tabs are child
## buttons of `Tabs` node (each has `Icon` and `Label` inside); active one marked
## with sliding "bookmark" (Indicator, drawn under tabs) and blue color,
## icon bounces on selection.

signal tab_selected(index: int)

const COLOR_ACTIVE := Color(0.184, 0.435, 0.722)
const COLOR_IDLE := Color(0.118, 0.227, 0.353, 0.5)
const PILL_SIZE := Vector2(66, 42)
const PILL_COLOR := Color(0.878, 0.929, 0.973)
const PILL_EAR := Color(0.72, 0.85, 0.95)

@onready var tabs: HBoxContainer = $Tabs
@onready var indicator: Control = $Indicator

var current := -1
var _pill_x := -1000.0
var _pill_tween: Tween
var _bounce_tweens: Dictionary = {}
var _dark_mode := false


func _ready() -> void:
	for i in tabs.get_child_count():
		var tab: Button = tabs.get_child(i)
		tab.pressed.connect(_on_tab_pressed.bind(i))
		tab.button_down.connect(_bounce.bind(tab.get_node("Box/Icon"), 0.86, 0.08))
		tab.button_up.connect(_bounce.bind(tab.get_node("Box/Icon"), 1.0, 0.3))
		_paint(tab, false)
	indicator.draw.connect(_draw_indicator)
	resized.connect(func() -> void: _move_pill(current, false))


func select(index: int, animate: bool = true) -> void:
	if index == current or index < 0 or index >= tabs.get_child_count():
		return
	var previous := current
	current = index
	for i in tabs.get_child_count():
		_paint(tabs.get_child(i), i == index, animate)
	if animate and previous >= 0:
		var icon: Control = tabs.get_child(index).get_node("Box/Icon")
		_bounce(icon, 1.22, 0.12)
		get_tree().create_timer(0.12).timeout.connect(_bounce.bind(icon, 1.0, 0.36))
	_move_pill(index, animate and previous >= 0)


func set_dark_mode(enabled: bool) -> void:
	_dark_mode = enabled
	for i in tabs.get_child_count():
		_paint(tabs.get_child(i), i == current)
	indicator.queue_redraw()


func _on_tab_pressed(index: int) -> void:
	select(index)
	tab_selected.emit(index)


func _paint(tab: Button, active: bool, animate: bool = false) -> void:
	var icon: TextureRect = tab.get_node("Box/Icon")
	var label: Label = tab.get_node("Box/Label")
	var color := COLOR_ACTIVE if active else (Color(0.78, 0.85, 0.91, 0.62) if _dark_mode else COLOR_IDLE)
	if animate:
		var tween := create_tween().set_parallel(true)
		tween.tween_property(icon, "modulate", color, 0.25)
		tween.tween_property(label, "modulate", color, 0.25)
	else:
		icon.modulate = color
		label.modulate = color


func _bounce(icon: Control, target: float, duration: float) -> void:
	icon.pivot_offset = icon.size * 0.5
	var old: Tween = _bounce_tweens.get(icon)
	if old:
		old.kill()
	var tween := create_tween()
	tween.tween_property(icon, "scale", Vector2.ONE * target, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_bounce_tweens[icon] = tween


## Bookmark slides to selected tab icon with slight overshoot.
func _move_pill(index: int, animate: bool) -> void:
	if index < 0:
		return
	await get_tree().process_frame
	var tab: Control = tabs.get_child(index)
	var icon: Control = tab.get_node("Box/Icon")
	var target := icon.global_position.x + icon.size.x * 0.5 - indicator.global_position.x
	if _pill_tween:
		_pill_tween.kill()
	if animate:
		_pill_tween = create_tween()
		_pill_tween.tween_method(_set_pill_x, _pill_x, target, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_set_pill_x(target)


func _set_pill_x(value: float) -> void:
	_pill_x = value
	indicator.queue_redraw()


func _draw_indicator() -> void:
	if current < 0:
		return
	var icon: Control = tabs.get_child(current).get_node("Box/Icon")
	var cy := icon.global_position.y + icon.size.y * 0.5 - indicator.global_position.y
	var rect := Rect2(Vector2(_pill_x - PILL_SIZE.x * 0.5, cy - PILL_SIZE.y * 0.5), PILL_SIZE)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.24, 0.34) if _dark_mode else PILL_COLOR
	style.set_corner_radius_all(14)
	style.corner_radius_top_right = 0
	indicator.draw_style_box(style, rect)
	# Folded corner of bookmark.
	var s := 12.0
	var a := rect.position + Vector2(rect.size.x - s, 0)
	var b := rect.position + Vector2(rect.size.x, s)
	var inner := rect.position + Vector2(rect.size.x - s, s)
	indicator.draw_colored_polygon(PackedVector2Array([a, b, inner]), Color(0.18, 0.37, 0.52) if _dark_mode else PILL_EAR)
	indicator.draw_line(a, b, Color(1, 1, 1, 0.7), 1.0, true)
