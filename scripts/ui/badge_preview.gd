extends Control

## Preview of floating button "文A" from settings: replicates Android button look
## (rounded square with mint -> blue diagonal gradient, thin light border)
## and shows selected size and opacity with smooth transition.

const BASE_SIZE := 64.0
const ARC_STEPS := 6

var _gradient := Gradient.new()
var _scale := 1.0
var _opacity := 1.0
var _shown_scale := 1.0
var _shown_opacity := 1.0
var _tween: Tween


func _ready() -> void:
	_gradient.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	_gradient.colors = PackedColorArray([Color("B9E9DD"), Color("3F80BD"), Color("285C9B")])


func set_badge(scale_value: float, opacity_value: float) -> void:
	_scale = scale_value
	_opacity = opacity_value
	if _tween:
		_tween.kill()
	_tween = create_tween().set_parallel(true)
	_tween.tween_method(_set_shown_scale, _shown_scale, _scale, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_set_shown_opacity, _shown_opacity, _opacity, 0.2)


func _set_shown_scale(value: float) -> void:
	_shown_scale = value
	queue_redraw()


func _set_shown_opacity(value: float) -> void:
	_shown_opacity = value
	queue_redraw()


## Rounded square outline: each vertex color comes from diagonal
## gradient, draw_polygon interpolates them across area.
func _draw() -> void:
	var s := BASE_SIZE * _shown_scale
	var origin := (size - Vector2(s, s)) * 0.5
	var radius := s * 0.31
	var rect := Rect2(origin, Vector2(s, s))

	var shadow := StyleBoxFlat.new()
	shadow.bg_color = Color(0, 0, 0, 0)
	shadow.set_corner_radius_all(int(radius))
	shadow.shadow_color = Color(0.118, 0.227, 0.353, 0.24 * _shown_opacity)
	shadow.shadow_size = int(10 * _shown_scale)
	shadow.shadow_offset = Vector2(0, 5)
	draw_style_box(shadow, rect)

	var points := PackedVector2Array()
	var centers := [
		[origin + Vector2(radius, radius), PI, 1.5 * PI],
		[origin + Vector2(s - radius, radius), 1.5 * PI, 2.0 * PI],
		[origin + Vector2(s - radius, s - radius), 0.0, 0.5 * PI],
		[origin + Vector2(radius, s - radius), 0.5 * PI, PI],
	]
	for corner in centers:
		var c: Vector2 = corner[0]
		for i in ARC_STEPS + 1:
			var a: float = lerpf(corner[1], corner[2], float(i) / ARC_STEPS)
			points.append(c + Vector2(cos(a), sin(a)) * radius)
	var colors := PackedColorArray()
	for p in points:
		var t := ((p.x - origin.x) + (p.y - origin.y)) / (2.0 * s)
		var col := _gradient.sample(t)
		col.a = _shown_opacity
		colors.append(col)
	draw_polygon(points, colors)
	draw_polyline(points, Color(0.85, 0.96, 0.94, 0.9 * _shown_opacity), 1.0, true)
	draw_line(points[-1], points[0], Color(0.85, 0.96, 0.94, 0.9 * _shown_opacity), 1.0, true)

	var font := get_theme_font("font")
	var font_size := int(19 * _shown_scale)
	var text := "文A"
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var pos := origin + Vector2((s - text_size.x) * 0.5, (s - text_size.y) * 0.5 + font.get_ascent(font_size))
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.09, 0.24, 0.34, _shown_opacity))
