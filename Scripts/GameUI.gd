extends CanvasLayer

const MoodPopup = preload("res://Scripts/MoodPopup.gd")

var money_label: Label
var timer_label: Label
var pause_panel: Control
var summary_panel: Control
var is_paused := false
var can_pause := true
var _last_toggle_frame := -1
var new_recipe_panel: Control
var new_recipe_key_store: String = ""
var mood_popup: MoodPopup
var 	mood_popup_shown := false
var fireworks_container: Control
var _circle_tex: Texture2D
const MAX_LEVEL := 100
var mood_tex: Texture2D
var mood_silhouette_tex: Texture2D
var _level_lbl: Label
var _mood_lbl: Label
var customer_counter_label: Label
var counter_title: Label

var _kedai_hud_colors := {
	"nasi_goreng": {
		"primary": Color(0.3, 0.9, 0.3),
		"timer": Color(0.3, 0.9, 0.3)
	},
	"pecel_lele": {
		"primary": Color(0.95, 0.75, 0.0),
		"timer": Color(0.95, 0.75, 0.0)
	},
	"nasi_padang": {
		"primary": Color(0.6, 0.0, 0.0),
		"timer": Color(0.6, 0.0, 0.0)
	},
	"mie_ayam_bakso": {
		"primary": Color(0.0, 0.0, 0.5),
		"timer": Color(0.0, 0.0, 0.5)
	},
	"angkringan": {
		"primary": Color(0.0, 0.0, 0.0),
		"timer": Color(0.0, 0.0, 0.0)
	}
}

func _ready():
	process_mode = PROCESS_MODE_WHEN_PAUSED
	setup_hud()
	setup_mood_display()
	setup_pause_panel()
	setup_summary_panel()
	setup_new_recipe_panel()
	mood_popup = MoodPopup.new()
	mood_popup.process_mode = PROCESS_MODE_WHEN_PAUSED
	add_child(mood_popup)
	mood_popup.setup()
	mood_popup.ok_pressed.connect(_on_mood_ok_pressed)
	mood_popup.video_pressed.connect(_on_mood_video_pressed)
	mood_popup.mood_recovered.connect(_on_mood_popup_recovered)
	Global.mood_recovered.connect(_on_global_mood_recovered)
	Lang.language_changed.connect(_on_language_changed)
	Ads.mood_reward_earned.connect(_on_ads_mood_reward_earned)
	Ads.mood_reward_failed.connect(_on_ads_mood_reward_failed)

func setup_hud():
	var fredoka = ResourceLoader.load("res://Assets/Fonts/Fredoka-Regular.ttf")
	var baloo2 = ResourceLoader.load("res://Assets/Fonts/Baloo2-Bold.ttf")
	_level_lbl = Label.new()
	_level_lbl.name = "level_lbl"
	_level_lbl.add_theme_font_override("font", baloo2)
	_level_lbl.add_theme_font_size_override("font_size", 18)
	_level_lbl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_level_lbl.position = Vector2(52, 24)
	_level_lbl.size = Vector2(80, 18)
	add_child(_level_lbl)

	money_label = Label.new()
	money_label.add_theme_font_override("font", baloo2)
	money_label.add_theme_font_size_override("font_size", 16)
	money_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	money_label.position = Vector2(145, 20)
	money_label.size = Vector2(80, 18)
	add_child(money_label)

	timer_label = Label.new()
	timer_label.add_theme_font_override("font", baloo2)
	timer_label.add_theme_font_size_override("font_size", 18)
	timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	timer_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	timer_label.position = Vector2(-135, 23)
	timer_label.size = Vector2(60, 24)
	add_child(timer_label)

	counter_title = Label.new()
	counter_title.name = "counter_title"
	counter_title.add_theme_font_override("font", baloo2)
	counter_title.add_theme_font_size_override("font_size", 16)
	counter_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	counter_title.position = Vector2(205, 42)
	counter_title.size = Vector2(60, 16)
	add_child(counter_title)
	counter_title.text = Lang.t("customer_counter")

	customer_counter_label = Label.new()
	customer_counter_label.name = "customer_counter_label"
	customer_counter_label.add_theme_font_override("font", baloo2)
	customer_counter_label.add_theme_font_size_override("font_size", 16)
	customer_counter_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	customer_counter_label.position = Vector2(227, 60)
	customer_counter_label.size = Vector2(60, 20)
	add_child(customer_counter_label)

	var pause_tex = TextureRect.new()
	pause_tex.name = "pause_tex"
	var ptex_path = "res://Art/Buttons/pause_button_en.png" if Lang.current_language == "en" else "res://Art/Buttons/pause_button_id.png"
	var ptex = load(ptex_path) as Texture2D
	var pimg = ptex.get_image()
	pimg.resize(110, 32, Image.INTERPOLATE_LANCZOS)
	pause_tex.texture = ImageTexture.create_from_image(pimg)
	pause_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pause_tex.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_tex.position = Vector2(-152, 48)
	pause_tex.size = Vector2(110, 32)
	pause_tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pause_tex)

