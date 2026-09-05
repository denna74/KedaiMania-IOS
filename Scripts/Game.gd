extends Node2D

@onready var station_container = $StationContainer
@onready var customer_container = $CustomerContainer
@onready var ui = $GameUI

var time_left: float
var game_active := false
var active_orders := []
var table_positions := []
var spawn_timer := 0.0
var customers_spawned := 0
var customers_finished := 0
var game_over_shown := false
var end_level_delay := false
var end_level_timer := 0.0
var has_new_recipe := false
var new_recipe_key := ""
var extend_btn_eng: Texture2D
var extend_btn_id: Texture2D
var extend_button: TextureButton
var row2_stations_created := false
func _ready():
	Engine.max_fps = Global.gameplay_config.get("max_fps", 60)
	extend_btn_eng = load("res://Art/Buttons/button_extend_kitchen.png")
	extend_btn_id = load("res://Art/Buttons/button_perluas_dapur.png")
	if IAP:
		IAP.kitchen_extended.connect(_on_kitchen_extended)
		IAP.extend_kitchen_failed.connect(_on_extend_kitchen_failed)
		IAP.purchases_restored.connect(_on_purchases_restored)
		if not IAP.get_pending_restorations().is_empty():
			_on_purchases_restored()
	Lang.language_changed.connect(_on_extend_lang_changed)
	setup_background()
	ui.set_kedai_colors(Global.current_kedai_id)
	setup_tables()
	setup_stations()
	start_level()

func setup_background():
	var bg_path = "res://Art/GameplayBackgrounds/gameplay_" + Global.current_kedai_id + ".png"
	var bg_tex = load(bg_path) as Texture2D
	if bg_tex:
		var frame = $Frame as Sprite2D
		if frame:
			frame.texture = bg_tex

func setup_tables():
	for i in range(3):
		table_positions.append(Vector2(90 + i * 150, 230))

func setup_stations():
	var is_mie = Global.current_kedai_id == "mie_ayam_bakso"
	var is_pecel = Global.current_kedai_id == "pecel_lele"
	var is_padang = Global.current_kedai_id == "nasi_padang"
	var is_angkringan = Global.current_kedai_id == "angkringan"
	var types = [
		Global.StationType.COOKING if is_padang or is_mie else (Global.StationType.SPICE_UP if is_angkringan else Global.StationType.CUTTING),
		Global.StationType.GRILL if is_padang else (Global.StationType.SPICE_UP if is_mie else (Global.StationType.GRILL if is_angkringan else Global.StationType.COOKING)),
		Global.StationType.GRILL if is_pecel else (Global.StationType.SPICE_UP if is_padang else (Global.StationType.MIXING if is_mie else (Global.StationType.PACKING if is_angkringan else Global.StationType.MIXING))),
		Global.StationType.SERVING
	]
	var centers = [65, 180, 295, 410]
	for i in range(types.size()):
		var s = preload("res://Scenes/Station.tscn").instantiate()
		s.init(types[i])
		s.position = Vector2(centers[i], 460)
		s.processing_done.connect(_on_processing_done)
		station_container.add_child(s)

	if Global.kedai_extended.get(Global.current_kedai_id, false):
		create_row2_stations()
	else:
		create_extend_button()

func _notification(what: int):
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		ui.toggle_pause()

func _input(event):
	if !game_active or ui.is_paused:
		return
	var is_click = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed)
	if is_click:
		var pos = get_global_mouse_position()
		if ui.is_pause_at(pos):
			ui.pause_click_anim()
			Sfx.play("res://Audio/click.wav")
			ui.toggle_pause()
			get_viewport().set_input_as_handled()
			return
		handle_station_click()
	elif event is InputEventKey and event.pressed and (event.keycode == KEY_ESCAPE or event.keycode == KEY_BACK):
		ui.toggle_pause()
		get_viewport().set_input_as_handled()

func handle_station_click():
	var pos = get_global_mouse_position()
	for s in station_container.get_children():
		var r = Rect2(s.position.x - 52, s.position.y - 100, 105, 200)
		if r.has_point(pos):
			s.click()
			if !s.is_processing:
				_on_station_used(s.station_type, s)
			return

