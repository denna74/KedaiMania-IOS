extends Control
class_name SettingsPopup

signal closed

const MAX_LEVEL := 4

var _title_lbl: Label
var _lang_name_lbl: Label
var _lang_btn: Button
var _bgm_name_lbl: Label
var _bgm_slider: HSlider
var _bgm_pct: Label
var _sfx_name_lbl: Label
var _sfx_slider: HSlider
var _sfx_pct: Label
var _cancel_btn: TextureButton
var _ok_btn: TextureButton

var _ok_tex: Texture2D
var _cancel_eng_tex: Texture2D
var _cancel_id_tex: Texture2D

var _snapshot_lang: String = ""
var _snapshot_bgm: int = MAX_LEVEL
var _snapshot_sfx: int = MAX_LEVEL

func setup():
	var fredoka = ResourceLoader.load("res://Assets/Fonts/Fredoka-Regular.ttf")
	var baloo2 = ResourceLoader.load("res://Assets/Fonts/Baloo2-Bold.ttf")

	visible = false

	var dim = ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var frame = Panel.new()
	frame.name = "sp_frame"
	var frame_style = StyleBoxFlat.new()
	frame_style.bg_color = Color(0.12, 0.12, 0.16, 0.95)
	frame_style.corner_radius_top_left = 16
	frame_style.corner_radius_top_right = 16
	frame_style.corner_radius_bottom_left = 16
	frame_style.corner_radius_bottom_right = 16
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.position = Vector2(50, 237)
	frame.size = Vector2(380, 380)
	add_child(frame)

	_title_lbl = Label.new()
	_title_lbl.text = Lang.t("settings")
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_override("font", baloo2)
	_title_lbl.add_theme_font_size_override("font_size", 22)
	_title_lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 0.15))
	_title_lbl.position = Vector2(40, 16)
	_title_lbl.size = Vector2(300, 36)
	frame.add_child(_title_lbl)

	_lang_name_lbl = Label.new()
	_lang_name_lbl.text = Lang.t("language")
	_lang_name_lbl.add_theme_font_override("font", fredoka)
	_lang_name_lbl.add_theme_font_size_override("font_size", 15)
	_lang_name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_lang_name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lang_name_lbl.position = Vector2(30, 72)
	_lang_name_lbl.size = Vector2(140, 30)
	frame.add_child(_lang_name_lbl)

	_lang_btn = Button.new()
	_lang_btn.name = "sp_lang"
	_lang_btn.text = Lang.get_language_flag() + "  " + Lang.get_language_name()
	_lang_btn.add_theme_font_override("font", fredoka)
	_lang_btn.add_theme_font_size_override("font_size", 15)
	_lang_btn.add_theme_color_override("font_color", Color.WHITE)
	var lang_sb = StyleBoxFlat.new()
	lang_sb.bg_color = Color(0.3, 0.3, 0.35)
	lang_sb.corner_radius_top_left = 6
	lang_sb.corner_radius_top_right = 6
	lang_sb.corner_radius_bottom_left = 6
	lang_sb.corner_radius_bottom_right = 6
	_lang_btn.add_theme_stylebox_override("normal", lang_sb)
	_lang_btn.pressed.connect(_on_language_pressed)
	_lang_btn.button_down.connect(_on_btn_down.bind(_lang_btn))
	_lang_btn.button_up.connect(_on_btn_up.bind(_lang_btn))
	_lang_btn.position = Vector2(180, 66)
	_lang_btn.size = Vector2(170, 38)
	frame.add_child(_lang_btn)

	_bgm_name_lbl = Label.new()
	_bgm_name_lbl.text = Lang.t("background_music")
	_bgm_name_lbl.add_theme_font_override("font", fredoka)
	_bgm_name_lbl.add_theme_font_size_override("font_size", 15)
	_bgm_name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_bgm_name_lbl.position = Vector2(30, 126)
	_bgm_name_lbl.size = Vector2(200, 26)
	frame.add_child(_bgm_name_lbl)

	_bgm_slider = _make_slider(fredoka)
	_bgm_slider.position = Vector2(30, 158)
	_bgm_slider.size = Vector2(260, 30)
	_bgm_slider.value_changed.connect(_on_bgm_changed)
	frame.add_child(_bgm_slider)

	_bgm_pct = _make_pct_label(fredoka)
	_bgm_pct.position = Vector2(300, 156)
	frame.add_child(_bgm_pct)

	_sfx_name_lbl = Label.new()
	_sfx_name_lbl.text = Lang.t("sound_effect")
	_sfx_name_lbl.add_theme_font_override("font", fredoka)
	_sfx_name_lbl.add_theme_font_size_override("font_size", 15)
	_sfx_name_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	_sfx_name_lbl.position = Vector2(30, 206)
	_sfx_name_lbl.size = Vector2(200, 26)
	frame.add_child(_sfx_name_lbl)

	_sfx_slider = _make_slider(fredoka)
	_sfx_slider.position = Vector2(30, 238)
	_sfx_slider.size = Vector2(260, 30)
	_sfx_slider.value_changed.connect(_on_sfx_changed)
	frame.add_child(_sfx_slider)

	_sfx_pct = _make_pct_label(fredoka)
	_sfx_pct.position = Vector2(300, 236)
	frame.add_child(_sfx_pct)

	_ok_tex = make_texture("res://Art/Buttons/button_ok.png", 140, 45)
	_cancel_eng_tex = make_texture("res://Art/Buttons/button_cancel.png", 140, 45)
	_cancel_id_tex = make_texture("res://Art/Buttons/button_batal.png", 140, 45)

	_ok_btn = TextureButton.new()
	_ok_btn.name = "sp_ok"
	_ok_btn.texture_normal = _ok_tex
	_ok_btn.position = Vector2(205, 305)
	_ok_btn.size = Vector2(140, 45)
	_ok_btn.pressed.connect(_on_save_pressed)
	_ok_btn.button_down.connect(_on_btn_down.bind(_ok_btn))
	_ok_btn.button_up.connect(_on_btn_up.bind(_ok_btn))
	frame.add_child(_ok_btn)

	_cancel_btn = TextureButton.new()
	_cancel_btn.name = "sp_cancel"
	_cancel_btn.texture_normal = _cancel_eng_tex if Lang.current_language == "en" else _cancel_id_tex
	_cancel_btn.position = Vector2(35, 305)
	_cancel_btn.size = Vector2(140, 45)
	_cancel_btn.pressed.connect(_on_cancel_pressed)
	_cancel_btn.button_down.connect(_on_btn_down.bind(_cancel_btn))
	_cancel_btn.button_up.connect(_on_btn_up.bind(_cancel_btn))
	frame.add_child(_cancel_btn)

