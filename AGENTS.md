# KedaiMania iOS Rules

- NEVER commit changes to Git unless explicitly asked by the user.

## iOS-Specific Notes

- This project targets iOS using Godot 4.7 with the Mobile renderer.
- IAP uses OpenIAP (StoreKit 2) - the `IAP` autoload.
- Ads use Unity Ads - the `Ads` autoload drives the `UnityAds` autoload, which
  wraps the native `GodotUnityAds` iOS plugin singleton.
- Product IDs use reverse-domain notation (e.g., `com.kedaimania.warung_pecel_lele`).

## Unity Ads Plugin Notes

The native bridge and `UnityAds.xcframework` are built by
`ios/plugins/unity-ads/build.sh` on the macOS GitHub Actions runner.
Configure the iOS Game ID and rewarded placement under Project Settings ->
`unity_ads/`.

## Godot IAP Plugin Notes

- Pinned to the official `godot-iap` **3.4.1** release from the OpenIAP monorepo
  (`hyodotdev/openiap`, tag `godot-iap-3.4.1`). Do NOT hand-patch the wrapper —
  replace the whole `addons/godot-iap/` folder from the release zip when
  upgrading.
- iOS export preset requires `application/min_ios_version` = **17.0** (the
  bundled `GodotIap.framework` / `SwiftGodotRuntime.framework` inherit the
  SwiftGodot iOS 17 minimum; anything lower crashes before startup).
- CI checks the plugin version and framework min iOS as a drift guard
  (`distribute.yml` "Verify Godot IAP Plugin" step).
- `Scripts/IAPManager.gd` owns all OpenIAP integration; it keeps its own
  diagnostics from the `products_fetched` / `purchase_updated` / `purchase_error`
  signals rather than relying on wrapper-internal state.

## Build & Deploy

- GitHub Actions CI/CD pipeline runs on `macos-latest` runners (free for public repos).
- Fastlane handles code-signing (cert/sigh) and TestFlight upload.
- See `README.md` for full setup instructions.
