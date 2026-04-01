import SwiftUI
import WidgetKit

private let widgetAppGroupId = "group.com.gridglance.app"

private struct GridGlanceEntry: TimelineEntry {
  let date: Date
  let values: [String: String]

  func text(_ key: String, fallback: String) -> String {
    values[key] ?? fallback
  }

  /// Loads an image from a file path stored in the entry values.
  func image(_ key: String) -> UIImage? {
    guard let path = values[key], !path.isEmpty else { return nil }
    return UIImage(contentsOfFile: path)
  }
}

private struct GridGlanceProvider: TimelineProvider {
  func placeholder(in context: Context) -> GridGlanceEntry {
    GridGlanceEntry(date: Date(), values: [
      "driver_widget_title": "Driver Standings",
      "driver_widget_subtitle": "Top 3 drivers",
      "driver_widget_season": "\(Calendar.current.component(.year, from: Date()))",
      "driver_1": "Max Verstappen - 0 pts",
      "driver_1_last_name": "VERSTAPPEN",
      "driver_1_pts": "0",
      "driver_2": "Lando Norris - 0 pts",
      "driver_2_last_name": "NORRIS",
      "driver_2_pts": "0",
      "driver_3": "Charles Leclerc - 0 pts",
      "driver_3_last_name": "LECLERC",
      "driver_3_pts": "0",
      "team_widget_title": "Team Standings",
      "team_widget_subtitle": "Top 3 teams",
      "team_widget_season": "\(Calendar.current.component(.year, from: Date()))",
      "team_1": "Red Bull - 0 pts",
      "team_1_name": "Red Bull",
      "team_1_pts": "0",
      "team_2": "Ferrari - 0 pts",
      "team_2_name": "Ferrari",
      "team_2_pts": "0",
      "team_3": "Mercedes - 0 pts",
      "team_3_name": "Mercedes",
      "team_3_pts": "0",
      "next_race_widget_title": "Next Race",
      "next_race_widget_name": "Race weekend",
      "next_race_widget_location": "Location TBA",
      "next_race_widget_start": "Time TBA",
      "next_race_widget_countdown": "Starts soon",
      "next_race_widget_days": "--",
      "next_race_widget_hours": "--",
      "next_race_widget_mins": "--",
      "next_race_widget_round": "",
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

// MARK: - Shared Components

private let f1Red = Color(red: 0.88, green: 0.02, blue: 0.0)
private let f1RedLight = Color(red: 1.0, green: 0.23, blue: 0.19)
private let silverColor = Color(red: 0.62, green: 0.65, blue: 0.71)
private let bronzeColor = Color(red: 0.80, green: 0.50, blue: 0.20)
private let surfaceAlt = Color(red: 0.11, green: 0.14, blue: 0.19)
private let borderColor = Color(red: 0.14, green: 0.17, blue: 0.23)
private let textMuted = Color.white.opacity(0.55)

private struct TeamLogoView: View {
  let image: UIImage?
  let size: CGFloat

  var body: some View {
    if let uiImage = image {
      Image(uiImage: uiImage)
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: size, height: size)
    } else {
      Color.clear
        .frame(width: size, height: size)
    }
  }
}

private struct DriverPhotoView: View {
  let image: UIImage?
  let size: CGFloat
  var borderColor: Color = .white.opacity(0.3)

  var body: some View {
    if let uiImage = image {
      Image(uiImage: uiImage)
        .resizable()
        .aspectRatio(contentMode: .fill)
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(borderColor, lineWidth: 1.5))
    } else {
      Circle()
        .fill(surfaceAlt)
        .frame(width: size, height: size)
        .overlay(Circle().stroke(borderColor, lineWidth: 1.5))
    }
  }
}

private struct WidgetHeader: View {
  let title: String
  let trailing: String

  var body: some View {
    HStack(spacing: 6) {
      RoundedRectangle(cornerRadius: 1.5)
        .fill(LinearGradient(colors: [f1Red, f1RedLight], startPoint: .leading, endPoint: .trailing))
        .frame(width: 28, height: 3)
      Text(title)
        .font(.system(size: 10, weight: .bold, design: .default))
        .textCase(.uppercase)
        .tracking(0.5)
      Spacer()
      Text(trailing)
        .font(.system(size: 9, weight: .bold))
        .foregroundColor(.white.opacity(0.6))
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(surfaceAlt)
        .cornerRadius(6)
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
              Color(red: 0.07, green: 0.09, blue: 0.13),
              Color(red: 0.08, green: 0.10, blue: 0.15)
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
              Color(red: 0.07, green: 0.09, blue: 0.13),
              Color(red: 0.08, green: 0.10, blue: 0.15)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
    }
  }
}

// MARK: - Podium Components

private struct PodiumBlock: View {
  let position: Int
  let height: CGFloat

  private var color: Color {
    switch position {
    case 1: return f1Red
    case 2: return silverColor
    default: return bronzeColor
    }
  }

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 6, style: .continuous)
        .fill(
          LinearGradient(
            colors: [color.opacity(0.35), color.opacity(0.12)],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .overlay(
          RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(color.opacity(0.35), lineWidth: 1)
        )
      Text("\(position)")
        .font(.system(size: height * 0.35, weight: .black))
        .foregroundColor(color)
    }
    .frame(height: height)
  }
}

// MARK: - Driver Standings (Podium)

private struct DriverStandingsWidgetView: View {
  let entry: GridGlanceEntry

