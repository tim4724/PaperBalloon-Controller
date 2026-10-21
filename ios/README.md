# Paper Balloon Controller — iOS

Native SwiftUI port of the Android launcher (functional parity; see
[../CONTRACT.md](../CONTRACT.md) for the launcher⇄game contract).

The Xcode project is generated, not committed:

```sh
brew install xcodegen   # once
cd ios
xcodegen generate
open PaperBalloon.xcodeproj
```

iOS 17+, no third-party dependencies. QR scanning uses AVFoundation and
degrades to manual room-code entry in the simulator (no camera).

`PaperBalloon/Resources/games-manifest.json` and `Resources/artwork/` are copies
of the Android assets (`../android/app/src/main/assets/`) — keep them in sync
when the manifest changes.

## App Clip

`PaperBalloonClip` (`games.paperballoon.controller.Clip`) lets a camera scan of a room link
play without installing the app. It compiles the same `PaperBalloon/` sources with
`APPCLIP` set (`PB.isAppClip`), so the invocation URL takes the Universal Link path
through `SceneDelegate`. Shared code must stay clip-safe: a clip has no Bonjour, so
§8 discovery and advertising are off there — see Apple's
[App Clip limitations](https://developer.apple.com/documentation/appclip/choosing-the-right-functionality-for-your-app-clip).
Invocation hosts are the clip's `appclips:` entitlements in `project.yml`; each must
serve an AASA naming the clip, and which URLs open it is set by the App Clip
experiences in App Store Connect.