func setup_mood_display():
	var baloo2 = ResourceLoader.load("res://Assets/Fonts/Baloo2-Bold.ttf")
	_mood_lbl = Label.new()
	_mood_lbl.name = "mood_lbl"
	_mood_lbl.text = Lang.t("mood_label")
	_mood_lbl.add_theme_font_override("font", baloo2)
	_mood_lbl.add_theme_font_size_override("font_size", 18)
	_mood_lbl.position = Vector2(52, 48)
	_mood_lbl.size = Vector2(36, 18)
	add_child(_mood_lbl)

	var chili_tex = load("res://Art/chili_mood.png") as Texture2D
	var chili_img = chili_tex.get_image()
	chili_img.resize(18, 18, Image.INTERPOLATE_LANCZOS)
	mood_tex = ImageTexture.create_from_image(chili_img)

	var silhouette_tex = load("res://Art/chili_mood_silhouette.png") as Texture2D
	var silhouette_img = silhouette_tex.get_image()
	silhouette_img.resize(18, 18, Image.INTERPOLATE_LANCZOS)
	mood_silhouette_tex = ImageTexture.create_from_image(silhouette_img)

	for i in range(3):
		var tr = TextureRect.new()
		tr.name = "mood_chili_" + str(i)
		tr.texture = mood_tex
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.position = Vector2(105 + i * 18, 53)
		tr.size = Vector2(18, 18)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(tr)

	update_mood_display()

func update_mood_display():
	for i in range(3):
		var tr = get_node_or_null("mood_chili_" + str(i))
		if tr:
			tr.visible = true
			tr.texture = mood_tex if i < Global.mood_level else mood_silhouette_tex

func _on_global_mood_recovered():
	update_mood_display()

