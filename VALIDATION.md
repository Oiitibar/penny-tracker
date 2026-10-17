# Delivery validation

Validation performed on 18 October 2026 (Asia/Rangoon), using the actual Flutter implementation in this directory.

| Check | Result |
| --- | --- |
| Frozen application dependency install: `flutter pub get --enforce-lockfile` | Passed; application lockfile included |
| Android SDK artifact preparation: `flutter precache --android` | Passed using the prepared, verified SDK cache |
| Formatting: `dart format --output=none --set-exit-if-changed lib test integration_test` | Passed; 19 Dart files |
| Static analysis: `flutter analyze --no-pub` | Passed; no issues |
| Unit, SQLite persistence, and widget tests: `flutter test --no-pub` | **53 passed, 0 failed, 0 skipped** |
| Flutter application asset/kernel bundle: `flutter build bundle --debug --target-platform android-arm64 --no-pub` | Passed; compiled kernel and local asset bundle produced (not an APK) |
| Android installable build: `flutter build apk --debug --target-platform android-arm64` | Blocked by network policy: HTTP 403 for Flutter Maven artifacts on `storage.googleapis.com`; no APK delivered |
| Android device/emulator integration test | Not run: no attached device or configured emulator |
| iOS build and device tests | Not run: this is a Linux machine without Xcode |
| Airplane mode on a physical device | Not run; application storage, fonts, icons and calculations are local, with no runtime network service |
| Figma frames | Not inspected: reference URL inaccessible from this environment |

## What the tests establish

- **31 financial/calendar tests:** direct integer-cent parsing; zero, negative, malformed, nonfinite, exponential, oversized and excessive-precision inputs; Monday/Sunday, month/year and leap-day boundaries; backdated records; the $120.65/$454.35 example; exact-budget, low-budget and overspending states; empty reports; consistent filters; stable ordering; normalized categories; shares allocating exactly 100%.
- **10 real SQLite repository tests:** seed creation, foreign-key/schema configuration, exact 1000-cent changes, custom category reuse, ignoring inactive custom input, an intentionally aborted insert rolling back both category and expense, edit identity/time preservation, deletion, disk database reopen, saved budget/payment/notice/colors, and no reseeding after deleting every expense.
- **12 widget tests:** persistent tab drafts, form reset, inline validation, custom categories and Cash/Card details, a failing-write draft and retry, delayed duplicate-submit protection, period filters, visible chart geometry, edit/delete/cancel, budget editing, resume, foreground midnight crossing into a new week, a 320×640 viewport at 200% text with keyboard insets, and actual rendered screenshots at 390×844.

The widget tests execute the real SQLite repository through a controlled adapter that moves native I/O outside Flutter's fake clock; the adapter can delay or fail a write. The disk restart tests close and reopen an independent database. These are meaningful host tests, and do not replace native plugin/device testing.

## Screenshots

`docs/screenshots/home.png`, `add.png`, and `insights.png` are captures of the actual Flutter widget renderer at a 390×844 logical viewport, rendered at 2× resolution. They are not Figma mockups, browser substitutes, or device/emulator screenshots. A deterministic test clock sets their sample dates to 15 October 2026; the production app uses the device's current local time.

## Android build blocker and next step

Java proxy configuration, a complete JDK/compiler, Android build tools and the NDK were prepared. The remaining confirmed error is the environment's HTTP 403 for these official Flutter artifacts:

- `io.flutter:arm64_v8a_debug:1.0.0-4c525dac5ebe5971c5708ef73558ed8edcf4a362`
- `io.flutter:flutter_embedding_debug:1.0.0-4c525dac5ebe5971c5708ef73558ed8edcf4a362`

Both are hosted under `https://storage.googleapis.com/download.flutter.io/`. The domain addition has been saved in the environment configuration draft, along with tested `install_script` and `start_skill` instructions. Saving the draft does not apply or publish it. Review and save the changes in environment settings, then publish the environment. Once the allowed domain is active, run:

```sh
source /workspace/.toolchains/activate.sh
cd /workspace/penny-tracker
flutter build apk --debug --target-platform android-arm64
```

The expected output is `build/app/outputs/flutter-apk/app-debug.apk`. An installable build and native smoke test are still outstanding; this delivery does not claim store-release, mobile-device or iOS validation.

## Toolchain provenance

Flutter 3.44.0, Dart 3.12.0, the Android SDK and JDK compiler were obtained from the public Cirrus Labs Flutter CI image (`ghcr.io/cirruslabs/flutter:stable`), whose image index resolved to `sha256:46691e311715845de03a3ba4753a475476936805b29431b1f00f1816981033f8`. The selected Linux amd64 manifest and each downloaded OCI layer were verified against their SHA-256 digests before use. This accessible distribution supplied the official SDK cache while direct Google Storage downloads were blocked. The image uses the pinned Flutter release tag, so `flutter doctor` reports its detached/custom branch rather than a channel checkout.

Gradle 9.1.0's downloaded distribution was verified against the official SHA-256 and that checksum is pinned in `android/gradle/wrapper/gradle-wrapper.properties`. The JDK uses the existing system Java certificate store; TLS and artifact verification were retained. No unverified artifact or disabled TLS workaround is used.
