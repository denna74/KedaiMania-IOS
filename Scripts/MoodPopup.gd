extends Control
class_name MoodPopup

signal ok_pressed
signal video_pressed
signal mood_recovered

var mood_timer: Timer
var watch_ads_eng: Texture2D
var watch_ads_id: Texture2D
var batal_tex: Texture2D
var _is_instant_mode: bool = false

func setup():
	var fredoka = ResourceLoader.load("res://Assets/Fonts/Fredoka-Regular.ttf")
	var baloo2 = ResourceLoader.load("res://Assets/Fonts/Baloo2-Bold.ttf")

	visible = false

	var bg = ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.7)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var frame = Panel.new()
	frame.name = "mp_frame"
	var frame_style = StyleBoxFlat.new()
	frame_style.bg_color = Color(0.12, 0.12, 0.16, 0.95)
	frame_style.corner_radius_top_left = 16
	frame_style.corner_radius_top_right = 16
	frame_style.corner_radius_bottom_left = 16
	frame_style.corner_radius_bottom_right = 16
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.position = Vector2(30, 100)
	frame.size = Vector2(420, 390)
	add_child(frame)

	var mp_img_tex = make_texture("res://Art/chili_mood.png", 75, 100)
	var mp_img = TextureRect.new()
	mp_img.name = "mp_img"
	if mp_img_tex:
		mp_img.texture = mp_img_tex
	mp_img.position = Vector2(208, 62)
	mp_img.size = Vector2(75, 100)
	add_child(mp_img)

	var title = Label.new()
	title.name = "mp_title"
	title.text = Lang.t("mood_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", baloo2)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(0.95, 0.75, 0.15))
	title.position = Vector2(30, 175)
	title.size = Vector2(420, 40)
	add_child(title)

	var body = Label.new()
	body.name = "mp_body"
	body.text = Lang.t("mood_body")
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	body.add_theme_font_override("font", fredoka)
	body.add_theme_font_size_override("font_size", 15)
	body.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	body.position = Vector2(40, 215)
	body.size = Vector2(400, 140)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(body)

	var timer_lbl = Label.new()
	timer_lbl.name = "mp_timer"
	timer_lbl.text = "02:00:00"
	timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timer_lbl.add_theme_font_override("font", baloo2)
	timer_lbl.add_theme_font_size_override("font_size", 28)
	timer_lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 0.15))
	timer_lbl.position = Vector2(30, 324)
	timer_lbl.size = Vector2(420, 40)
	add_child(timer_lbl)

	mood_timer = Timer.new()
	mood_timer.name = "mp_timer_node"
	mood_timer.one_shot = false
	mood_timer.wait_time = 1.0
	mood_timer.timeout.connect(_on_mood_timer_timeout)
	add_child(mood_timer)

	var ok_btn = TextureButton.new()
	ok_btn.name = "mp_ok"
	ok_btn.texture_normal = make_texture("res://Art/Buttons/button_ok.png", 200, 50)
	ok_btn.size = Vector2(200, 50)
	ok_btn.position = Vector2(35, 385)
	ok_btn.pressed.connect(_on_ok_pressed)
	ok_btn.button_down.connect(_on_btn_down.bind(ok_btn))
	ok_btn.button_up.connect(_on_btn_up.bind(ok_btn))
	add_child(ok_btn)

	watch_ads_eng = make_texture("res://Art/Buttons/button_watch_ads_eng.png", 200, 50)
	watch_ads_id = make_texture("res://Art/Buttons/button_watch_ads_id.png", 200, 50)
	batal_tex = make_texture("res://Art/Buttons/button_batal.png", 200, 50)
	var video_btn = TextureButton.new()
	video_btn.name = "mp_video"
	video_btn.texture_normal = watch_ads_eng if Lang.current_language == "en" else watch_ads_id
	video_btn.size = Vector2(200, 50)
	video_btn.position = Vector2(245, 385)
	video_btn.pressed.connect(_on_video_pressed)
	video_btn.button_down.connect(_on_btn_down.bind(video_btn))
	video_btn.button_up.connect(_on_btn_up.bind(video_btn))
	add_child(video_btn)

func show_popup():
	_is_instant_mode = false
	_update_timer_label()
	mood_timer.start()
	visible = true

func hide_popup():
	mood_timer.stop()
	_is_instant_mode = false
	visible = false

func show_instant_mood_popup():
	_is_instant_mode = true
	if mood_timer:
		mood_timer.stop()
	_apply_instant_mood_mode()
	visible = true

func _apply_instant_mood_mode():
	var timer_lbl = get_node_or_null("mp_timer")
	if timer_lbl:
		timer_lbl.visible = false
	var title_lbl = get_node("mp_title") as Label
	if title_lbl:
		title_lbl.text = Lang.t("mood_instant_title")
	var body_lbl = get_node("mp_body") as Label
	if body_lbl:
		body_lbl.text = Lang.t("mood_instant_body")
	var ok_btn = get_node("mp_ok") as TextureButton
	if ok_btn and batal_tex:
		ok_btn.texture_normal = batal_tex

func on_language_changed():
	var title_lbl = get_node("mp_title")
	if title_lbl:
		title_lbl.text = Lang.t("mood_instant_title") if _is_instant_mode else Lang.t("mood_title")
	var body_lbl = get_node("mp_body")
	if body_lbl:
		body_lbl.text = Lang.t("mood_instant_body") if _is_instant_mode else Lang.t("mood_body")
	var video_btn = get_node("mp_video") as TextureButton
	if video_btn:
		video_btn.texture_normal = watch_ads_eng if Lang.current_language == "en" else watch_ads_id
	if _is_instant_mode:
		var ok_btn = get_node("mp_ok") as TextureButton
		if ok_btn and batal_tex:
			ok_btn.texture_normal = batal_tex
		var timer_lbl = get_node_or_null("mp_timer")
		if timer_lbl:
			timer_lbl.visible = false

func _update_timer_label():
	var remaining = Global.get_mood_recovery_remaining_time()
	var hours = remaining / 3600
	var minutes = (remaining % 3600) / 60
	var seconds = remaining % 60
	var timer_lbl = get_node("mp_timer")
	if timer_lbl:
		timer_lbl.text = "%02d:%02d:%02d" % [hours, minutes, seconds]

func _on_mood_timer_timeout():
	Global.process_mood_recovery()
	if Global.mood_level > 0:
		hide_popup()
		mood_recovered.emit()
		return
	_update_timer_label()

func _on_ok_pressed():
	hide_popup()
	ok_pressed.emit()

func _on_video_pressed():
	video_pressed.emit()

func _on_btn_down(btn):
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(0.93, 0.93), 0.06)

func _on_btn_up(btn):
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)

static func make_texture(path: String, w: int, h: int) -> Texture2D:
	var t = load(path)
	var tex = t as Texture2D if t else null
	if tex == null:
		var img = Image.new()
		if img.load(ProjectSettings.globalize_path(path)) != OK:
			return null
		img.resize(w, h, Image.INTERPOLATE_LANCZOS)
		return ImageTexture.create_from_image(img)
	var i = tex.get_image()
	if i == null:
		return null
	i.resize(w, h, Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(i)

