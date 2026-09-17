extends Control

## Page switcher: child nodes are pages (stretched to full node),
## exactly one visible. Transition is "shuffling sheets": outgoing page
## shifts toward tab and fades, new one enters from opposite side.
## After showing, page_shown emitted — page animates its content.

signal page_shown(page: Control, first_time: bool)

const SHIFT := 56.0

var current := -1
var _shown: Dictionary = {}
var _tween: Tween


func _ready() -> void:
	for child in get_children():
		child.visible = false


func show_page(index: int, animate: bool = true) -> void:
	if index == current or index < 0 or index >= get_child_count():
		return
	var direction := 1.0 if index > current else -1.0
	var outgoing: Control = get_child(current) if current >= 0 else null
	var incoming: Control = get_child(index)
	current = index
	if _tween:
		_tween.kill()
		for child in get_children():
			child.position.x = 0.0
			child.modulate.a = 1.0
			child.visible = child == outgoing
	var first_time: bool = not _shown.has(incoming)
	_shown[incoming] = true

	if not animate or outgoing == null:
		if outgoing:
			outgoing.visible = false
		incoming.visible = true
		incoming.position.x = 0.0
		incoming.modulate.a = 1.0
		page_shown.emit(incoming, first_time)
		return

	incoming.visible = true
	incoming.position.x = SHIFT * direction
	incoming.modulate.a = 0.0
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(outgoing, "position:x", -SHIFT * 0.6 * direction, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_tween.tween_property(outgoing, "modulate:a", 0.0, 0.14)
	_tween.tween_property(incoming, "position:x", 0.0, 0.42).set_delay(0.08).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(incoming, "modulate:a", 1.0, 0.26).set_delay(0.08)
	_tween.chain().tween_callback(func() -> void:
		outgoing.visible = false
		outgoing.position.x = 0.0
		outgoing.modulate.a = 1.0
	)
	page_shown.emit(incoming, first_time)
