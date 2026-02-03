# Build Notes

- The project relies on Xcode-generated Info.plist settings; avoid adding a standalone Info.plist file to the app target to prevent duplicate build outputs.
- Removed the duplicate Info.plist file that was causing build output conflicts.