func setup_pause_panel():
	var fredoka = ResourceLoader.load("res://Assets/Fonts/Fredoka-Regular.ttf")
	var baloo2 = ResourceLoader.load("res://Assets/Fonts/Baloo2-Bold.ttf")
	pause_panel = Control.new()
	pause_panel.visible = false
	pause_panel.process_mode = PROCESS_MODE_WHEN_PAUSED
	add_child(pause_panel)

	var bg = ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.7)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_panel.add_child(bg)

	var frame = Panel.new()
	var frame_style = StyleBoxFlat.new()
	frame_style.bg_color = Color(0.12, 0.12, 0.16, 0.95)
	frame_style.corner_radius_top_left = 16
	frame_style.corner_radius_top_right = 16
	frame_style.corner_radius_bottom_left = 16
	frame_style.corner_radius_bottom_right = 16
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.position = Vector2(90, 140)
	frame.size = Vector2(300, 200)
	pause_panel.add_child(frame)

	var title = Label.new()
	title.name = "p_title"
	title.text = Lang.t("pause")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", baloo2)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0.95, 0.75, 0.15))
	title.position = Vector2(90, 150)
	title.size = Vector2(300, 40)
	pause_panel.add_child(title)

	var resume_btn = TextureButton.new()
	resume_btn.name = "p_resume"
	resume_btn.texture_normal = load("res://Art/Buttons/button_continue.png") if Lang.current_language == "en" else load("res://Art/Buttons/button_lanjutkan.png")
	resume_btn.position = Vector2(140, 210)
	resume_btn.size = Vector2(200, 50)
	resume_btn.pressed.connect(_on_resume_pressed)
	resume_btn.button_down.connect(_on_btn_down.bind(resume_btn))
	resume_btn.button_up.connect(_on_btn_up.bind(resume_btn))
	pause_panel.add_child(resume_btn)

	var menu_btn = TextureButton.new()
	menu_btn.name = "p_menu"
	menu_btn.texture_normal = load("res://Art/Buttons/button_pause_menu_eng.png") if Lang.current_language == "en" else load("res://Art/Buttons/button_pause_menu_id.png")
	menu_btn.position = Vector2(140, 275)
	menu_btn.size = Vector2(200, 50)
	menu_btn.pressed.connect(_on_main_menu_pause)
	menu_btn.button_down.connect(_on_btn_down.bind(menu_btn))
	menu_btn.button_up.connect(_on_btn_up.bind(menu_btn))
	pause_panel.add_child(menu_btn)

func setup_summary_panel():
	var fredoka = ResourceLoader.load("res://Assets/Fonts/Fredoka-Regular.ttf")
	var baloo2 = ResourceLoader.load("res://Assets/Fonts/Baloo2-Bold.ttf")
	summary_panel = Control.new()
	summary_panel.visible = false
	summary_panel.process_mode = PROCESS_MODE_PAUSABLE
	add_child(summary_panel)

	var bg = ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.12, 0.8)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	summary_panel.add_child(bg)

	var frame = Panel.new()
	frame.name = "frame_bg"
	var frame_style = StyleBoxFlat.new()
	frame_style.bg_color = Color(1, 1, 1, 0.9)
	frame_style.corner_radius_top_left = 16
	frame_style.corner_radius_top_right = 16
	frame_style.corner_radius_bottom_left = 16
	frame_style.corner_radius_bottom_right = 16
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.position = Vector2(40, 60)
	frame.size = Vector2(400, 500)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	summary_panel.add_child(frame)

	var title = Label.new()
	title.name = "s_title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", baloo2)
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.95, 0.75, 0.15))
	title.position = Vector2(40, 80)
	title.size = Vector2(400, 50)
	summary_panel.add_child(title)

	var stats = Label.new()
	stats.name = "s_stats"
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_override("font", fredoka)
	stats.add_theme_font_size_override("font_size", 17)
	stats.add_theme_color_override("font_color", Color(0.15, 0.15, 0.15))
	stats.position = Vector2(50, 145)
	stats.size = Vector2(380, 210)
	summary_panel.add_child(stats)

	var prompt = Label.new()
	prompt.name = "s_prompt"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_override("font", fredoka)
	prompt.add_theme_font_size_override("font_size", 17)
	prompt.add_theme_color_override("font_color", Color(0.3, 0.3, 0.3))
	prompt.position = Vector2(50, 365)
	prompt.size = Vector2(380, 40)
	summary_panel.add_child(prompt)

	var next_btn = TextureButton.new()
	next_btn.name = "s_next"
	next_btn.texture_normal = load("res://Art/Buttons/button_continue.png") if Lang.current_language == "en" else load("res://Art/Buttons/button_lanjutkan.png")
	next_btn.position = Vector2(140, 415)
	next_btn.size = Vector2(200, 50)
	next_btn.pressed.connect(_on_next_or_ok_pressed)
	next_btn.button_down.connect(_on_btn_down.bind(next_btn))
	next_btn.button_up.connect(_on_btn_up.bind(next_btn))
	summary_panel.add_child(next_btn)

	var menu_btn = TextureButton.new()
	menu_btn.name = "s_menu"
	menu_btn.texture_normal = load("res://Art/Buttons/button_main_menu_eng.png") if Lang.current_language == "en" else load("res://Art/Buttons/button_main_menu_id.png")
	menu_btn.position = Vector2(140, 485)
	menu_btn.size = Vector2(200, 50)
	menu_btn.pressed.connect(_on_main_menu_summary)
	menu_btn.button_down.connect(_on_btn_down.bind(menu_btn))
	menu_btn.button_up.connect(_on_btn_up.bind(menu_btn))
	summary_panel.add_child(menu_btn)

	fireworks_container = Control.new()
	fireworks_container.name = "fireworks"
	fireworks_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fireworks_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	summary_panel.add_child(fireworks_container)

	_circle_tex = _make_circle_tex(10)

