extends Control

## Indicator "overlay running": mint dot with soft halo that
## breathes while active.

@export var color := Color(0.56, 0.85, 0.70)

var _tween: Tween
var _halo := 0.0


func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, 6.0 + 8.0 * _halo, Color(color, 0.35 * (1.0 - _halo)))
	draw_circle(c, 6.0, color)
	draw_circle(c, 2.5, Color(1, 1, 1, 0.9))


func set_active(active: bool) -> void:
	if _tween:
		_tween.kill()
		_tween = null
	if active:
		_tween = create_tween().set_loops()
		_tween.tween_method(_set_halo, 0.0, 1.0, 1.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_tween.tween_interval(0.3)
	else:
		_set_halo(0.0)


func _set_halo(value: float) -> void:
	_halo = value
	queue_redraw()