  var body: some View {
    WidgetSurface {
      VStack(alignment: .leading, spacing: 0) {
        WidgetHeader(
          title: entry.text("driver_widget_title", fallback: "Driver Standings"),
          trailing: entry.text("driver_widget_season", fallback: "--")
        )
        .foregroundColor(.white)

        Spacer(minLength: 4)

        // Podium: driver photos + names + blocks
        HStack(alignment: .bottom, spacing: 4) {
          // 2nd place
          VStack(spacing: 3) {
            DriverPhotoView(image: entry.image("driver_2_image"), size: 32)
            Text(entry.text("driver_2_last_name", fallback: "P2"))
              .font(.system(size: 8, weight: .bold, design: .default))
              .tracking(0.3)
              .lineLimit(1)
            Text("\(entry.text("driver_2_pts", fallback: "0")) pts")
              .font(.system(size: 7))
              .foregroundColor(textMuted)
            PodiumBlock(position: 2, height: 32)
          }
          .frame(maxWidth: .infinity)

          // 1st place
          VStack(spacing: 3) {
            DriverPhotoView(image: entry.image("driver_1_image"), size: 40, borderColor: f1Red.opacity(0.6))
            Text(entry.text("driver_1_last_name", fallback: "P1"))
              .font(.system(size: 9, weight: .bold, design: .default))
              .tracking(0.3)
              .lineLimit(1)
            Text("\(entry.text("driver_1_pts", fallback: "0")) pts")
              .font(.system(size: 7, weight: .semibold))
              .foregroundColor(.white.opacity(0.7))
            PodiumBlock(position: 1, height: 44)
          }
          .frame(maxWidth: .infinity)

          // 3rd place
          VStack(spacing: 3) {
            DriverPhotoView(image: entry.image("driver_3_image"), size: 32)
            Text(entry.text("driver_3_last_name", fallback: "P3"))
              .font(.system(size: 8, weight: .bold, design: .default))
              .tracking(0.3)
              .lineLimit(1)
            Text("\(entry.text("driver_3_pts", fallback: "0")) pts")
              .font(.system(size: 7))
              .foregroundColor(textMuted)
            PodiumBlock(position: 3, height: 22)
          }
          .frame(maxWidth: .infinity)
        }
      }
      .foregroundColor(.white)
    }
  }
}

// MARK: - Team Standings (Podium)

private struct TeamStandingsWidgetView: View {
  let entry: GridGlanceEntry

