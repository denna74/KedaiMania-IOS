extends Node

# Cross-platform IAP manager using OpenIAP (StoreKit 2 on iOS).
# Registered as the `IAP` autoload in project.godot.

const Types = preload("res://addons/godot-iap/types.gd")

signal kedai_unlocked(kedai_id: String, token: String)
signal kitchen_extended(token: String)
signal extend_kitchen_failed
signal purchases_restored
signal restore_completed(found: bool)
signal purchase_failed(message: String)

enum PurchaseResult { OK, NOT_INITIALIZED, NO_SKU, UNAVAILABLE }

var _initialized: bool = false
var _products_ready: bool = false
var _products_fetch_started: bool = false
var _extend_purchase_pending: bool = false
var _pending_purchase_sku: String = ""
var _pending_restorations: Array[Dictionary] = []
var _purchases_by_token: Dictionary = {}
var _restore_in_progress: bool = false
var last_products_status: String = ""
var _last_products_raw: Dictionary = {}
var _last_products_native_count: int = 0
var _last_products_error: String = ""

func _ready():
	await get_tree().process_frame
	var iap = _get_iap()
	if not iap:
		print("OpenIAP plugin not found")
		return
	iap.connected.connect(_on_connected)
	iap.disconnected.connect(_on_disconnected)
	iap.purchase_updated.connect(_on_purchase_updated)
	iap.purchase_error.connect(_on_purchase_error)
	iap.products_fetched.connect(_on_products_fetched_raw)
	var connected = await iap.init_connection()
	if connected and not _initialized:
		_on_connected()
	elif not connected:
		print("OpenIAP connection failed")

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

func restore_purchases() -> int:
	var iap = _get_iap()
	if not iap:
		return PurchaseResult.UNAVAILABLE
	if not _initialized:
		return PurchaseResult.NOT_INITIALIZED
	if _restore_in_progress:
		return PurchaseResult.OK
	while not _products_ready and _initialized:
		await get_tree().process_frame
	if not _initialized:
		return PurchaseResult.NOT_INITIALIZED
	_restore_in_progress = true
	print("Restoring purchases...")
	var found = await _check_pending_restorations()
	_restore_in_progress = false
	restore_completed.emit(found)
	return PurchaseResult.OK

func _on_connected():
	if _initialized:
		return
	_initialized = true
	print("OpenIAP connected")
	_fetch_products()

func _on_disconnected():
	_initialized = false
	_products_ready = false
	print("OpenIAP disconnected")

func _on_products_fetched_raw(result: Dictionary) -> void:
	if not result.has("productsJson") and not result.has("products"):
		return
	_last_products_raw = result
	var products_json = String(result.get("productsJson", "[]"))
	var parsed = JSON.parse_string(products_json)
	_last_products_native_count = (parsed.size() if parsed is Array else 0)
	_last_products_error = String(result.get("error", ""))

func _fetch_products():
	if _products_fetch_started:
		return
	_products_fetch_started = true
	var iap = _get_iap()
	if not iap:
		_products_fetch_started = false
		return
	var request = {
		"skus": _get_all_skus(),
		"type": "in-app"
	}
	print("Fetching IAP products: ", request["skus"])
	last_products_status = "Fetching: %s" % ", ".join(request["skus"])
	var products = await iap.fetch_products(request)
	var fetched_skus: Array[String] = []
	for product in products:
		if product is Object and product.has_method("to_dict"):
			product = product.to_dict()
		if product is Dictionary:
			var product_id = String(product.get("id", product.get("productId", "")))
			if not product_id.is_empty():
				fetched_skus.append(product_id)
	print("IAP products returned: ", fetched_skus)
	last_products_status = "Products: %s" % (
		", ".join(fetched_skus) if not fetched_skus.is_empty() else "none"
	)
	await get_tree().process_frame
	if products.is_empty() and not _last_products_raw.is_empty():
		last_products_status = "StoreKit response:\n%s" % JSON.stringify(_last_products_raw)
	elif products.is_empty() and _last_products_native_count > 0:
		last_products_status = "StoreKit returned products, but mapping failed"
	elif products.is_empty() and not _last_products_error.is_empty():
		last_products_status = "StoreKit error: %s" % _last_products_error
	if products.size() > 0:
		_products_ready = true
		print("Product details loaded: ", products.size(), " products")
		_check_pending_restorations()
	else:
		print("Failed to load product details")
		if _last_products_native_count == 0 and _last_products_error.is_empty():
			last_products_status = "StoreKit returned no matching products"
		# StoreKit can still resolve a valid product during requestPurchase.
		# Do not block the purchase flow solely because the metadata query was empty.
		_products_ready = true

func _get_all_skus() -> Array:
	var skus := []
	for wid in IAPConfig.SKUS:
		skus.append(IAPConfig.SKUS[wid])
	skus.append(IAPConfig.EXTEND_KITCHEN_SKU)
	return skus

