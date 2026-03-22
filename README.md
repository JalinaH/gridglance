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
- Provides detail pages for drivers and teams, including points trend charts, head-to-head comparisons, and recent form.
- Race Weekend Center with live weather forecasts for upcoming sessions.
- Predict race podiums and qualifying top 3, with season-long scoring.
- Share standings and race countdown cards as images.
- Adds race sessions to the device calendar from race detail screens.
- Schedules local race-weekend notifications with configurable lead times, weekend digests, and favorite driver/team result alerts.
- Supports home-screen widgets on Android and iOS:
  - Driver Standings
  - Team Standings
  - Favorite Driver
  - Favorite Team
  - Next Race Countdown
  - Next Session
- Persists user preferences (theme mode, selected season, favorite driver/team, notification toggles).
- Animated splash screen with F1 starting lights sequence, logo reveal, racing stripes, and glow effects.
- Polished interactions: haptic feedback, bounce-tap animations, celebratory confetti/pulse overlays, swipe-to-favorite gestures, skeleton loading states, and adaptive responsive layouts.

## Tech stack

- Flutter + Dart
- HTTP client: `http`
- Local notifications: `flutter_local_notifications`
- Calendar integration: `add_2_calendar`
- Widgets: `home_widget`
- Local persistence: `shared_preferences`
- Timezone handling: `timezone`
- Background tasks: `workmanager`
- Typography: `google_fonts`

## Data source

Race and standings data is loaded from the Ergast-compatible Jolpica API endpoint:

- `https://api.jolpi.ca/ergast/f1/`

## Project structure

```text
gridglance/
├── lib/
│   ├── data/            # API client with HTTP response caching
│   ├── models/          # Domain models (race, standings, results)
│   ├── screens/         # 15 app screens and flows (includes splash screen)
│   ├── services/        # Notifications, predictions, weather, calendar, sharing, preferences
│   ├── theme/           # AppColors theme extension (dark/light)
│   ├── utils/           # Formatting, haptics, team assets
│   └── widgets/         # 16 reusable UI components
├── android/             # Android app + 6 AppWidget providers
├── ios/                 # iOS runner + WidgetKit extension
├── test/
│   ├── models/          # Race, results, standings model tests
│   ├── services/        # Notification, prediction, preferences tests
│   ├── utils/           # Date formatting, team asset tests
│   ├── screens/         # SplashScreen, AboutScreen tests
│   └── widgets/         # BounceTap, AnimatedCounter, EmptyState, SwipeAction, Celebration tests
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
- Current application ID is `com.gridglance.app` and should be changed before production release.

### iOS

- Calendar permission usage descriptions are configured in `ios/Runner/Info.plist`.
- WidgetKit extension target is `GridGlanceWidgets` (iOS 14+).
- App and widget share data via App Group `group.com.gridglance.app`.

## Testing

128 automated tests covering:

- **Models** — Race, RaceSession, DriverStanding, ConstructorStanding, and all result types (race, sprint, qualifying)
- **Screens** — SplashScreen (animation sequence, 5 starting lights, onComplete callback, racing stripes, logo fade-in, dark background, disposal), AboutScreen (sections, features, info cards, links, Season card removal, scrollability)
- **Services** — NotificationService key generation and ID determinism, NotificationPreferences (session toggles, lead times, weekend digest, favorite alerts), UserPreferences (season, favorite driver/team), PredictionService (scoring, season aggregation, input validation)
- **Utils** — Date/time formatting (relative labels, localized dates), team logo asset lookup (case-insensitive matching, legacy names, 2026 roster)
- **Widgets** — BounceTap (scale animation, event pass-through), AnimatedCounter (value animation, formatting, prefix/suffix), EmptyState (icon mapping for all 7 types), SwipeActionWrapper (primary/secondary swipe actions, threshold behavior), CelebrationOverlay (confetti/pulse variants, IgnorePointer)

```bash
flutter test                 # Run all tests
flutter test test/models/    # Run model tests only
flutter test test/widgets/   # Run widget tests only
```