  var body: some View {
    WidgetSurface {
      VStack(alignment: .leading, spacing: 0) {
        WidgetHeader(
          title: entry.text("team_widget_title", fallback: "Team Standings"),
          trailing: entry.text("team_widget_season", fallback: "--")
        )
        .foregroundColor(.white)

        Spacer(minLength: 6)

        HStack(alignment: .bottom, spacing: 4) {
          // 2nd
          VStack(spacing: 3) {
            TeamLogoView(image: entry.image("team_2_logo"), size: 20)
            Text(entry.text("team_2_name", fallback: "P2"))
              .font(.system(size: 9, weight: .bold))
              .multilineTextAlignment(.center)
              .lineLimit(2)
            Text("\(entry.text("team_2_pts", fallback: "0")) pts")
              .font(.system(size: 7))
              .foregroundColor(textMuted)
            PodiumBlock(position: 2, height: 32)
          }
          .frame(maxWidth: .infinity)

          // 1st
          VStack(spacing: 3) {
            TeamLogoView(image: entry.image("team_1_logo"), size: 24)
            Text(entry.text("team_1_name", fallback: "P1"))
              .font(.system(size: 10, weight: .bold))
              .multilineTextAlignment(.center)
              .lineLimit(2)
            Text("\(entry.text("team_1_pts", fallback: "0")) pts")
              .font(.system(size: 8, weight: .semibold))
              .foregroundColor(.white.opacity(0.7))
            PodiumBlock(position: 1, height: 44)
          }
          .frame(maxWidth: .infinity)

          // 3rd
          VStack(spacing: 3) {
            TeamLogoView(image: entry.image("team_3_logo"), size: 20)
            Text(entry.text("team_3_name", fallback: "P3"))
              .font(.system(size: 9, weight: .bold))
              .multilineTextAlignment(.center)
              .lineLimit(2)
            Text("\(entry.text("team_3_pts", fallback: "0")) pts")
              .font(.system(size: 7))
              .foregroundColor(textMuted)
            PodiumBlock(position: 3, height: 22)
          }
          .frame(maxWidth: .infinity)
        }
      }
      .foregroundColor(.white)
    }
  }
}

// MARK: - Next Race (Countdown Segments)

private struct CountdownBox: View {
  let value: String
  let label: String

  var body: some View {
    VStack(spacing: 2) {
      Text(value)
        .font(.system(size: 18, weight: .bold))
        .foregroundColor(.white)
      Text(label)
        .font(.system(size: 7, weight: .bold))
        .foregroundColor(textMuted)
        .textCase(.uppercase)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 6)
    .background(surfaceAlt)
    .cornerRadius(8)
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(f1Red.opacity(0.2), lineWidth: 1)
    )
  }
}

private struct NextRaceWidgetView: View {
  let entry: GridGlanceEntry

  var body: some View {
    WidgetSurface {
      VStack(alignment: .leading, spacing: 0) {
        HStack {
          WidgetHeader(
            title: entry.text("next_race_widget_title", fallback: "Next Race"),
            trailing: entry.text("next_race_widget_round", fallback: "")
          )
        }
        .foregroundColor(.white)

        Spacer(minLength: 6)

        Text(entry.text("next_race_widget_name", fallback: "No upcoming race"))
          .font(.system(size: 13, weight: .bold))
          .lineLimit(1)

        Text(entry.text("next_race_widget_location", fallback: "Location TBA"))
          .font(.system(size: 9))
          .foregroundColor(textMuted)
          .lineLimit(1)
          .padding(.top, 1)

        Text(entry.text("next_race_widget_start", fallback: "Time TBA"))
          .font(.system(size: 8))
          .foregroundColor(textMuted)
          .lineLimit(1)

        Spacer(minLength: 6)

        // Countdown boxes
        HStack(spacing: 4) {
          CountdownBox(
            value: entry.text("next_race_widget_days", fallback: "--"),
            label: "Days"
          )
          Text(":")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(f1Red.opacity(0.3))
          CountdownBox(
            value: entry.text("next_race_widget_hours", fallback: "--"),
            label: "Hrs"
          )
          Text(":")
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(f1Red.opacity(0.3))
          CountdownBox(
            value: entry.text("next_race_widget_mins", fallback: "--"),
            label: "Min"
          )
        }
      }
      .foregroundColor(.white)
    }
  }
}

