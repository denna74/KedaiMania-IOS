extends Control

const MoodPopup = preload("res://Scripts/MoodPopup.gd")
const SettingsPopupScript = preload("res://Scripts/SettingsPopup.gd")

var instr: Label
var cook_eng: Texture2D
var cook_id: Texture2D
var exit_eng: Texture2D	
var exit_id: Texture2D
var main_menu_eng: Texture2D
var main_menu_id: Texture2D
var build_btn_eng: Texture2D
var build_btn_id: Texture2D
var settings_btn: Button
var settings_popup: SettingsPopup

enum MenuState { STATE_MAIN, STATE_KEDAI, STATE_LEVEL_SELECT }
var current_state = MenuState.STATE_MAIN
var kedai_buttons: Array[BaseButton] = []
var start_btn_pos: Vector2
var quit_btn_pos: Vector2
var click_player: AudioStreamPlayer
var page_player: AudioStreamPlayer
var current_tween: Tween
var kedai_btn_positions: Array[Vector2] = []
var catalog_buttons: Array[BaseButton] = []
var catalog_btn_positions: Array[Vector2] = []
var kedai_textures: Array[TextureRect] = []
var kedai_name_labels: Array[Label] = []
var gameplay_buttons: Array[BaseButton] = []
var kedai_texture_positions: Array[Vector2] = []
var kedai_label_positions: Array[Vector2] = []
var gameplay_btn_positions: Array[Vector2] = []
var build_buttons: Array[TextureButton] = []
var build_btn_positions: Array[Vector2] = []
var buy_popup: Control = null
var current_buy_kedai_id: String = ""
const _KEDAI_IDS := ["nasi_goreng", "pecel_lele", "angkringan", "nasi_padang", "mie_ayam_bakso"]
var catalog_panel: Control
var catalog_recipes: Array = []
var catalog_current_page: int = 0
var mood_chilis: Array[TextureRect] = []
var mood_popup: MoodPopup
var _swipe_start_x: float = 0.0
var mood_tex: Texture2D
var mood_silhouette_tex: Texture2D
var instant_mood_btn: TextureButton
var instant_mood_tex: Texture2D

var savings_label: Label
var level_select_panel: Control
var level_popup: Control
var level_nodes: Array[Control] = []
var level_node_tex_rects: Array[TextureRect] = []
var level_node_lock_rects: Array[TextureRect] = []
var level_node_labels: Array[Label] = []
var _level_node_tex_small: Texture2D
var _lock_tex_small: Texture2D
var _baloo2_font: Font
var _level_select_bg: TextureRect
var _kedai_enabled_flags: Array[bool] = []
var level_popup_selected_level: int = 1
var level_ok_tex: Texture2D
var level_cancel_eng: Texture2D
var level_cancel_id: Texture2D
var level_cancel_btn: TextureButton
var level_popup_title: Label
var _level_pulse_tween: Tween
var _btn_breath_tween: Tween
var _ls_scroll_y: int = 0
var _ls_touching: bool = false
var _ls_touch_start: Vector2 = Vector2()
const LS_SCROLL_AREA_HEIGHT: int = 725

func _notification(what: int):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if settings_popup.visible:
			settings_popup.hide_popup()
			return
		if catalog_panel.visible:
			catalog_panel.visible = false
			return
		if current_state == MenuState.STATE_KEDAI:
			_on_back_to_main()
		elif current_state == MenuState.STATE_LEVEL_SELECT:
			_on_level_select_main_menu()
		elif current_state == MenuState.STATE_MAIN:
			pass

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK):
		if settings_popup.visible:
			settings_popup.hide_popup()
			get_viewport().set_input_as_handled()
			return
		if catalog_panel.visible:
			catalog_panel.visible = false
			get_viewport().set_input_as_handled()
			return
		if current_state == MenuState.STATE_KEDAI:
			_on_back_to_main()
		elif current_state == MenuState.STATE_LEVEL_SELECT:
			_on_level_select_main_menu()
		get_viewport().set_input_as_handled()

func _ready():
	click_player = AudioStreamPlayer.new()
	click_player.stream = load("res://Audio/click.wav")
	click_player.bus = &"SFX"
	add_child(click_player)
	page_player = AudioStreamPlayer.new()
	page_player.stream = load("res://Audio/page_flip.wav")
	page_player.bus = &"SFX"
	add_child(page_player)
	setup_ui()
	settings_popup = SettingsPopupScript.new()
	add_child(settings_popup)
	settings_popup.setup()
	mood_popup = MoodPopup.new()
	add_child(mood_popup)
	mood_popup.setup()
	mood_popup.ok_pressed.connect(_on_mood_ok_pressed)
	mood_popup.video_pressed.connect(_on_mood_video_pressed)
	mood_popup.mood_recovered.connect(_on_mood_popup_recovered)
	Global.mood_recovered.connect(_on_global_mood_recovered)
	Lang.language_changed.connect(_on_language_changed)
	setup_level_select_ui()
	Ads.mood_reward_earned.connect(_on_ads_mood_reward_earned)
	Ads.mood_reward_failed.connect(_on_ads_mood_reward_failed)
	if IAP:
		IAP.kedai_unlocked.connect(_on_iap_kedai_unlocked)
		IAP.purchases_restored.connect(_on_purchases_restored)
		if not IAP.get_pending_restorations().is_empty():
			_on_purchases_restored()


func make_texture(path: String, w: int, h: int) -> Texture2D:
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

func _update_logo():
	var logo = get_node("logo")
	var path = "res://Assets/main_menu_logo_eng.png" if Lang.current_language == "en" else "res://Assets/main_menu_logo_id.png"
	var original = load(path) as Texture2D
	var img = original.get_image()
	img.resize(447, 284, Image.INTERPOLATE_LANCZOS)
	logo.texture = ImageTexture.create_from_image(img)