func _make_slider(font: Font) -> HSlider:
	var slider = HSlider.new()
	slider.max_value = MAX_LEVEL
	slider.min_value = 0
	slider.step = 1
	slider.tick_count = MAX_LEVEL + 1
	slider.add_theme_font_override("font", font)
	return slider

func _make_pct_label(font: Font) -> Label:
	var lbl = Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	lbl.size = Vector2(50, 30)
	return lbl

func show_popup():
	_snapshot_lang = Lang.current_language
	_snapshot_bgm = Music.bgm_level
	_snapshot_sfx = Sfx.sfx_level
	_lang_btn.text = Lang.get_language_flag() + "  " + Lang.get_language_name()
	_bgm_slider.set_value_no_signal(Music.bgm_level)
	_sfx_slider.set_value_no_signal(Sfx.sfx_level)
	_refresh_pcts()
	visible = true

func hide_popup():
	visible = false

func on_language_changed():
	_title_lbl.text = Lang.t("settings")
	_lang_name_lbl.text = Lang.t("language")
	_bgm_name_lbl.text = Lang.t("background_music")
	_sfx_name_lbl.text = Lang.t("sound_effect")
	_lang_btn.text = Lang.get_language_flag() + "  " + Lang.get_language_name()
	_cancel_btn.texture_normal = _cancel_eng_tex if Lang.current_language == "en" else _cancel_id_tex

func _refresh_pcts():
	_bgm_pct.text = str(int(round(_bgm_slider.value * 100.0 / MAX_LEVEL))) + "%"
	_sfx_pct.text = str(int(round(_sfx_slider.value * 100.0 / MAX_LEVEL))) + "%"

func _on_language_pressed():
	Lang.switch_language()

func _on_bgm_changed(value: float):
	Music.set_bgm_level(int(value))
	_refresh_pcts()

func _on_sfx_changed(value: float):
	Sfx.set_sfx_level(int(value))
	Sfx.play_click()
	_refresh_pcts()

func _on_cancel_pressed():
	Sfx.play_click()
	if Lang.current_language != _snapshot_lang:
		Lang.set_language(_snapshot_lang)
	Music.set_bgm_level(_snapshot_bgm)
	Sfx.set_sfx_level(_snapshot_sfx)
	hide_popup()

func _on_save_pressed():
	Sfx.play_click()
	closed.emit()
	hide_popup()

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
