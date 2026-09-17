@tool
extends Control

## Card styling as paper sheet: folded corner in top-right
## in section color (fold underside — background paper, folded part — face
## with crease and shadow stack) and optional notebook ruling with margin.
## Node placed as first child of PanelContainer: draws under content, and
## recalculates coords via parent stylebox margins so corner and lines
## reach real card edges.

@export var ear_size := 40.0
@export var ear_a := Color(0.83, 0.95, 0.88)
@export var ear_b := Color(0.60, 0.86, 0.71)
@export var under_color := Color(0.90, 0.93, 0.955)
@export var ruled := false
@export var label_path: NodePath
@export var line_color := Color(0.80, 0.87, 0.93, 0.9)
@export var margin_color := Color(0.31, 0.56, 0.85, 0.5)


func _draw() -> void:
	var panel := get_parent() as Control
	var sb := panel.get_theme_stylebox("panel") if panel else null
	var left := -(sb.content_margin_left if sb else 0.0)
	var top := -(sb.content_margin_top if sb else 0.0)
	var right := size.x + (sb.content_margin_right if sb else 0.0)
	var bottom := size.y + (sb.content_margin_bottom if sb else 0.0)

	if ruled:
		_draw_lines(left, top, right, bottom)
	_draw_ear(right, top)


## Ruling under text with hint label line step and blue margin line.
func _draw_lines(left: float, top: float, right: float, bottom: float) -> void:
	var step := 30.0
	var label := get_node_or_null(label_path) as Label
	if label:
		var font := label.get_theme_font("font")
		var font_size := label.get_theme_font_size("font_size")
		step = font.get_height(font_size) + label.get_theme_constant("line_spacing")
	var y := label.position.y + step - 4.0 if label else step
	while y < bottom - 10.0:
		draw_line(Vector2(left, y), Vector2(right, y), line_color, 1.0, true)
		y += step
	draw_line(Vector2(left + 14.0, top), Vector2(left + 14.0, bottom), margin_color, 1.5, true)


func _draw_ear(right: float, top: float) -> void:
	var s := ear_size
	var corner := Vector2(right, top)
	var a := Vector2(right - s, top)
	var b := Vector2(right, top + s)
	var inner := Vector2(right - s, top + s)
	draw_colored_polygon(PackedVector2Array([a, corner, b]), under_color)
	for i in 4:
		var off := Vector2(2.0 + i * 1.5, 2.0 + i * 1.5)
		draw_colored_polygon(
			PackedVector2Array([a + off, b + off, inner + off]),
			Color(0.118, 0.227, 0.353, 0.04)
		)
	draw_polygon(
		PackedVector2Array([a, b, inner]),
		PackedColorArray([ear_a, ear_b, ear_a.lerp(ear_b, 0.5)])
	)
	draw_line(a, b, Color(1, 1, 1, 0.6), 1.0, true)
