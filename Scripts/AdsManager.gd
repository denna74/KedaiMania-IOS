extends Node

# Project-wide AdMob manager for iOS. Owns the two-ad rewarded flow used to
# recover mood. Registered as the `Ads` autoload in project.godot.
# Both Main.gd and GameUI.gd call into this -- they don't touch ad SDK internals.
#
# AdMob rewarded ad flow:
#   1. Load first rewarded ad
#   2. Show first ad -> on user earned reward -> load second ad
#   3. Show second ad -> on user earned reward -> flow complete

signal mood_reward_earned
signal mood_reward_failed
signal initialized

var _sdk_initialized: bool = false
var _ad_flow_active: bool = false
var _ads_completed: int = 0

var _rewarded_ad = null
var _full_screen_callback = null
var _admob_available: bool = false
var _mobile_ads = null

var _body_label: Label
var _pending_body_label: Label

func _ready():
	_admob_available = ClassDB.class_exists("MobileAds")
	if _admob_available:
		_setup_admob()
	else:
		print("AdsManager: AdMob plugin not available (editor mode)")

func _setup_admob():
	_mobile_ads = ClassDB.instantiate("MobileAds")
	var signal_name := "initialization_completed"
	_mobile_ads.connect(signal_name, _on_initialized)
	_full_screen_callback = ClassDB.instantiate("FullScreenContentCallback")
	_full_screen_callback.on_ad_dismissed_full_screen_content = _on_ad_dismissed
	_full_screen_callback.on_ad_failed_to_show_full_screen_content = _on_ad_show_failed
	_mobile_ads.initialize()

func is_initialized() -> bool:
	return _sdk_initialized

func is_flow_active() -> bool:
	return _ad_flow_active

enum StartResult { SDK_READY, SDK_NOT_READY, FLOW_ALREADY_ACTIVE }

func start_mood_reward_flow(body_label: Label = null) -> int:
	if _ad_flow_active:
		return StartResult.FLOW_ALREADY_ACTIVE
	if not _sdk_initialized:
		_pending_body_label = body_label
		return StartResult.SDK_NOT_READY
	_kick_off_flow(body_label)
	return StartResult.SDK_READY

func _kick_off_flow(body_label: Label):
	_ad_flow_active = true
	_ads_completed = 0
	_body_label = body_label
	_pending_body_label = null
	if not _has_internet():
		_set_body_text(Lang.t("mood_ad_no_internet"))
		_abort_ad_flow()
		return
	_set_body_text(Lang.t("mood_ad_loading"))
	_load_rewarded_ad()

func _has_internet() -> bool:
	var addresses = IP.get_local_addresses()
	for addr in addresses:
		if addr.begins_with("127."):
			continue
		if "." in addr and not addr.begins_with("0."):
			return true
	return false

func _load_rewarded_ad():
	if not _admob_available:
		_abort_ad_flow()
		return
	var unit_id := "ca-app-pub-3940256099942544/1712485313"
	var load_callback = ClassDB.instantiate("RewardedAdLoadCallback")
	load_callback.on_ad_loaded = func(ad):
		print("AdsManager: rewarded ad loaded, ads_completed=", _ads_completed)
		_rewarded_ad = ad
		_rewarded_ad.full_screen_content_callback = _full_screen_callback
		if _ads_completed == 0:
			_set_body_text(Lang.t("mood_ad_watch_1"))
		else:
			_set_body_text(Lang.t("mood_ad_watch_2"))
		_show_rewarded_ad()
	load_callback.on_ad_failed_to_load = func(error):
		print("AdsManager: ad FAILED to load - ", error.message)
		_abort_ad_flow()
	var loader = ClassDB.instantiate("RewardedAdLoader")
	var ad_request = ClassDB.instantiate("AdRequest")
	loader.load(unit_id, ad_request, load_callback)

func _show_rewarded_ad():
	if _rewarded_ad and _admob_available:
		var reward_listener = ClassDB.instantiate("OnUserEarnedRewardListener")
		reward_listener.on_user_earned_reward = func(reward):
			print("AdsManager: rewarded, ads_completed was=", _ads_completed)
			_ads_completed += 1
			if _ads_completed == 1:
				_set_body_text(Lang.t("mood_ad_loading_next"))
				_load_rewarded_ad()
			elif _ads_completed >= 2:
				_complete_ad_flow()
		_rewarded_ad.show(reward_listener)

func _on_initialized(_status = null):
	_sdk_initialized = true
	print("AdsManager: AdMob SDK initialized")
	initialized.emit()
	if _pending_body_label != null and not _ad_flow_active:
		_kick_off_flow(_pending_body_label)

func _on_ad_dismissed():
	print("AdsManager: ad dismissed")

func _on_ad_show_failed(ad_error = null):
	print("AdsManager: ad FAILED to show - ", ad_error.message if ad_error else "unknown")
	_abort_ad_flow()

func _complete_ad_flow():
	_ad_flow_active = false
	_ads_completed = 0
	_rewarded_ad = null
	_body_label = null
	mood_reward_earned.emit()

func _abort_ad_flow():
	_ad_flow_active = false
	_ads_completed = 0
	_rewarded_ad = null
	_set_body_text(Lang.t("mood_ad_failed"))
	_body_label = null
	mood_reward_failed.emit()

func _set_body_text(text: String):
	if _body_label and is_instance_valid(_body_label):
		_body_label.text = text
