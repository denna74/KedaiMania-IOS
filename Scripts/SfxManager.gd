extends Node

signal sfx_changed

const MAX_LEVEL := 4
const CLICK_PATH := "res://Audio/click.wav"

var sfx_level: int = MAX_LEVEL

var _click_player: AudioStreamPlayer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_sfx_setting()
	_click_player = AudioStreamPlayer.new()
	_click_player.stream = load(CLICK_PATH)
	_click_player.bus = &"SFX"
	add_child(_click_player)
	_apply_sfx_level()

func _apply_sfx_level():
	var idx := AudioServer.get_bus_index("SFX")
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, sfx_level <= 0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(float(sfx_level) / float(MAX_LEVEL)))

func load_sfx_setting():
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		sfx_level = clampi(config.get_value("settings", "sfx_level", MAX_LEVEL), 0, MAX_LEVEL)

func save_sfx_setting():
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("settings", "sfx_level", sfx_level)
	config.save("user://settings.cfg")

func set_sfx_level(level: int):
	level = clampi(level, 0, MAX_LEVEL)
	if sfx_level == level:
		return
	sfx_level = level
	save_sfx_setting()
	_apply_sfx_level()
	sfx_changed.emit()

func play(path: String):
	var player = AudioStreamPlayer.new()
	player.stream = load(path)
	player.bus = &"SFX"
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)

func play_click():
	if _click_player:
		_click_player.play()
