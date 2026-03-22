# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run Commands

```bash
flutter pub get              # Install dependencies
flutter run                  # Run app (auto-detects device)
flutter analyze              # Static analysis (uses flutter_lints)
flutter test                 # Run all tests
flutter test test/models/race_model_test.dart  # Run a single test file
flutter build apk --release  # Android release build
flutter build ios --release  # iOS release build
```

No code generation (build_runner, freezed, json_serializable) is used — models have manual `fromJson()` factories.

## Architecture

**State management:** Stateful widgets with local state — no Provider, Riverpod, or Bloc.

**API layer:** Single `ApiService` class (`lib/data/api_service.dart`) queries the Jolpica F1 API (`api.jolpi.ca/ergast/f1/`). Has built-in HTTP response caching via SharedPreferences with `CachedApiResponse<T>` wrapper. Falls back to cached data on network failure. Screens call `ApiService` methods directly.

**Theme system:** Custom `AppColors` as `ThemeExtension` in `lib/theme/`. Dark mode is the default, toggled via SharedPreferences (`theme_mode` key). F1 brand red (#E10600) is the primary accent.

**Platform channels:** Two MethodChannels for Android widget integration:

- `gridglance/dps` — widget data persistence via DeviceProtectedStorage
- `gridglance/widget_intent` — routes widget clicks back to Flutter

**Navigation:** Standard `Navigator.push()` — no named routes or router packages. `MainShell` provides bottom navigation between Home, Widgets, and About tabs.

## Key Directories

- `lib/data/` — API service (single file)
- `lib/models/` — Domain models with manual JSON parsing
- `lib/screens/` — UI screens (13+)
- `lib/services/` — Notifications, background tasks, widgets, weather, predictions, sharing, calendar, preferences
- `lib/theme/` — AppColors extension and AppTheme
- `lib/widgets/` — Reusable UI components
- `android/app/src/main/kotlin/` — 6 Android widget providers + MainActivity with MethodChannel bridges
- `ios/GridGlanceWidgets/` — WidgetKit extension (iOS 14+)
- `test/` — Unit tests for models, utils, and services

## App Initialization (main.dart)

Startup order: WidgetUpdateService → NotificationService → BackgroundTaskService → runApp. The app observes lifecycle via `WidgetsBindingObserver` and runs `FavoriteResultAlertService` on resume.

## Platform Notes

- **Android:** Requires INTERNET, POST_NOTIFICATIONS, SCHEDULE_EXACT_ALARM permissions. Background tasks run every 30 min via workmanager.
- **iOS:** Uses App Groups (`group.com.gridglance.app`) for widget data sharing. Background modes: fetch + processing.
