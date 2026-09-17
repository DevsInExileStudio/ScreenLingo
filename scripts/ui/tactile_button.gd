extends Button

## Tactile feedback: button "presses in" on press (scale from center)
## and springs back. Attach to Button (incl. ChoiceField).

@export var press_scale := 0.965

var _tween: Tween


func _ready() -> void:
	_update_pivot()
	resized.connect(_update_pivot)
	button_down.connect(_on_down)
	button_up.connect(_on_up)


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func _on_down() -> void:
	_animate(Vector2.ONE * press_scale, 0.08, Tween.TRANS_QUAD, Tween.EASE_OUT)


func _on_up() -> void:
	_animate(Vector2.ONE, 0.32, Tween.TRANS_BACK, Tween.EASE_OUT)


func _animate(target: Vector2, duration: float, trans: Tween.TransitionType, ease_type: Tween.EaseType) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "scale", target, duration).set_trans(trans).set_ease(ease_type)
