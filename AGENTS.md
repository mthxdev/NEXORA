# Build & Verify

This is an iOS/SwiftUI project using [xcodesgen](https://github.com/yonaskoon/xcodegen) for project generation. Building requires macOS + Xcode.

## Generate project
```bash
xcodegen
```

## Build
```bash
xcodebuild -project Nexora.xcodeproj -scheme Nexora -destination "platform=iOS Simulator,name=iPhone 16" build
```

## Run tests
```bash
xcodebuild -project Nexora.xcodeproj -scheme Nexora -destination "platform=iOS Simulator,name=iPhone 16" test
```

## Lint
SwiftLint is not currently configured. If added in the future:
```bash
swiftlint
```
