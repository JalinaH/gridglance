import SwiftUI
import WidgetKit

private let widgetAppGroupId = "group.com.example.gridglance"

private struct GridGlanceEntry: TimelineEntry {
  let date: Date
  let values: [String: String]

  func text(_ key: String, fallback: String) -> String {
    values[key] ?? fallback
  }
}

private struct GridGlanceProvider: TimelineProvider {
  func placeholder(in context: Context) -> GridGlanceEntry {
    GridGlanceEntry(date: Date(), values: [
      "driver_widget_title": "Driver Standings",
      "driver_widget_subtitle": "Top 3 drivers",
      "driver_widget_season": "\(Calendar.current.component(.year, from: Date()))",
      "driver_1": "Max Verstappen - 0 pts",
      "driver_2": "Lando Norris - 0 pts",
      "driver_3": "Charles Leclerc - 0 pts",
      "team_widget_title": "Team Standings",
      "team_widget_subtitle": "Top 3 teams",
      "team_widget_season": "\(Calendar.current.component(.year, from: Date()))",
      "team_1": "Red Bull - 0 pts",
      "team_2": "Ferrari - 0 pts",
      "team_3": "Mercedes - 0 pts",
      "next_race_widget_title": "Next Race",
      "next_race_widget_name": "Race weekend",
      "next_race_widget_location": "Location TBA",
      "next_race_widget_start": "Time TBA",
      "next_race_widget_countdown": "Starts soon",
      "next_session_widget_title": "Next Session",
      "next_session_widget_name": "Practice 1",
      "next_session_widget_race": "Race weekend",
      "next_session_widget_countdown": "Starts soon",
      "next_session_widget_line1": "Practice 2 • Fri 5:00 PM",
      "next_session_widget_line2": "Qualifying • Sat 4:00 PM",
      "favorite_driver_default_name": "Set favorite driver",
      "favorite_driver_default_team": "",
      "favorite_driver_default_position": "--",
      "favorite_driver_default_points": "-- pts",
      "favorite_driver_default_season": "\(Calendar.current.component(.year, from: Date()))",
      "favorite_team_default_name": "Set favorite team",
      "favorite_team_default_position": "--",
      "favorite_team_default_points": "-- pts",
      "favorite_team_default_driver1": "TBD",
      "favorite_team_default_driver2": "TBD",
      "favorite_team_default_season": "\(Calendar.current.component(.year, from: Date()))"
    ])
  }

  func getSnapshot(in context: Context, completion: @escaping (GridGlanceEntry) -> Void) {
    completion(loadEntry())
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<GridGlanceEntry>) -> Void) {
    let entry = loadEntry()
    let refresh = Calendar.current.date(byAdding: .minute, value: 15, to: Date()) ?? Date().addingTimeInterval(900)
    completion(Timeline(entries: [entry], policy: .after(refresh)))
  }

  private func loadEntry() -> GridGlanceEntry {
    let defaults = UserDefaults(suiteName: widgetAppGroupId)
    var values: [String: String] = [:]
    defaults?.dictionaryRepresentation().forEach { key, value in
      if let text = value as? String {
        values[key] = text
      }
    }
    return GridGlanceEntry(date: Date(), values: values)
  }
}

private struct WidgetHeader: View {
  let title: String
  let subtitle: String

  var body: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(.headline)
        .lineLimit(1)
      Text(subtitle)
        .font(.caption2)
        .foregroundColor(.white.opacity(0.8))
        .lineLimit(1)
    }
  }
}

private struct WidgetSurface<Content: View>: View {
  let content: Content

