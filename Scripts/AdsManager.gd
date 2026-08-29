extends Node

signal mood_reward_earned
signal mood_reward_failed
signal initialized

var _sdk_initialized := false
var _ad_flow_active := false
var _ads_completed := 0
var _flow_pending := false
var _body_label: Label
var _pending_body_label: Label

func _ready() -> void:
	UnityAds.initialized.connect(_on_initialized)
	UnityAds.init_failed.connect(_on_init_failed)
	UnityAds.ad_loaded.connect(_on_ad_loaded)
	UnityAds.ad_load_failed.connect(_on_ad_load_failed)
	UnityAds.rewarded.connect(_on_rewarded)
	UnityAds.ad_completed.connect(_on_ad_completed)
	UnityAds.ad_show_failed.connect(_on_ad_show_failed)

func is_initialized() -> bool:
	return _sdk_initialized

func is_flow_active() -> bool:
	return _ad_flow_active

enum StartResult { SDK_READY, SDK_NOT_READY, FLOW_ALREADY_ACTIVE }

func start_mood_reward_flow(body_label: Label = null) -> int:
	if _ad_flow_active:
		return StartResult.FLOW_ALREADY_ACTIVE
	if not _sdk_initialized:
		_flow_pending = true
		_pending_body_label = body_label
		return StartResult.SDK_NOT_READY
	_kick_off_flow(body_label)
	return StartResult.SDK_READY

func _kick_off_flow(body_label: Label) -> void:
	_ad_flow_active = true
	_ads_completed = 0
	_flow_pending = false
	_body_label = body_label
	_pending_body_label = null
	_set_body_text(Lang.t("mood_ad_loading"))
	UnityAds.load_rewarded()

func _on_initialized() -> void:
	_sdk_initialized = true
	initialized.emit()
	if _flow_pending and not _ad_flow_active:
		_kick_off_flow(_pending_body_label)

func _on_init_failed(error: String, message: String) -> void:
	print("AdsManager: Unity Ads initialization failed - error=", error, " msg=", message)
	_sdk_initialized = false
	if _flow_pending:
		_flow_pending = false
		_pending_body_label = null
		mood_reward_failed.emit()

func _on_ad_loaded(_placement_id: String) -> void:
	if not _ad_flow_active:
		return
	_set_body_text(Lang.t("mood_ad_watch_1" if _ads_completed == 0 else "mood_ad_watch_2"))
	UnityAds.show_rewarded()

func _on_ad_load_failed(_placement_id: String, error: String, message: String) -> void:
	print("AdsManager: ad failed to load - error=", error, " msg=", message)
	_abort_ad_flow()

func _on_rewarded(_placement_id: String) -> void:
	_ads_completed += 1
	if _ads_completed == 1:
		_set_body_text(Lang.t("mood_ad_loading_next"))
		UnityAds.load_rewarded()
	else:
		_complete_ad_flow()

func _on_ad_completed(_placement_id: String, state: String) -> void:
	if _ad_flow_active and state != "COMPLETED":
		_abort_ad_flow()

func _on_ad_show_failed(_placement_id: String, error: String, message: String) -> void:
	print("AdsManager: ad failed to show - error=", error, " msg=", message)
	_abort_ad_flow()

func _complete_ad_flow() -> void:
	_ad_flow_active = false
	_ads_completed = 0
	_body_label = null
	mood_reward_earned.emit()

func _abort_ad_flow() -> void:
	_ad_flow_active = false
	_ads_completed = 0
	_set_body_text(Lang.t("mood_ad_failed"))
	_body_label = null
	mood_reward_failed.emit()

func _set_body_text(text: String) -> void:
	if _body_label and is_instance_valid(_body_label):
		_body_label.text = text