func setup_ui():
	var fredoka = ResourceLoader.load("res://Assets/Fonts/Fredoka-Regular.ttf")
	var baloo2 = ResourceLoader.load("res://Assets/Fonts/Baloo2-Bold.ttf")
	var bg = TextureRect.new()
	bg.name = "bg"
	bg.texture = load("res://Art/bg1.png")
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var logo = TextureRect.new()
	logo.name = "logo"
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.position = Vector2(21, 55)
	logo.size = Vector2(340, 216)
	add_child(logo)
	_update_logo()

	instr = Label.new()
	instr.name = "instructions"
	instr.text = Lang.t("instructions")
	instr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instr.add_theme_font_override("font", fredoka)
	instr.add_theme_font_size_override("font_size", 14)
	instr.add_theme_color_override("font_color", Color.WHITE)
	instr.set_anchors_preset(Control.PRESET_CENTER_TOP)
	instr.position = Vector2(-160, 773)
	instr.size = Vector2(320, 50)
	add_child(instr)

	var instr_bg = ColorRect.new()
	instr_bg.name = "instr_bg"
	instr_bg.color = Color(0, 0, 0, 0.5)
	instr_bg.set_anchors_preset(Control.PRESET_CENTER_TOP)
	instr_bg.position = Vector2(-160, 771)
	instr_bg.size = Vector2(320, 52)
	add_child(instr_bg)
	move_child(instr_bg, 2)

	settings_btn = Button.new()
	settings_btn.name = "settings_btn"
	settings_btn.text = Lang.t("settings")
	var gear_tex = make_texture("res://Art/Buttons/setting_small.png", 24, 24)
	if gear_tex:
		var gear_img = gear_tex.get_image()
		var padded = Image.create(27, 24, false, gear_img.get_format())
		padded.blit_rect(gear_img, Rect2i(0, 0, 24, 24), Vector2i(3, 0))
		settings_btn.icon = ImageTexture.create_from_image(padded)
	else:
		settings_btn.icon = gear_tex
	settings_btn.expand_icon = true
	settings_btn.add_theme_font_override("font", fredoka)
	settings_btn.add_theme_font_size_override("font_size", 16)
	settings_btn.add_theme_color_override("font_color", Color.WHITE)
	var settings_sb = StyleBoxFlat.new()
	settings_sb.bg_color = Color(0.3, 0.3, 0.35)
	settings_sb.corner_radius_top_left = 6
	settings_sb.corner_radius_top_right = 6
	settings_sb.corner_radius_bottom_left = 6
	settings_sb.corner_radius_bottom_right = 6
	settings_btn.add_theme_stylebox_override("normal", settings_sb)
	settings_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	settings_btn.position = Vector2(-160, 8)
	settings_btn.size = Vector2(148, 36)
	settings_btn.pressed.connect(_on_settings_pressed)
	settings_btn.button_down.connect(_on_btn_down.bind(settings_btn))
	settings_btn.button_up.connect(_on_btn_up.bind(settings_btn))
	add_child(settings_btn)

	cook_eng = make_texture("res://Art/Buttons/cook_button_eng.png", 260, 228)
	cook_id = make_texture("res://Art/Buttons/cook_button_id.png", 260, 228)
	exit_eng = make_texture("res://Art/Buttons/exit_button_eng.png", 210, 127)
	exit_id = make_texture("res://Art/Buttons/exit_button_id.png", 210, 127)
	build_btn_eng = make_texture("res://Art/Buttons/button_build.png", 130, 40)
	build_btn_id = make_texture("res://Art/Buttons/button_bangun.png", 130, 40)

	var is_en = Lang.current_language == "en"
	var start_btn = TextureButton.new()
	start_btn.name = "start_btn"
	start_btn.texture_normal = cook_eng if is_en else cook_id
	start_btn.position = Vector2(110, 380)
	start_btn.size = Vector2(260, 228)
	start_btn.pivot_offset = Vector2(130, 114)
	start_btn.pressed.connect(_on_start)
	start_btn.button_down.connect(_on_btn_down.bind(start_btn))
	start_btn.button_up.connect(_on_btn_up.bind(start_btn))
	add_child(start_btn)
	start_btn_pos = start_btn.position

	var quit_btn = TextureButton.new()
	quit_btn.name = "quit_btn"
	quit_btn.texture_normal = exit_eng if is_en else exit_id
	quit_btn.position = Vector2(135, 630)
	quit_btn.size = Vector2(210, 127)
	quit_btn.pressed.connect(_on_quit)
	quit_btn.button_down.connect(_on_btn_down.bind(quit_btn))
	quit_btn.button_up.connect(_on_btn_up.bind(quit_btn))
	add_child(quit_btn)
	quit_btn_pos = quit_btn.position

	var mood_label = Label.new()
	mood_label.name = "mood_label"
	mood_label.text = Lang.t("mood_label")
	mood_label.add_theme_font_override("font", baloo2)
	mood_label.add_theme_font_size_override("font_size", 18)
	mood_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	mood_label.position = Vector2(52, 135)
	mood_label.size = Vector2(40, 20)
	mood_label.visible = false
	add_child(mood_label)

	savings_label = Label.new()
	savings_label.name = "savings_label"
	savings_label.text = Lang.t("savings") + " : " + _format_money(Global.money)
	savings_label.add_theme_font_override("font", baloo2)
	savings_label.add_theme_font_size_override("font_size", 18)
	savings_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	savings_label.position = Vector2(52, 170)
	savings_label.size = Vector2(180, 20)
	savings_label.visible = false
	add_child(savings_label)

	var chili_tex = load("res://Art/chili_mood.png") as Texture2D
	var chili_img = chili_tex.get_image()
	chili_img.resize(20, 20, Image.INTERPOLATE_LANCZOS)
	mood_tex = ImageTexture.create_from_image(chili_img)

	var silhouette_tex = load("res://Art/chili_mood_silhouette.png") as Texture2D
	var silhouette_img = silhouette_tex.get_image()
	silhouette_img.resize(20, 20, Image.INTERPOLATE_LANCZOS)
	mood_silhouette_tex = ImageTexture.create_from_image(silhouette_img)

	for i in range(3):
		var tr = TextureRect.new()
		tr.name = "mood_chili_" + str(i)
		tr.texture = mood_tex
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.position = Vector2(105 + i * 24, 135)
		tr.size = Vector2(20, 20)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.visible = false
		add_child(tr)
		mood_chilis.append(tr)

	instant_mood_tex = make_texture("res://Art/Buttons/button_instant_mood.png", 90, 40)
	instant_mood_btn = TextureButton.new()
	instant_mood_btn.name = "instant_mood_btn"
	if instant_mood_tex:
		instant_mood_btn.texture_normal = instant_mood_tex
	instant_mood_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	instant_mood_btn.position = Vector2(185, 125)
	instant_mood_btn.size = Vector2(90, 40)
	instant_mood_btn.visible = false
	instant_mood_btn.pressed.connect(_on_instant_mood_btn_pressed)
	instant_mood_btn.button_down.connect(_on_btn_down.bind(instant_mood_btn))
	instant_mood_btn.button_up.connect(_on_btn_up.bind(instant_mood_btn))
	add_child(instant_mood_btn)

	var kedai_data = [
		["Kedai Nasi Goreng", "nasi_goreng", true, "res://Art/Kedais/kedai_nasi_goreng.png"],
		["Kedai Pecel Lele", "pecel_lele", Global.is_kedai_unlocked("pecel_lele"), "res://Art/Kedais/kedai_pecel_lele.png"],
		["Kedai Angkringan", "angkringan", Global.is_kedai_unlocked("angkringan"), "res://Art/Kedais/kedai_angkringan.png"],
		["Kedai Nasi Padang", "nasi_padang", Global.is_kedai_unlocked("nasi_padang"), "res://Art/Kedais/kedai_makan_padang.png"],
		["Kedai Mie Ayam Bakso", "mie_ayam_bakso", Global.is_kedai_unlocked("mie_ayam_bakso"), "res://Art/Kedais/mie_ayam_bakso.png"],
	]
	_kedai_enabled_flags = []
	for data in kedai_data:
		var idx = kedai_data.find(data)
		var base_y = 210 + idx * 110
		var is_enabled = data[2]
		_kedai_enabled_flags.append(is_enabled)

		var kedai_tex = TextureRect.new()
		kedai_tex.texture = make_texture(data[3], 85, 73)
		kedai_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		kedai_tex.position = Vector2(20, base_y)
		kedai_tex.size = Vector2(85, 73)
		kedai_tex.visible = false
		if not is_enabled:
			kedai_tex.modulate = Color(0.5, 0.5, 0.5)
		kedai_texture_positions.append(kedai_tex.position)
		add_child(kedai_tex)
		kedai_textures.append(kedai_tex)

		var name_lbl = Label.new()
		name_lbl.text = data[0]
		name_lbl.add_theme_font_override("font", baloo2)
		name_lbl.add_theme_font_size_override("font_size", 18)
		name_lbl.position = Vector2(115, base_y + 22)
		name_lbl.size = Vector2(170, 40)
		name_lbl.visible = false
		if not is_enabled:
			name_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		kedai_label_positions.append(name_lbl.position)
		add_child(name_lbl)
		kedai_name_labels.append(name_lbl)

		var gp_btn = TextureButton.new()
		gp_btn.texture_normal = make_texture("res://Assets/open_kedai.png", 50, 50)
		gp_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		gp_btn.position = Vector2(315, base_y + 12)
		gp_btn.size = Vector2(48, 48)
		gp_btn.visible = false
		if is_enabled:
			gp_btn.pressed.connect(_on_kedai_selected.bind(data[1]))
			gp_btn.button_down.connect(_on_btn_down.bind(gp_btn))
			gp_btn.button_up.connect(_on_btn_up.bind(gp_btn))
		else:
			gp_btn.disabled = true
			var gp_sb = StyleBoxFlat.new()
			gp_sb.bg_color = Color(0.25, 0.25, 0.28)
			gp_sb.corner_radius_top_left = 4
			gp_sb.corner_radius_top_right = 4
			gp_sb.corner_radius_bottom_left = 4
			gp_sb.corner_radius_bottom_right = 4
			gp_btn.add_theme_stylebox_override("normal", gp_sb)
			gp_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		gameplay_btn_positions.append(gp_btn.position)
		add_child(gp_btn)
		gameplay_buttons.append(gp_btn)

		var cat_btn = TextureButton.new()
		cat_btn.texture_normal = make_texture("res://Assets/food_catalog.png", 50, 50)
		cat_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		cat_btn.size = Vector2(48, 48)
		cat_btn.position = Vector2(400, base_y + 12)
		cat_btn.visible = false
		if is_enabled:
			cat_btn.pressed.connect(_on_catalog_open.bind(data[1]))
			cat_btn.button_down.connect(_on_btn_down.bind(cat_btn))
			cat_btn.button_up.connect(_on_btn_up.bind(cat_btn))
		else:
			cat_btn.disabled = true
			var csb = StyleBoxFlat.new()
			csb.bg_color = Color(0.25, 0.25, 0.28)
			csb.corner_radius_top_left = 4
			csb.corner_radius_top_right = 4
			csb.corner_radius_bottom_left = 4
			csb.corner_radius_bottom_right = 4
			cat_btn.add_theme_stylebox_override("normal", csb)
			cat_btn.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		catalog_btn_positions.append(cat_btn.position)
		add_child(cat_btn)
		catalog_buttons.append(cat_btn)

		var build_btn = TextureButton.new()
		build_btn.texture_normal = build_btn_eng if is_en else build_btn_id
		build_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		build_btn.position = Vector2(315, base_y + 16)
		build_btn.size = Vector2(130, 40)
		build_btn.visible = false
		if not is_enabled:
			build_btn.pressed.connect(_on_build_pressed.bind(data[1]))
			build_btn.button_down.connect(_on_btn_down.bind(build_btn))
			build_btn.button_up.connect(_on_btn_up.bind(build_btn))
		else:
			build_btn.disabled = true
		build_btn_positions.append(build_btn.position)
		add_child(build_btn)
		build_buttons.append(build_btn)

	main_menu_eng = make_texture("res://Art/Buttons/button_main_menu_eng.png", 200, 50)
	main_menu_id = make_texture("res://Art/Buttons/button_main_menu_id.png", 200, 50)
	var back_btn = TextureButton.new()
	back_btn.name = "back_btn"
	back_btn.texture_normal = main_menu_eng if Lang.current_language == "en" else main_menu_id
	back_btn.size = Vector2(200, 50)
	back_btn.position = Vector2(140, 210 + kedai_data.size() * 110)
	back_btn.visible = false
	back_btn.pressed.connect(_on_back_to_main)
	back_btn.button_down.connect(_on_btn_down.bind(back_btn))
	back_btn.button_up.connect(_on_btn_up.bind(back_btn))
	kedai_btn_positions.append(back_btn.position)
	add_child(back_btn)
	kedai_buttons.append(back_btn)

	setup_catalog_panel()
	_start_btn_breath()