func start_level():
	var cfg = Global.get_level_config()
	time_left = cfg.level_duration
	game_active = true
	customers_spawned = 0
	customers_finished = 0
	ui.update_customer_counter(0, get_max_customers())
	spawn_timer = Global.gameplay_config.get("initial_spawn_delay", 3.0)
	game_over_shown = false
	end_level_delay = false
	ui.can_pause = true
	Global.today_revenue = 0
	Global.today_fund = 0
	var lvl_recipes = Global._get_unlocked_recipes_for_level(Global.level)
	if lvl_recipes.size() > Global.unlocked_recipes.size():
		Global.unlocked_recipes = lvl_recipes
	Global.on_gameplay_started()
	ui.show_level_start(Global.level)

func _process(delta):
	if end_level_delay and !game_active:
		end_level_timer -= delta
		if end_level_timer <= 0:
			end_level_delay = false
			if has_new_recipe:
				ui.show_new_recipe_popup(new_recipe_key)
				has_new_recipe = false
			else:
				ui.show_level_summary()
		return

	if !game_active or ui.is_paused:
		return

	time_left -= delta
	ui.update_timer(max(0, int(time_left)))

	spawn_timer -= delta
	if spawn_timer <= 0 and customers_spawned < get_max_customers():
		spawn_timer = Global.get_level_config().spawn_interval
		if table_positions.size() > 0:
			spawn_customer()

	for order in active_orders:
		if !order.served:
			order.customer.patience -= delta
			if order.customer.patience <= 0 and !order.leaving:
				order.leaving = true
				customer_leaves(order)
				
	if customers_spawned >= get_max_customers() and active_orders.is_empty() and !game_over_shown and !end_level_delay:
		game_over_shown = true
		end_level()

	if time_left <= 0 and !game_over_shown and !end_level_delay:
		game_over_shown = true
		end_level()

func get_max_customers() -> int:
	return Global.get_level_config().max_customers

func spawn_customer():
	if table_positions.size() == 0:
		return

	var recipe_key = Global.get_random_recipe_key()
	var recipe = Global.get_recipe(recipe_key)
	var person = Global.get_random_person()
	var table_pos = table_positions.pop_front()

	var cust = preload("res://Scenes/Customer.tscn").instantiate()
	cust.position = Vector2(-100, table_pos.y)
	var level_cfg = Global.get_level_config()
	cust.setup(person.name, person.gender, recipe_key, recipe, table_pos, level_cfg.patience)
	customer_container.add_child(cust)

	var tween = create_tween()
	tween.tween_property(cust, "position", table_pos, Global.gameplay_config.get("customer_walk_time", 1.5)).set_trans(Tween.TRANS_SINE)

	var order = {
		"recipe_key": recipe_key,
		"recipe": recipe,
		"customer": cust,
		"current_step": 0,
		"completed_stations": [],
		"is_done": false,
		"served": false,
		"leaving": false,
		"processing_station": null
	}
	active_orders.append(order)
	customers_spawned += 1
	ui.add_order(order)

func _on_station_used(station_type: int, station_node: Node):
	if !game_active:
		return

	if station_type == Global.StationType.SERVING:
		for order in active_orders:
			if order.is_done and !order.served:
				station_node.start_processing(Global.gameplay_config.get("serve_time", 0.4))
				order.processing_station = station_node
				return
		return

	for order in active_orders:
		if order.served or order.is_done or order.leaving or order.processing_station != null:
			continue
		var ings = order.recipe.ingredients
		if order.current_step < ings.size() and ings[order.current_step] == station_type:
			station_node.start_processing(order.recipe.prep_time)
			order.processing_station = station_node
			return

func _on_processing_done(station_type: int):
	if !game_active:
		return

	if station_type == Global.StationType.SERVING:
		for order in active_orders:
			if order.processing_station != null and order.is_done and !order.served:
				serve_order(order)
				return
		return

	for order in active_orders:
		if order.processing_station != null and !order.served and !order.is_done and !order.leaving:
			var ings = order.recipe.ingredients
			if order.current_step < ings.size() and ings[order.current_step] == station_type:
				order.current_step += 1
				order.completed_stations.append(station_type)
				order.processing_station = null
				order.customer.update_steps(order.current_step)
				ui.update_order(order)
				if order.current_step >= ings.size():
					order.is_done = true
					ui.update_order(order)
				return

