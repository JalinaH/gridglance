import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> fetchDriverStandings() async {
  // The endpoint for the current season's driver standings
  final url = Uri.parse(
    'https://api.jolpica-f1.com/ergast/f1/current/driverStandings.json',
  );

  try {
    print("Fetching F1 Data...");
    final response = await http.get(url);

    if (response.statusCode == 200) {
      // 1. Decode the JSON data
      final data = jsonDecode(response.body);

      // 2. Navigate the nested JSON structure
      // MRData -> StandingsTable -> StandingsLists -> [0] -> DriverStandings
      final standingsList =
          data['MRData']['StandingsTable']['StandingsLists'][0]['DriverStandings'];

      print("\n--- 🏎️ CURRENT F1 STANDINGS 🏎️ ---\n");

      // 3. Loop through the drivers and print details
      for (var driver in standingsList) {
        final position = driver['position'];
        final points = driver['points'];
        final givenName = driver['Driver']['givenName'];
        final familyName = driver['Driver']['familyName'];
        final team = driver['Constructors'][0]['name'];

        print("#$position - $givenName $familyName ($team) - $points pts");
      }
    } else {
      print("Failed to load data. Status Code: ${response.statusCode}");
    }
  } catch (e) {
    print("Error fetching data: $e");
  }
}

// Quick test to run this function immediately when the app starts
void main() {
  fetchDriverStandings();
}