func _make_circle_tex(r: int) -> Texture2D:
	var d = r * 2
	var img = Image.create(d, d, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rsq = r * r
	for x in range(d):
		for y in range(d):
			var dx = x - r + 0.5
			var dy = y - r + 0.5
			if dx * dx + dy * dy <= rsq:
				img.set_pixel(x, y, Color(1, 1, 1))
	return ImageTexture.create_from_image(img)

func setup_new_recipe_panel():
	var fredoka = ResourceLoader.load("res://Assets/Fonts/Fredoka-Regular.ttf")
	var baloo2 = ResourceLoader.load("res://Assets/Fonts/Baloo2-Bold.ttf")
	new_recipe_panel = Control.new()
	new_recipe_panel.visible = false
	new_recipe_panel.process_mode = PROCESS_MODE_PAUSABLE
	add_child(new_recipe_panel)

	var bg = ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.7)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	new_recipe_panel.add_child(bg)

	var frame = Panel.new()
	var frame_style = StyleBoxFlat.new()
	frame_style.bg_color = Color(39.0, 245.0, 189.0, 0.85)
	frame_style.corner_radius_top_left = 16
	frame_style.corner_radius_top_right = 16
	frame_style.corner_radius_bottom_left = 16
	frame_style.corner_radius_bottom_right = 16
	frame.add_theme_stylebox_override("panel", frame_style)
	frame.position = Vector2(40, 170)
	frame.size = Vector2(400, 270)
	new_recipe_panel.add_child(frame)

	var title = Label.new()
	title.name = "nr_title"
	title.text = Lang.t("new_menu_title")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_override("font", baloo2)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(0, 0, 0))
	title.position = Vector2(40, 185)
	title.size = Vector2(400, 40)
	new_recipe_panel.add_child(title)

	var body = Label.new()
	body.name = "nr_body"
	body.text = Lang.t("new_menu_body")
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_theme_font_override("font", fredoka)
	body.add_theme_font_size_override("font_size", 16)
	body.add_theme_color_override("font_color", Color(0, 0, 0))
	body.position = Vector2(40, 230)
	body.size = Vector2(400, 25)
	new_recipe_panel.add_child(body)

	var food_img = TextureRect.new()
	food_img.name = "nr_image"
	food_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	food_img.position = Vector2(165, 260)
	food_img.size = Vector2(150, 100)
	new_recipe_panel.add_child(food_img)

	var food_name = Label.new()
	food_name.name = "nr_food_name"
	food_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	food_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	food_name.add_theme_font_override("font", fredoka)
	food_name.add_theme_font_size_override("font_size", 16)
	food_name.add_theme_color_override("font_color", Color(0, 0, 0))
	food_name.position = Vector2(40, 350)
	food_name.size = Vector2(400, 25)
	new_recipe_panel.add_child(food_name)

	var ok_btn = TextureButton.new()
	ok_btn.name = "nr_ok"
	var ok_tex = ResourceLoader.load("res://Art/Buttons/button_ok.png")
	ok_btn.texture_normal = ok_tex
	ok_btn.position = Vector2(140, 380)
	ok_btn.size = Vector2(200, 50)
	ok_btn.pressed.connect(_on_new_recipe_ok)
	new_recipe_panel.add_child(ok_btn)

