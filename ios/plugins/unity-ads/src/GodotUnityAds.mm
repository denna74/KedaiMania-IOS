#import "GodotUnityAds.h"
#import <UIKit/UIKit.h>
#import <UnityAds/UnityAds.h>
#import <UnityAds/UnityAds-Swift.h>
#include "core/config/engine.h"

GodotUnityAdsBridge *GodotUnityAdsBridge::instance = NULL;

@implementation GodotUnityAds
- (void)initializationComplete { dispatch_async(dispatch_get_main_queue(), ^{ GodotUnityAdsBridge::get_singleton()->emit_initialized(); }); }
- (void)initializationFailed:(UnityAdsInitializationError)error withMessage:(NSString *)message {
	[self unityAdsInitializationFailed:error withMessage:message];
}
- (void)unityAdsInitializationFailed:(UnityAdsInitializationError)error withMessage:(NSString *)message {
	NSString *err = [NSString stringWithFormat:@"%ld", (long)error];
	dispatch_async(dispatch_get_main_queue(), ^{ GodotUnityAdsBridge::get_singleton()->emit_init_failed([err UTF8String], [message UTF8String]); });
}
- (void)unityAdsAdLoaded:(NSString *)placementId { dispatch_async(dispatch_get_main_queue(), ^{ GodotUnityAdsBridge::get_singleton()->emit_ad_loaded([placementId UTF8String]); }); }
- (void)unityAdsAdFailedToLoad:(NSString *)placementId withError:(UnityAdsLoadError)error withMessage:(NSString *)message {
	NSString *err = [NSString stringWithFormat:@"%ld", (long)error];
	dispatch_async(dispatch_get_main_queue(), ^{ GodotUnityAdsBridge::get_singleton()->emit_ad_load_failed([placementId UTF8String], [err UTF8String], [message UTF8String]); });
}
- (void)unityAdsShowStart:(NSString *)placementId {}
- (void)unityAdsShowClick:(NSString *)placementId {}
- (void)unityAdsShowComplete:(NSString *)placementId withFinishState:(UnityAdsShowCompletionState)state {
	NSString *stateString = state == kUnityShowCompletionStateCompleted ? @"COMPLETED" : (state == kUnityShowCompletionStateSkipped ? @"SKIPPED" : @"ERROR");
	dispatch_async(dispatch_get_main_queue(), ^{
		GodotUnityAdsBridge::get_singleton()->emit_ad_completed([placementId UTF8String], [stateString UTF8String]);
		if (state == kUnityShowCompletionStateCompleted) GodotUnityAdsBridge::get_singleton()->emit_rewarded([placementId UTF8String]);
	});
}
- (void)unityAdsShowFailed:(NSString *)placementId withError:(UnityAdsShowError)error withMessage:(NSString *)message {
	NSString *err = [NSString stringWithFormat:@"%ld", (long)error];
	dispatch_async(dispatch_get_main_queue(), ^{ GodotUnityAdsBridge::get_singleton()->emit_ad_show_failed([placementId UTF8String], [err UTF8String], [message UTF8String]); });
}
@end

