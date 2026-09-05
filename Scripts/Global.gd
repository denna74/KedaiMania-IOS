extends Node

signal mood_recovered
signal money_changed(amount: int)

var money: int
var level: int
var max_level: int
var customers_served: int
var customers_lost: int
var mood_level: int = 3
var mood_recovery_accumulated: float = 0.0
var mood_recovery_timestamp: int = 0
var last_save_timestamp: int = 0

const MOOD_RECOVERY_INTERVAL := 2400

var is_gameplay_active: bool = false
var today_revenue: int
var today_fund: int

enum StationType { CUTTING, COOKING, MIXING, SERVING, PACKING, GRILL, SPICE_UP }

const STATION_TYPE_KEYS := ["CUTTING", "COOKING", "MIXING", "SERVING", "PACKING", "GRILL", "SPICE_UP"]
const STATION_TYPE_NAMES := {
	"CUTTING": StationType.CUTTING,
	"COOKING": StationType.COOKING,
	"MIXING": StationType.MIXING,
	"SERVING": StationType.SERVING,
	"PACKING": StationType.PACKING,
	"GRILL": StationType.GRILL,
	"SPICE_UP": StationType.SPICE_UP
}

var unlocked_recipes: Array = []

const SAVE_PASSPHRASE := "K3d@iM4n!@_S3cr3tP4ss_2025"
const SAVE_FILE := "user://kedai.save"

var recipes := {}
var kedai_recipes := {}
var station_info := {}
var npc_persons := []
var npc_textures := []
var step_names := {}
var level_config_data := {}
var gameplay_config := {}

var current_kedai_id: String = "nasi_goreng"
var kedai_levels := { "nasi_goreng": 1, "pecel_lele": 1, "nasi_padang": 1, "mie_ayam_bakso": 1, "angkringan": 1 }
var kedai_max_levels := { "nasi_goreng": 1, "pecel_lele": 1, "nasi_padang": 1, "mie_ayam_bakso": 1, "angkringan": 1 }
var kedai_unlocked_recipes := { "nasi_goreng": [], "pecel_lele": [], "nasi_padang": [], "mie_ayam_bakso": [], "angkringan": [] }
var kedai_unlocked := { "nasi_goreng": true }
var kedai_extended := { "nasi_goreng": false, "pecel_lele": false, "nasi_padang": false, "mie_ayam_bakso": false, "angkringan": false }
var processed_purchases: Dictionary = {}

var _last_recovery_check: int = 0

func _ready():
	load_data()
	randomize()
	load_game()

func _process(_delta):
	var now = Time.get_unix_time_from_system()
	if now - _last_recovery_check >= 3:
		_last_recovery_check = now
		process_mood_recovery()

func load_data():
	var raw = _load_json("res://Resources/recipes.json")
	recipes.clear()
	kedai_recipes.clear()
	for wid in raw:
		var arr = raw[wid]
		kedai_recipes[wid] = []
		recipes[wid] = {}
		for entry in arr:
			var key = entry.id
			var recipe = entry.duplicate()
			recipe.erase("id")
			var ings = recipe.ingredients
			var converted = []
			for ing in ings:
				converted.append(STATION_TYPE_NAMES[ing])
			recipe.ingredients = converted
			var c = recipe.color
			recipe.color = Color(c[0], c[1], c[2])
			recipes[wid][key] = recipe
			kedai_recipes[wid].append(key)

	var sdata = _load_json("res://Resources/stations.json")
	for type_name in sdata:
		var type_val = STATION_TYPE_NAMES[type_name]
		var info = sdata[type_name]
		info.texture = load(info.texture)
		var c = info.color
		info.color = Color(c[0], c[1], c[2])
		station_info[type_val] = info

	var ndata = _load_json("res://Resources/npcs.json")
	npc_persons = ndata.persons
	npc_textures = ndata.textures
	step_names = ndata.step_names

	level_config_data = _load_json("res://Resources/levels.json")
	gameplay_config = _load_json("res://Resources/gameplay.json")

