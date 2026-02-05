import 'package:flutter/material.dart';
import '../models/race.dart';
import '../theme/app_theme.dart';
import '../widgets/compact_search_field.dart';
import '../widgets/f1_scaffold.dart';
import '../widgets/reveal.dart';
import '../widgets/season_cards.dart';

enum RaceFilter { all, upcoming, completed }

class RaceScheduleScreen extends StatefulWidget {
  final List<Race> races;
  final String season;

  const RaceScheduleScreen({
    super.key,
    required this.races,
    required this.season,
  });

  @override
  State<RaceScheduleScreen> createState() => _RaceScheduleScreenState();
}

class _RaceScheduleScreenState extends State<RaceScheduleScreen> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';
  RaceFilter _filter = RaceFilter.all;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Race> get _filteredRaces {
    var races = widget.races;
    if (_filter != RaceFilter.all) {
      races = races.where((race) {
        final isUpcoming = _isUpcoming(race);
        return _filter == RaceFilter.upcoming ? isUpcoming : !isUpcoming;
      }).toList();
    }
    if (_query.isEmpty) {
      return races;
    }
    final query = _query.toLowerCase();
    return races.where((race) {
      return race.raceName.toLowerCase().contains(query) ||
          race.circuitName.toLowerCase().contains(query) ||
          race.location.toLowerCase().contains(query) ||
          race.round.toLowerCase().contains(query) ||
          race.date.toLowerCase().contains(query);
    }).toList();
  }

  bool _isUpcoming(Race race) {
    final start = race.startDateTime;
    if (start == null) {
      return true;
    }
    final now = DateTime.now();
    if (race.time == null || race.time!.isEmpty) {
      final endOfDay = DateTime(start.year, start.month, start.day, 23, 59, 59);
      return now.isBefore(endOfDay);
    }
    return now.isBefore(start);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final races = _filteredRaces;
    return F1Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Race Schedule"),
            Text(
              "Season ${widget.season}",
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
      body: widget.races.isEmpty
          ? Center(
              child: Text(
                "No race schedule available.",
                style: TextStyle(color: colors.textMuted),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: CompactSearchField(
                    controller: _controller,
                    hintText: 'Search races or circuits',
                    onChanged: (value) {
                      setState(() {
                        _query = value.trim();
                      });
                    },
                    onClear: _query.isEmpty
                        ? null
                        : () {
                            _controller.clear();
                            setState(() {
                              _query = '';
                            });
                          },
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      _buildFilterChip(
                        label: 'All',
                        selected: _filter == RaceFilter.all,
                        onTap: () => _setFilter(RaceFilter.all),
                      ),
                      SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Upcoming',
                        selected: _filter == RaceFilter.upcoming,
                        onTap: () => _setFilter(RaceFilter.upcoming),
                      ),
                      SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Completed',
                        selected: _filter == RaceFilter.completed,
                        onTap: () => _setFilter(RaceFilter.completed),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: races.isEmpty
                      ? Center(
                          child: Text(
                            "No matching races.",
                            style: TextStyle(color: colors.textMuted),
                          ),
                        )
                      : ListView.builder(
                          padding: EdgeInsets.only(bottom: 24),
                          physics: BouncingScrollPhysics(),
                          itemCount: races.length,
                          itemBuilder: (context, index) {
                            return Reveal(
                              index: index,
                              child: RaceCard(race: races[index]),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  void _setFilter(RaceFilter filter) {
    if (_filter == filter) {
      return;
    }
    setState(() {
      _filter = filter;
    });
  }

  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final colors = AppColors.of(context);
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : colors.textMuted,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
      selected: selected,
      selectedColor: colors.f1Red,
      backgroundColor: colors.surfaceAlt,
      onSelected: (_) => onTap(),
      shape: StadiumBorder(
        side: BorderSide(color: colors.border),
      ),
    );
  }
}
