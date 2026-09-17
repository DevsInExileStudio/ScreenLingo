extends ScrollContainer

## "Grab and drag" scrolling like native apps: gesture starts anywhere —
## on card, button, list — not only empty space. Built-in Godot scroll
## works only where event reaches ScrollContainer, but everything is covered
## by PanelContainers and buttons. So events are caught in _input (before GUI):
##   • press is remembered but passed to button as usual;
##   • as soon as cursor moves from press point — gesture is taken over, and
##     pressed button state reset without synthetic cursor motion;
##   • click reaches element only on release without any shift;
##   • after release scrolling continues with inertia and friction.
## Horizontal shift also cancels click but doesn't change vertical scroll.
## Mouse wheel stays native.
## If picker sheet is open above (touch_blocker group), lower pages don't get gesture.

const GROUP := "touch_scroll"
const BLOCKER_GROUP := "touch_blocker"
## Inertia friction (higher = stops faster) and stop threshold, px/s.
const FRICTION := 4.2
const MIN_VELOCITY := 24.0
const MAX_VELOCITY := 5200.0

var _pressed := false
var _dragging := false
var _pressed_button: BaseButton
var _pressed_slider: Slider
var _press_pos := Vector2.ZERO
var _last_pos := Vector2.ZERO
var _last_time := 0.0
## Recent shifts to estimate release velocity: [dy, dt].
var _samples: Array[Vector2] = []
var _velocity := 0.0
var _scroll_target := 0.0


func _ready() -> void:
	add_to_group(GROUP)
	set_process(false)
	set_process_input(true)


func _gui_input(event: InputEvent) -> void:
	# Suppress built-in touch scroll of ScrollContainer so it doesn't conflict;
	# wheel (WHEEL_*) left untouched.
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		if event.pressed:
			_on_press(event.position)
		else:
			_on_release()
	elif event is InputEventMouseMotion:
		if not _pressed:
			return
		_on_move(event.position)


func _on_press(pos: Vector2) -> void:
	if not is_visible_in_tree() or not _is_top_most_at(pos):
		return
	_pressed = true
	_dragging = false
	_pressed_button = _button_under_pointer()
	_pressed_slider = _slider_under_pointer()
	_press_pos = pos
	_last_pos = pos
	_last_time = _now()
	_samples.clear()
	_stop_inertia()


func _on_move(pos: Vector2) -> void:
	# Slider takes gesture from press start: give it all MouseMotion without
	# threshold and don't try to scroll page in parallel.
	if is_instance_valid(_pressed_slider):
		return
	if not _dragging:
		var delta := pos - _press_pos
		# Even minimal real offset cancels child GUI element press.
		# Motion events with same position not counted as movement.
		if delta.is_zero_approx():
			return
		_take_over()
		_scroll_by(-delta.y)
		var now := _now()
		_samples.append(Vector2(delta.y, maxf(now - _last_time, 0.001)))
		_last_pos = pos
		_last_time = now
		return
	var dy := pos.y - _last_pos.y
	var now := _now()
	_samples.append(Vector2(dy, maxf(now - _last_time, 0.001)))
	if _samples.size() > 6:
		_samples.pop_front()
	_last_pos = pos
	_last_time = now
	_scroll_by(-dy)
	get_viewport().set_input_as_handled()


func _on_release() -> void:
	if not _pressed:
		return
	_pressed = false
	if not _dragging:
		return
	_dragging = false
	get_viewport().set_input_as_handled()
	# Velocity from last ~100ms of gesture; if finger stopped — no inertia.
	var dy := 0.0
	var dt := 0.0
	for i in range(_samples.size() - 1, -1, -1):
		dy += _samples[i].x
		dt += _samples[i].y
		if dt > 0.1:
			break
	if _now() - _last_time > 0.08 or dt <= 0.0:
		return
	_velocity = clampf(-dy / dt, -MAX_VELOCITY, MAX_VELOCITY)
	if absf(_velocity) > MIN_VELOCITY:
		_scroll_target = get_v_scroll_bar().value
		set_process(true)


## Take over gesture from pressed button: first "move" cursor far away (button stops
## considering press as its own), then release — pressed signal won't fire, and button_up
## returns button to normal look.
func _take_over() -> void:
	_dragging = true
	if is_instance_valid(_pressed_button) and not _pressed_button.disabled:
		_pressed_button.disabled = true
		_pressed_button.set_deferred("disabled", false)
	get_viewport().gui_release_focus()
	get_viewport().set_input_as_handled()


func _button_under_pointer() -> BaseButton:
	var control := get_viewport().gui_get_hovered_control()
	while control != null:
		if control is BaseButton:
			return control
		control = control.get_parent_control()
	return null


func _slider_under_pointer() -> Slider:
	var control := get_viewport().gui_get_hovered_control()
	while control != null:
		if control is Slider:
			return control
		control = control.get_parent_control()
	return null


func _scroll_by(dy: float) -> void:
	var bar := get_v_scroll_bar()
	bar.value = clampf(bar.value + dy, bar.min_value, bar.max_value - bar.page)


func _process(delta: float) -> void:
	var bar := get_v_scroll_bar()
	var limit := bar.max_value - bar.page
	_scroll_target += _velocity * delta
	_velocity *= exp(-FRICTION * delta)
	if _scroll_target <= bar.min_value or _scroll_target >= limit:
		_scroll_target = clampf(_scroll_target, bar.min_value, limit)
		_velocity = 0.0
	bar.value = _scroll_target
	if absf(_velocity) < MIN_VELOCITY:
		_stop_inertia()


func _stop_inertia() -> void:
	_velocity = 0.0
	set_process(false)


## Gesture belongs to topmost (last in tree) visible receiver under point:
## list in open picker sheet above page, and sheet itself (blocker) covers page.
func _is_top_most_at(pos: Vector2) -> bool:
	if not get_global_rect().has_point(pos):
		return false
	var top: Node = self
	for group in [GROUP, BLOCKER_GROUP]:
		for node: Control in get_tree().get_nodes_in_group(group):
			if node == self or not node.is_visible_in_tree() or not node.get_global_rect().has_point(pos):
				continue
			if node.is_greater_than(top):
				top = node
	return top == self


func _now() -> float:
	return Time.get_ticks_usec() / 1_000_000.0