  init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  var body: some View {
    if #available(iOSApplicationExtension 17.0, *) {
      content
        .padding(14)
        .containerBackground(for: .widget) {
          LinearGradient(
            colors: [
              Color(red: 0.12, green: 0.12, blue: 0.14),
              Color(red: 0.18, green: 0.08, blue: 0.09)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        }
    } else {
      content
        .padding(14)
        .background(
          LinearGradient(
            colors: [
              Color(red: 0.12, green: 0.12, blue: 0.14),
              Color(red: 0.18, green: 0.08, blue: 0.09)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
    }
  }
}

private struct DriverStandingsWidgetView: View {
  let entry: GridGlanceEntry

  var body: some View {
    WidgetSurface {
      VStack(alignment: .leading, spacing: 8) {
        WidgetHeader(
          title: entry.text("driver_widget_title", fallback: "Driver Standings"),
          subtitle: "Season \(entry.text("driver_widget_season", fallback: "--"))"
        )
        Text(entry.text("driver_1", fallback: "Update from app"))
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
        Text(entry.text("driver_2", fallback: "TBD"))
          .font(.caption)
          .lineLimit(1)
        Text(entry.text("driver_3", fallback: "TBD"))
          .font(.caption)
          .lineLimit(1)
      }
      .foregroundColor(.white)
    }
  }
}

private struct TeamStandingsWidgetView: View {
  let entry: GridGlanceEntry

  var body: some View {
    WidgetSurface {
      VStack(alignment: .leading, spacing: 8) {
        WidgetHeader(
          title: entry.text("team_widget_title", fallback: "Team Standings"),
          subtitle: "Season \(entry.text("team_widget_season", fallback: "--"))"
        )
        Text(entry.text("team_1", fallback: "Update from app"))
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
        Text(entry.text("team_2", fallback: "TBD"))
          .font(.caption)
          .lineLimit(1)
        Text(entry.text("team_3", fallback: "TBD"))
          .font(.caption)
          .lineLimit(1)
      }
      .foregroundColor(.white)
    }
  }
}

private struct NextRaceWidgetView: View {
  let entry: GridGlanceEntry

  var body: some View {
    WidgetSurface {
      VStack(alignment: .leading, spacing: 8) {
        WidgetHeader(
          title: entry.text("next_race_widget_title", fallback: "Next Race"),
          subtitle: "Season \(entry.text("next_race_widget_season", fallback: "--"))"
        )
        Text(entry.text("next_race_widget_name", fallback: "No upcoming race"))
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
        Text(entry.text("next_race_widget_location", fallback: "Location TBA"))
          .font(.caption)
          .lineLimit(1)
        Text(entry.text("next_race_widget_start", fallback: "Time TBA"))
          .font(.caption2)
          .foregroundColor(.white.opacity(0.8))
          .lineLimit(1)
        Text(entry.text("next_race_widget_countdown", fallback: "Awaiting next calendar"))
          .font(.caption2.weight(.semibold))
          .lineLimit(1)
      }
      .foregroundColor(.white)
    }
  }
}

private struct NextSessionWidgetView: View {
  let entry: GridGlanceEntry

  var body: some View {
    WidgetSurface {
      VStack(alignment: .leading, spacing: 8) {
        WidgetHeader(
          title: entry.text("next_session_widget_title", fallback: "Next Session"),
          subtitle: "Season \(entry.text("next_session_widget_season", fallback: "--"))"
        )
        Text(entry.text("next_session_widget_name", fallback: "No upcoming session"))
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
        Text(entry.text("next_session_widget_race", fallback: "Schedule unavailable"))
          .font(.caption)
          .lineLimit(1)
        Text(entry.text("next_session_widget_countdown", fallback: "Check again later"))
          .font(.caption2.weight(.semibold))
          .lineLimit(1)
        Text(entry.text("next_session_widget_line1", fallback: "No additional sessions"))
          .font(.caption2)
          .lineLimit(1)
      }
      .foregroundColor(.white)
    }
  }
}

private struct FavoriteDriverWidgetView: View {
  let entry: GridGlanceEntry

  var body: some View {
    WidgetSurface {
      VStack(alignment: .leading, spacing: 8) {
        WidgetHeader(
          title: "Favorite Driver",
          subtitle: "Season \(entry.text("favorite_driver_default_season", fallback: "--"))"
        )
        Text(entry.text("favorite_driver_default_name", fallback: "Set favorite driver"))
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
        Text(entry.text("favorite_driver_default_team", fallback: ""))
          .font(.caption)
          .lineLimit(1)
        HStack(spacing: 8) {
          Text("P\(entry.text("favorite_driver_default_position", fallback: "--"))")
          Text(entry.text("favorite_driver_default_points", fallback: "-- pts"))
        }
        .font(.caption2.weight(.semibold))
      }
      .foregroundColor(.white)
    }
  }
}

private struct FavoriteTeamWidgetView: View {
  let entry: GridGlanceEntry

  var body: some View {
    WidgetSurface {
      VStack(alignment: .leading, spacing: 8) {
        WidgetHeader(
          title: "Favorite Team",
          subtitle: "Season \(entry.text("favorite_team_default_season", fallback: "--"))"
        )
        Text(entry.text("favorite_team_default_name", fallback: "Set favorite team"))
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
        HStack(spacing: 8) {
          Text("P\(entry.text("favorite_team_default_position", fallback: "--"))")
          Text(entry.text("favorite_team_default_points", fallback: "-- pts"))
        }
        .font(.caption2.weight(.semibold))
        Text(
          "\(entry.text("favorite_team_default_driver1", fallback: "TBD"))  \(entry.text("favorite_team_default_driver2", fallback: "TBD"))"
        )
        .font(.caption)
        .lineLimit(1)
      }
      .foregroundColor(.white)
    }
  }
}

struct GridGlanceDriverStandingsWidget: Widget {
  let kind: String = "GridGlanceDriverStandingsWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: GridGlanceProvider()) { entry in
      DriverStandingsWidgetView(entry: entry)
    }
    .configurationDisplayName("Driver Standings")
    .description("Top 3 Formula 1 drivers.")
    .supportedFamilies([.systemMedium])
  }
}

struct GridGlanceTeamStandingsWidget: Widget {
  let kind: String = "GridGlanceTeamStandingsWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: GridGlanceProvider()) { entry in
      TeamStandingsWidgetView(entry: entry)
    }
    .configurationDisplayName("Team Standings")
    .description("Top 3 Formula 1 teams.")
    .supportedFamilies([.systemMedium])
  }
}