// MARK: - Next Session (Badge Style)

private struct NextSessionWidgetView: View {
  let entry: GridGlanceEntry

  var body: some View {
    WidgetSurface {
      VStack(alignment: .leading, spacing: 0) {
        WidgetHeader(
          title: entry.text("next_session_widget_title", fallback: "Next Session"),
          trailing: entry.text("next_session_widget_season", fallback: "--")
        )
        .foregroundColor(.white)

        Spacer(minLength: 6)

        // Session badge
        Text(entry.text("next_session_widget_name", fallback: "No upcoming session"))
          .font(.system(size: 11, weight: .bold))
          .foregroundColor(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 3)
          .background(
            LinearGradient(colors: [f1Red, f1RedLight], startPoint: .leading, endPoint: .trailing)
          )
          .cornerRadius(4)

        Text(entry.text("next_session_widget_race", fallback: "Schedule unavailable"))
          .font(.system(size: 11, weight: .semibold))
          .foregroundColor(.white.opacity(0.85))
          .lineLimit(1)
          .padding(.top, 6)

        // Countdown
        Text(entry.text("next_session_widget_countdown", fallback: "Check again later"))
          .font(.system(size: 12, weight: .bold))
          .foregroundColor(.white)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(8)
          .background(surfaceAlt)
          .cornerRadius(8)
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(borderColor, lineWidth: 1)
          )
          .padding(.top, 6)

        Spacer(minLength: 4)

        // Upcoming
        VStack(alignment: .leading, spacing: 4) {
          HStack(spacing: 6) {
            Circle()
              .fill(Color(red: 0.17, green: 0.21, blue: 0.27))
              .frame(width: 5, height: 5)
            Text(entry.text("next_session_widget_line1", fallback: "No additional sessions"))
              .font(.system(size: 9))
              .foregroundColor(.white.opacity(0.7))
              .lineLimit(1)
          }
          HStack(spacing: 6) {
            Circle()
              .fill(Color(red: 0.17, green: 0.21, blue: 0.27))
              .frame(width: 5, height: 5)
            Text(entry.text("next_session_widget_line2", fallback: "Check again soon"))
              .font(.system(size: 9))
              .foregroundColor(textMuted)
              .lineLimit(1)
          }
        }
      }
      .foregroundColor(.white)
    }
  }
}

// MARK: - Favorite Driver (Split Card)

private struct FavoriteDriverWidgetView: View {
  let entry: GridGlanceEntry

  private var pointsNumber: String {
    entry.text("favorite_driver_default_points", fallback: "-- pts")
      .replacingOccurrences(of: " pts", with: "")
      .replacingOccurrences(of: "pts", with: "")
  }

  private var tColor: Color {
    parseTeamColor(entry.text("favorite_driver_default_team_color", fallback: "#E10600"))
  }

