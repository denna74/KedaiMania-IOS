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

## Build & Deploy

- GitHub Actions CI/CD pipeline runs on `macos-latest` runners (free for public repos).
- Fastlane handles code-signing (cert/sigh) and TestFlight upload.
- See `README.md` for full setup instructions.