func _load_json(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		print("Failed to load: ", path)
		return {}
	var content = file.get_as_text()
	return JSON.parse_string(content)

func reset_game():
	money = 50
	level = 1
	max_level = 1
	customers_served = 0
	customers_lost = 0
	today_revenue = 0
	today_fund = 0
	for wid in kedai_levels:
		kedai_levels[wid] = 1
		kedai_max_levels[wid] = 1
		kedai_unlocked_recipes[wid] = _get_unlocked_recipes_for_level(1, wid)
	unlocked_recipes = kedai_unlocked_recipes.get(current_kedai_id, [])
	kedai_unlocked.clear()
	kedai_unlocked["nasi_goreng"] = true
	kedai_extended = { "nasi_goreng": false, "pecel_lele": false, "nasi_padang": false, "mie_ayam_bakso": false, "angkringan": false }
	last_save_timestamp = 0
	reset_mood()

static func _derive_key() -> PackedByteArray:
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(SAVE_PASSPHRASE.to_utf8_buffer())
	return ctx.finish()

static func _pkcs7_pad(data: PackedByteArray) -> PackedByteArray:
	var pad_len = 16 - (data.size() % 16)
	if pad_len == 0:
		pad_len = 16
	var result = data.duplicate()
	for i in range(pad_len):
		result.append(pad_len)
	return result

static func _pkcs7_unpad(data: PackedByteArray) -> PackedByteArray:
	if data.size() == 0:
		return data
	var pad_len = data[data.size() - 1]
	if pad_len < 1 or pad_len > 16:
		return data
	return data.slice(0, data.size() - pad_len)

static func _generate_iv() -> PackedByteArray:
	var iv = PackedByteArray()
	iv.resize(16)
	for i in range(16):
		iv[i] = randi() % 256
	return iv

func _encrypt_save_data(plaintext: PackedByteArray) -> PackedByteArray:
	var key = _derive_key()
	var iv = _generate_iv()
	var padded = _pkcs7_pad(plaintext)

	var aes = AESContext.new()
	aes.start(AESContext.MODE_CBC_ENCRYPT, key, iv)
	var ciphertext = aes.update(padded)
	aes.finish()

	var integrity = HashingContext.new()
	integrity.start(HashingContext.HASH_SHA256)
	integrity.update(iv)
	integrity.update(ciphertext)
	var hash = integrity.finish()

	var result = iv.duplicate()
	result.append_array(ciphertext)
	result.append_array(hash)
	return result

func _decrypt_save_data(data: PackedByteArray) -> PackedByteArray:
	if data.size() < 64:
		return PackedByteArray()

	var iv = data.slice(0, 16)
	var hash = data.slice(data.size() - 32, data.size())
	var ciphertext = data.slice(16, data.size() - 32)

	var check = HashingContext.new()
	check.start(HashingContext.HASH_SHA256)
	check.update(iv)
	check.update(ciphertext)
	var expected_hash = check.finish()

	if hash != expected_hash:
		return PackedByteArray()

	var key = _derive_key()

	var aes = AESContext.new()
	aes.start(AESContext.MODE_CBC_DECRYPT, key, iv)
	var padded = aes.update(ciphertext)
	aes.finish()

	return _pkcs7_unpad(padded)

func get_recipe(key: String, kedai_id: String = "") -> Dictionary:
	if kedai_id == "":
		kedai_id = current_kedai_id
	return recipes.get(kedai_id, {}).get(key, {})

func get_recipe_name(key: String) -> String:
	return Lang.t(key)

func get_recipes_for_kedai(kedai_id: String) -> Array:
	return kedai_recipes.get(kedai_id, []).duplicate()

func get_unlock_order_for_kedai(kedai_id: String) -> Array:
	return kedai_recipes.get(kedai_id, []).duplicate()

func is_kedai_unlocked(kedai_id: String) -> bool:
	return kedai_unlocked.get(kedai_id, false)

func is_purchase_processed(token: String) -> bool:
	return processed_purchases.has(token)

func mark_purchase_processed(token: String, sku: String):
	processed_purchases[token] = {
		"sku": sku,
		"timestamp": Time.get_unix_time_from_system()
	}
	save_game()

func unlock_kedai(kedai_id: String):
	kedai_unlocked[kedai_id] = true
	save_game()

func add_money(amount: int):
	money += amount
	money_changed.emit(money)
	save_game()

func switch_to_kedai(kedai_id: String):
	kedai_levels[current_kedai_id] = level
	kedai_max_levels[current_kedai_id] = max_level
	kedai_unlocked_recipes[current_kedai_id] = unlocked_recipes
	current_kedai_id = kedai_id
	level = kedai_levels.get(kedai_id, 1)
	max_level = kedai_max_levels.get(kedai_id, 1)
	unlocked_recipes = kedai_unlocked_recipes.get(kedai_id, _get_unlocked_recipes_for_level(1, kedai_id))

func get_new_recipe_key(kedai_id: String, current_count: int) -> String:
	var order = get_unlock_order_for_kedai(kedai_id)
	if current_count < order.size():
		return order[current_count]
	return ""

func get_recipe_unlock_level(key: String, kedai_id: String = "") -> int:
	if kedai_id == "":
		kedai_id = current_kedai_id
	var order = kedai_recipes.get(kedai_id, [])
	var idx = order.find(key)
	if idx >= 0:
		return 3 * max(0, idx - 4) + 1
	return -1

func get_station_name(type: int) -> String:
	return Lang.t(station_info[type].name_key)

func get_random_recipe_key() -> String:
	var kedai_recipes = get_recipes_for_kedai(current_kedai_id)
	if kedai_recipes.is_empty():
		return ""
	var available = []
	for k in kedai_recipes:
		if k in unlocked_recipes:
			available.append(k)
	if available.is_empty():
		available = kedai_recipes
	return available[randi() % available.size()]

func reset_mood():
	mood_level = 3
	mood_recovery_accumulated = 0.0
	mood_recovery_timestamp = 0

func reduce_mood() -> bool:
	if mood_level <= 0:
		return false
	mood_level -= 1
	mood_recovery_timestamp = Time.get_unix_time_from_system()
	mood_recovery_accumulated = 0.0
	mood_recovered.emit()
	save_game()
	return mood_level <= 0

func is_mood_depleted() -> bool:
	return mood_level <= 0

func process_mood_recovery():
	if mood_level >= 3:
		return
	if is_gameplay_active:
		return

	var now = Time.get_unix_time_from_system()

	if now < mood_recovery_timestamp:
		mood_recovery_accumulated = 0.0
		mood_recovery_timestamp = now
		save_game()
		return

	var elapsed = now - mood_recovery_timestamp
	var total = mood_recovery_accumulated + elapsed
	var changed = false

	while total >= MOOD_RECOVERY_INTERVAL and mood_level < 3:
		mood_level += 1
		total -= MOOD_RECOVERY_INTERVAL
		changed = true
		mood_recovered.emit()

	mood_recovery_accumulated = fmod(total, MOOD_RECOVERY_INTERVAL)
	mood_recovery_timestamp = now

	if changed:
		save_game()

func on_gameplay_started():
	if mood_recovery_timestamp > 0:
		var now = Time.get_unix_time_from_system()
		var elapsed = now - mood_recovery_timestamp
		var total = mood_recovery_accumulated + elapsed
		var changed = false

		while total >= MOOD_RECOVERY_INTERVAL and mood_level < 3:
			mood_level += 1
			total -= MOOD_RECOVERY_INTERVAL
			changed = true

		mood_recovery_accumulated = fmod(total, MOOD_RECOVERY_INTERVAL)

		if changed:
			save_game()

	is_gameplay_active = true

func on_gameplay_ended():
	is_gameplay_active = false
	mood_recovery_timestamp = Time.get_unix_time_from_system()
	save_game()

func get_mood_recovery_remaining_time() -> int:
	if mood_level >= 3:
		return 0

	var total: float
	if mood_recovery_timestamp == 0:
		total = mood_recovery_accumulated
	else:
		var now = Time.get_unix_time_from_system()
		if now < mood_recovery_timestamp:
			total = mood_recovery_accumulated
		else:
			total = mood_recovery_accumulated + (now - mood_recovery_timestamp)

	var remaining = MOOD_RECOVERY_INTERVAL - fmod(total, MOOD_RECOVERY_INTERVAL)
	return int(max(0, remaining))

func _get_unlocked_recipes_for_level(lvl: int, kedai_id: String = "") -> Array:
	if kedai_id == "":
		kedai_id = current_kedai_id
	var order = kedai_recipes.get(kedai_id, [])
	var count = mini(order.size(), 5 + max(0, lvl - 1) / 3)
	return order.slice(0, count)

func get_random_person() -> Dictionary:
	return npc_persons[randi() % npc_persons.size()]

func get_random_name() -> String:
	return get_random_person().name

func get_textures_for_gender(gender: String) -> Array:
	var result = []
	for t in npc_textures:
		if t.gender == gender:
			result.append(t.image)
	return result

func get_level_config() -> Dictionary:
	var d = level_config_data
	var g = gameplay_config
	return {
		"level_duration": d.base_duration + level * d.duration_per_level,
		"max_customers": d.base_customers + level * d.customers_per_level,
		"spawn_interval": max(d.min_spawn_interval, d.base_spawn_interval - level * d.spawn_interval_reduction),
		"patience": max(g.get("min_patience", 15.0), g.get("base_patience", 30.0) - (level - 1) * g.get("patience_reduction", 2.0))
	}

func save_game():
	last_save_timestamp = Time.get_unix_time_from_system()
	kedai_levels[current_kedai_id] = level
	kedai_max_levels[current_kedai_id] = max_level
	kedai_unlocked_recipes[current_kedai_id] = unlocked_recipes
	var data = {
		"level": level,
		"max_level": max_level,
		"money": money,
		"unlocked_recipes": unlocked_recipes,
		"total_served": customers_served,
		"mood_level": mood_level,
		"mood_recovery_accumulated": mood_recovery_accumulated,
		"mood_recovery_timestamp": mood_recovery_timestamp,
		"last_save_timestamp": last_save_timestamp,
		"current_kedai_id": current_kedai_id,
		"kedai_levels": kedai_levels,
		"kedai_max_levels": kedai_max_levels,
		"kedai_unlocked_recipes": kedai_unlocked_recipes,
		"kedai_unlocked": kedai_unlocked,
		"kedai_extended": kedai_extended,
		"processed_purchases": processed_purchases
	}
	var json_str = JSON.stringify(data)
	var plaintext = json_str.to_utf8_buffer()
	var encrypted = _encrypt_save_data(plaintext)

	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file:
		file.store_buffer(encrypted)
		file.close()
	else:
		push_error("Failed to open save file for writing")

func load_game():
	if not FileAccess.file_exists(SAVE_FILE):
		reset_game()
		return

	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	if not file:
		reset_game()
		return

	var encrypted = file.get_buffer(file.get_length())
	file.close()

	var plaintext = _decrypt_save_data(encrypted)
	if plaintext.is_empty():
		reset_game()
		return

	var json_str = plaintext.get_string_from_utf8()
	var parsed = JSON.parse_string(json_str)
	if parsed == null or typeof(parsed) != TYPE_DICTIONARY:
		reset_game()
		return

	kedai_levels = parsed.get("kedai_levels", { "nasi_goreng": parsed.get("level", 1), "pecel_lele": 1, "nasi_padang": 1, "mie_ayam_bakso": 1 })
	kedai_max_levels = parsed.get("kedai_max_levels", { "nasi_goreng": parsed.get("max_level", parsed.get("level", 1)), "pecel_lele": 1, "nasi_padang": 1, "mie_ayam_bakso": 1 })
	kedai_unlocked = parsed.get("kedai_unlocked", { "nasi_goreng": true })
	if not kedai_unlocked.has("nasi_goreng"):
		kedai_unlocked["nasi_goreng"] = true
	kedai_extended = parsed.get("kedai_extended", { "nasi_goreng": false, "pecel_lele": false, "nasi_padang": false, "mie_ayam_bakso": false, "angkringan": false })
	kedai_unlocked_recipes = parsed.get("kedai_unlocked_recipes", {})
	for wid in kedai_levels:
		kedai_unlocked_recipes[wid] = _get_unlocked_recipes_for_level(kedai_max_levels[wid], wid)
	current_kedai_id = parsed.get("current_kedai_id", "nasi_goreng")
	if not kedai_levels.has(current_kedai_id):
		kedai_levels[current_kedai_id] = 1
		kedai_max_levels[current_kedai_id] = 1
		kedai_unlocked_recipes[current_kedai_id] = _get_unlocked_recipes_for_level(1, current_kedai_id)

	level = kedai_levels[current_kedai_id]
	max_level = kedai_max_levels[current_kedai_id]
	money = parsed.get("money", 50)
	unlocked_recipes = kedai_unlocked_recipes[current_kedai_id]
	var expected = _get_unlocked_recipes_for_level(max_level, current_kedai_id)
	if expected.size() > unlocked_recipes.size():
		unlocked_recipes = expected
		kedai_unlocked_recipes[current_kedai_id] = unlocked_recipes
	customers_served = parsed.get("total_served", 0)
	customers_lost = 0
	mood_level = parsed.get("mood_level", 3)
	mood_recovery_accumulated = parsed.get("mood_recovery_accumulated", 0.0)
	mood_recovery_timestamp = parsed.get("mood_recovery_timestamp", 0)
	last_save_timestamp = parsed.get("last_save_timestamp", 0)
	processed_purchases = parsed.get("processed_purchases", {})
	is_gameplay_active = false
	if mood_recovery_timestamp == 0:
		if last_save_timestamp > 0:
			mood_recovery_timestamp = last_save_timestamp
		else:
			mood_recovery_timestamp = Time.get_unix_time_from_system()