func serve_order(order: Dictionary):
	order.served = true
	var recipe = order.recipe
	Global.money += recipe.price - recipe.fund
	Global.today_revenue += recipe.price
	Global.today_fund += recipe.fund
	Global.customers_served += 1

	# --- Phase 1: Food sprite arcs from SERVING station to customer ---
	var food_tex_path = _get_food_image_path(order.recipe_key)
	var food_tex = load(food_tex_path) as Texture2D
	if food_tex:
		var food_sprite = Sprite2D.new()
		food_sprite.texture = food_tex
		food_sprite.scale = Vector2(0.22, 0.22)
		food_sprite.position = order.processing_station.position
		add_child(food_sprite)

		Sfx.play("res://Audio/serve.wav")

		var target_pos = order.customer.position
		var mid_x = (food_sprite.position.x + target_pos.x) / 2.0
		var arc_height = -60.0
		var tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tween.tween_property(food_sprite, "position", Vector2(mid_x, food_sprite.position.y + arc_height), 0.4)
		tween.tween_property(food_sprite, "position", target_pos, 0.4)
		tween.parallel().tween_property(food_sprite, "scale", Vector2(0.28, 0.28), 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tween.tween_callback(food_sprite.queue_free)
		await tween.finished

	# --- Phase 2: Customer receives order (visual update) ---
	order.customer.serve()
	ui.update_order(order)

	# --- Phase 3: Money sprite zooms from customer to Today's Sale label ---
	var money_sprite = Sprite2D.new()
	money_sprite.texture = load("res://Assets/money.png")
	money_sprite.scale = Vector2(0.15, 0.15)
	money_sprite.position = order.customer.position + Vector2(0, -30)
	add_child(money_sprite)

	var label_pos = ui.get_money_label_global_pos()
	var money_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	money_tween.tween_property(money_sprite, "position", label_pos, 0.5)
	money_tween.parallel().tween_property(money_sprite, "scale", Vector2(0.03, 0.03), 0.5)
	money_tween.tween_callback(func():
		money_sprite.queue_free()
		Sfx.play("res://Audio/get_coin.wav")
	)
	await money_tween.finished

	ui.update_display()

	# --- Phase 4: Customer leaves ---
	ui.remove_order(order)
	active_orders.erase(order)
	customers_finished += 1
	ui.update_customer_counter(customers_finished, get_max_customers())

	var tween = create_tween()
	tween.tween_property(order.customer, "position", Vector2(order.customer.position.x + 200, order.customer.position.y), 1.0)
	await get_tree().create_timer(Global.gameplay_config.get("customer_cleanup_time", 1.5)).timeout
	if is_instance_valid(order.customer):
		table_positions.append(order.customer.table_pos)
		order.customer.queue_free()

func _get_food_image_path(recipe_key: String) -> String:
	var kedai_cap = "Kedai"
	for part in Global.current_kedai_id.split("_"):
		kedai_cap += part.capitalize()
	return "res://Art/FoodImages/" + kedai_cap + "/" + recipe_key + ".png"

func customer_leaves(order: Dictionary):
	Global.customers_lost += 1
	Global.reduce_mood()
	ui.update_mood_display()
	order.served = true
	order.customer.leave()

	var tween = create_tween()
	tween.tween_property(order.customer, "position", Vector2(order.customer.position.x - 200, order.customer.position.y), 1.0)
	ui.remove_order(order)
	active_orders.erase(order)
	customers_finished += 1
	ui.update_customer_counter(customers_finished, get_max_customers())
	await get_tree().create_timer(Global.gameplay_config.get("customer_cleanup_time", 1.5)).timeout
	if is_instance_valid(order.customer):
		table_positions.append(order.customer.table_pos)
		order.customer.queue_free()

	if Global.mood_level <= 0:
		Global.save_game()
		await get_tree().create_timer(0.3).timeout
		ui.show_mood_popup()

func end_level():
	game_active = false
	end_level_delay = true
	ui.can_pause = false

	for order in active_orders:
		if is_instance_valid(order.customer):
			order.customer.queue_free()
	active_orders.clear()

	var current_count = Global.unlocked_recipes.size()
	var next_count = Global._get_unlocked_recipes_for_level(Global.level + 1).size()
	has_new_recipe = next_count > current_count
	if has_new_recipe:
		new_recipe_key = Global.get_new_recipe_key(Global.current_kedai_id, current_count)
		Global.unlocked_recipes.append(new_recipe_key)

	Global.max_level = maxi(Global.max_level, Global.level + 1)

	Global.on_gameplay_ended()

	end_level_timer = 1.0

func create_extend_button():
	if Global.kedai_extended.get(Global.current_kedai_id, false):
		return
	if extend_button and is_instance_valid(extend_button):
		return
	var is_en = Lang.current_language == "en"
	extend_button = TextureButton.new()
	extend_button.texture_normal = extend_btn_eng if is_en else extend_btn_id
	extend_button.position = Vector2(140, 730)
	extend_button.size = Vector2(200, 50)
	extend_button.pressed.connect(_on_extend_kitchen_pressed)
	extend_button.button_down.connect(_on_btn_down.bind(extend_button))
	extend_button.button_up.connect(_on_btn_up.bind(extend_button))
	add_child(extend_button)

func _on_btn_down(btn):
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(0.93, 0.93), 0.06)