func _on_btn_down(btn):
	if btn.name == "start_btn":
		_stop_btn_breath()
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(0.93, 0.93), 0.06)

func _on_btn_up(btn):
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)
	if btn.name == "start_btn":
		_start_btn_breath()

func _on_start():
	if current_state == MenuState.STATE_KEDAI:
		return
	click_player.play(0.0)
	_show_kedai_menu()

func _on_quit():
	get_tree().quit()

func _on_settings_pressed():
	if current_state != MenuState.STATE_MAIN:
		return
	click_player.play(0.0)
	settings_popup.show_popup()

func _on_language_changed():
	_update_logo()
	instr.text = Lang.t("instructions")
	var is_en = Lang.current_language == "en"
	settings_btn.text = Lang.t("settings")
	get_node("start_btn").texture_normal = cook_eng if is_en else cook_id
	get_node("quit_btn").texture_normal = exit_eng if is_en else exit_id
	var back_btn = get_node("back_btn") as TextureButton
	if back_btn:
		back_btn.texture_normal = main_menu_eng if is_en else main_menu_id
	var mood_label_node = get_node_or_null("mood_label")
	if mood_label_node:
		mood_label_node.text = Lang.t("mood_label")
	savings_label.text = Lang.t("savings") + " : " + _format_money(Global.money)
	var build_tex = build_btn_eng if is_en else build_btn_id
	for btn in build_buttons:
		btn.texture_normal = build_tex
	if catalog_panel.visible:
		_show_catalog_page(catalog_current_page)
	if mood_popup.visible:
		mood_popup.on_language_changed()
	if settings_popup.visible:
		settings_popup.on_language_changed()
	if level_select_panel:
		var mm_btn = level_select_panel.get_node_or_null("ls_main_menu") as TextureButton
		if mm_btn:
			mm_btn.texture_normal = main_menu_eng if is_en else main_menu_id
		if level_select_panel.visible:
			_update_level_select_mood_savings()
	if level_popup and level_popup.visible:
		level_popup_title.text = Lang.t("play_level") + "\n" + Lang.t("level") + str(level_popup_selected_level) + " ?"
	level_cancel_btn.texture_normal = level_cancel_eng if is_en else level_cancel_id