func set_kedai_colors(kedai_id: String):
	var colors = _kedai_hud_colors.get(kedai_id, _kedai_hud_colors["nasi_goreng"])
	_level_lbl.add_theme_color_override("font_color", colors["primary"])
	money_label.add_theme_color_override("font_color", colors["primary"])
	timer_label.add_theme_color_override("font_color", colors["timer"])
	_mood_lbl.add_theme_color_override("font_color", colors["primary"])
	counter_title.add_theme_color_override("font_color", colors["primary"])
	customer_counter_label.add_theme_color_override("font_color", colors["primary"])

func _unhandled_input(event):
	if event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK):
		toggle_pause()
		get_viewport().set_input_as_handled()
		return
	var is_click = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if !is_click:
		return
	if is_paused:
		return
	var pos = get_viewport().get_mouse_position()
	var pause_tex = get_node("pause_tex") as TextureRect
	var r = pause_tex.get_global_rect()
	if r.has_point(pos):
		pause_click_anim()
		Sfx.play("res://Audio/click.wav")
		toggle_pause()
		get_viewport().set_input_as_handled()

func pause_click_anim():
	var btn = get_node("pause_tex")
	btn.scale = Vector2(0.85, 0.85)
	var tw = create_tween()
	tw.tween_interval(0.05)
	tw.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.05)

func is_pause_at(pos: Vector2) -> bool:
	var pause_tex = get_node("pause_tex") as TextureRect
	return pause_tex.get_global_rect().has_point(pos)

func _on_btn_down(btn):
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(0.93, 0.93), 0.06)

func _on_btn_up(btn):
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)

func _on_resume_pressed():
	toggle_pause()

func toggle_pause():
	if !can_pause:
		return
	var frame = Engine.get_process_frames()
	if frame == _last_toggle_frame:
		return
	_last_toggle_frame = frame
	is_paused = !is_paused
	pause_panel.visible = is_paused
	get_tree().paused = is_paused

func _on_next_or_ok_pressed():
	if Global.level >= MAX_LEVEL:
		_on_last_level_ok()
	else:
		_on_next_level()

func _on_next_level():
	Global.level += 1
	Global.save_game()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/Game.tscn")

func _on_last_level_ok():
	Global.save_game()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")

func start_fireworks():
	for c in fireworks_container.get_children():
		c.queue_free()
	_fw_loop()

func _fw_loop():
	for i in range(8):
		if not is_instance_valid(fireworks_container):
			return
		_fw_burst()
		await get_tree().create_timer(0.5).timeout

func _fw_burst():
	if not is_instance_valid(fireworks_container):
		return
	var cx = randi_range(120, 400)
	var cy = randi_range(60, 280)
	var hue = [0.0, 0.02, 0.06, 0.0, 0.55, 0.6, 0.65, 0.55, 0.0][randi() % 9]
	var col = Color.from_hsv(hue, 0.9, 1.0)

	for burst_idx in range(3):
		if burst_idx > 0:
			await get_tree().create_timer(0.15).timeout
			if not is_instance_valid(fireworks_container):
				return
		var col2 = col if burst_idx == 1 else Color.from_hsv(fmod(hue + 0.05 * burst_idx, 1.0), 0.8, 1.0)
		var burst = Node2D.new()
		var s = GDScript.new()
		s.source_code = """
extends Node2D

var center: Vector2
var color: Color
var elapsed: float = 0.0
var duration: float = 1.0
var _angles: Array
var _radii: Array

func _ready():
	var n = 28
	for i in range(n):
		_angles.append((float(i) / float(n)) * TAU + randf_range(-0.07, 0.07))
		_radii.append(randf_range(70, 160))

func _process(delta):
	elapsed += delta
	if elapsed >= duration:
		queue_free()
	queue_redraw()

func _draw():
	var t = elapsed / duration
	if t > 1.0:
		return
	var a = 1.0 - t * t
	a = max(a, 0.0)
	var r_factor = sqrt(min(t * 2.5, 1.0))
	for i in range(_angles.size()):
		var ang = _angles[i]
		var rad = _radii[i] * r_factor
		var head = Vector2(center.x + cos(ang) * rad, center.y + sin(ang) * rad)
		var c = Color(color.r, color.g, color.b, a)
		draw_line(center, head, c, 2.0)
"""
		s.reload()
		burst.set_script(s)
		burst.center = Vector2(cx, cy)
		burst.color = col2
		fireworks_container.add_child(burst)