func _check_pending_restorations() -> bool:
	var iap = _get_iap()
	if not iap:
		return false
	var restore_result = await iap.restore_purchases()
	if not restore_result.success:
		print("Failed to restore purchases")
		return false
	var result = await iap.get_available_purchases_result()
	if result.get("success", false):
		var purchases = result.get("purchases", [])
		if purchases.is_empty():
			print("No pending purchases to restore")
			return false
		print("Found ", purchases.size(), " purchase(s) to reconcile")
		var added := false
		for purchase in purchases:
			var purchase_dict = _to_canonical_purchase_dict(purchase)
			if purchase_dict.is_empty():
				continue
			var product_id = purchase_dict.get("productId", "")
			if product_id.is_empty():
				continue
			if not _is_purchased(purchase_dict.get("purchaseState", "")):
				continue
			var token = purchase_dict.get("transactionId", "")
			if token.is_empty():
				continue
			if Global.is_purchase_processed(token):
				print("Purchase already delivered, cleaning up: ", product_id, " token=", token)
				_acknowledge_purchase(purchase_dict, product_id)
			else:
				var already_pending := false
				for p in _pending_restorations:
					if p["token"] == token:
						already_pending = true
						break
				if already_pending:
					continue
				_purchases_by_token[token] = purchase_dict
				print("Pending delivery for: ", product_id, " token=", token)
				_pending_restorations.append({"sku": product_id, "token": token})
				added = true
		if not _pending_restorations.is_empty():
			purchases_restored.emit()
		return added
	return false

func _to_canonical_purchase_dict(purchase) -> Dictionary:
	var purchase_dict: Dictionary
	if purchase is Dictionary:
		purchase_dict = purchase
	elif purchase is Object and purchase.has_method("to_dict"):
		purchase_dict = purchase.to_dict()
	else:
		return {}
	if String(purchase_dict.get("productId", "")) != "":
		return purchase_dict
	var mapped := purchase_dict.duplicate(true)
	if not mapped.has("productId") and mapped.has("product_id"):
		mapped["productId"] = mapped["product_id"]
	if not mapped.has("transactionId") and mapped.has("transaction_id"):
		mapped["transactionId"] = mapped["transaction_id"]
	if not mapped.has("purchaseState") and mapped.has("purchase_state"):
		mapped["purchaseState"] = mapped["purchase_state"]
	mapped.erase("product_id")
	mapped.erase("transaction_id")
	mapped.erase("purchase_state")
	if String(mapped.get("productId", "")) != "":
		return mapped
	return {}

func _is_purchased(state) -> bool:
	if state is int:
		return state == Types.PurchaseState.PURCHASED
	return String(state).strip_edges().to_lower() == "purchased"

func purchase_kedai(kedai_id: String) -> int:
	var iap = _get_iap()
	if not iap:
		return PurchaseResult.UNAVAILABLE
	if not _initialized:
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
	_pending_purchase_sku = sku
	var request_result = iap.request_purchase(props)
	print("Purchase request result: ", request_result)
	if request_result is Dictionary and not request_result.get("success", true):
		_on_purchase_error(request_result)
	return PurchaseResult.OK

func purchase_extend_kitchen() -> int:
	var iap = _get_iap()
	if not iap:
		return PurchaseResult.UNAVAILABLE
	if not _initialized:
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
	_pending_purchase_sku = sku
	var request_result = iap.request_purchase(props)
	print("Purchase request result: ", request_result)
	if request_result is Dictionary and not request_result.get("success", true):
		_extend_purchase_pending = false
		_on_purchase_error(request_result)
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
	var message = String(error.get("message", error.get("error", "unknown")))
	var sku = String(error.get("productId", _pending_purchase_sku))
	if message.to_lower().contains("sku") and not sku.is_empty():
		message = "%s: %s" % [message, sku]
	print("Purchase failed: ", message, " code=", error.get("code", "unknown"))
	purchase_failed.emit(message)
	_pending_purchase_sku = ""
	if _extend_purchase_pending:
		_extend_purchase_pending = false
		extend_kitchen_failed.emit()

func finalize_purchase(token: String, sku: String):
	var purchase = _purchases_by_token.get(token)
	if not purchase is Dictionary:
		push_error("Cannot finalize purchase without its purchase payload: %s" % token)
		return
	if IAPConfig.get_type(sku) == IAPConfig.SkuType.NON_CONSUMABLE:
		_purchases_by_token.erase(token)
		return
	_acknowledge_purchase(purchase, sku)
	_purchases_by_token.erase(token)

func finish_purchase(token: String, sku: String):
	var purchase = _purchases_by_token.get(token)
	if not purchase is Dictionary:
		push_error("Cannot finish purchase without its purchase payload: %s" % token)
		return
	_acknowledge_purchase(purchase, sku)
	_purchases_by_token.erase(token)

func _acknowledge_purchase(purchase: Dictionary, sku: String):
	var iap = _get_iap()
	if not iap:
		return
	var is_consumable = IAPConfig.get_type(sku) == IAPConfig.SkuType.CONSUMABLE
	iap.finish_transaction_dict(purchase, is_consumable)
