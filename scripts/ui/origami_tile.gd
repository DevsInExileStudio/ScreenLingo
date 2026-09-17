extends ColorRect

## Logo tile (origami_tile shader): animates folding four flaps to center,
## shows glyphs as their face lands, occasionally runs sheen across sheet
## and rebuilds on tap. Material made unique per node, size passed to shader in px.

signal folded

## Glyph labels: appear after their face (top — A, left — あ, bottom — 文).
@export var glyph_top: NodePath
@export var glyph_left: NodePath
@export var glyph_bottom: NodePath
@export var fold_duration := 0.55
@export var fold_stagger := 0.14

const FOLDS: Array[StringName] = [&"fold_top", &"fold_right", &"fold_left", &"fold_bottom"]

var _material: ShaderMaterial
var _fold_tween: Tween
var _sheen_tween: Tween
var _sheen_timer: Timer
var _running := false
var _busy := false
var _glyphs: Dictionary = {}
var _press_position := Vector2.INF


func _ready() -> void:
	material = material.duplicate()
	_material = material as ShaderMaterial
	_sync_size()
	resized.connect(_sync_size)
	_glyphs = {
		&"fold_top": get_node_or_null(glyph_top),
		&"fold_left": get_node_or_null(glyph_left),
		&"fold_bottom": get_node_or_null(glyph_bottom),
	}
	for glyph in _glyphs.values():
		if glyph:
			glyph.pivot_offset = glyph.size * 0.5
	_sheen_timer = Timer.new()
	_sheen_timer.one_shot = true
	_sheen_timer.timeout.connect(_on_sheen_timer)
	add_child(_sheen_timer)
	gui_input.connect(_on_gui_input)


func _sync_size() -> void:
	_material.set_shader_parameter("rect_size", size)
	_material.set_shader_parameter("radius", size.x * 0.18)


## Instantly open envelope: flaps beyond edge, glyphs hidden.
func set_open() -> void:
	for fold in FOLDS:
		_material.set_shader_parameter(fold, 0.0)
	_material.set_shader_parameter("tuck", 0.0)
	for glyph in _glyphs.values():
		if glyph:
			glyph.modulate.a = 0.0
			glyph.scale = Vector2(0.6, 0.6)


## Fold envelope: flaps land one after another with light "slap",
## each glyph pops when its face lands, corner tucks at end.
func fold_in(delay := 0.0) -> void:
	if _fold_tween:
		_fold_tween.kill()
	_busy = true
	_fold_tween = create_tween().set_parallel(true)
	var t := delay
	for fold in FOLDS:
		_fold_tween.tween_method(_set_param.bind(fold), 0.0, 1.0, fold_duration) \
			.set_delay(t).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		var glyph: Control = _glyphs.get(fold)
		if glyph:
			var g := t + fold_duration * 0.55
			_fold_tween.tween_property(glyph, "modulate:a", 1.0, 0.22).set_delay(g)
			_fold_tween.tween_property(glyph, "scale", Vector2.ONE, 0.5) \
				.set_delay(g).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t += fold_stagger
	var tuck_at := t - fold_stagger + fold_duration * 0.7
	_fold_tween.tween_method(_set_param.bind(&"tuck"), 0.0, 1.0, 0.4) \
		.set_delay(tuck_at).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_fold_tween.chain().tween_callback(func() -> void:
		_busy = false
		folded.emit()
		sweep_sheen()
		_schedule_sheen()
	)


## Replay: quickly unfold in reverse order and fold again.
func replay() -> void:
	if _busy:
		return
	if _fold_tween:
		_fold_tween.kill()
	_busy = true
	_fold_tween = create_tween().set_parallel(true)
	_fold_tween.tween_method(_set_param.bind(&"tuck"), 1.0, 0.0, 0.16)
	var t := 0.06
	for i in range(FOLDS.size() - 1, -1, -1):
		var fold := FOLDS[i]
		_fold_tween.tween_method(_set_param.bind(fold), 1.0, 0.0, 0.26) \
			.set_delay(t).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		var glyph: Control = _glyphs.get(fold)
		if glyph:
			_fold_tween.tween_property(glyph, "modulate:a", 0.0, 0.12).set_delay(t)
			_fold_tween.tween_property(glyph, "scale", Vector2(0.6, 0.6), 0.2).set_delay(t)
		t += 0.07
	_fold_tween.chain().tween_callback(fold_in.bind(0.05))


## Sheen run across sheet diagonal.
func sweep_sheen() -> void:
	if _sheen_tween:
		_sheen_tween.kill()
	_sheen_tween = create_tween()
	_sheen_tween.tween_method(_set_param.bind(&"sheen"), -0.3, 1.3, 1.1) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## When running, tile "breathes" sheen more often.
func set_running(running: bool) -> void:
	_running = running
	if running:
		sweep_sheen()
	_schedule_sheen()


func _schedule_sheen() -> void:
	_sheen_timer.start(2.4 if _running else randf_range(5.0, 8.0))


func _on_sheen_timer() -> void:
	if not _busy:
		sweep_sheen()
	_schedule_sheen()


func _set_param(value: float, param: StringName) -> void:
	_material.set_shader_parameter(param, value)


## Tap without drag rebuilds tile. Events not consumed so
## list scroll starting on tile keeps working.
func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		if event.pressed:
			_press_position = event.position
		elif _press_position.distance_to(event.position) < 14.0:
			replay()
