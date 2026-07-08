# Video Reverser

A SwiftUI iOS app that reverses videos — the whole clip, or just a part of it as a
"replay" — with playback-speed control and a boomerang mode.

## Features

- **Reverse all** — play the entire video backwards.
- **Replay part** — pick a segment on the filmstrip timeline; the video plays
  forward, then the selected part plays in reverse before continuing.
- **Boomerang** — forward, then backward, in a loopable clip.
- **Speed dial** — snap the playback speed of the effect from 50% to 200%.
- **Audio options** — keep the original audio, mute it, or reverse it along with
  the video.
- **Export options** — 720p / 1080p / original quality, save to Photos, share sheet.
- **Recent projects** — finished videos are kept on the home screen for quick
  re-viewing and sharing.
- Three-page onboarding and a review prompt after the first finished video.
- All UI text lives in a String Catalog (`Localizable.xcstrings`) — English today,
  ready for more languages without code changes.

## Requirements

- Xcode 15+ / iOS 17+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (the `.xcodeproj` is generated,
  not checked in)

## Getting started

```sh
brew install xcodegen
xcodegen
open VideoReverser.xcodeproj
```

Then select your signing team in *Signing & Capabilities* and run on a simulator
or device.

## Project layout

```
project.yml            XcodeGen spec (target, Info.plist keys)
VideoReverser/
  App/                 entry point, app-wide state
  Onboarding/          3-page intro flow
  Home/                video picker + recent projects
  Editor/              preview, filmstrip timeline, speed dial, mode & audio pickers
  Processing/          AVFoundation reverse engine, audio reversal, composition assembly
  Export/              export progress, result, save & share, review prompt
  Support/             small shared helpers
  Localization/        String Catalog
```

## Notes

- The onboarding demos are lightweight SwiftUI animations; drop real demo clips
  into `Resources` and swap them in if you prefer video demos.
- CI builds the app (simulator, unsigned) on every push via GitHub Actions.
