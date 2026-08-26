# KedaiMania iOS Rules

- NEVER commit changes to Git unless explicitly asked by the user.

## iOS-Specific Notes

- This project targets iOS using Godot 4.6 with the Mobile renderer.
- IAP uses OpenIAP (StoreKit 2) - the `IAP` autoload.
- Ads use the poing-godot-admob iOS plugin - the `MobileAds` singleton.
- The `UnityAds` autoload has been removed (was Android-only).
- Product IDs use reverse-domain notation (e.g., `com.kedaimania.warung_pecel_lele`).

## AdMob Plugin Notes

**ALWAYS pass `null` (or nothing) to `RewardedAdLoader.load()`** — the test ad unit ID
for iOS is `ca-app-pub-3940256099942544/1712485313`. Replace with your own ad unit ID
before production release.

## Build & Deploy

- GitHub Actions CI/CD pipeline runs on `macos-latest` runners (free for public repos).
- Fastlane handles code-signing (match) and TestFlight upload.
- See `README.md` for full setup instructions.
