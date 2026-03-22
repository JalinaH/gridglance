import 'package:flutter/material.dart';
import '../data/api_service.dart';
import '../models/driver_standing.dart';
import '../screens/driver_detail_screen.dart';
import '../services/share_card_service.dart';
import '../theme/app_theme.dart';
import '../utils/date_time_format.dart';
import '../widgets/compact_search_field.dart';
import '../widgets/empty_state.dart';
import '../widgets/f1_scaffold.dart';
import '../widgets/adaptive_layout.dart';
import '../widgets/reveal.dart';
import '../widgets/bounce_tap.dart';
import '../widgets/season_cards.dart';
import '../widgets/share_cards.dart';
import '../widgets/swipe_action_wrapper.dart';
import '../services/user_preferences.dart';

class DriverStandingsScreen extends StatefulWidget {
  final List<DriverStanding> standings;
  final String season;
  final DateTime? lastUpdated;
  final bool isFromCache;

  const DriverStandingsScreen({
    super.key,
    required this.standings,
    required this.season,
    this.lastUpdated,
    this.isFromCache = false,
  });

  @override
  State<DriverStandingsScreen> createState() => _DriverStandingsScreenState();
}

class _DriverStandingsScreenState extends State<DriverStandingsScreen> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey _shareCardKey = GlobalKey();
  String _query = '';
  bool _sharingCard = false;
  late List<DriverStanding> _standings = widget.standings;
  DateTime? _lastUpdated;
  bool _isFromCache = false;
  String? _favoriteDriverId;

  @override
  void initState() {
    super.initState();
    _lastUpdated = widget.lastUpdated;
    _isFromCache = widget.isFromCache;
    _loadFavoriteDriver();
  }

  Future<void> _loadFavoriteDriver() async {
    final id = await UserPreferences.getFavoriteDriverId();
    if (mounted) setState(() => _favoriteDriverId = id);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final snapshot = await ApiService().getDriverStandingsSnapshot(
      season: widget.season,
    );
    if (!mounted) return;
    setState(() {
      _standings = snapshot.data;
      _lastUpdated = snapshot.lastUpdated;
      _isFromCache = snapshot.isFromCache;
    });
  }

  List<DriverStanding> get _filteredStandings {
    if (_query.isEmpty) {
      return _standings;
    }
    final query = _query.toLowerCase();
    return _standings.where((driver) {
      final name = '${driver.givenName} ${driver.familyName}'.toLowerCase();
      final team = driver.teamName.toLowerCase();
      return name.contains(query) ||
          team.contains(query) ||
          driver.position.toLowerCase().contains(query) ||
          driver.points.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _toggleFavoriteDriver(DriverStanding driver) async {
    final isFav = _favoriteDriverId == driver.driverId;
    final newId = isFav ? null : driver.driverId;
    await UserPreferences.setFavoriteDriverId(newId);
    if (!mounted) return;
    setState(() => _favoriteDriverId = newId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFav
              ? '${driver.givenName} ${driver.familyName} removed from favorites'
              : '${driver.givenName} ${driver.familyName} set as favorite',
        ),
      ),
    );
  }

  List<DriverStanding> get _shareStandings {
    final filtered = _filteredStandings;
    return filtered.isNotEmpty ? filtered : widget.standings;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final standings = _filteredStandings;
    return F1Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Driver Standings"),
            Text(
              "Season ${widget.season}",
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
      body: _standings.isEmpty
          ? Center(
              child: EmptyState(
                message: "No driver standings available.",
                type: EmptyStateType.standings,
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Shareable standings card',
                          style: TextStyle(
                            color: colors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      BounceTap(
                        child: TextButton.icon(
                          onPressed: _sharingCard ? null : _shareStandingsCard,
                          icon: _sharingCard
                              ? SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colors.f1RedBright,
                                  ),
                                )
                              : Icon(Icons.ios_share, size: 16),
                          label: Text(
                            _sharingCard ? 'Sharing...' : 'Share image',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 2, 16, 8),
                  child: RepaintBoundary(
                    key: _shareCardKey,
                    child: DriverStandingsShareCard(
                      standings: _shareStandings,
                      season: widget.season,
                    ),
                  ),
                ),
                if (_lastUpdated != null)
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _isFromCache
                            ? '${formatLastUpdatedAgo(_lastUpdated!)} • Offline cache'
                            : formatLastUpdatedAgo(_lastUpdated!),
                        style: TextStyle(color: colors.textMuted, fontSize: 11),
                      ),
                    ),
                  ),
                Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 10),
                  child: CompactSearchField(
                    controller: _controller,
                    hintText: 'Search drivers or teams',
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
                Expanded(
                  child: standings.isEmpty
                      ? Center(
                          child: Text(
                            "No matching drivers.",
                            style: TextStyle(color: colors.textMuted),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _refresh,
                          color: colors.f1Red,
                          child: AdaptiveCardList(
                            padding: EdgeInsets.only(bottom: 24),
                            physics: AlwaysScrollableScrollPhysics(
                              parent: BouncingScrollPhysics(),
                            ),
                            itemCount: standings.length,
                            itemBuilder: (context, index) {
                              final driver = standings[index];
                              final isFav =
                                  _favoriteDriverId == driver.driverId;
                              return Reveal(
                                index: index,
                                child: SwipeActionWrapper(
                                  icon: isFav ? Icons.star : Icons.star_border,
                                  label: isFav ? 'Unfavorite' : 'Favorite',
                                  backgroundColor: isFav ? Colors.orange : null,
                                  onSwipe: () => _toggleFavoriteDriver(driver),
                                  child: DriverStandingCard(
                                    driver: driver,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => DriverDetailScreen(
                                            driver: driver,
                                            season: widget.season,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                ),
              ],
            ),
    );
  }

  Future<void> _shareStandingsCard() async {
    if (_shareStandings.isEmpty || _sharingCard) {
      return;
    }
    setState(() {
      _sharingCard = true;
    });
    try {
      await ShareCardService.shareRepaintBoundary(
        repaintBoundaryKey: _shareCardKey,
        devicePixelRatio: View.of(context).devicePixelRatio,
        fileName: 'driver-standings-${widget.season}',
        text: 'F1 driver standings (${widget.season}) via GridGlance',
        subject: 'F1 Driver Standings',
      );
    } on ShareCardException catch (error) {
      _showSnackBar(error.message);
    } catch (_) {
      _showSnackBar('Unable to share standings card right now.');
    } finally {
      if (mounted) {
        setState(() {
          _sharingCard = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
