# KedaiMania iOS

iOS port of KedaiMania cooking time management game, built with Godot 4.6.

## Prerequisites

1. **Apple Developer Account** ($100/year) - [developer.apple.com](https://developer.apple.com)
2. **GitHub Account** - For CI/CD pipeline (public repo = free macOS runners)

## Setup Instructions

### 1. Apple Developer Account Setup

1. Enroll in the Apple Developer Program
2. Create an App ID with bundle identifier `com.kedaimania`
3. Create an App Store Connect API key for Fastlane
4. Store the certificate `.p12` as the `BUILD_CERTIFICATE_P12` GitHub secret

### 2. GitHub Repository Setup

1. Create a **public** GitHub repository for this project
2. Go to **Settings → Secrets and variables → Actions**
3. Add the following repository secrets:

| Secret | Description |
|--------|-------------|
| `APP_STORE_CONNECT_API_KEY_ID` | Your App Store Connect API key ID |
| `APP_STORE_CONNECT_API_ISSUER_ID` | Your App Store Connect API issuer ID |
| `APP_STORE_CONNECT_API_KEY_KEY` | Your App Store Connect API private key (base64) |
| `BUILD_CERTIFICATE_P12` | Base64-encoded Apple Distribution `.p12` |

### 3. Initial Certificate Setup (One-Time)

On a Mac (or borrow one briefly), run:

```bash
# Install Fastlane
gem install fastlane

# Generate certificates through the GitHub Actions Initialize Certificates workflow
fastlane ios init_certificates
```

This creates the signing certificate and provisioning profile used by the workflow.

### 4. Build & Deploy

Push to `main` branch or trigger manually from GitHub Actions:

```bash
git push origin main
```

Or go to **Actions → Distribute to TestFlight → Run workflow**.

### 5. Test via TestFlight

1. Install the **TestFlight** app on your iOS device
2. Wait for the build to process (usually 10-30 minutes)
3. Install and test the build

### 6. App Store Submission

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Select the TestFlight build
3. Submit for App Store review

## Project Structure

```
KedaiManiaIos/
├── Art/                    # Game art assets
├── Assets/                 # UI assets, fonts
├── Audio/                  # Sound files
├── Resources/              # Game data (JSON)
├── Scenes/                 # Godot scene files
├── Scripts/                # GDScript files
├── addons/                 # Godot plugins
│   └── godot-iap/          # OpenIAP (StoreKit 2)
├── ios/plugins/            # iOS native plugins
│   └── unity-ads/          # Unity Ads iOS bridge and manifest
├── fastlane/               # Fastlane config
├── .github/workflows/      # GitHub Actions CI/CD
└── project.godot           # Godot project file
```

## Key Changes from Android Version

| Feature | Android | iOS |
|---------|---------|-----|
| IAP | Google Play Billing | OpenIAP (StoreKit 2) |
| Ads | Unity Ads | Unity Ads iOS bridge |
| Build | Gradle | GitHub Actions + Fastlane |

## Unity Ads Configuration

Set the real iOS Game ID in Project Settings -> `unity_ads/ios/game_id`.
The default rewarded placement is `Rewarded_iOS`; replace it with the
placement configured in the Unity Dashboard before production release.

## Troubleshooting

### Build fails with "No matching provisioning profiles"

Run the `Initialize Certificates` workflow again to regenerate certificates.

### Godot export fails

Ensure you have the latest Godot 4.6 stable release and iOS export templates installed.

### TestFlight build not appearing

Check the GitHub Actions logs. Common issues:
- Missing or incorrect secrets
- Certificate/profile mismatch
- Bundle ID mismatch