func _show_kedai_menu():
	_stop_btn_breath()
	if current_tween and current_tween.is_running():
		current_tween.kill()
	current_state = MenuState.STATE_KEDAI
	var logo = get_node("logo")
	var start_btn = get_node("start_btn")
	var quit_btn = get_node("quit_btn")
	var instr = get_node("instructions")
	var instr_bg = get_node("instr_bg")

	var tween = create_tween().set_parallel(true)
	current_tween = tween
	tween.tween_property(logo, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_property(settings_btn, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_property(instr, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_property(instr_bg, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_property(start_btn, "position", start_btn.position + Vector2(0, -50), 0.3)
	tween.tween_property(start_btn, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_property(quit_btn, "position", quit_btn.position + Vector2(0, -50), 0.3)
	tween.tween_property(quit_btn, "modulate", Color(1, 1, 1, 0), 0.3)
	await tween.finished

	start_btn.visible = false
	quit_btn.visible = false

	var tween2 = create_tween().set_parallel(true)
	current_tween = tween2
	for i in kedai_buttons.size():
		var btn = kedai_buttons[i]
		btn.visible = true
		btn.modulate = Color(1, 1, 1, 0)
		btn.position = kedai_btn_positions[i] + Vector2(0, 30)
		tween2.tween_property(btn, "position", kedai_btn_positions[i], 0.3)
		tween2.tween_property(btn, "modulate", Color(1, 1, 1, 1), 0.3)
	for i in catalog_buttons.size():
		var btn = catalog_buttons[i]
		btn.visible = true
		btn.modulate = Color(1, 1, 1, 0)
		btn.position = catalog_btn_positions[i] + Vector2(0, 30)
		tween2.tween_property(btn, "position", catalog_btn_positions[i], 0.3)
		var is_enabled = _kedai_enabled_flags[i] if i < _kedai_enabled_flags.size() else false
		tween2.tween_property(btn, "modulate", Color(1, 1, 1, 0.4) if not is_enabled else Color(1, 1, 1, 1), 0.3)
	for i in kedai_textures.size():
		var tex = kedai_textures[i]
		var is_enabled = _kedai_enabled_flags[i] if i < _kedai_enabled_flags.size() else false
		tex.visible = true
		tex.modulate = Color(1, 1, 1, 0)
		tex.position = kedai_texture_positions[i] + Vector2(0, 30)
		tween2.tween_property(tex, "position", kedai_texture_positions[i], 0.3)
		tween2.tween_property(tex, "modulate", Color(0.5, 0.5, 0.5, 1) if not is_enabled else Color(1, 1, 1, 1), 0.3)
	for i in kedai_name_labels.size():
		var lbl = kedai_name_labels[i]
		lbl.visible = true
		lbl.modulate = Color(1, 1, 1, 0)
		lbl.position = kedai_label_positions[i] + Vector2(0, 30)
		tween2.tween_property(lbl, "position", kedai_label_positions[i], 0.3)
		tween2.tween_property(lbl, "modulate", Color(1, 1, 1, 1), 0.3)
	for i in gameplay_buttons.size():
		var btn = gameplay_buttons[i]
		var is_enabled = _kedai_enabled_flags[i] if i < _kedai_enabled_flags.size() else false
		btn.visible = true
		btn.modulate = Color(1, 1, 1, 0)
		btn.position = gameplay_btn_positions[i] + Vector2(0, 30)
		tween2.tween_property(btn, "position", gameplay_btn_positions[i], 0.3)
		tween2.tween_property(btn, "modulate", Color(1, 1, 1, 0.4) if not is_enabled else Color(1, 1, 1, 1), 0.3)
	for i in build_buttons.size():
		var btn = build_buttons[i]
		var is_enabled = _kedai_enabled_flags[i] if i < _kedai_enabled_flags.size() else false
		btn.visible = not is_enabled
		if not is_enabled:
			btn.modulate = Color(1, 1, 1, 0)
			btn.position = build_btn_positions[i] + Vector2(0, 30)
			tween2.tween_property(btn, "position", build_btn_positions[i], 0.3)
			tween2.tween_property(btn, "modulate", Color(1, 1, 1, 1), 0.3)
	Global.process_mood_recovery()
	update_mood_display()
	var mood_label = get_node("mood_label")
	mood_label.visible = true
	mood_label.modulate = Color(1, 1, 1, 0)
	tween2.tween_property(mood_label, "modulate", Color(1, 1, 1, 1), 0.3)
	savings_label.text = Lang.t("savings") + " : " + _format_money(Global.money)
	savings_label.visible = true
	savings_label.modulate = Color(1, 1, 1, 0)
	tween2.tween_property(savings_label, "modulate", Color(1, 1, 1, 1), 0.3)
	for tr in mood_chilis:
		if tr.visible:
			tr.modulate = Color(1, 1, 1, 0)
			tween2.tween_property(tr, "modulate", Color(1, 1, 1, 1), 0.3)
	if instant_mood_btn:
		instant_mood_btn.visible = true
		instant_mood_btn.modulate = Color(1, 1, 1, 0)
		tween2.tween_property(instant_mood_btn, "modulate", Color(1, 1, 1, 0.4) if Global.mood_level >= 3 else Color(1, 1, 1, 1), 0.3)
	await tween2.finished


func _show_main_menu():
	if current_tween and current_tween.is_running():
		current_tween.kill()
	current_state = MenuState.STATE_MAIN

	var tween = create_tween().set_parallel(true)
	current_tween = tween
	for i in kedai_buttons.size():
		var btn = kedai_buttons[i]
		tween.tween_property(btn, "position", kedai_btn_positions[i] + Vector2(0, -30), 0.3)
		tween.tween_property(btn, "modulate", Color(1, 1, 1, 0), 0.3)
	for i in catalog_buttons.size():
		var btn = catalog_buttons[i]
		tween.tween_property(btn, "position", catalog_btn_positions[i] + Vector2(0, -30), 0.3)
		tween.tween_property(btn, "modulate", Color(1, 1, 1, 0), 0.3)
	for i in kedai_textures.size():
		var tex = kedai_textures[i]
		tween.tween_property(tex, "position", kedai_texture_positions[i] + Vector2(0, -30), 0.3)
		tween.tween_property(tex, "modulate", Color(1, 1, 1, 0), 0.3)
	for i in kedai_name_labels.size():
		var lbl = kedai_name_labels[i]
		tween.tween_property(lbl, "position", kedai_label_positions[i] + Vector2(0, -30), 0.3)
		tween.tween_property(lbl, "modulate", Color(1, 1, 1, 0), 0.3)
	for i in gameplay_buttons.size():
		var btn = gameplay_buttons[i]
		tween.tween_property(btn, "position", gameplay_btn_positions[i] + Vector2(0, -30), 0.3)
		tween.tween_property(btn, "modulate", Color(1, 1, 1, 0), 0.3)
	for i in build_buttons.size():
		var btn = build_buttons[i]
		tween.tween_property(btn, "position", build_btn_positions[i] + Vector2(0, -30), 0.3)
		tween.tween_property(btn, "modulate", Color(1, 1, 1, 0), 0.3)
	var mood_label_node = get_node("mood_label")
	tween.tween_property(mood_label_node, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_property(savings_label, "modulate", Color(1, 1, 1, 0), 0.3)
	for tr in mood_chilis:
		tween.tween_property(tr, "modulate", Color(1, 1, 1, 0), 0.3)
	if instant_mood_btn:
		tween.tween_property(instant_mood_btn, "modulate", Color(1, 1, 1, 0), 0.3)
	await tween.finished

	for i in kedai_buttons.size():
		kedai_buttons[i].visible = false
		kedai_buttons[i].position = kedai_btn_positions[i]

	for i in catalog_buttons.size():
		catalog_buttons[i].visible = false
		catalog_buttons[i].position = catalog_btn_positions[i]

	for i in kedai_textures.size():
		kedai_textures[i].visible = false
		kedai_textures[i].position = kedai_texture_positions[i]

	for i in kedai_name_labels.size():
		kedai_name_labels[i].visible = false
		kedai_name_labels[i].position = kedai_label_positions[i]

	for i in gameplay_buttons.size():
		gameplay_buttons[i].visible = false
		gameplay_buttons[i].position = gameplay_btn_positions[i]

	for i in build_buttons.size():
		build_buttons[i].visible = false
		build_buttons[i].position = build_btn_positions[i]

	mood_label_node.visible = false
	savings_label.visible = false
	for tr in mood_chilis:
		tr.visible = false
	if instant_mood_btn:
		instant_mood_btn.visible = false

	var logo = get_node("logo")
	var start_btn = get_node("start_btn")
	var quit_btn = get_node("quit_btn")
	var instr = get_node("instructions")
	var instr_bg = get_node("instr_bg")

	start_btn.visible = true
	quit_btn.visible = true

	var tween2 = create_tween().set_parallel(true)
	current_tween = tween2
	tween2.tween_property(logo, "modulate", Color(1, 1, 1, 1), 0.3)
	tween2.tween_property(settings_btn, "modulate", Color(1, 1, 1, 1), 0.3)
	tween2.tween_property(instr, "modulate", Color(1, 1, 1, 1), 0.3)
	tween2.tween_property(instr_bg, "modulate", Color(1, 1, 1, 1), 0.3)
	tween2.tween_property(start_btn, "position", start_btn_pos, 0.3)
	tween2.tween_property(start_btn, "modulate", Color(1, 1, 1, 1), 0.3)
	tween2.tween_property(quit_btn, "position", quit_btn_pos, 0.3)
	tween2.tween_property(quit_btn, "modulate", Color(1, 1, 1, 1), 0.3)
	await tween2.finished
	_start_btn_breath()


func setup_catalog_panel():
	var fredoka = ResourceLoader.load("res://Assets/Fonts/Fredoka-Regular.ttf")
	var baloo2 = ResourceLoader.load("res://Assets/Fonts/Baloo2-Bold.ttf")
	catalog_panel = Control.new()
	catalog_panel.visible = false
	add_child(catalog_panel)

	var bg = ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.85)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catalog_panel.add_child(bg)

	var notebook = TextureRect.new()
	notebook.name = "c_notebook"
	var ntex = load("res://Art/notebook.png") as Texture2D
	var nimg = ntex.get_image()
	nimg.resize(450, 790, Image.INTERPOLATE_LANCZOS)
	notebook.texture = ImageTexture.create_from_image(nimg)
	notebook.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notebook.position = Vector2(15, 30)
	notebook.size = Vector2(450, 790)
	catalog_panel.add_child(notebook)

	var close_btn = Button.new()
	close_btn.name = "c_close"
	close_btn.text = "X"
	close_btn.add_theme_font_override("font", baloo2)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	var close_sb = StyleBoxFlat.new()
	close_sb.bg_color = Color(0.75, 0.1, 0.1)
	close_sb.corner_radius_top_left = 6
	close_sb.corner_radius_top_right = 6
	close_sb.corner_radius_bottom_left = 6
	close_sb.corner_radius_bottom_right = 6
	close_btn.add_theme_stylebox_override("normal", close_sb)
	close_btn.position = Vector2(380, 45)
	close_btn.size = Vector2(28, 28)
	close_btn.pressed.connect(_on_catalog_close)
	notebook.add_child(close_btn)

	var name_lbl = Label.new()
	name_lbl.name = "c_name"
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_override("font", baloo2)
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	name_lbl.position = Vector2(25, 30)
	name_lbl.size = Vector2(400, 40)
	notebook.add_child(name_lbl)

	var food_img = TextureRect.new()
	food_img.name = "c_image"
	food_img.position = Vector2(150, 45)
	food_img.size = Vector2(150, 100)
	food_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	food_img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notebook.add_child(food_img)

	var info_lbl = Label.new()
	info_lbl.name = "c_info"
	info_lbl.add_theme_font_override("font", fredoka)
	info_lbl.add_theme_font_size_override("font_size", 15)
	info_lbl.add_theme_color_override("font_color", Color(0.2, 0.2, 0.2))
	info_lbl.position = Vector2(70, 220)
	info_lbl.size = Vector2(400, 240)
	info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notebook.add_child(info_lbl)

	var desc_lbl = Label.new()
	desc_lbl.name = "c_desc"
	desc_lbl.add_theme_font_override("font", fredoka)
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	desc_lbl.position = Vector2(70, 410)
	desc_lbl.size = Vector2(350, 230)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notebook.add_child(desc_lbl)

	var page_lbl = Label.new()
	page_lbl.name = "c_page"
	page_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	page_lbl.add_theme_font_override("font", baloo2)
	page_lbl.add_theme_font_size_override("font_size", 15)
	page_lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	page_lbl.position = Vector2(125, 650)
	page_lbl.size = Vector2(200, 30)
	notebook.add_child(page_lbl)

	var prev_btn = Button.new()
	prev_btn.name = "c_prev"
	prev_btn.text = "<"
	prev_btn.add_theme_font_override("font", baloo2)
	prev_btn.add_theme_font_size_override("font_size", 18)
	prev_btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	var nav_sb = StyleBoxFlat.new()
	nav_sb.bg_color = Color(0.8, 0.8, 0.8)
	nav_sb.corner_radius_top_left = 6
	nav_sb.corner_radius_top_right = 6
	nav_sb.corner_radius_bottom_left = 6
	nav_sb.corner_radius_bottom_right = 6
	prev_btn.add_theme_stylebox_override("normal", nav_sb)
	prev_btn.position = Vector2(45, 690)
	prev_btn.size = Vector2(70, 40)
	prev_btn.pressed.connect(_on_catalog_prev)
	notebook.add_child(prev_btn)

	var next_btn = Button.new()
	next_btn.name = "c_next"
	next_btn.text = ">"
	next_btn.add_theme_font_override("font", baloo2)
	next_btn.add_theme_font_size_override("font_size", 18)
	next_btn.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	var nav_sb2 = StyleBoxFlat.new()
	nav_sb2.bg_color = Color(0.8, 0.8, 0.8)
	nav_sb2.corner_radius_top_left = 6
	nav_sb2.corner_radius_top_right = 6
	nav_sb2.corner_radius_bottom_left = 6
	nav_sb2.corner_radius_bottom_right = 6
	next_btn.add_theme_stylebox_override("normal", nav_sb2)
	next_btn.position = Vector2(335, 690)
	next_btn.size = Vector2(70, 40)
	next_btn.pressed.connect(_on_catalog_next)
	notebook.add_child(next_btn)


func _on_catalog_open(kedai_id: String):
	click_player.play(0.0)
	Global.switch_to_kedai(kedai_id)
	catalog_recipes = Global.get_recipes_for_kedai(kedai_id)
	if catalog_recipes.is_empty():
		return
	catalog_current_page = 0
	_show_catalog_page(0)
	catalog_panel.visible = true

func _show_catalog_page(page: int):
	if catalog_recipes.is_empty():
		return
	if page < 0 or page >= catalog_recipes.size():
		return
	catalog_current_page = page
	var key = catalog_recipes[page]
	var is_unlocked = key in Global.unlocked_recipes

	var name_lbl = catalog_panel.get_node("c_notebook/c_name")
	var food_img = catalog_panel.get_node("c_notebook/c_image")
	var info_lbl = catalog_panel.get_node("c_notebook/c_info")
	var desc_lbl = catalog_panel.get_node("c_notebook/c_desc")
	var prev_btn = catalog_panel.get_node("c_notebook/c_prev")
	var next_btn = catalog_panel.get_node("c_notebook/c_next")
	var page_lbl = catalog_panel.get_node("c_notebook/c_page")

	page_lbl.text = Lang.t("page") + str(page + 1) + "/" + str(catalog_recipes.size())
	prev_btn.disabled = page == 0
	next_btn.disabled = page == catalog_recipes.size() - 1

	if is_unlocked:
		var recipe = Global.get_recipe(key, Global.current_kedai_id)
		name_lbl.visible = false
		food_img.visible = true
		food_img.size = Vector2(150, 100)
		food_img.position = Vector2(150, 45)
		var parts = 	Global.current_kedai_id.split("_")
		var kedai_cap = "Kedai"
		for p in parts:
			kedai_cap += p.substr(0, 1).to_upper() + p.substr(1)
		var tex = load("res://Art/FoodImages/" + kedai_cap + "/" + key + ".png") as Texture2D
		if tex:
			var img = tex.get_image()
			img.resize(150, 100, Image.INTERPOLATE_LANCZOS)
			food_img.texture = ImageTexture.create_from_image(img)

		name_lbl.text = Global.get_recipe_name(key)
		name_lbl.position = Vector2(125, 150)
		name_lbl.size = Vector2(200, 30)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.add_theme_font_size_override("font_size", 16)
		name_lbl.add_theme_constant_override("line_spacing", -8)
		name_lbl.visible = true

		var items = ""
		for ing in recipe.ingredients:
			items += "- " + Global.get_station_name(ing) + "\n"
		info_lbl.text = Lang.t("price") + ": Rp " + str(recipe.price) + "\n" + Lang.t("capital") + ": Rp " + str(recipe.fund) + "\n\n" + Lang.t("steps") + ":\n" + items
		info_lbl.visible = true

		desc_lbl.text = Lang.t("desc_" + key)
		desc_lbl.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
		desc_lbl.visible = true
	else:
		name_lbl.visible = false
		food_img.visible = true
		var lock_tex = load("res://Assets/lock.png") as Texture2D
		if lock_tex:
			var orig_size = lock_tex.get_size()
			var scale_h = 120.0
			var scale = scale_h / orig_size.y
			var new_w = int(orig_size.x * scale)
			var new_h = int(orig_size.y * scale)
			var img = lock_tex.get_image()
			img.resize(new_w, new_h, Image.INTERPOLATE_LANCZOS)
			food_img.texture = ImageTexture.create_from_image(img)
			food_img.size = Vector2(new_w, new_h)
			food_img.position = Vector2(225 - new_w / 2, 45)
		info_lbl.visible = false
		var unlock_level = Global.get_recipe_unlock_level(key)
		if unlock_level >= 0:
			desc_lbl.text = "                              " + Lang.t("unlock_level") + str(unlock_level)
		else:
			desc_lbl.text = "\t\t\t???"
		desc_lbl.add_theme_font_override("font", load("res://Assets/Fonts/Baloo2-Bold.ttf"))
		desc_lbl.visible = true

func _on_catalog_next():
	page_player.play(0.0)
	_show_catalog_page(catalog_current_page + 1)

func _on_catalog_prev():
	page_player.play(0.0)
	_show_catalog_page(catalog_current_page - 1)

func _on_catalog_close():
	click_player.play(0.0)
	catalog_panel.visible = false

func _input(event):
	if catalog_panel and catalog_panel.visible:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_swipe_start_x = event.position.x
			elif event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
				var dx = event.position.x - _swipe_start_x
				if dx > 50:
					_on_catalog_prev()
				elif dx < -50:
					_on_catalog_next()

func update_mood_display():
	for i in range(3):
		if i < mood_chilis.size():
			mood_chilis[i].visible = current_state == MenuState.STATE_KEDAI
			mood_chilis[i].texture = mood_tex if i < Global.mood_level else mood_silhouette_tex
	if instant_mood_btn:
		var in_kedai = current_state == MenuState.STATE_KEDAI
		var at_max = Global.mood_level >= 3
		instant_mood_btn.visible = in_kedai
		instant_mood_btn.disabled = at_max
		instant_mood_btn.modulate = Color(1, 1, 1, 0.4) if at_max else Color(1, 1, 1, 1)

func _on_instant_mood_btn_pressed():
	click_player.play(0.0)
	mood_popup.show_instant_mood_popup()

func _on_mood_popup_recovered():
	update_mood_display()

func _on_global_mood_recovered():
	update_mood_display()



func _on_mood_ok_pressed():
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")

func _on_mood_video_pressed():
	var body = mood_popup.get_node("mp_body") as Label
	var result = Ads.start_mood_reward_flow(body)
	if result == Ads.StartResult.SDK_NOT_READY:
		# SDK is still initializing; AdsManager will auto-start the flow
		# when ready. Show a loading message rather than a failed one.
		if body:
			body.text = Lang.t("mood_ad_loading")
	elif result == Ads.StartResult.FLOW_ALREADY_ACTIVE:
		pass
	else:
		# SDK_READY shouldn't be reached here (AdsManager already set
		# the body text), but guard anyway.
		pass

func _on_ads_mood_reward_earned():
	Global.mood_level = mini(3, Global.mood_level + 1)
	Global.save_game()
	mood_popup.hide_popup()
	update_mood_display()

func _on_ads_mood_reward_failed():
	# Body text was set to "mood_ad_failed" by AdsManager; popup stays
	# open so the player can retry or hit OK.
	pass


func _on_kedai_selected(kedai_id: String):
	click_player.play(0.0)
	Global.process_mood_recovery()
	if Global.is_mood_depleted():
		mood_popup.show_popup()
		return
	Global.switch_to_kedai(kedai_id)
	_refresh_level_nodes()
	_show_level_select()


func _on_back_to_main():
	if current_state == MenuState.STATE_MAIN:
		return
	click_player.play(0.0)
	_show_main_menu()

const LEVELS_MAX = 100
const NODES_PER_ROW = 5
const NODE_SIZE = 40
const NODE_SPACING_X = 64
const NODE_SPACING_Y = 72
const NODE_START_X = 100
const NODE_START_Y = 20

func _get_level_node_pos(level: int) -> Vector2:
	var idx = level - 1
	var row = idx / NODES_PER_ROW
	var col = idx % NODES_PER_ROW
	if row % 2 == 1:
		col = NODES_PER_ROW - 1 - col
	var x = NODE_START_X + col * NODE_SPACING_X
	var y = NODE_START_Y + row * NODE_SPACING_Y
	return Vector2(x, y)


func setup_level_select_ui():
	var baloo2 = ResourceLoader.load("res://Assets/Fonts/Baloo2-Bold.ttf")

	level_select_panel = Control.new()
	level_select_panel.visible = false
	level_select_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(level_select_panel)

	_level_select_bg = TextureRect.new()
	_update_level_select_bg()
	_level_select_bg.stretch_mode = TextureRect.STRETCH_SCALE
	_level_select_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_level_select_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_select_panel.add_child(_level_select_bg)

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_select_panel.add_child(overlay)

	var top_bar = ColorRect.new()
	top_bar.color = Color(0, 0, 0, 0.75)
	top_bar.position = Vector2(0, 0)
	top_bar.size = Vector2(480, 55)
	top_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_select_panel.add_child(top_bar)

	var mood_lbl = Label.new()
	mood_lbl.text = Lang.t("mood_label")
	mood_lbl.add_theme_font_override("font", baloo2)
	mood_lbl.add_theme_font_size_override("font_size", 18)
	mood_lbl.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	mood_lbl.position = Vector2(16, 6)
	mood_lbl.size = Vector2(50, 20)
	level_select_panel.add_child(mood_lbl)

	for i in range(3):
		var tr = TextureRect.new()
		tr.name = "ls_chili_" + str(i)
		tr.texture = mood_tex if i < Global.mood_level else mood_silhouette_tex
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.position = Vector2(78 + i * 22, 6)
		tr.size = Vector2(18, 18)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		level_select_panel.add_child(tr)

	var ls_savings = Label.new()
	ls_savings.name = "ls_savings"
	ls_savings.text = Lang.t("savings") + " : " + _format_money(Global.money)
	ls_savings.add_theme_font_override("font", baloo2)
	ls_savings.add_theme_font_size_override("font_size", 18)
	ls_savings.add_theme_color_override("font_color", Color(0.2, 0.8, 0.2))
	ls_savings.position = Vector2(16, 30)
	ls_savings.size = Vector2(200, 20)
	level_select_panel.add_child(ls_savings)

	var scroll_area = Control.new()
	scroll_area.name = "ls_scroll"
	scroll_area.position = Vector2(0, 55)
	scroll_area.size = Vector2(480, LS_SCROLL_AREA_HEIGHT)
	scroll_area.clip_contents = true
	level_select_panel.add_child(scroll_area)

	var track_height = ((LEVELS_MAX - 1) / NODES_PER_ROW + 1) * NODE_SPACING_Y + 60
	var track_container = Control.new()
	track_container.name = "ls_track"
	track_container.position = Vector2(0, 0)
	track_container.size = Vector2(460, track_height)
	track_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scroll_area.add_child(track_container)
	scroll_area.gui_input.connect(_on_level_select_input)

	var dot_color = Color(0.85, 0.85, 0.85)
	var dot_size = 2
	var dot_spacing = 6
	var dot_radius = dot_size / 2
	var dot_style = StyleBoxFlat.new()
	dot_style.bg_color = dot_color
	dot_style.corner_radius_top_left = dot_radius
	dot_style.corner_radius_top_right = dot_radius
	dot_style.corner_radius_bottom_left = dot_radius
	dot_style.corner_radius_bottom_right = dot_radius

	for i in range(1, LEVELS_MAX):
		var pos_a = _get_level_node_pos(i)
		var pos_b = _get_level_node_pos(i + 1)

		if pos_a.y == pos_b.y:
			var left = mini(pos_a.x, pos_b.x) + NODE_SIZE
			var right = maxi(pos_a.x, pos_b.x)
			var y = pos_a.y + NODE_SIZE / 2 - dot_radius
			var x = left
			while x < right:
				var dot = ColorRect.new()
				dot.size = Vector2(dot_size, dot_size)
				dot.position = Vector2(x, y)
				dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
				dot.add_theme_stylebox_override("normal", dot_style)
				track_container.add_child(dot)
				x += dot_spacing
		else:
			var top = pos_a.y + NODE_SIZE
			var bottom = pos_b.y
			var x = pos_a.x + NODE_SIZE / 2 - dot_radius
			var y = top
			while y < bottom:
				var dot = ColorRect.new()
				dot.size = Vector2(dot_size, dot_size)
				dot.position = Vector2(x, y)
				dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
				dot.add_theme_stylebox_override("normal", dot_style)
				track_container.add_child(dot)
				y += dot_spacing

	var lock_tex = load("res://Assets/lock.png") as Texture2D
	var lock_img = lock_tex.get_image()
	lock_img.resize(24, 30, Image.INTERPOLATE_LANCZOS)
	_lock_tex_small = ImageTexture.create_from_image(lock_img)

	var level_node_tex = load("res://Assets/LevelNodes/level_node_" + Global.current_kedai_id + ".png") as Texture2D
	var level_node_img = level_node_tex.get_image()
	level_node_img.resize(NODE_SIZE, NODE_SIZE, Image.INTERPOLATE_LANCZOS)
	_level_node_tex_small = ImageTexture.create_from_image(level_node_img)

	_baloo2_font = baloo2

	for level in range(1, LEVELS_MAX + 1):
		var pos = _get_level_node_pos(level)
		var is_playable = level <= Global.max_level
		var is_current = level == Global.max_level

		var node = Control.new()
		node.name = "ls_node_" + str(level)
		node.position = pos
		node.size = Vector2(NODE_SIZE, NODE_SIZE)
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE

		var level_tr = TextureRect.new()
		level_tr.name = "tex"
		level_tr.texture = _level_node_tex_small
		level_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		level_tr.size = Vector2(NODE_SIZE, NODE_SIZE)
		level_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		level_tr.visible = is_playable
		node.add_child(level_tr)
		level_node_tex_rects.append(level_tr)

		var lbl = Label.new()
		lbl.name = "lbl"
		lbl.text = str(level)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.position = Vector2(5, NODE_SIZE - 23)
		lbl.size = Vector2(14, 14)
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.add_theme_font_override("font", _baloo2_font)
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color(0, 0, 0))
		lbl.visible = is_playable
		node.add_child(lbl)
		level_node_labels.append(lbl)

		var lock_tr = TextureRect.new()
		lock_tr.name = "lock"
		lock_tr.texture = _lock_tex_small
		lock_tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock_tr.position = Vector2(NODE_SIZE / 2 - 12, NODE_SIZE / 2 - 13)
		lock_tr.size = Vector2(24, 26)
		lock_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock_tr.visible = not is_playable
		node.add_child(lock_tr)
		level_node_lock_rects.append(lock_tr)

		track_container.add_child(node)
		level_nodes.append(node)

	var mm_btn = TextureButton.new()
	mm_btn.name = "ls_main_menu"
	mm_btn.texture_normal = main_menu_eng if Lang.current_language == "en" else main_menu_id
	mm_btn.size = Vector2(200, 50)
	mm_btn.position = Vector2(140, 790)
	mm_btn.pressed.connect(_on_level_select_main_menu)
	mm_btn.button_down.connect(_on_btn_down.bind(mm_btn))
	mm_btn.button_up.connect(_on_btn_up.bind(mm_btn))
	level_select_panel.add_child(mm_btn)

	level_popup = Control.new()
	level_popup.visible = false
	level_select_panel.add_child(level_popup)

	var popup_bg = ColorRect.new()
	popup_bg.color = Color(0, 0, 0, 0.7)
	popup_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	level_popup.add_child(popup_bg)

	var popup_frame = Panel.new()
	var popup_frame_style = StyleBoxFlat.new()
	popup_frame_style.bg_color = Color(0.12, 0.12, 0.16, 0.95)
	popup_frame_style.corner_radius_top_left = 16
	popup_frame_style.corner_radius_top_right = 16
	popup_frame_style.corner_radius_bottom_left = 16
	popup_frame_style.corner_radius_bottom_right = 16
	popup_frame.add_theme_stylebox_override("panel", popup_frame_style)
	popup_frame.position = Vector2(65, 160)
	popup_frame.size = Vector2(350, 220)
	level_popup.add_child(popup_frame)

	level_popup_title = Label.new()
	level_popup_title.name = "lp_title"
	level_popup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	level_popup_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	level_popup_title.add_theme_font_override("font", baloo2)
	level_popup_title.add_theme_font_size_override("font_size", 22)
	level_popup_title.add_theme_color_override("font_color", Color(0.95, 0.75, 0.15))
	level_popup_title.position = Vector2(65, 180)
	level_popup_title.size = Vector2(350, 70)
	level_popup.add_child(level_popup_title)

	level_ok_tex = make_texture("res://Art/Buttons/button_ok.png", 140, 45)
	level_cancel_eng = make_texture("res://Art/Buttons/button_cancel.png", 140, 45)
	level_cancel_id = make_texture("res://Art/Buttons/button_batal.png", 140, 45)

	var ok_btn = TextureButton.new()
	ok_btn.name = "lp_ok"
	ok_btn.texture_normal = level_ok_tex
	ok_btn.position = Vector2(170, 257)
	ok_btn.size = Vector2(140, 45)
	ok_btn.pressed.connect(_on_level_popup_ok)
	ok_btn.button_down.connect(_on_btn_down.bind(ok_btn))
	ok_btn.button_up.connect(_on_btn_up.bind(ok_btn))
	level_popup.add_child(ok_btn)

	level_cancel_btn = TextureButton.new()
	level_cancel_btn.name = "lp_cancel"
	level_cancel_btn.texture_normal = level_cancel_eng if Lang.current_language == "en" else level_cancel_id
	level_cancel_btn.position = Vector2(170, 313)
	level_cancel_btn.size = Vector2(140, 45)
	level_cancel_btn.pressed.connect(_on_level_popup_cancel)
	level_cancel_btn.button_down.connect(_on_btn_down.bind(level_cancel_btn))
	level_cancel_btn.button_up.connect(_on_btn_up.bind(level_cancel_btn))
	level_popup.add_child(level_cancel_btn)


func _on_level_select_input(event: InputEvent):
	var area = level_select_panel.get_node("ls_scroll") as Control
	var track = area.get_node("ls_track") as Control
	var max_scroll = max(0, track.size.y - LS_SCROLL_AREA_HEIGHT)

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var adjusted = event.position + Vector2(0, _ls_scroll_y)
			_check_level_select_tap(adjusted)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_ls_scroll_y = max(0, _ls_scroll_y - 80)
			track.position.y = -_ls_scroll_y
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_ls_scroll_y = mini(_ls_scroll_y + 80, max_scroll)
			track.position.y = -_ls_scroll_y
	elif event is InputEventScreenTouch:
		if event.pressed:
			_ls_touching = true
			_ls_touch_start = event.position
		elif _ls_touching:
			_ls_touching = false
			if _ls_touch_start.distance_to(event.position) < 15:
				var adjusted = event.position + Vector2(0, _ls_scroll_y)
				_check_level_select_tap(adjusted)
	elif event is InputEventScreenDrag and _ls_touching:
		_ls_scroll_y = clampi(_ls_scroll_y - int(event.relative.y), 0, max_scroll)
		track.position.y = -_ls_scroll_y


func _check_level_select_tap(pos: Vector2):
	for level in range(1, LEVELS_MAX + 1):
		if level > Global.max_level:
			break
		var node_pos = _get_level_node_pos(level)
		var rect = Rect2(node_pos, Vector2(NODE_SIZE, NODE_SIZE))
		if rect.has_point(pos):
			click_player.play(0.0)
			level_popup_selected_level = level
			level_popup_title.text = Lang.t("play_level") + "\n" + Lang.t("level") + str(level) + " ?"
			level_popup.visible = true
			return


func _on_level_popup_ok():
	click_player.play(0.0)
	Global.level = level_popup_selected_level
	Global.on_gameplay_started()
	get_tree().change_scene_to_file("res://Scenes/Game.tscn")


func _on_level_popup_cancel():
	click_player.play(0.0)
	level_popup.visible = false


func _on_level_select_main_menu():
	click_player.play(0.0)
	_stop_level_pulse()
	var tween = create_tween()
	tween.tween_property(level_select_panel, "modulate", Color(1, 1, 1, 0), 0.3)
	await tween.finished
	level_select_panel.visible = false
	level_popup.visible = false
	_show_main_menu()


func _update_level_select_bg():
	var bg_path = "res://Assets/Backgrounds/leveling_" + Global.current_kedai_id + ".png"
	var bg_tex = load(bg_path) as Texture2D
	if bg_tex:
		var bg_img = bg_tex.get_image()
		bg_img.resize(480, 854, Image.INTERPOLATE_LANCZOS)
		_level_select_bg.texture = ImageTexture.create_from_image(bg_img)

func _refresh_level_nodes():
	_update_level_select_bg()
	var node_tex_path = "res://Assets/LevelNodes/level_node_" + Global.current_kedai_id + ".png"
	var node_tex = load(node_tex_path) as Texture2D
	if node_tex:
		var node_img = node_tex.get_image()
		node_img.resize(NODE_SIZE, NODE_SIZE, Image.INTERPOLATE_LANCZOS)
		_level_node_tex_small = ImageTexture.create_from_image(node_img)
	for level in range(1, LEVELS_MAX + 1):
		var idx = level - 1
		var is_playable = level <= Global.max_level
		level_node_tex_rects[idx].texture = _level_node_tex_small
		level_node_tex_rects[idx].visible = is_playable
		level_node_labels[idx].visible = is_playable
		level_node_lock_rects[idx].visible = not is_playable

func _show_level_select():
	if current_tween and current_tween.is_running():
		current_tween.kill()
	current_state = MenuState.STATE_LEVEL_SELECT

	var tween = create_tween().set_parallel(true)
	current_tween = tween
	for i in kedai_buttons.size():
		var btn = kedai_buttons[i]
		tween.tween_property(btn, "position", kedai_btn_positions[i] + Vector2(0, -30), 0.3)
		tween.tween_property(btn, "modulate", Color(1, 1, 1, 0), 0.3)
	for i in catalog_buttons.size():
		var btn = catalog_buttons[i]
		tween.tween_property(btn, "position", catalog_btn_positions[i] + Vector2(0, -30), 0.3)
		tween.tween_property(btn, "modulate", Color(1, 1, 1, 0), 0.3)
	for i in kedai_textures.size():
		var tex = kedai_textures[i]
		tween.tween_property(tex, "position", kedai_texture_positions[i] + Vector2(0, -30), 0.3)
		tween.tween_property(tex, "modulate", Color(1, 1, 1, 0), 0.3)
	for i in kedai_name_labels.size():
		var lbl = kedai_name_labels[i]
		tween.tween_property(lbl, "position", kedai_label_positions[i] + Vector2(0, -30), 0.3)
		tween.tween_property(lbl, "modulate", Color(1, 1, 1, 0), 0.3)
	for i in gameplay_buttons.size():
		var btn = gameplay_buttons[i]
		tween.tween_property(btn, "position", gameplay_btn_positions[i] + Vector2(0, -30), 0.3)
		tween.tween_property(btn, "modulate", Color(1, 1, 1, 0), 0.3)
	for i in build_buttons.size():
		var btn = build_buttons[i]
		tween.tween_property(btn, "position", build_btn_positions[i] + Vector2(0, -30), 0.3)
		tween.tween_property(btn, "modulate", Color(1, 1, 1, 0), 0.3)
	var mood_label_node = get_node("mood_label")
	tween.tween_property(mood_label_node, "modulate", Color(1, 1, 1, 0), 0.3)
	tween.tween_property(savings_label, "modulate", Color(1, 1, 1, 0), 0.3)
	for tr in mood_chilis:
		tween.tween_property(tr, "modulate", Color(1, 1, 1, 0), 0.3)
	if instant_mood_btn:
		tween.tween_property(instant_mood_btn, "modulate", Color(1, 1, 1, 0), 0.3)
	await tween.finished

	for i in kedai_buttons.size():
		kedai_buttons[i].visible = false
		kedai_buttons[i].position = kedai_btn_positions[i]
	for i in catalog_buttons.size():
		catalog_buttons[i].visible = false
		catalog_buttons[i].position = catalog_btn_positions[i]
	for i in kedai_textures.size():
		kedai_textures[i].visible = false
		kedai_textures[i].position = kedai_texture_positions[i]
	for i in kedai_name_labels.size():
		kedai_name_labels[i].visible = false
		kedai_name_labels[i].position = kedai_label_positions[i]
	for i in gameplay_buttons.size():
		gameplay_buttons[i].visible = false
		gameplay_buttons[i].position = gameplay_btn_positions[i]
	for i in build_buttons.size():
		build_buttons[i].visible = false
		build_buttons[i].position = build_btn_positions[i]
	mood_label_node.visible = false
	savings_label.visible = false
	for tr in mood_chilis:
		tr.visible = false
	if instant_mood_btn:
		instant_mood_btn.visible = false

	Global.process_mood_recovery()
	_update_level_select_mood_savings()
	var is_en = Lang.current_language == "en"
	var mm_btn = level_select_panel.get_node_or_null("ls_main_menu") as TextureButton
	if mm_btn:
		mm_btn.texture_normal = main_menu_eng if is_en else main_menu_id
	var ls_area = level_select_panel.get_node("ls_scroll") as Control
	_ls_scroll_y = 0
	if ls_area:
		var ls_track = ls_area.get_node("ls_track") as Control
		if ls_track:
			ls_track.position.y = 0
	level_select_panel.visible = true
	level_select_panel.modulate = Color(1, 1, 1, 0)
	var tween2 = create_tween().set_parallel(true)
	current_tween = tween2
	tween2.tween_property(level_select_panel, "modulate", Color(1, 1, 1, 1), 0.3)
	await tween2.finished
	_start_level_pulse()


func _update_level_select_mood_savings():
	var panel = level_select_panel
	if not panel:
		return
	for i in range(3):
		var tr = panel.get_node_or_null("ls_chili_" + str(i))
		if tr:
			tr.texture = mood_tex if i < Global.mood_level else mood_silhouette_tex
	var ls_sav = panel.get_node_or_null("ls_savings")
	if ls_sav:
		ls_sav.text = Lang.t("savings") + " : " + _format_money(Global.money)


func _start_level_pulse():
	var track_node = level_select_panel.get_node_or_null("ls_scroll/ls_track/ls_node_" + str(Global.max_level))
	if not track_node:
		return
	track_node.scale = Vector2(1, 1)
	_level_pulse_tween = create_tween().set_loops()
	_level_pulse_tween.tween_property(track_node, "scale", Vector2(1.15, 1.15), 0.6)
	_level_pulse_tween.tween_property(track_node, "scale", Vector2(1.0, 1.0), 0.6)

func _stop_level_pulse():
	if _level_pulse_tween and _level_pulse_tween.is_running():
		_level_pulse_tween.kill()
	_level_pulse_tween = null

func _start_btn_breath():
	var btn = get_node_or_null("start_btn")
	if not btn:
		return
	_stop_btn_breath()
	_btn_breath_tween = create_tween().set_loops()
	_btn_breath_tween.tween_property(btn, "scale", Vector2(1.08, 1.08), 0.8)
	_btn_breath_tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.8)

func _stop_btn_breath():
	if _btn_breath_tween and _btn_breath_tween.is_running():
		_btn_breath_tween.kill()
	_btn_breath_tween = null
	var btn = get_node_or_null("start_btn")
	if btn:
		btn.scale = Vector2(1, 1)

func _on_build_pressed(kedai_id: String):
	click_player.play(0.0)
	_show_buy_popup(kedai_id)

func _show_buy_popup(kedai_id: String):
	current_buy_kedai_id = kedai_id
	if buy_popup:
		buy_popup.queue_free()
	buy_popup = Control.new()
	buy_popup.name = "buy_popup"
	buy_popup.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(buy_popup)

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	buy_popup.add_child(overlay)

	var baloo2 = ResourceLoader.load("res://Assets/Fonts/Baloo2-Bold.ttf")
	var fredoka = ResourceLoader.load("res://Assets/Fonts/Fredoka-Regular.ttf")
	var is_en = Lang.current_language == "en"

	var frame = Panel.new()
	var frame_style = StyleBoxFlat.new()
	frame_style.bg_color = Color(0.12, 0.12, 0.16, 0.95)
	frame_style.corner_radius_top_left = 16
	frame_style.corner_radius_top_right = 16
	frame_style.corner_radius_bottom_left = 16
	frame_style.corner_radius_bottom_right = 16
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.position = Vector2(10, 317)
	frame.size = Vector2(460, 230)
	buy_popup.add_child(frame)

	var title_lbl = Label.new()
	title_lbl.text = Lang.t("build_title")
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_override("font", baloo2)
	title_lbl.add_theme_font_size_override("font_size", 20)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 0.15))
	title_lbl.position = Vector2(40, 330)
	title_lbl.size = Vector2(400, 32)
	buy_popup.add_child(title_lbl)

	var desc_lbl = Label.new()
	desc_lbl.text = _get_kedai_display_name(kedai_id)
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.add_theme_font_override("font", fredoka)
	desc_lbl.add_theme_font_size_override("font_size", 14)
	desc_lbl.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	desc_lbl.position = Vector2(40, 365)
	desc_lbl.size = Vector2(400, 24)
	buy_popup.add_child(desc_lbl)

	var prices = IAPConfig.get_price(kedai_id)

	var trade_tex = load("res://Art/Buttons/button_trade.png" if is_en else "res://Art/Buttons/button_tukar.png") as Texture2D
	if trade_tex:
		var trade_btn = TextureButton.new()
		trade_btn.texture_normal = trade_tex
		trade_btn.position = Vector2(30, 405)
		trade_btn.size = Vector2(160, 50)
		if Global.money >= prices.game_money:
			trade_btn.pressed.connect(_on_trade_pressed)
		else:
			trade_btn.disabled = true
			trade_btn.modulate = Color(1, 1, 1, 0.35)
		trade_btn.button_down.connect(_on_btn_down.bind(trade_btn))
		trade_btn.button_up.connect(_on_btn_up.bind(trade_btn))
		buy_popup.add_child(trade_btn)

		var price_lbl = Label.new()
		price_lbl.text = _format_money(prices.game_money)
		price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_lbl.add_theme_font_override("font", fredoka)
		price_lbl.add_theme_font_size_override("font_size", 14)
		price_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.3) if Global.money >= prices.game_money else Color(0.8, 0.3, 0.3))
		price_lbl.position = Vector2(50, 460)
		price_lbl.size = Vector2(160, 20)
		buy_popup.add_child(price_lbl)

		if Global.money < prices.game_money:
			var insuff_lbl = Label.new()
			insuff_lbl.text = Lang.t("insufficient_funds")
			insuff_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			insuff_lbl.add_theme_font_override("font", fredoka)
			insuff_lbl.add_theme_font_size_override("font_size", 14)
			insuff_lbl.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
			insuff_lbl.position = Vector2(50, 482)
			insuff_lbl.size = Vector2(160, 20)
			buy_popup.add_child(insuff_lbl)

	var buy_tex = load("res://Art/Buttons/button_buy.png" if is_en else "res://Art/Buttons/button_beli.png") as Texture2D
	if buy_tex:
		var buy_btn = TextureButton.new()
		buy_btn.texture_normal = buy_tex
		buy_btn.position = Vector2(250, 405)
		buy_btn.size = Vector2(160, 50)
		buy_btn.pressed.connect(_on_iap_pressed)
		buy_btn.button_down.connect(_on_btn_down.bind(buy_btn))
		buy_btn.button_up.connect(_on_btn_up.bind(buy_btn))
		buy_popup.add_child(buy_btn)

		var iap_price_lbl = Label.new()
		iap_price_lbl.text = Lang.t("google_play_price") % str(prices.google_play_price)
		iap_price_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		iap_price_lbl.add_theme_font_override("font", fredoka)
		iap_price_lbl.add_theme_font_size_override("font_size", 12)
		iap_price_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
		iap_price_lbl.position = Vector2(270, 460)
		iap_price_lbl.size = Vector2(160, 20)
		buy_popup.add_child(iap_price_lbl)

		var iap_status_lbl = Label.new()
		iap_status_lbl.name = "iap_status_lbl"
		iap_status_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		iap_status_lbl.add_theme_font_override("font", fredoka)
		iap_status_lbl.add_theme_font_size_override("font_size", 14)
		iap_status_lbl.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
		iap_status_lbl.position = Vector2(270, 482)
		iap_status_lbl.size = Vector2(160, 20)
		iap_status_lbl.visible = false
		buy_popup.add_child(iap_status_lbl)

	var close_btn = Button.new()
	close_btn.text = "X"
	close_btn.add_theme_font_override("font", baloo2)
	close_btn.add_theme_font_size_override("font_size", 20)
	close_btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	var close_sb = StyleBoxFlat.new()
	close_sb.bg_color = Color(0.75, 0.1, 0.1)
	close_sb.corner_radius_top_left = 6
	close_sb.corner_radius_top_right = 6
	close_sb.corner_radius_bottom_left = 6
	close_sb.corner_radius_bottom_right = 6
	close_btn.add_theme_stylebox_override("normal", close_sb)
	close_btn.position = Vector2(404, 325)
	close_btn.size = Vector2(28, 28)
	close_btn.pressed.connect(_on_buy_popup_close)
	buy_popup.add_child(close_btn)

