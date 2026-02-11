# GridGlance

GridGlance is a Flutter app for following Formula 1 standings and race weekends in a fast, glanceable format.

## What it does

- Shows a season overview with:
  - Next race countdown
  - Last race results (Race, Qualifying, Sprint)
  - Top driver and constructor standings
  - Upcoming races
- Lets users switch seasons (1950 to current year).
- Includes searchable driver, constructor, and race schedule views.
- Provides detail pages for drivers and teams, including points trend charts and recent form.
- Adds race sessions to the device calendar from race detail screens.
- Schedules local race-weekend notifications (default: 15 minutes before each session, when permissions are granted).
- Supports home-screen widgets on Android and iOS:
  - Driver Standings
  - Team Standings
  - Favorite Driver
  - Favorite Team
  - Next Race Countdown
  - Next Session
- Persists user preferences (theme mode, selected season, favorite driver/team, notification toggles).

## Tech stack

- Flutter + Dart
- HTTP client: `http`
- Local notifications: `flutter_local_notifications`
- Calendar integration: `add_2_calendar`
- Widgets: `home_widget`
- Local persistence: `shared_preferences`
- Timezone handling: `timezone`

## Data source

Race and standings data is loaded from the Ergast-compatible Jolpica API endpoint:

- `https://api.jolpi.ca/ergast/f1/`

## Project structure

```text
gridglance/
├── lib/
│   ├── data/            # API client
│   ├── models/          # Domain models (race, standings, results)
│   ├── screens/         # App screens and flows
│   ├── services/        # Notifications, widgets, calendar, preferences
│   ├── theme/           # App theme
│   ├── utils/           # Formatting/helpers
│   └── widgets/         # Reusable UI components
├── android/             # Android app + AppWidget providers/layouts
├── ios/                 # iOS runner project
└── pubspec.yaml
```

## Getting started

### Prerequisites

- Flutter SDK (stable)
- Xcode (for iOS builds)
- Android Studio / Android SDK (for Android builds)

### Install dependencies

```bash
flutter pub get
```

### Run the app

```bash
flutter run
```

To target a specific platform/device:

```bash
flutter run -d android
flutter run -d ios
```

## Development commands

```bash
flutter analyze
flutter test
flutter build apk --release
flutter build ios --release
```

## Platform notes

### Android

- Uses `POST_NOTIFICATIONS` and `SCHEDULE_EXACT_ALARM` permissions for reminders.
- Widgets are implemented as Android App Widgets in `android/app/src/main/`.
- Current application ID is `com.example.gridglance` and should be changed before production release.

### iOS

- Calendar permission usage descriptions are configured in `ios/Runner/Info.plist`.
- WidgetKit extension target is `GridGlanceWidgets` (iOS 14+).
- App and widget share data via App Group `group.com.example.gridglance`.

## Current status

- Automated tests are available under `test/` for core models, formatting utilities, and notifications.
