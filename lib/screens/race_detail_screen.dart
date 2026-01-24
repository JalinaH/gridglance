import 'package:flutter/material.dart';
import '../models/race.dart';
import '../widgets/season_cards.dart';

class RaceDetailScreen extends StatelessWidget {
  final Race race;
  final String season;

  const RaceDetailScreen({
    required this.race,
    required this.season,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Next Race"),
            Text(
              "Season $season",
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.only(top: 12, bottom: 20),
        children: [
          RaceCard(race: race, highlight: true),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow("Round", race.round),
                _buildDetailRow("Date", race.date),
                if (race.time != null && race.time!.isNotEmpty)
                  _buildDetailRow("Time", race.time!),
                _buildDetailRow("Circuit", race.circuitName),
                _buildDetailRow("Location", race.location),
              ],
            ),
          ),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Session Schedule",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 10),
                ..._buildSessionRows(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSessionRows() {
    final sessions = race.sessions
        .where((session) => session.date.isNotEmpty)
        .toList();
    if (sessions.isEmpty) {
      return [
        Text(
          "Session times not available.",
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ];
    }

    return sessions
        .map(
          (session) => _buildDetailRow(
            session.name,
            session.displayDateTime,
            labelWidth: 110,
          ),
        )
        .toList();
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    double labelWidth = 70,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