func _on_main_menu_pause():
	Global.on_gameplay_ended()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")

func _on_main_menu_summary():
	Global.level += 1
	Global.save_game()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")

func show_new_recipe_popup(recipe_key: String):
	var kedai_cap = "Kedai"
	for part in Global.current_kedai_id.split("_"):
		kedai_cap += part.capitalize()
	var tex = load("res://Art/FoodImages/" + kedai_cap + "/" + recipe_key + ".png") as Texture2D
	if tex:
		var img = tex.get_image()
		img.resize(150, 100, Image.INTERPOLATE_LANCZOS)
		new_recipe_panel.get_node("nr_image").texture = ImageTexture.create_from_image(img)
		new_recipe_panel.get_node("nr_food_name").text = Global.get_recipe_name(recipe_key)
	new_recipe_key_store = recipe_key
	summary_panel.visible = false
	new_recipe_panel.visible = true

func _on_new_recipe_ok():
	new_recipe_panel.visible = false
	show_level_summary()

func show_level_start(level: int):
	get_node("level_lbl").text = Lang.t("level") + str(level)
	update_display()
	update_mood_display()

func update_display():
	money_label.text = Lang.t("today_sales") + ": " + _format_money(Global.today_revenue)

func get_money_label_global_pos() -> Vector2:
	return money_label.get_global_transform().origin

func update_timer(seconds: int):
	var m = seconds / 60
	var s = seconds % 60
	timer_label.text = "%02d:%02d" % [m, s]

func update_customer_counter(finished: int, total: int):
	customer_counter_label.text = "%d / %d" % [finished, total]

func add_order(order: Dictionary):
	update_display()

func update_order(order: Dictionary):
	update_display()

func remove_order(order: Dictionary):
	update_display()

func show_level_summary():
	summary_panel.visible = true
	var title_text = Lang.t("level") + str(Global.level) + " " + Lang.t("level_complete").strip_edges()
	summary_panel.get_node("s_title").text = title_text
	
	var served = Global.customers_served
	var lost = Global.customers_lost
	var tabungan_sebelumnya = Global.money - (Global.today_revenue - Global.today_fund)
	var stats_text = Lang.t("served") + str(served) + "\n"
	stats_text += Lang.t("lost") + str(lost) + "\n\n"
	stats_text += Lang.t("savings") + " : " + _format_money(tabungan_sebelumnya) + "\n"
	stats_text += Lang.t("today_sales") + " : " + _format_money(Global.today_revenue) + "\n"
	stats_text += Lang.t("capital_today") + " : " + _format_money(Global.today_fund) + "\n"
	stats_text += Lang.t("profit_today") + " : " + _format_money(Global.today_revenue - Global.today_fund) + "\n"
	stats_text += Lang.t("total_savings") + " : " + _format_money(Global.money)
	summary_panel.get_node("s_stats").text = stats_text
	
	var next_btn = summary_panel.get_node("s_next") as TextureButton
	var menu_btn = summary_panel.get_node("s_menu") as TextureButton
	if Global.level >= MAX_LEVEL:
		summary_panel.get_node("s_prompt").text = Lang.t("all_levels_complete")
		next_btn.texture_normal = load("res://Art/Buttons/button_ok.png")
		menu_btn.visible = false
		start_fireworks()
	else:
		var next_level = Global.level + 1
		summary_panel.get_node("s_prompt").text = Lang.t("next_level_prompt") + str(next_level) + Lang.t("next_level_prompt_tail")
		next_btn.texture_normal = load("res://Art/Buttons/button_continue.png") if Lang.current_language == "en" else load("res://Art/Buttons/button_lanjutkan.png")
		menu_btn.texture_normal = load("res://Art/Buttons/button_main_menu_eng.png") if Lang.current_language == "en" else load("res://Art/Buttons/button_main_menu_id.png")