struct GridGlanceNextRaceWidget: Widget {
  let kind: String = "GridGlanceNextRaceWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: GridGlanceProvider()) { entry in
      NextRaceWidgetView(entry: entry)
    }
    .configurationDisplayName("Next Race Countdown")
    .description("Upcoming race and start countdown.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct GridGlanceNextSessionWidget: Widget {
  let kind: String = "GridGlanceNextSessionWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: GridGlanceProvider()) { entry in
      NextSessionWidgetView(entry: entry)
    }
    .configurationDisplayName("Next Session")
    .description("Upcoming Formula 1 session details.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct GridGlanceFavoriteDriverWidget: Widget {
  let kind: String = "GridGlanceFavoriteDriverWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: GridGlanceProvider()) { entry in
      FavoriteDriverWidgetView(entry: entry)
    }
    .configurationDisplayName("Favorite Driver")
    .description("Watch your favorite driver's position and points.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

struct GridGlanceFavoriteTeamWidget: Widget {
  let kind: String = "GridGlanceFavoriteTeamWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: GridGlanceProvider()) { entry in
      FavoriteTeamWidgetView(entry: entry)
    }
    .configurationDisplayName("Favorite Team")
    .description("Watch your favorite team's points and drivers.")
    .supportedFamilies([.systemSmall, .systemMedium])
  }
}

@main
struct GridGlanceWidgetsBundle: WidgetBundle {
  var body: some Widget {
    GridGlanceDriverStandingsWidget()
    GridGlanceTeamStandingsWidget()
    GridGlanceFavoriteDriverWidget()
    GridGlanceFavoriteTeamWidget()
    GridGlanceNextRaceWidget()
    GridGlanceNextSessionWidget()
  }
}