  var body: some View {
    WidgetSurface {
      VStack(spacing: 0) {
        // Top half: driver photo + name overlay
        ZStack(alignment: .topLeading) {
          if let driverImage = entry.image("favorite_driver_default_image") {
            Image(uiImage: driverImage)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .padding(4)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else {
            Rectangle()
              .fill(surfaceAlt)
          }

          // Number badge + last name overlay
          HStack(spacing: 5) {
            DriverNumberBadge(
              number: entry.text("favorite_driver_default_number", fallback: "--"),
              tint: tColor
            )
            Text(entry.text("favorite_driver_default_last_name", fallback: ""))
              .font(.system(size: 12, weight: .bold, design: .default).italic())
              .foregroundColor(tColor)
              .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
              .lineLimit(1)
            Spacer()
            Text(entry.text("favorite_driver_default_season", fallback: "--"))
              .font(.system(size: 8, weight: .bold))
              .foregroundColor(.white.opacity(0.5))
              .padding(.horizontal, 5)
              .padding(.vertical, 2)
              .background(Color.black.opacity(0.4))
              .cornerRadius(4)
          }
          .padding(.horizontal, 10)
          .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        // Bottom half: details + stats
        HStack(spacing: 0) {
          RoundedRectangle(cornerRadius: 2)
            .fill(tColor)
            .frame(width: 4)

          VStack(alignment: .leading, spacing: 0) {
            Text(entry.text("favorite_driver_default_name", fallback: "Set favorite driver"))
              .font(.system(size: 13, weight: .bold, design: .default))
              .lineLimit(1)

            Text(entry.text("favorite_driver_default_team", fallback: ""))
              .font(.system(size: 8))
              .foregroundColor(textMuted)
              .lineLimit(1)
              .padding(.top, 1)

            // Stats — inline team-colored
            HStack(spacing: 5) {
              HStack(spacing: 1) {
                Text("P")
                  .font(.system(size: 11, weight: .bold, design: .default).italic())
                  .foregroundColor(textMuted)
                Text(entry.text("favorite_driver_default_position", fallback: "--"))
                  .font(.system(size: 15, weight: .bold, design: .default).italic())
                  .foregroundColor(tColor)
              }
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(tColor.opacity(0.15))
              .cornerRadius(6)

              HStack(spacing: 3) {
                Text(pointsNumber)
                  .font(.system(size: 15, weight: .bold, design: .default).italic())
                  .foregroundColor(tColor)
                Text("PTS")
                  .font(.system(size: 8, weight: .bold))
                  .foregroundColor(textMuted)
              }
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(tColor.opacity(0.15))
              .cornerRadius(6)
            }
            .padding(.top, 6)
          }
          .padding(.leading, 8)
          .padding(.trailing, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .foregroundColor(.white)
    }
  }
}

private struct StatBox: View {
  let label: String
  let value: String

  var body: some View {
    VStack(spacing: 1) {
      Text(label)
        .font(.system(size: 7, weight: .bold))
        .foregroundColor(textMuted)
      Text(value)
        .font(.system(size: 15, weight: .bold))
        .foregroundColor(.white)
    }
    .frame(width: 48, height: 36)
    .background(surfaceAlt)
    .cornerRadius(8)
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(borderColor, lineWidth: 1)
    )
  }
}

// MARK: - Favorite Team (Split Card)

private func parseTeamColor(_ hex: String) -> Color {
  var cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
  if cleaned.hasPrefix("#") { cleaned.removeFirst() }
  // Drop alpha prefix if 8 chars (AARRGGBB).
  if cleaned.count == 8 { cleaned = String(cleaned.dropFirst(2)) }
  guard cleaned.count == 6, let rgb = UInt64(cleaned, radix: 16) else { return f1Red }
  return Color(
    red: Double((rgb >> 16) & 0xFF) / 255,
    green: Double((rgb >> 8) & 0xFF) / 255,
    blue: Double(rgb & 0xFF) / 255
  )
}

private struct DriverNumberBadge: View {
  let number: String
  let tint: Color

  var body: some View {
    Text(number)
      .font(.system(size: 12, weight: .bold, design: .default).italic())
      .foregroundColor(tint)
      .frame(width: 26, height: 20)
      .background(tint.opacity(0.2))
      .cornerRadius(5)
  }
}

private struct FavoriteTeamWidgetView: View {
  let entry: GridGlanceEntry

  private var pointsNumber: String {
    entry.text("favorite_team_default_points", fallback: "-- pts")
      .replacingOccurrences(of: " pts", with: "")
      .replacingOccurrences(of: "pts", with: "")
  }

  private var tColor: Color {
    parseTeamColor(entry.text("favorite_team_default_team_color", fallback: "#E10600"))
  }

  var body: some View {
    WidgetSurface {
      VStack(spacing: 0) {
        // Top half: team name over car image area
        ZStack(alignment: .topLeading) {
          // Car image or placeholder
          if let carImage = entry.image("favorite_team_default_car_image") {
            Image(uiImage: carImage)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .padding(6)
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else {
            Rectangle()
              .fill(surfaceAlt)
          }

          // Team name overlay
          HStack {
            Text(entry.text("favorite_team_default_name", fallback: "Set favorite team"))
              .font(.system(size: 13, weight: .bold, design: .default))
              .textCase(.uppercase)
              .tracking(0.5)
              .foregroundColor(tColor)
              .shadow(color: .black.opacity(0.6), radius: 3, y: 1)
              .lineLimit(1)
            Spacer()
            Text(entry.text("favorite_team_default_season", fallback: "--"))
              .font(.system(size: 8, weight: .bold))
              .foregroundColor(.white.opacity(0.5))
              .padding(.horizontal, 5)
              .padding(.vertical, 2)
              .background(Color.black.opacity(0.4))
              .cornerRadius(4)
          }
          .padding(.horizontal, 10)
          .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)

        // Bottom half: driver details + stats
        HStack(spacing: 0) {
          // Team color bar
          RoundedRectangle(cornerRadius: 2)
            .fill(tColor)
            .frame(width: 4)

          VStack(alignment: .leading, spacing: 0) {
            // Driver 1
            HStack(spacing: 6) {
              DriverNumberBadge(
                number: entry.text("favorite_team_default_d1_number", fallback: "--"),
                tint: tColor
              )
              Text(entry.text("favorite_team_default_d1_name", fallback: "TBD"))
                .font(.system(size: 11, weight: .bold, design: .default).italic())
                .foregroundColor(tColor)
                .lineLimit(1)
              Spacer()
              Text(entry.text("favorite_team_default_d1_code", fallback: "---"))
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(textMuted)
            }

            // Driver 2
            HStack(spacing: 6) {
              DriverNumberBadge(
                number: entry.text("favorite_team_default_d2_number", fallback: "--"),
                tint: tColor
              )
              Text(entry.text("favorite_team_default_d2_name", fallback: "TBD"))
                .font(.system(size: 11, weight: .bold, design: .default).italic())
                .foregroundColor(tColor)
                .lineLimit(1)
              Spacer()
              Text(entry.text("favorite_team_default_d2_code", fallback: "---"))
                .font(.system(size: 8, weight: .bold))
                .foregroundColor(textMuted)
            }
            .padding(.top, 4)

            // Stats — inline team-colored
            HStack(spacing: 5) {
              // Position
              HStack(spacing: 1) {
                Text("P")
                  .font(.system(size: 11, weight: .bold, design: .default).italic())
                  .foregroundColor(textMuted)
                Text(entry.text("favorite_team_default_position", fallback: "--"))
                  .font(.system(size: 15, weight: .bold, design: .default).italic())
                  .foregroundColor(tColor)
              }
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(tColor.opacity(0.15))
              .cornerRadius(6)

              // Points
              HStack(spacing: 3) {
                Text(pointsNumber)
                  .font(.system(size: 15, weight: .bold, design: .default).italic())
                  .foregroundColor(tColor)
                Text("PTS")
                  .font(.system(size: 8, weight: .bold))
                  .foregroundColor(textMuted)
              }
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(tColor.opacity(0.15))
              .cornerRadius(6)
            }
            .padding(.top, 6)
          }
          .padding(.leading, 8)
          .padding(.trailing, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
      .foregroundColor(.white)
    }
  }
}

// MARK: - Widget Declarations

struct GridGlanceDriverStandingsWidget: Widget {
  let kind: String = "GridGlanceDriverStandingsWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: GridGlanceProvider()) { entry in
      DriverStandingsWidgetView(entry: entry)
    }
    .configurationDisplayName("Driver Standings")
    .description("Top 3 Formula 1 drivers on a podium.")
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
    .description("Top 3 Formula 1 teams on a podium.")
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
    .description("Upcoming race with countdown timer.")
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
