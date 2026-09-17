extends Node

## Autoload `YOUR_ID_HERE`: single access point to Android plugin `YOUR_ID_HERE`.
## UI talks only to this node — typed signals and methods, and on desktop
## (without plugin) settings live in memory so UI can be debugged in editor.

signal permission_changed(granted: bool)
signal overlay_state_changed(running: bool)
signal status_message(text: String)
signal overlay_error(text: String)

const PLUGIN_NAME := "YOUR_ID_HERE"

## Engine identifiers — same as in TranslationEngines.kt of plugin.
const ENGINE_MLKIT := "mlkit"
const ENGINE_GOOGLE_WEB := "google_web"
const ENGINE_MYMEMORY := "mymemory"
const ENGINE_GEMINI := "gemini"
const ENGINE_GROQ := "groq"
const ENGINE_DEEPL := "deepl"
const ENGINE_OPENROUTER := "openrouter"
const ENGINE_CLAUDE := "claude"
const ENGINE_OPENAI := "openai"
const ENGINE_DEEPSEEK := "deepseek"
const ENGINE_MISTRAL := "mistral"
const ENGINE_GOOGLE_CLOUD := "google_cloud"
const ENGINE_YANDEX := "yandex"
const BACKGROUND_ADAPTIVE := "adaptive"
const BACKGROUND_DARK := "dark"
const BACKGROUND_LIGHT := "light"

var available: bool = false

var _plugin: Object = null
## Fallback values for desktop where plugin doesn't exist.
var _fallback := {
	"target": "en",
	"script": "latin",
	"engine": ENGINE_MLKIT,
	"api_keys": {},
	"models": {},
	"auto_hide": 0,
	"background": BACKGROUND_ADAPTIVE,
	"font_scale": 1.0,
	"badge_scale": 1.0,
	"badge_opacity": 1.0,
}


func _ready() -> void:
	if not Engine.has_singleton(PLUGIN_NAME):
		return
	_plugin = Engine.get_singleton(PLUGIN_NAME)
	available = true
	_plugin.connect("permission_changed", func(granted: bool) -> void: permission_changed.emit(granted))
	_plugin.connect("overlay_state_changed", func(running: bool) -> void: overlay_state_changed.emit(running))
	_plugin.connect("status_message", func(text: String) -> void: status_message.emit(text))
	_plugin.connect("overlay_error", func(text: String) -> void: overlay_error.emit(text))


# ---------------------------------------------------------------- overlay

func has_overlay_permission() -> bool:
	return _plugin.hasOverlayPermission() if available else false


func request_overlay_permission() -> void:
	if available:
		_plugin.requestOverlayPermission()


## Returns false if "Display over other apps" permission must be granted first
## (plugin opens settings and starts overlay itself after returning).
func start_overlay(target_language: String, source_script: String) -> bool:
	if not available:
		return false
	return _plugin.startOverlay(target_language, source_script)


func stop_overlay() -> void:
	if available:
		_plugin.stopOverlay()


func is_overlay_running() -> bool:
	return _plugin.isOverlayRunning() if available else false


# ---------------------------------------------------------------- settings

func set_target_language(code: String) -> void:
	_fallback["target"] = code
	if available:
		_plugin.setTargetLanguage(code)


func get_target_language() -> String:
	return _plugin.getTargetLanguage() if available else _fallback["target"]


func set_source_script(script: String) -> void:
	_fallback["script"] = script
	if available:
		_plugin.setSourceScript(script)


func get_source_script() -> String:
	return _plugin.getSourceScript() if available else _fallback["script"]


func set_engine(engine: String) -> void:
	_fallback["engine"] = engine
	if available:
		_plugin.setEngine(engine)


func get_engine() -> String:
	return _plugin.getEngine() if available else _fallback["engine"]


## Engine key goes only to plugin's private storage; never read back.
func set_api_key(engine: String, key: String) -> void:
	_fallback["api_keys"][engine] = key
	if available:
		_plugin.setApiKey(engine, key)


func has_api_key(engine: String) -> bool:
	if available:
		return _plugin.hasApiKey(engine)
	return not String(_fallback["api_keys"].get(engine, "")).is_empty()


## LLM engine model; empty string means default (see ENGINES in main.gd).
func set_engine_model(engine: String, model: String) -> void:
	_fallback["models"][engine] = model
	if available:
		_plugin.setEngineModel(engine, model)


func get_engine_model(engine: String) -> String:
	if available:
		return _plugin.getEngineModel(engine)
	return String(_fallback["models"].get(engine, ""))


func set_auto_hide_seconds(seconds: int) -> void:
	_fallback["auto_hide"] = seconds
	if available:
		_plugin.setAutoHideSeconds(seconds)


func get_auto_hide_seconds() -> int:
	return _plugin.getAutoHideSeconds() if available else _fallback["auto_hide"]


func set_overlay_background(mode: String) -> void:
	_fallback["background"] = mode
	if available:
		_plugin.setOverlayBackground(mode)


func get_overlay_background() -> String:
	return _plugin.getOverlayBackground() if available else _fallback["background"]


func set_font_scale(scale: float) -> void:
	_fallback["font_scale"] = scale
	if available:
		_plugin.setFontScale(scale)


func get_font_scale() -> float:
	return _plugin.getFontScale() if available else _fallback["font_scale"]


## Floating button scale (0.75–1.5 of base 54dp).
func set_badge_scale(scale: float) -> void:
	_fallback["badge_scale"] = scale
	if available:
		_plugin.setBadgeScale(scale)


func get_badge_scale() -> float:
	return _plugin.getBadgeScale() if available else _fallback["badge_scale"]


## Floating button opacity at rest (0.4–1).
func set_badge_opacity(opacity: float) -> void:
	_fallback["badge_opacity"] = opacity
	if available:
		_plugin.setBadgeOpacity(opacity)


func get_badge_opacity() -> float:
	return _plugin.getBadgeOpacity() if available else _fallback["badge_opacity"]


func reset_badge_position() -> void:
	if available:
		_plugin.resetBadgePosition()


func clear_translation_cache() -> void:
	if available:
		_plugin.clearTranslationCache()
	else:
		status_message.emit(tr("Translation cache is cleared only on Android."))
