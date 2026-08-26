extends Node

signal bgm_changed

const MAX_LEVEL := 4

var menu_player: AudioStreamPlayer
var game_player: AudioStreamPlayer

var bgm_level: int = MAX_LEVEL

var _menu_stream: AudioStream
var _kedai_bgm_map := {}

func _ready():
	load_bgm_setting()
	menu_player = AudioStreamPlayer.new()
	menu_player.name = "MenuMusicPlayer"
	menu_player.process_mode = PROCESS_MODE_ALWAYS
	menu_player.bus = &"Music"
	_menu_stream = load("res://Audio/Stalls_of_Gold.mp3")
	if _menu_stream:
		_menu_stream.loop = true
		menu_player.stream = _menu_stream
	add_child(menu_player)

	game_player = AudioStreamPlayer.new()
	game_player.name = "GameMusicPlayer"
	game_player.process_mode = PROCESS_MODE_ALWAYS
	game_player.bus = &"Music"
	add_child(game_player)

	_kedai_bgm_map["nasi_goreng"] = load("res://Audio/BGM/nasi_goreng.mp3")
	_kedai_bgm_map["pecel_lele"] = load("res://Audio/BGM/pecel_lele.mp3")
	_kedai_bgm_map["nasi_padang"] = load("res://Audio/BGM/padang.mp3")
	_kedai_bgm_map["angkringan"] = load("res://Audio/BGM/angkringan.mp3")
	_kedai_bgm_map["mie_ayam_bakso"] = load("res://Audio/BGM/mie_ayam_bakso.mp3")

	get_tree().node_added.connect(_on_node_added)
	call_deferred("_update_music")

func _on_node_added(node: Node):
	if node == get_tree().current_scene:
		call_deferred("_update_music")

func _update_music():
	var scene = get_tree().current_scene
	if not scene:
		return

	var path = scene.scene_file_path

	if path == "res://Scenes/Main.tscn":
		_play_menu()
	elif path == "res://Scenes/Game.tscn":
		_play_game()

func _play_menu():
	_stop_all()
	if bgm_level > 0 and not menu_player.playing:
		menu_player.play()

func _play_game():
	var kedai_id = Global.current_kedai_id
	var stream = _kedai_bgm_map.get(kedai_id)
	if not stream:
		push_error("No BGM found for kedai: ", kedai_id)
		return
	stream.loop = true
	if game_player.stream != stream:
		game_player.stop()
		game_player.stream = stream
	_stop_all()
	if bgm_level > 0 and not game_player.playing:
		game_player.play()

func _stop_all():
	if menu_player.playing:
		menu_player.stop()
	if game_player.playing:
		game_player.stop()

func load_bgm_setting():
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	if err == OK:
		if config.has_section_key("settings", "bgm_level"):
			bgm_level = clampi(config.get_value("settings", "bgm_level", MAX_LEVEL), 0, MAX_LEVEL)
		else:
			# Legacy saves only stored the old on/off bool.
			var legacy_enabled = config.get_value("settings", "bgm_enabled", true)
			bgm_level = MAX_LEVEL if legacy_enabled else 0
	else:
		bgm_level = MAX_LEVEL
	_apply_bgm_level()

func save_bgm_setting():
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("settings", "bgm_level", bgm_level)
	config.save("user://settings.cfg")

func set_bgm_enabled(value: bool):
	set_bgm_level(MAX_LEVEL if value else 0)

func set_bgm_level(level: int):
	level = clampi(level, 0, MAX_LEVEL)
	if bgm_level == level:
		return
	bgm_level = level
	_apply_bgm_level()
	save_bgm_setting()
	if bgm_level > 0:
		var active := _get_active_player()
		if active and not active.playing:
			active.play()
	else:
		_stop_all()
	bgm_changed.emit()

func _get_active_player() -> AudioStreamPlayer:
	var scene = get_tree().current_scene
	if not scene:
		return null
	match scene.scene_file_path:
		"res://Scenes/Main.tscn":
			return menu_player
		"res://Scenes/Game.tscn":
			return game_player
	return null

func toggle_bgm():
	set_bgm_enabled(bgm_level <= 0)

func _apply_bgm_level():
	var idx := AudioServer.get_bus_index("Music")
	if idx < 0:
		return
	AudioServer.set_bus_mute(idx, bgm_level <= 0)
	AudioServer.set_bus_volume_db(idx, linear_to_db(float(bgm_level) / float(MAX_LEVEL)))