func _on_buy_popup_close():
	click_player.play(0.0)
	if buy_popup:
		buy_popup.queue_free()
		buy_popup = null

func _on_trade_pressed():
	var price = IAPConfig.get_price(current_buy_kedai_id).game_money
	if Global.money >= price:
		Global.money -= price
		Global.unlock_kedai(current_buy_kedai_id)
		_on_buy_popup_close()
		_refresh_kedai_row(current_buy_kedai_id)

func _on_iap_pressed():
	if not IAP:
		return
	if Global.is_kedai_unlocked(current_buy_kedai_id):
		_on_buy_popup_close()
		_refresh_kedai_row(current_buy_kedai_id)
		return
	var result = IAP.purchase_kedai(current_buy_kedai_id)
	match result:
		IAP.PurchaseResult.UNAVAILABLE:
			_show_iap_status(Lang.t("iap_unavailable"))
		IAP.PurchaseResult.NOT_INITIALIZED:
			_show_iap_status(Lang.t("iap_not_ready"))
		IAP.PurchaseResult.NO_SKU:
			_show_iap_status(Lang.t("iap_unavailable"))

func _show_iap_status(text: String):
	if not buy_popup:
		return
	var lbl = buy_popup.get_node("iap_status_lbl") as Label
	if lbl:
		lbl.text = text
		lbl.visible = true

