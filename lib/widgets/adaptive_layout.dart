import 'package:flutter/material.dart';

/// Breakpoint at which the app switches to tablet/wide layout.
const double kTabletBreakpoint = 720.0;

/// Returns true when the available width is wide enough for a two-column layout.
bool isWideScreen(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kTabletBreakpoint;

/// A widget that picks between a narrow (phone) and wide (tablet) builder
/// based on available width using [LayoutBuilder].
class AdaptiveLayout extends StatelessWidget {
  final Widget Function(BuildContext context) narrow;
  final Widget Function(BuildContext context, double width) wide;

  const AdaptiveLayout({super.key, required this.narrow, required this.wide});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= kTabletBreakpoint) {
          return wide(context, constraints.maxWidth);
        }
        return narrow(context);
      },
    );
  }
}

/// Wraps a scrollable list and lays out items in a two-column grid on wide
/// screens, falling back to a single-column [ListView.builder] on phones.
class AdaptiveCardList extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext context, int index) itemBuilder;
  final EdgeInsetsGeometry? padding;
  final ScrollPhysics? physics;
  final Widget? header;

  const AdaptiveCardList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    this.physics,
    this.header,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= kTabletBreakpoint) {
          return _buildWideList(context, constraints.maxWidth);
        }
        return _buildNarrowList(context);
      },
    );
  }

  Widget _buildNarrowList(BuildContext context) {
    final headerOffset = header != null ? 1 : 0;
    return ListView.builder(
      padding: padding,
      physics: physics,
      itemCount: itemCount + headerOffset,
      itemBuilder: (context, index) {
        if (header != null && index == 0) return header!;
        return itemBuilder(context, index - headerOffset);
      },
    );
  }

  Widget _buildWideList(BuildContext context, double width) {
    // Build rows of 2 items each.
    final rowCount = (itemCount + 1) ~/ 2;
    final headerOffset = header != null ? 1 : 0;
    return ListView.builder(
      padding: padding,
      physics: physics,
      itemCount: rowCount + headerOffset,
      itemBuilder: (context, index) {
        if (header != null && index == 0) return header!;
        final rowIndex = index - headerOffset;
        final firstIndex = rowIndex * 2;
        final secondIndex = firstIndex + 1;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: itemBuilder(context, firstIndex)),
            if (secondIndex < itemCount)
              Expanded(child: itemBuilder(context, secondIndex))
            else
              Expanded(child: SizedBox.shrink()),
          ],
        );
      },
    );
  }
}
