extends Node

# Cross-platform IAP manager using OpenIAP (StoreKit 2 on iOS).
# Registered as the `IAP` autoload in project.godot.

signal kedai_unlocked(kedai_id: String, token: String)
signal kitchen_extended(token: String)
signal extend_kitchen_failed
signal purchases_restored

enum PurchaseResult { OK, NOT_INITIALIZED, NO_SKU, UNAVAILABLE }

var _initialized: bool = false
var _products_ready: bool = false
var _extend_purchase_pending: bool = false
var _pending_restorations: Array[Dictionary] = []
var _purchases_by_token: Dictionary = {}

func _ready():
	if ClassDB.class_exists("GodotIap") or Engine.has_singleton("GodotIap"):
		var iap = _get_iap()
		if iap:
			iap.connected.connect(_on_connected)
			iap.disconnected.connect(_on_disconnected)
			iap.purchase_updated.connect(_on_purchase_updated)
			iap.purchase_error.connect(_on_purchase_error)
			iap.init_connection()
	else:
		print("OpenIAP plugin not found")

func _get_iap():
	return get_node_or_null("/root/GodotIapPlugin")

func is_available() -> bool:
	return _get_iap() != null

func is_initialized() -> bool:
	return _initialized

func get_pending_restorations() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for p in _pending_restorations:
		if not Global.is_purchase_processed(p["token"]):
			result.append({"sku": p["sku"], "token": p["token"]})
	return result

func _on_connected():
	_initialized = true
	print("OpenIAP connected")
	_fetch_products()

func _on_disconnected():
	_initialized = false
	_products_ready = false
	print("OpenIAP disconnected")

func _fetch_products():
	var iap = _get_iap()
	if not iap:
		return
	var request = {
		"skus": _get_all_skus(),
		"type": "in-app"
	}
	var products = await iap.fetch_products(request)
	if products.size() > 0:
		_products_ready = true
		print("Product details loaded: ", products.size(), " products")
		_check_pending_restorations()
	else:
		print("Failed to load product details")

func _get_all_skus() -> Array:
	var skus := []
	for wid in IAPConfig.SKUS:
		skus.append(IAPConfig.SKUS[wid])
	skus.append(IAPConfig.EXTEND_KITCHEN_SKU)
	return skus

func _check_pending_restorations():
	var iap = _get_iap()
	if not iap:
		return
	var restore_result = await iap.restore_purchases()
	if not restore_result.success:
		print("Failed to restore purchases")
		return
	var result = await iap.get_available_purchases_result()
	if result.get("success", false):
		var purchases = result.get("purchases", [])
		if purchases.is_empty():
			print("No pending purchases to restore")
			return
		print("Found ", purchases.size(), " purchase(s) to reconcile")
		for purchase in purchases:
			var product_id = purchase.get("productId", "")
			if product_id.is_empty():
				continue
			var state = purchase.get("purchaseState", "")
			if state != "purchased":
				continue
			var token = purchase.get("transactionId", "")
			if token.is_empty():
				continue
			if Global.is_purchase_processed(token):
				print("Purchase already delivered, cleaning up: ", product_id, " token=", token)
				_acknowledge_purchase(purchase, product_id)
			else:
				_purchases_by_token[token] = purchase
				print("Pending delivery for: ", product_id, " token=", token)
				_pending_restorations.append({"sku": product_id, "token": token})
		if not _pending_restorations.is_empty():
			purchases_restored.emit()

func purchase_kedai(kedai_id: String) -> int:
	var iap = _get_iap()
	if not iap:
		return PurchaseResult.UNAVAILABLE
	if not _initialized:
		return PurchaseResult.NOT_INITIALIZED
	if not _products_ready:
		return PurchaseResult.NOT_INITIALIZED
	var sku = IAPConfig.get_sku(kedai_id)
	if sku.is_empty():
		return PurchaseResult.NO_SKU
	var props = {
		"requestPurchase": {
			"apple": {"sku": sku}
		},
		"type": "in-app"
	}
	iap.request_purchase(props)
	return PurchaseResult.OK

func purchase_extend_kitchen() -> int:
	var iap = _get_iap()
	if not iap:
		return PurchaseResult.UNAVAILABLE
	if not _initialized:
		return PurchaseResult.NOT_INITIALIZED
	if not _products_ready:
		return PurchaseResult.NOT_INITIALIZED
	var sku = IAPConfig.EXTEND_KITCHEN_SKU
	if sku.is_empty():
		return PurchaseResult.NO_SKU
	var props = {
		"requestPurchase": {
			"apple": {"sku": sku}
		},
		"type": "in-app"
	}
	_extend_purchase_pending = true
	iap.request_purchase(props)
	return PurchaseResult.OK

func _on_purchase_updated(purchase: Dictionary):
	var product_id = purchase.get("productId", "")
	var token = purchase.get("transactionId", "")
	if product_id.is_empty() or token.is_empty():
		return
	print("Purchase updated: ", product_id, " token=", token)
	_purchases_by_token[token] = purchase
	if product_id == IAPConfig.EXTEND_KITCHEN_SKU:
		_extend_purchase_pending = false
		kitchen_extended.emit(token)
	else:
		for wid in IAPConfig.SKUS:
			if IAPConfig.SKUS[wid] == product_id:
				kedai_unlocked.emit(wid, token)
				break

func _on_purchase_error(error: Dictionary):
	print("Purchase failed: ", error.get("message", "unknown"))
	if _extend_purchase_pending:
		_extend_purchase_pending = false
		extend_kitchen_failed.emit()

func finalize_purchase(token: String, sku: String):
	var purchase = _purchases_by_token.get(token)
	if not purchase is Dictionary:
		push_error("Cannot finalize purchase without its purchase payload: %s" % token)
		return
	_acknowledge_purchase(purchase, sku)
	_purchases_by_token.erase(token)

func _acknowledge_purchase(purchase: Dictionary, sku: String):
	var iap = _get_iap()
	if not iap:
		return
	var is_consumable = IAPConfig.get_type(sku) == IAPConfig.SkuType.CONSUMABLE
	iap.finish_transaction_dict(purchase, is_consumable)
