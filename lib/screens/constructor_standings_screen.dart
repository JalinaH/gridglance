import 'package:flutter/material.dart';
import '../data/api_service.dart';
import '../models/constructor_standing.dart';
import '../screens/team_detail_screen.dart';
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

class ConstructorStandingsScreen extends StatefulWidget {
  final List<ConstructorStanding> standings;
  final String season;
  final DateTime? lastUpdated;
  final bool isFromCache;

  const ConstructorStandingsScreen({
    super.key,
    required this.standings,
    required this.season,
    this.lastUpdated,
    this.isFromCache = false,
  });

  @override
  State<ConstructorStandingsScreen> createState() =>
      _ConstructorStandingsScreenState();
}

class _ConstructorStandingsScreenState
    extends State<ConstructorStandingsScreen> {
  final TextEditingController _controller = TextEditingController();
  final GlobalKey _shareCardKey = GlobalKey();
  String _query = '';
  bool _sharingCard = false;
  late List<ConstructorStanding> _standings = widget.standings;
  DateTime? _lastUpdated;
  bool _isFromCache = false;
  String? _favoriteTeamId;

  @override
  void initState() {
    super.initState();
    _lastUpdated = widget.lastUpdated;
    _isFromCache = widget.isFromCache;
    _loadFavoriteTeam();
  }

  Future<void> _loadFavoriteTeam() async {
    final id = await UserPreferences.getFavoriteTeamId();
    if (mounted) setState(() => _favoriteTeamId = id);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final snapshot = await ApiService().getConstructorStandingsSnapshot(
      season: widget.season,
    );
    if (!mounted) return;
    setState(() {
      _standings = snapshot.data;
      _lastUpdated = snapshot.lastUpdated;
      _isFromCache = snapshot.isFromCache;
    });
  }

  List<ConstructorStanding> get _filteredStandings {
    if (_query.isEmpty) {
      return _standings;
    }
    final query = _query.toLowerCase();
    return _standings.where((team) {
      return team.teamName.toLowerCase().contains(query) ||
          team.position.toLowerCase().contains(query) ||
          team.points.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _toggleFavoriteTeam(ConstructorStanding team) async {
    final isFav = _favoriteTeamId == team.constructorId;
    final newId = isFav ? null : team.constructorId;
    await UserPreferences.setFavoriteTeamId(newId);
    if (!mounted) return;
    setState(() => _favoriteTeamId = newId);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isFav
              ? '${team.teamName} removed from favorites'
              : '${team.teamName} set as favorite',
        ),
      ),
    );
  }

  List<ConstructorStanding> get _shareStandings {
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
            Text("Team Standings"),
            Text(
              "Season ${widget.season}",
              style: TextStyle(color: colors.textMuted, fontSize: 12),
            ),
          ],
        ),
        actions: [
          BounceTap(
            child: IconButton(
              onPressed: _sharingCard ? null : _shareStandingsCard,
              icon: _sharingCard
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.f1RedBright,
                      ),
                    )
                  : Icon(Icons.ios_share, size: 20),
              tooltip: 'Share standings',
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Off-screen share card (painted but invisible; needed for capture)
          Positioned(
            left: -9999,
            top: -9999,
            child: RepaintBoundary(
              key: _shareCardKey,
              child: SizedBox(
                width: 400,
                child: ConstructorStandingsShareCard(
                  standings: _shareStandings,
                  season: widget.season,
                ),
              ),
            ),
          ),
          _standings.isEmpty
              ? Center(
                  child: EmptyState(
                    message: "No team standings available.",
                    type: EmptyStateType.standings,
                  ),
                )
              : Column(
                  children: [
                    if (_lastUpdated != null)
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _isFromCache
                                ? '${formatLastUpdatedAgo(_lastUpdated!)} • Offline cache'
                                : formatLastUpdatedAgo(_lastUpdated!),
                            style: TextStyle(
                              color: colors.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, 10),
                      child: CompactSearchField(
                        controller: _controller,
                        hintText: 'Search teams',
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
                                "No matching teams.",
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
                                  final team = standings[index];
                                  final isFav =
                                      _favoriteTeamId == team.constructorId;
                                  return Reveal(
                                    index: index,
                                    child: SwipeActionWrapper(
                                      icon: isFav
                                          ? Icons.star
                                          : Icons.star_border,
                                      label: isFav ? 'Unfavorite' : 'Favorite',
                                      backgroundColor: isFav
                                          ? Colors.orange
                                          : null,
                                      onSwipe: () => _toggleFavoriteTeam(team),
                                      child: ConstructorStandingCard(
                                        team: team,
                                        onTap: () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => TeamDetailScreen(
                                                team: team,
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
        fileName: 'team-standings-${widget.season}',
        text: 'F1 team standings (${widget.season}) via GridGlance',
        subject: 'F1 Team Standings',
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