func show_mood_popup():
	if mood_popup_shown:
		return
	mood_popup_shown = true
	Global.on_gameplay_ended()
	mood_popup.show_popup()
	get_tree().paused = true

func _on_mood_popup_recovered():
	mood_popup_shown = false
	get_tree().paused = false
	Global.on_gameplay_started()
	update_mood_display()

func _on_mood_ok_pressed():
	mood_popup_shown = false
	get_tree().paused = false
	Global.save_game()
	get_tree().change_scene_to_file("res://Scenes/Main.tscn")

func _on_mood_video_pressed():
	var body = mood_popup.get_node("mp_body") as Label
	var result = Ads.start_mood_reward_flow(body)
	if result == Ads.StartResult.SDK_NOT_READY:
		# SDK is still initializing; AdsManager will auto-start the flow
		# when ready. Show a loading message rather than a failed one.
		if body:
			body.text = Lang.t("mood_ad_loading")
	# FLOW_ALREADY_ACTIVE and SDK_READY need no further action.

func _on_ads_mood_reward_earned():
	Global.mood_level = mini(3, Global.mood_level + 1)
	Global.save_game()
	mood_popup.hide_popup()
	mood_popup_shown = false
	get_tree().paused = false
	Global.on_gameplay_started()
	update_mood_display()

func _on_ads_mood_reward_failed():
	# Body text was set to "mood_ad_failed" by AdsManager; popup stays
	# open and the game stays paused so the player can retry.
	pass

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

func _on_language_changed():
	update_display()
	var mood_lbl = get_node_or_null("mood_lbl")
	if mood_lbl:
		mood_lbl.text = Lang.t("mood_label")
	var counter_title = get_node_or_null("counter_title") as Label
	if counter_title:
		counter_title.text = Lang.t("customer_counter")
	var pause_tex = get_node_or_null("pause_tex") as TextureRect
	if pause_tex:
		var ptex_path = "res://Art/Buttons/pause_button_en.png" if Lang.current_language == "en" else "res://Art/Buttons/pause_button_id.png"
		var ptex = load(ptex_path) as Texture2D
		var pimg = ptex.get_image()
		pimg.resize(120, 42, Image.INTERPOLATE_LANCZOS)
		pause_tex.texture = ImageTexture.create_from_image(pimg)
	if pause_panel.visible:
		pause_panel.get_node("p_title").text = Lang.t("pause")
		var resume_btn = pause_panel.get_node("p_resume") as TextureButton
		resume_btn.texture_normal = load("res://Art/Buttons/button_continue.png") if Lang.current_language == "en" else load("res://Art/Buttons/button_lanjutkan.png")
		var menu_btn = pause_panel.get_node("p_menu") as TextureButton
		menu_btn.texture_normal = load("res://Art/Buttons/button_pause_menu_eng.png") if Lang.current_language == "en" else load("res://Art/Buttons/button_pause_menu_id.png")
	if summary_panel.visible:
		show_level_summary()
	if new_recipe_panel.visible:
		new_recipe_panel.get_node("nr_title").text = Lang.t("new_menu_title")
		new_recipe_panel.get_node("nr_body").text = Lang.t("new_menu_body")
		new_recipe_panel.get_node("nr_ok").text = Lang.t("ok")
	if mood_popup.visible:
		mood_popup.on_language_changed()
