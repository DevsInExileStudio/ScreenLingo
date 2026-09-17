@tool
extends Control

## Small logo-inspired marker. Two shapes:
##  TILE — mini envelope: four faces folded to center (top/right light,
##         left mid, bottom dark), with thin creases and shadow;
##  ARROW — paper "play" triangle folded from light and dark halves.
## Face colors defined by light/dark pair, intermediate tones computed.

enum Shape { TILE, ARROW }

@export var shape: Shape = Shape.TILE:
	set(value):
		shape = value
		queue_redraw()
@export var color_light := Color(0.72, 0.90, 0.80):
	set(value):
		color_light = value
		queue_redraw()
@export var color_dark := Color(0.31, 0.56, 0.85):
	set(value):
		color_dark = value
		queue_redraw()

const SHADOW := Color(0.118, 0.227, 0.353, 0.16)
const CREASE := Color(1, 1, 1, 0.55)


func _get_minimum_size() -> Vector2:
	return Vector2(18, 18)


func _draw() -> void:
	var s := minf(size.x, size.y)
	var o := (size - Vector2(s, s)) * 0.5
	match shape:
		Shape.TILE:
			_draw_tile(o, s)
		Shape.ARROW:
			_draw_arrow(o, s)


func _draw_tile(o: Vector2, s: float) -> void:
	var tl := o
	var tr := o + Vector2(s, 0)
	var bl := o + Vector2(0, s)
	var br := o + Vector2(s, s)
	var c := o + Vector2(s, s) * 0.5
	var shift := Vector2(0, 1.5)
	draw_colored_polygon(PackedVector2Array([tl + shift, tr + shift, br + shift, bl + shift]), SHADOW)
	var mid := color_light.lerp(color_dark, 0.5)
	draw_colored_polygon(PackedVector2Array([tl, tr, c]), color_light)
	draw_colored_polygon(PackedVector2Array([tr, br, c]), color_light.lerp(color_dark, 0.25))
	draw_colored_polygon(PackedVector2Array([bl, tl, c]), mid)
	draw_colored_polygon(PackedVector2Array([br, bl, c]), color_dark)
	draw_line(tl, br, CREASE, 1.0, true)
	draw_line(tr, bl, CREASE, 1.0, true)


func _draw_arrow(o: Vector2, s: float) -> void:
	var a := o + Vector2(s * 0.12, 0)
	var b := o + Vector2(s * 0.12, s)
	var tip := o + Vector2(s, s * 0.5)
	var mid := o + Vector2(s * 0.12, s * 0.5)
	var shift := Vector2(0, 1.5)
	draw_colored_polygon(PackedVector2Array([a + shift, tip + shift, b + shift]), SHADOW)
	draw_colored_polygon(PackedVector2Array([a, tip, mid]), color_light)
	draw_colored_polygon(PackedVector2Array([mid, tip, b]), color_dark)
	draw_line(mid, tip, CREASE, 1.0, true)
