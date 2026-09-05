extends Node

enum SkuType { CONSUMABLE, NON_CONSUMABLE }

const SKUS := {
	"instant_cash_1": "com.kedaimania.instant_cash_1",
	"instant_cash_2": "com.kedaimania.instant_cash_2",
	"instant_cash_3": "com.kedaimania.instant_cash_3",
}

const EXTEND_KITCHEN_SKU := "com.kedaimania.extend_kitchen"

const SKU_TYPES := {
	"com.kedaimania.extend_kitchen": SkuType.CONSUMABLE,
	"com.kedaimania.instant_cash_1": SkuType.CONSUMABLE,
	"com.kedaimania.instant_cash_2": SkuType.CONSUMABLE,
	"com.kedaimania.instant_cash_3": SkuType.CONSUMABLE,
}

const CASH_REWARDS := {
	"instant_cash_1": 6000000,
	"instant_cash_2": 15000000,
	"instant_cash_3": 25000000,
}

static var kedai_prices := {
	"pecel_lele": { "game_money": 15_000_000 },
	"angkringan": { "game_money": 10_000_000 },
	"nasi_padang": { "game_money": 30_000_000 },
	"mie_ayam_bakso": { "game_money": 20_000_000 },
}

static func get_sku(kedai_id: String) -> String:
	return SKUS.get(kedai_id, "")

static func get_price(kedai_id: String) -> Dictionary:
	return kedai_prices.get(kedai_id, { "game_money": 0 })

static func get_cash_reward(sku: String) -> int:
	for key in SKUS:
		if SKUS[key] == sku:
			return CASH_REWARDS.get(key, 0)
	return 0

static func get_type(sku: String) -> SkuType:
	return SKU_TYPES.get(sku, SkuType.CONSUMABLE)
