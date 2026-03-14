# iOS Client Skeleton

This folder contains source files for a pure iOS app with local persistence.

## Recommended Target

- iOS 17.0+
- SwiftUI
- SwiftData

## Build in Xcode

1. Create a new iOS App project (`File -> New -> Project`).
2. Product Name: `CarRecord`
3. Interface: `SwiftUI`
4. Language: `Swift`
5. Add all files from `ios/CarRecord` to the app target.
6. Build and run.

## Notes

- The app has no networking layer by design.
- All records are stored on-device.
- You can migrate to CloudKit or backend later without replacing feature UI.
