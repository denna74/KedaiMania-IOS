extends Node2D

signal processing_done(station_type: int)

var station_type: int
var station_info: Dictionary
var is_processing := false
var progress := 0.0
var process_time := 0.0
var bg_rect: Panel
var progress_bar: ColorRect
var name_label: Label
var status_label: Label
var process_sprite: Sprite2D
var click_player: AudioStreamPlayer

var frame_textures: Array[Texture2D]
var current_frame: int = 0
var anim_timer: float = 0.0
var base_scale: float = 0.12
const ANIM_SPEED: float = 0.15
const SPRITE_BASE_PATH: String = "res://Art/ProcessSprites/"

func init(type: int):
	station_type = type
	station_info = Global.station_info[type]
	build_visual()
	setup_audio()
	Lang.language_changed.connect(_on_language_changed)

func build_visual():
	var fredoka = ResourceLoader.load("res://Assets/Fonts/Fredoka-Regular.ttf")
	bg_rect = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	var cr := 12
	style.corner_radius_top_left = cr
	style.corner_radius_top_right = cr
	style.corner_radius_bottom_right = cr
	style.corner_radius_bottom_left = cr
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.15, 0.15, 0.15)
	bg_rect.add_theme_stylebox_override("panel", style)
	bg_rect.size = Vector2(105, 200)
	bg_rect.position = Vector2(-52, -100)
	add_child(bg_rect)

	name_label = Label.new()
	name_label.text = Global.get_station_name(station_type)
	name_label.add_theme_font_override("font", fredoka)
	name_label.add_theme_font_size_override("font_size", 16)
	name_label.add_theme_color_override("font_color", Color.WHITE)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(-50, -92)
	name_label.size = Vector2(100, 20)
	add_child(name_label)

	status_label = Label.new()
	status_label.text = Lang.t("ready")
	status_label.add_theme_font_override("font", fredoka)
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.position = Vector2(-50, 60)
	status_label.size = Vector2(100, 16)
	add_child(status_label)

	progress_bar = ColorRect.new()
	progress_bar.color = Color(0.2, 0.9, 0.3)
	progress_bar.size = Vector2(0, 10)
	progress_bar.position = Vector2(-45, 80)
	add_child(progress_bar)

	if station_info.has("sprite_prefix"):
		var prefix: String = station_info.sprite_prefix
		var frame_count: int = station_info.get("frame_count", 5)
		for i in range(1, frame_count + 1):
			var path: String = SPRITE_BASE_PATH + prefix + "_" + str(i) + ".png"
			var tex = load(path)
			if tex:
				frame_textures.append(tex)

	process_sprite = Sprite2D.new()
	if frame_textures.size() > 0:
		process_sprite.texture = frame_textures[0]
	else:
		process_sprite.texture = station_info.texture
	process_sprite.position = Vector2(0, -5)
	var tex_height = process_sprite.texture.get_height()
	base_scale = 120.0 / tex_height
	process_sprite.scale = Vector2(base_scale, base_scale)
	add_child(process_sprite)

func setup_audio():
	click_player = AudioStreamPlayer.new()
	click_player.stream = load("res://Audio/click.wav")
	click_player.bus = &"SFX"
	add_child(click_player)

func click():
	var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BOUNCE)
	tween.tween_method(_on_click_tween, 1.0, 0.85, 0.08)
	tween.tween_method(_on_click_tween, 0.85, 1.0, 0.12)
	click_player.play()

func _on_click_tween(val: float):
	process_sprite.scale = Vector2(base_scale * val, base_scale * val)

func start_processing(time: float):
	is_processing = true
	progress = 0.0
	process_time = time
	status_label.text = Lang.t("working")

func _process(delta):
	if !is_processing:
		return
	progress += delta / process_time
	progress_bar.size.x = 90 * min(progress, 1.0)

	if frame_textures.size() > 1:
		anim_timer += delta
		if anim_timer >= ANIM_SPEED:
			anim_timer = 0.0
			current_frame = (current_frame + 1) % frame_textures.size()
			process_sprite.texture = frame_textures[current_frame]
			_apply_frame_offset()

	if progress >= 1.0:
		progress = 1.0
		is_processing = false
		status_label.text = Lang.t("ready")
		progress_bar.size.x = 0
		if frame_textures.size() > 0:
			current_frame = 0
			anim_timer = 0.0
			process_sprite.texture = frame_textures[0]
			_apply_frame_offset()
		processing_done.emit(station_type)

func _apply_frame_offset():
	if station_info.has("frame_centers"):
		var centers = station_info.frame_centers
		if current_frame < centers.size():
			process_sprite.offset.x = centers[0] - centers[current_frame]
		else:
			process_sprite.offset.x = 0.0
	else:
		process_sprite.offset.x = 0.0

func _on_language_changed():
	name_label.text = Global.get_station_name(station_type)
	status_label.text = Lang.t("ready") if !is_processing else Lang.t("working")
