# Build Notes

- The project relies on Xcode-generated Info.plist settings; avoid adding a standalone Info.plist file to the app target to prevent duplicate build outputs.
- The standalone Info.plist is intentionally absent from the repo to prevent duplicate build output conflicts.
- ADB functionality is implemented natively in Swift; no Python runtime is bundled.
- App icons are provided by `Assets.xcassets/AppIcon.appiconset`. Ensure the AppIcon set is included and built so `CFBundleIconName` is injected.
