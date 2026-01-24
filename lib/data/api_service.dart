import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/driver_standing.dart';

class ApiService {
  static const String _baseUrl = 'https://api.jolpi.ca/ergast/f1/';

  Future<List<DriverStanding>> getDriverStandings() async {
    final response = await http.get(
      Uri.parse('${_baseUrl}2025/driverstandings/'),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List standingsJson =
          data['MRData']['StandingsTable']['StandingsLists'][0]['DriverStandings'];

      return standingsJson
          .map((json) => DriverStanding.fromJson(json))
          .toList();
    } else {
      throw Exception('Failed to load standings');
    }
  }
}
