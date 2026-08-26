extends Node

signal language_changed

const LANG_ENGLISH = "en"
const LANG_BAHASA = "id"

var current_language: String = LANG_BAHASA
var _strings: Dictionary = {}

func _ready():
	load_language()
	load_strings()

func load_strings():
	var en = _load_json("res://Resources/strings_en.json")
	var id = _load_json("res://Resources/strings_id.json")
	_strings = {LANG_ENGLISH: en, LANG_BAHASA: id}

func _load_json(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		print("Failed to load: ", path)
		return {}
	var content = file.get_as_text()
	return JSON.parse_string(content)

func set_language(lang: String):
	current_language = lang
	save_language()
	language_changed.emit()

func load_language():
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err == OK:
		current_language = config.get_value("settings", "language", LANG_BAHASA)
	else:
		current_language = LANG_BAHASA

func save_language():
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	config.set_value("settings", "language", current_language)
	config.save("user://settings.cfg")

func tr_text(key: String) -> String:
	return TranslationServer.translate(key)

func get_language_name() -> String:
	match current_language:
		LANG_ENGLISH:
			return "English"
		LANG_BAHASA:
			return "Bahasa Indonesia"
		_:
			return current_language

func get_language_flag() -> String:
	match current_language:
		LANG_ENGLISH:
			return "🇬🇧"
		LANG_BAHASA:
			return "🇮🇩"
		_:
			return ""

func switch_language():
	if current_language == LANG_BAHASA:
		set_language(LANG_ENGLISH)
	else:
		set_language(LANG_BAHASA)

func t(key: String) -> String:
	return _strings.get(current_language, {}).get(key, key)