func _on_iap_kedai_unlocked(kedai_id: String, token: String):
	Global.unlock_kedai(kedai_id)
	var sku = IAPConfig.get_sku(kedai_id)
	Global.mark_purchase_processed(token, sku)
	IAP.finalize_purchase(token, sku)
	_on_buy_popup_close()
	_refresh_kedai_row(kedai_id)

func _on_purchases_restored():
	var pending = IAP.get_pending_restorations()
	for p in pending:
		var sku = p["sku"]
		var token = p["token"]
		if sku == IAPConfig.EXTEND_KITCHEN_SKU:
			continue
		for wid in IAPConfig.SKUS:
			if IAPConfig.SKUS[wid] == sku:
				Global.unlock_kedai(wid)
				Global.mark_purchase_processed(token, sku)
				IAP.finalize_purchase(token, sku)
				_refresh_kedai_row(wid)
				break

func _refresh_kedai_row(kedai_id: String):
	var idx = _KEDAI_IDS.find(kedai_id)
	if idx < 0 or idx >= _kedai_enabled_flags.size():
		return

	_kedai_enabled_flags[idx] = true

	kedai_textures[idx].modulate = Color(1, 1, 1, 1)

	var name_lbl = kedai_name_labels[idx]
	name_lbl.add_theme_color_override("font_color", Color(1, 1, 1))

	gameplay_buttons[idx].disabled = false
	gameplay_buttons[idx].visible = current_state == MenuState.STATE_KEDAI
	gameplay_buttons[idx].modulate = Color(1, 1, 1, 1)
	var gp_styles = gameplay_buttons[idx].get_theme_stylebox("normal") as StyleBoxFlat
	if gp_styles:
		gp_styles.bg_color = Color(0, 0, 0, 0)
	if not gameplay_buttons[idx].pressed.is_connected(_on_kedai_selected):
		gameplay_buttons[idx].pressed.connect(_on_kedai_selected.bind(kedai_id))
		gameplay_buttons[idx].button_down.connect(_on_btn_down.bind(gameplay_buttons[idx]))
		gameplay_buttons[idx].button_up.connect(_on_btn_up.bind(gameplay_buttons[idx]))

	catalog_buttons[idx].disabled = false
	catalog_buttons[idx].visible = current_state == MenuState.STATE_KEDAI
	catalog_buttons[idx].modulate = Color(1, 1, 1, 1)
	var cat_styles = catalog_buttons[idx].get_theme_stylebox("normal") as StyleBoxFlat
	if cat_styles:
		cat_styles.bg_color = Color(0, 0, 0, 0)
	if not catalog_buttons[idx].pressed.is_connected(_on_catalog_open):
		catalog_buttons[idx].pressed.connect(_on_catalog_open.bind(kedai_id))
		catalog_buttons[idx].button_down.connect(_on_btn_down.bind(catalog_buttons[idx]))
		catalog_buttons[idx].button_up.connect(_on_btn_up.bind(catalog_buttons[idx]))

	build_buttons[idx].visible = false
	build_buttons[idx].disabled = true

	savings_label.text = Lang.t("savings") + " : " + _format_money(Global.money)

func _get_kedai_display_name(kedai_id: String) -> String:
	var names = {
		"pecel_lele": "Kedai Pecel Lele",
		"angkringan": "Kedai Angkringan",
		"nasi_padang": "Kedai Nasi Padang",
		"mie_ayam_bakso": "Kedai Mie Ayam Bakso",
	}
	return names.get(kedai_id, "Kedai")

static func _format_money(amount: int) -> String:
	var s = str(amount)
	var result = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "." + result
		result = s[i] + result
		count += 1
	return "Rp " + result