func _on_btn_up(btn):
	var tween = create_tween()
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.08)

func _on_extend_kitchen_pressed():
	if not IAP:
		return
	ui.toggle_pause()
	var result = IAP.purchase_extend_kitchen()
	match result:
		IAP.PurchaseResult.UNAVAILABLE:
			ui.toggle_pause()
			show_extend_error("extend_kitchen_unavailable")
		IAP.PurchaseResult.NOT_INITIALIZED:
			ui.toggle_pause()
			show_extend_error("extend_kitchen_not_ready")
		IAP.PurchaseResult.NO_SKU:
			ui.toggle_pause()
			show_extend_error("extend_kitchen_error")
		IAP.PurchaseResult.BUSY:
			ui.toggle_pause()
			show_extend_error("extend_kitchen_error")

func _on_kitchen_extended(token: String):
	ui.toggle_pause()
	var current_id = Global.current_kedai_id
	Global.kedai_extended[current_id] = true
	Global.mark_purchase_processed(token, IAPConfig.EXTEND_KITCHEN_SKU)
	IAP.finalize_purchase(token, IAPConfig.EXTEND_KITCHEN_SKU)
	if extend_button and is_instance_valid(extend_button):
		extend_button.queue_free()
		extend_button = null
	create_row2_stations()

func _on_purchases_restored():
	var pending = IAP.get_pending_restorations()
	for p in pending:
		var sku = p["sku"]
		var token = p["token"]
		if sku == IAPConfig.EXTEND_KITCHEN_SKU:
			var current_id = Global.current_kedai_id
			if not Global.kedai_extended.get(current_id, false):
				Global.kedai_extended[current_id] = true
			Global.mark_purchase_processed(token, sku)
			IAP.finalize_purchase(token, sku)

func _on_extend_kitchen_failed():
	ui.toggle_pause()
	show_extend_error("extend_kitchen_error")

func get_row2_types() -> Array:
	var is_mie = Global.current_kedai_id == "mie_ayam_bakso"
	var is_pecel = Global.current_kedai_id == "pecel_lele"
	var is_padang = Global.current_kedai_id == "nasi_padang"
	var is_angkringan = Global.current_kedai_id == "angkringan"
	return [
		Global.StationType.COOKING if is_padang or is_mie else (Global.StationType.SPICE_UP if is_angkringan else Global.StationType.CUTTING),
		Global.StationType.GRILL if is_padang else (Global.StationType.SPICE_UP if is_mie else (Global.StationType.GRILL if is_angkringan else Global.StationType.COOKING)),
		Global.StationType.GRILL if is_pecel else (Global.StationType.SPICE_UP if is_padang else (Global.StationType.MIXING if is_mie else (Global.StationType.PACKING if is_angkringan else Global.StationType.MIXING))),
	]

func create_row2_stations():
	var types = get_row2_types()
	var centers = [65, 180, 295]
	for i in range(types.size()):
		var s = preload("res://Scenes/Station.tscn").instantiate()
		s.init(types[i])
		s.position = Vector2(centers[i], 700)
		s.processing_done.connect(_on_processing_done)
		station_container.add_child(s)
	row2_stations_created = true

func _on_extend_lang_changed():
	if extend_button and is_instance_valid(extend_button):
		var is_en = Lang.current_language == "en"
		extend_button.texture_normal = extend_btn_eng if is_en else extend_btn_id

func show_extend_error(key: String):
	var label = Label.new()
	label.text = Lang.t(key)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(140, 660)
	label.size = Vector2(200, 20)
	label.add_theme_font_size_override("font_size", 14)
	label.modulate = Color(1, 0.3, 0.3)
	add_child(label)
	var tween = create_tween()
	tween.tween_interval(5.0)
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.tween_callback(label.queue_free)
