extends Node
## Centralized catalog of UI and translation languages.
## Codes are stored in settings, and [method to_engine_code] maps regional
## variants to BCP-47 expected by ML Kit and online engines.

const DEFAULT_LANGUAGE := "en"

const LANGUAGES: Array = [
	{"code": "en", "name": "English"},
	{"code": "fr", "name": "Français"},
	{"code": "it", "name": "Italiano"},
	{"code": "de", "name": "Deutsch"},
	{"code": "es", "name": "Español"},
	{"code": "pt_br", "name": "Português (BR)"},
	{"code": "ru", "name": "Русский"},
	{"code": "uk", "name": "Українська"},
	{"code": "ja", "name": "日本語"},
	{"code": "ko", "name": "한국어"},
	{"code": "zh_tw", "name": "繁體中文"},
	{"code": "ar", "name": "العربية"},
	{"code": "nl", "name": "Nederlands"},
	{"code": "id", "name": "Bahasa Indonesia"},
	{"code": "hi", "name": "हिन्दी"},
	{"code": "tr", "name": "Türkçe"},
	{"code": "zh_cn", "name": "简体中文"},
	{"code": "th", "name": "ไทย"},
	{"code": "vi", "name": "Tiếng Việt"},
	{"code": "pl", "name": "Polski"},
]


func has(code: String) -> bool:
	for language in LANGUAGES:
		if language.code == code:
			return true
	return false


func options() -> Array[Array]:
	var result: Array[Array] = []
	for language in LANGUAGES:
		# Self-names are not translated: makes the language easy to find in any UI.
		result.append([language.code, language.name])
	return result


func to_translation_locale(code: String) -> String:
	match code:
		"pt_br": return "pt_BR"
		"zh_tw": return "zh_TW"
		"zh_cn": return "zh_CN"
		_: return code


func to_engine_code(code: String) -> String:
	match code:
		"pt_br": return "pt-BR"
		"zh_tw": return "zh-TW"
		"zh_cn": return "zh-CN"
		_: return code