GodotUnityAdsBridge::GodotUnityAdsBridge() { ERR_FAIL_COND(instance != NULL); instance = this; unityAds = [[GodotUnityAds alloc] init]; }
GodotUnityAdsBridge::~GodotUnityAdsBridge() { if (instance == this) instance = NULL; unityAds = nil; }
GodotUnityAdsBridge *GodotUnityAdsBridge::get_singleton() { return instance; }
bool GodotUnityAdsBridge::is_available() { return [UnityServices isInitialized]; }
void GodotUnityAdsBridge::initialize(String game_id, bool test_mode) { NSString *gameId = [NSString stringWithUTF8String:game_id.utf8().get_data()]; [UnityAds initialize:gameId testMode:test_mode initializationDelegate:unityAds]; }
void GodotUnityAdsBridge::load_ad(String placement_id) { NSString *placement = [NSString stringWithUTF8String:placement_id.utf8().get_data()]; [UnityAds load:placement loadDelegate:unityAds]; }
void GodotUnityAdsBridge::show_ad(String placement_id) {
	NSString *placement = [NSString stringWithUTF8String:placement_id.utf8().get_data()];
	UIViewController *rootController = nil;
	for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
		if (scene.activationState == UISceneActivationStateForegroundActive && [scene isKindOfClass:[UIWindowScene class]]) {
			rootController = ((UIWindowScene *)scene).keyWindow.rootViewController;
			break;
		}
	}
	if (rootController == nil && UIApplication.sharedApplication.keyWindow != nil) rootController = UIApplication.sharedApplication.keyWindow.rootViewController;
	[UnityAds show:rootController placementId:placement showDelegate:unityAds];
}
void GodotUnityAdsBridge::load_banner(String, String) {}
void GodotUnityAdsBridge::show_banner() {}
void GodotUnityAdsBridge::hide_banner() {}
void GodotUnityAdsBridge::destroy_banner() {}
void GodotUnityAdsBridge::emit_initialized() { emit_signal("initialized"); }
void GodotUnityAdsBridge::emit_init_failed(String e, String m) { emit_signal("init_failed", e, m); }
void GodotUnityAdsBridge::emit_ad_loaded(String p) { emit_signal("ad_loaded", p); }
void GodotUnityAdsBridge::emit_ad_load_failed(String p, String e, String m) { emit_signal("ad_load_failed", p, e, m); }
void GodotUnityAdsBridge::emit_ad_completed(String p, String s) { emit_signal("ad_completed", p, s); }
void GodotUnityAdsBridge::emit_rewarded(String p) { emit_signal("rewarded", p); }
void GodotUnityAdsBridge::emit_ad_show_failed(String p, String e, String m) { emit_signal("ad_show_failed", p, e, m); }

void GodotUnityAdsBridge::_bind_methods() {
	ADD_SIGNAL(MethodInfo("initialized"));
	ADD_SIGNAL(MethodInfo("init_failed", PropertyInfo(Variant::STRING, "error"), PropertyInfo(Variant::STRING, "message")));
	ADD_SIGNAL(MethodInfo("ad_loaded", PropertyInfo(Variant::STRING, "placement_id")));
	ADD_SIGNAL(MethodInfo("ad_load_failed", PropertyInfo(Variant::STRING, "placement_id"), PropertyInfo(Variant::STRING, "error"), PropertyInfo(Variant::STRING, "message")));
	ADD_SIGNAL(MethodInfo("ad_completed", PropertyInfo(Variant::STRING, "placement_id"), PropertyInfo(Variant::STRING, "state")));
	ADD_SIGNAL(MethodInfo("ad_show_failed", PropertyInfo(Variant::STRING, "placement_id"), PropertyInfo(Variant::STRING, "error"), PropertyInfo(Variant::STRING, "message")));
	ADD_SIGNAL(MethodInfo("rewarded", PropertyInfo(Variant::STRING, "placement_id")));
	ClassDB::bind_method(D_METHOD("is_available"), &GodotUnityAdsBridge::is_available);
	ClassDB::bind_method(D_METHOD("initialize"), &GodotUnityAdsBridge::initialize);
	ClassDB::bind_method(D_METHOD("load_ad"), &GodotUnityAdsBridge::load_ad);
	ClassDB::bind_method(D_METHOD("show_ad"), &GodotUnityAdsBridge::show_ad);
	ClassDB::bind_method(D_METHOD("load_banner"), &GodotUnityAdsBridge::load_banner);
	ClassDB::bind_method(D_METHOD("show_banner"), &GodotUnityAdsBridge::show_banner);
	ClassDB::bind_method(D_METHOD("hide_banner"), &GodotUnityAdsBridge::hide_banner);
	ClassDB::bind_method(D_METHOD("destroy_banner"), &GodotUnityAdsBridge::destroy_banner);
}

GodotUnityAdsBridge *godot_unity_ads;
void register_godot_unity_ads_types() { godot_unity_ads = memnew(GodotUnityAdsBridge); Engine::get_singleton()->add_singleton(Engine::Singleton("GodotUnityAds", godot_unity_ads)); }
void unregister_godot_unity_ads_types() { if (godot_unity_ads) memdelete(godot_unity_ads); }
