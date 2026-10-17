# Student Penny Tracker

A complete offline Flutter expense tracker for a student's weekly allowance. Android is the primary target; the source includes an iOS project. The mint interface has exactly three tabs: **Home**, **Add**, and **Insights**. Expense details, corrections, deletion, and budget editing use sheets and dialogs.

## Run

Toolchain used: **Flutter 3.44.0**, **Dart 3.12.0**, **OpenJDK 21**, Android SDK 36, Android build tools 36.0.0, NDK 28.2.13676358, Gradle 9.1.0, and Android Gradle Plugin 9.0.1. `.fvmrc` pins Flutter; `pubspec.lock` pins Dart packages. Install Flutter 3.44.0 from the official distribution or use FVM, and complete Android Studio's SDK setup. Android API 24+ is the minimum supported by this Flutter toolchain.

```sh
flutter doctor
flutter pub get --enforce-lockfile
flutter devices
flutter run -d <android-device-id>
```

On this prepared cloud machine, activate the installed SDK first:

```sh
source /workspace/.toolchains/activate.sh
cd /workspace/penny-tracker
flutter pub get --enforce-lockfile
```

Use the existing checkout. Cloud tasks already provide isolation; a Git worktree is unnecessary. The app runs on a connected phone or emulator, and has no server to start. Emulator or physical-device access is not provided by this cloud container.

For iOS, use macOS with Xcode, accept Xcode's license, select a development team in `ios/Runner.xcworkspace`, and run `flutter run -d <ios-device-id>`. iOS compilation and device behavior must be verified on that toolchain; they are not implied by Android or host tests. The generated project uses Flutter's Swift Package Manager integration.

## Build and verify

On Linux, SQLite-backed host tests require `libsqlite3-dev` (or a development-library link to your installed `libsqlite3.so.0`). macOS provides SQLite. The production app uses native `sqflite`, not the host test adapter.

```sh
flutter pub get --enforce-lockfile
dart format --output=none --set-exit-if-changed lib test integration_test
flutter analyze --no-pub
flutter test --no-pub
# Or run all three checks together:
./tool/verify.sh

# Installable local Android build:
flutter build apk --debug --target-platform android-arm64
# Install on a connected phone:
flutter install --debug -d <android-device-id>

# Native device integration test (separate test database):
flutter test integration_test/app_smoke_test.dart -d <android-device-id>
```

`test/app_test.dart` also saves actual Flutter renderer captures of the three screens in `artifacts/screenshots/`. These are host-rendered app screenshots, not device/emulator captures. The screenshot test loads the bundled fonts and Material icon font; it optionally loads a host Noto emoji font. Android and iOS use their built-in emoji fallback fonts.

Actual host-rendered screen captures are included in `docs/screenshots/`.

`VALIDATION.md` records exactly what ran in the delivery environment, including any Android build limitation. Flutter, pub, Gradle, Android SDK, and Maven dependencies need network access **during development and installation**. The installed app needs no network, account, server, API keys, or runtime permissions.

A store distribution needs your own signing identity. The generated Android release configuration currently uses the development debug key for local installation, following Flutter's template. Before store submission, configure an upload keystore in an ignored `android/key.properties`, wire its signing config in `android/app/build.gradle.kts`, and build with `flutter build appbundle --release`. Never commit keystores, passwords, or `key.properties`. iOS App Store distribution likewise needs your Apple signing identity. An installable development build is not a store-signed release.

## Behavior

