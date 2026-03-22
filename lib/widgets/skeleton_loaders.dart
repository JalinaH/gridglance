import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_theme.dart';
import 'season_cards.dart';

// ---------------------------------------------------------------------------
// Primitives
// ---------------------------------------------------------------------------

class _ShimmerWrap extends StatelessWidget {
  final Widget child;

  const _ShimmerWrap({required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? colors.surfaceAlt : colors.border.withValues(alpha: 0.3),
      highlightColor: isDark ? colors.surface : colors.surfaceAlt,
      child: child,
    );
  }
}

class ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class ShimmerCircle extends StatelessWidget {
  final double size;

  const ShimmerCircle({super.key, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Card Skeletons
// ---------------------------------------------------------------------------

/// Matches [DriverStandingCard] / [ConstructorStandingCard] layout.
class StandingCardSkeleton extends StatelessWidget {
  const StandingCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: _ShimmerWrap(
        child: Row(
          children: [
            ShimmerBox(width: 28, height: 20),
            SizedBox(width: 12),
            ShimmerCircle(size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(width: 120, height: 14),
                  SizedBox(height: 6),
                  ShimmerBox(width: 80, height: 12),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ShimmerBox(width: 60, height: 22, radius: 20),
                SizedBox(height: 6),
                ShimmerBox(width: 40, height: 22, radius: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Matches [RaceCard] layout.
class RaceCardSkeleton extends StatelessWidget {
  const RaceCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: _ShimmerWrap(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ShimmerBox(width: 64, height: 22, radius: 20),
                SizedBox(width: 8),
                Expanded(child: ShimmerBox(width: 100, height: 12)),
              ],
            ),
            SizedBox(height: 10),
            ShimmerBox(width: 180, height: 16),
            SizedBox(height: 4),
            ShimmerBox(width: 140, height: 12),
          ],
        ),
      ),
    );
  }
}

/// Matches the home screen _buildSummaryCard layout.
class SummaryCardSkeleton extends StatelessWidget {
  final int contentLines;

  const SummaryCardSkeleton({super.key, this.contentLines = 2});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: _ShimmerWrap(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: ShimmerBox(width: 130, height: 16)),
                ShimmerBox(width: 20, height: 20, radius: 4),
              ],
            ),
            SizedBox(height: 4),
            ShimmerBox(width: 100, height: 12),
            SizedBox(height: 10),
            for (int i = 0; i < contentLines; i++) ...[
              ShimmerBox(
                width: i == contentLines - 1 ? 160 : double.infinity,
                height: 12,
              ),
              if (i < contentLines - 1) SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// Full home screen skeleton — 7 summary cards with staggered reveal.
class HomeScreenSkeleton extends StatelessWidget {
  const HomeScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(bottom: 24),
      physics: NeverScrollableScrollPhysics(),
      children: [
        SizedBox(height: 12),
        SummaryCardSkeleton(contentLines: 3), // Favorites
        SummaryCardSkeleton(contentLines: 2), // Next Race
        SummaryCardSkeleton(contentLines: 1), // Last Race Results
        SummaryCardSkeleton(contentLines: 3), // Driver Standings
        SummaryCardSkeleton(contentLines: 3), // Team Standings
        SummaryCardSkeleton(contentLines: 2), // Upcoming Races
        SummaryCardSkeleton(contentLines: 2), // Compare Mode
      ],
    );
  }
}

/// Chart area skeleton for points-per-race cards.
class ChartSkeleton extends StatelessWidget {
  const ChartSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrap(
      child: Column(
        children: [
          Row(
            children: [
              ShimmerBox(width: 60, height: 24, radius: 8),
              SizedBox(width: 8),
              ShimmerBox(width: 60, height: 24, radius: 8),
              SizedBox(width: 8),
              ShimmerBox(width: 60, height: 24, radius: 8),
            ],
          ),
          SizedBox(height: 12),
          ShimmerBox(width: double.infinity, height: 120, radius: 12),
        ],
      ),
    );
  }
}

/// Result row skeleton for race results lists.
class ResultRowSkeleton extends StatelessWidget {
  const ResultRowSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: _ShimmerWrap(
        child: Row(
          children: [
            ShimmerBox(width: 22, height: 16),
            SizedBox(width: 12),
            ShimmerCircle(size: 24),
            SizedBox(width: 12),
            Expanded(child: ShimmerBox(width: 100, height: 14)),
            ShimmerBox(width: 50, height: 14),
          ],
        ),
      ),
    );
  }
}

/// Race results loading skeleton — header + result rows.
class RaceResultsSkeleton extends StatelessWidget {
  final int rowCount;

  const RaceResultsSkeleton({super.key, this.rowCount = 8});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        RaceCardSkeleton(),
        SizedBox(height: 4),
        GlassCard(
          child: Column(
            children: List.generate(
              rowCount,
              (_) => ResultRowSkeleton(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Weather card content skeleton.
class WeatherSkeleton extends StatelessWidget {
  const WeatherSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return _ShimmerWrap(
      child: Row(
        children: [
          ShimmerBox(width: 32, height: 32, radius: 8),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 100, height: 14),
                SizedBox(height: 6),
                ShimmerBox(width: 140, height: 12),
              ],
            ),
          ),
          ShimmerBox(width: 50, height: 20, radius: 8),
        ],
      ),
    );
  }
}

/// Compare mode bootstrap skeleton.
class CompareModeSkeleton extends StatelessWidget {
  const CompareModeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.only(bottom: 24),
      physics: NeverScrollableScrollPhysics(),
      children: [
        // Mode card
        GlassCard(
          child: _ShimmerWrap(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 100, height: 14),
                SizedBox(height: 10),
                Row(
                  children: [
                    ShimmerBox(width: 80, height: 32, radius: 20),
                    SizedBox(width: 8),
                    ShimmerBox(width: 80, height: 32, radius: 20),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Picker card
        GlassCard(
          child: _ShimmerWrap(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 120, height: 14),
                SizedBox(height: 10),
                ShimmerBox(width: double.infinity, height: 40, radius: 12),
                SizedBox(height: 8),
                ShimmerBox(width: double.infinity, height: 40, radius: 12),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Standings list skeleton — multiple standing card skeletons.
class StandingsListSkeleton extends StatelessWidget {
  final int count;

  const StandingsListSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (_) => StandingCardSkeleton()),
    );
  }
}
