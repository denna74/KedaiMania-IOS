extends Node

enum SkuType { CONSUMABLE, NON_CONSUMABLE }

const SKUS := {
	"pecel_lele": "com.kedaimania.warung_pecel_lele",
	"angkringan": "com.kedaimania.warung_angkringan",
	"nasi_padang": "com.kedaimania.warung_nasi_padang",
	"mie_ayam_bakso": "com.kedaimania.warung_mie_ayam_bakso",
	"instant_cash_1": "com.kedaimania.instant_cash_1",
	"instant_cash_2": "com.kedaimania.instant_cash_2",
	"instant_cash_3": "com.kedaimania.instant_cash_3",
}

const EXTEND_KITCHEN_SKU := "com.kedaimania.extend_kitchen"

const SKU_TYPES := {
	"com.kedaimania.warung_pecel_lele": SkuType.NON_CONSUMABLE,
	"com.kedaimania.warung_angkringan": SkuType.NON_CONSUMABLE,
	"com.kedaimania.warung_nasi_padang": SkuType.NON_CONSUMABLE,
	"com.kedaimania.warung_mie_ayam_bakso": SkuType.NON_CONSUMABLE,
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
	"pecel_lele": { "game_money": 15_000_000, "apple_price": 2 },
	"angkringan": { "game_money": 10_000_000, "apple_price": 1 },
	"nasi_padang": { "game_money": 30_000_000, "apple_price": 4 },
	"mie_ayam_bakso": { "game_money": 20_000_000, "apple_price": 3 },
}

static func get_sku(kedai_id: String) -> String:
	return SKUS.get(kedai_id, "")

static func get_price(kedai_id: String) -> Dictionary:
	return kedai_prices.get(kedai_id, { "game_money": 0, "apple_price": 0.0 })

static func get_cash_reward(sku: String) -> int:
	for key in SKUS:
		if SKUS[key] == sku:
			return CASH_REWARDS.get(key, 0)
	return 0

static func get_type(sku: String) -> SkuType:
	return SKU_TYPES.get(sku, SkuType.CONSUMABLE)
