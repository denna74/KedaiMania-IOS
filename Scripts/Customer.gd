extends Node2D

var customer_name: String
var customer_gender: String
var recipe_key: String
var recipe: Dictionary
var table_pos: Vector2
var patience: float = 30.0
var max_patience: float = 30.0
var is_served := false
var is_leaving := false

var sprite: Sprite2D
var name_label: Label
var order_label: Label
var steps_label: RichTextLabel
var steps_completed: int = 0
var patience_bar: ColorRect

static var _textures_by_gender: Dictionary = {}

func setup(name: String, gender: String, r_key: String, r: Dictionary, t_pos: Vector2, p: float):
	customer_name = name
	customer_gender = gender
	recipe_key = r_key
	recipe = r
	table_pos = t_pos
	patience = p
	max_patience = p
	build_visual()
	Lang.language_changed.connect(_on_language_changed)

func build_visual():
	var fredoka = ResourceLoader.load("res://Assets/Fonts/Fredoka-Regular.ttf")
	var w = 100
	var h = 220
	var tex
	var tex_w
	var tex_h
	var target_h = 55
	var scale_f
	if _textures_by_gender.is_empty():
		for t in Global.npc_textures:
			if not _textures_by_gender.has(t.gender):
				_textures_by_gender[t.gender] = []
			_textures_by_gender[t.gender].append(load("res://Art/NPCs/" + t.image))

	var paper_tex = load("res://Art/paper_transparent.png")
	var paper_bg = Sprite2D.new()
	paper_bg.texture = paper_tex
	paper_bg.scale = Vector2(w / 768.0, h / 1370.0) * 1.4
	add_child(paper_bg)

	var gender_textures = _textures_by_gender[customer_gender]
	tex = gender_textures[randi() % gender_textures.size()]
	sprite = Sprite2D.new()
	sprite.texture = tex
	tex_w = tex.get_width()
	tex_h = tex.get_height()
	scale_f = target_h / float(tex_h)
	sprite.scale = Vector2(scale_f, scale_f)
	sprite.position = Vector2(0, -h/2 + 26 + (tex_h * scale_f) / 2)
	add_child(sprite)

	name_label = Label.new()
	name_label.text = customer_name
	name_label.add_theme_font_override("font", fredoka)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.add_theme_color_override("font_color", Color(0.15, 0.1, 0.05))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(-w/2, -h/2 + 5)
	name_label.size = Vector2(w, 20)
	add_child(name_label)

	order_label = Label.new()
	order_label.text = Global.get_recipe_name(recipe_key)
	order_label.add_theme_font_override("font", fredoka)
	order_label.add_theme_font_size_override("font_size", 14)
	order_label.add_theme_color_override("font_color", Color(0.1, 0.1, 0.1))
	order_label.add_theme_constant_override("line_spacing", 1)
	order_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	order_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	order_label.position = Vector2(-w/2-10, h/2 - 130)
	order_label.size = Vector2(w+20, 30)
	add_child(order_label)

	steps_label = RichTextLabel.new()
	steps_label.bbcode_enabled = true
	steps_label.add_theme_font_override("normal_font", fredoka)
	steps_label.add_theme_font_size_override("normal_font_size", 14)
	steps_label.add_theme_color_override("default_color", Color(0.05, 0.05, 0.05))
	steps_label.position = Vector2(-w/2 + 3, h/2 - 70)
	steps_label.size = Vector2(w - 6, 55)
	add_child(steps_label)
	update_steps(0)

	patience_bar = ColorRect.new()
	patience_bar.color = Color(0.2, 0.9, 0.2)
	patience_bar.size = Vector2(w - 10, 6)
	patience_bar.position = Vector2(-w/2 + 5, h/2 - 7)
	add_child(patience_bar)

func _process(_delta):
	var pct
	if is_leaving or is_served:
		return
	pct = patience / max_patience
	patience_bar.size.x = 90 * max(0, pct)
	var pb = Global.gameplay_config.get("patience_bar", {})
	if pct > pb.get("green_threshold", 0.5):
		var c = pb.get("green_color", [0.2, 0.9, 0.2])
		patience_bar.color = Color(c[0], c[1], c[2])
	elif pct > pb.get("yellow_threshold", 0.25):
		var c = pb.get("yellow_color", [0.9, 0.8, 0.2])
		patience_bar.color = Color(c[0], c[1], c[2])
	else:
		var c = pb.get("red_color", [0.9, 0.2, 0.2])
		patience_bar.color = Color(c[0], c[1], c[2])

func serve():
	is_served = true
	order_label.text = Lang.t("done")
	modulate = Color(0.7, 1, 0.7)

func leave():
	is_leaving = true
	order_label.text = Lang.t("leaving")
	modulate = Color(1, 0.6, 0.6)

func update_steps(completed_count: int):
	steps_completed = completed_count
	var lines = []
	for i in range(recipe.ingredients.size()):
		var ing = recipe.ingredients[i]
		var name = Global.step_names.get(Global.STATION_TYPE_KEYS[ing], "?")
		name = Lang.t(name)
		if i < completed_count:
			lines.append("[color=#22cc22]✓ [s]" + name + "[/s][/color]")
		else:
			lines.append("  " + name)
	steps_label.text = "[center]" + "\n".join(lines) + "[/center]"

func _on_language_changed():
	order_label.text = Global.get_recipe_name(recipe_key) if !is_served and !is_leaving else order_label.text
	update_steps(steps_completed)
