import 'package:flutter/material.dart';

import 'shimmer_box.dart';

class ShimmerCard extends StatelessWidget {
  const ShimmerCard({
    this.height = 96,
    this.margin = const EdgeInsets.only(bottom: 14),
    super.key,
  });

  final double height;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      margin: margin,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .08),
        ),
      ),
      child: const Row(
        children: [
          ShimmerBox(width: 48, height: 48, radius: 14),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShimmerBox(width: 130, height: 14, radius: 6),
                SizedBox(height: 10),
                ShimmerBox(width: 200, height: 11, radius: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CoursesShimmer extends StatelessWidget {
  const CoursesShimmer({super.key});
  @override
  Widget build(BuildContext context) =>
      const _PageShimmer(header: true, grid: true);
}

class TasksShimmer extends StatelessWidget {
  const TasksShimmer({super.key});
  @override
  Widget build(BuildContext context) => const _PageShimmer(cards: 5);
}

class ExamsShimmer extends StatelessWidget {
  const ExamsShimmer({super.key});
  @override
  Widget build(BuildContext context) => const _PageShimmer(cards: 5);
}

class ProfileShimmer extends StatelessWidget {
  const ProfileShimmer({super.key});
  @override
  Widget build(BuildContext context) =>
      const _PageShimmer(avatar: true, cards: 3);
}

class AcademicInformationShimmer extends StatelessWidget {
  const AcademicInformationShimmer({super.key});
  @override
  Widget build(BuildContext context) => const _PageShimmer(cards: 6);
}

class ScheduleShimmer extends StatelessWidget {
  const ScheduleShimmer({super.key});
  @override
  Widget build(BuildContext context) =>
      const _PageShimmer(calendar: true, cards: 3);
}

class HomeShimmer extends StatelessWidget {
  const HomeShimmer({super.key});
  @override
  Widget build(BuildContext context) => const _HomePageShimmer();
}

class _HomePageShimmer extends StatelessWidget {
  const _HomePageShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ShimmerBox(width: 150, height: 18, radius: 6),
        const SizedBox(height: 12),
        const ShimmerBox(width: double.infinity, height: 165, radius: 18),
        const SizedBox(height: 20),
        const ShimmerBox(width: 170, height: 18, radius: 6),
        const SizedBox(height: 12),
        ...List.generate(
          3,
          (_) => const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: ShimmerBox(width: double.infinity, height: 106, radius: 18),
          ),
        ),
      ],
    );
  }
}

class _PageShimmer extends StatelessWidget {
  const _PageShimmer({
    this.header = false,
    this.avatar = false,
    this.calendar = false,
    this.grid = false,
    this.cards = 4,
  });

  final bool header;
  final bool avatar;
  final bool calendar;
  final bool grid;
  final int cards;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (avatar)
            const Center(child: ShimmerBox(width: 110, height: 110, radius: 55))
          else if (header) ...[
            const ShimmerBox(width: 180, height: 30, radius: 8),
            const SizedBox(height: 10),
            const ShimmerBox(width: 230, height: 14, radius: 6),
          ],
          if (calendar) ...[
            const SizedBox(height: 22),
            const ShimmerBox(width: double.infinity, height: 180, radius: 20),
          ],
          if (grid)
            Padding(
              padding: const EdgeInsets.only(top: 20),
              child: Wrap(
                spacing: 14,
                runSpacing: 14,
                children: List.generate(
                  6,
                  (_) => const SizedBox(
                    width: 150,
                    child: ShimmerCard(height: 150, margin: EdgeInsets.zero),
                  ),
                ),
              ),
            )
          else ...[
            SizedBox(height: header || avatar || calendar ? 22 : 0),
            ...List.generate(cards, (_) => const ShimmerCard()),
          ],
        ],
      ),
    );
  }
}
