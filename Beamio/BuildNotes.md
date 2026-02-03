# Build Notes

- The project relies on Xcode-generated Info.plist settings; avoid adding a standalone Info.plist file to the app target to prevent duplicate build outputs.
- The standalone Info.plist is intentionally absent from the repo to prevent duplicate build output conflicts.