- The first database creation inserts eight categories, a $575.00 weekly allowance, the local name Crystal, and four sample expenses totaling $120.65 across all dates. Their dates are resolved once, relative to that first launch. Weekly totals depend on the actual calendar week. The dismissible sample notice is stored.
- Weeks start on Monday and end before the next Monday. Today and Month use the same local calendar rules on every screen. Midnight and app resume refresh the period. Old expenses remain in history.
- The allowance applies to every week, without rollover or historical budget versions. Status thresholds are based on the balance. Overspending shows the absolute overage and zero remaining progress.
- An Add draft survives tab changes. Saving validates the amount, date and category, commits locally, refreshes shared state, clears the form, and returns Home. Cash is initially selected; subsequent new entries remember the last successfully saved payment method.
- Other requires a custom name. Whitespace is normalized and case-insensitive matches reuse predefined or saved categories. Custom categories receive stable stored colors and appear as reusable chips.
- Details show local recorded time, category, and payment. Edit preserves identity, recorded time, and creation timestamp. Delete requires confirmation. Errors retain the draft and do not report success.
- Insights uses the same filtered records for the list, horizontal segmented category bar, percentages, and top category. Largest remainders make displayed whole shares sum to 100%; raw ratios determine bar widths. Ties use category names.

## Storage and data flow

SQLite stores `expenses`, `categories`, and one `preferences` row. `AppDatabase` enables foreign keys, indexed calendar/category queries, check constraints, schema version 1, and a seed marker. Seeding occurs only in `onCreate`; deleting all expenses never triggers reseeding. Future schema changes must add an explicit migration and increment the schema version; unsupported upgrades or downgrades fail without resetting data.

The production database is `student_penny_tracker.db` in the platform's application database directory. Data stays in the app's sandbox. Android automatic backup is disabled. Uninstalling or clearing app data removes the tracker; ordinary updates with the same application ID/signature retain it. There is no telemetry or transaction-content logging in application code.

Amounts are parsed from validated decimal text straight into **integer cents**. Database values and sums stay integer; floating-point ratios are used only to draw percentages, and currency formatting converts cents for display. A local `YYYY-MM-DD` date and `HH:mm:ss` recorded time stay separate from UTC audit timestamps so changing device timezone does not move old expenses to another calendar date.

Riverpod injects the repository and clock. `AppStore` owns the current database snapshot. Repository mutations create/reuse categories, write the expense and payment preference, and read the refreshed snapshot within one SQLite transaction. A failure rolls back the entire operation. Widgets render that committed snapshot through shared `SpendingReport` and `BudgetSummary` calculations; they do not keep competing totals. UI submission locks prevent repeated taps from inserting duplicates. A refresh revision guard prevents a stale background read from replacing newer write results.

Tests use a separate SQLite database through `sqflite_common_ffi` and an injected clock. The UI test adapter runs the real repository's native I/O outside Flutter's fake clock and can simulate failures or delayed writes; no production database is touched. The on-device integration test also uses a distinct test database.

## Main editing locations

| Change | File |
| --- | --- |
| Colors, typography, component theme, icon mapping | `lib/core/theme.dart` |
| English UI copy / future localization entry point | `lib/core/strings.dart` |
| USD formatting, input validation, periods, percentages and budget thresholds | `lib/core/finance.dart` |
| Source records and preferences | `lib/core/models.dart` |
| Category definitions, palette, schema, defaults, one-time sample data | `lib/data/database.dart` |
| Atomic SQLite operations | `lib/data/repository.dart` |
| Shared state, repository and clock injection | `lib/state/providers.dart` |
| Bottom navigation, resume and midnight refresh | `lib/app.dart` |
| Dashboard | `lib/features/dashboard.dart` |
| Single reused Add/Edit form | `lib/features/expense_form.dart` |
| History, chart, legend and top-spending card | `lib/features/insights.dart` |
| Details, edit sheet and delete confirmation | `lib/features/transaction_details.dart` |
| Bundled Plus Jakarta Sans / Nunito Sans and SIL licenses | `assets/fonts/` |
| Original launcher artwork / build-time icon generator | `assets/branding/`, `tool/generate_icons.py` |

The provided ZIP was a TypeScript web implementation. This delivery is a Flutter mobile rebuild using the attached written requirements. The referenced Figma page was inaccessible from the build environment, so no claim is made to have inspected its frames. No website or web wrapper is used.
