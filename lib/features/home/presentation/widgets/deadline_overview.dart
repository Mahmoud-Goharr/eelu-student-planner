import 'package:flutter/material.dart';
import '../../../../core/utils/egypt_time.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/shimmer/shimmer_card.dart';
import '../../../deadlines/presentation/screens/all_deadlines_screen.dart';
import '../viewmodels/home_cubit.dart';
import '../models/home_deadline.dart';
import '../viewmodels/home_state.dart';

class DeadlineOverview extends StatelessWidget {
  const DeadlineOverview({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<HomeCubit, HomeState>(
      listener: (context, homeState) {
        if (homeState.errorMessage == 'offline') {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context).offlineUsingCachedData,
                ),
              ),
            );
        }
      },
      builder: (context, homeState) {
        if (homeState.status == HomeStatus.initial ||
            homeState.status == HomeStatus.loading) {
          return const HomeShimmer();
        }

        final deadlines = homeState.deadlines;
        final localizations = AppLocalizations.of(context);
        if (deadlines.isEmpty) {
          return EmptyDeadlines(
            localizations: localizations,
            showAllCaughtUp: homeState.hasDeadlineHistory,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DeadlineCard(
              deadline: deadlines.first,
              heading: localizations.nextDeadline,
              prominent: true,
            ),
            const SizedBox(height: 18),
            Text(
              localizations.upcomingDeadlines,
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            ...deadlines
                .skip(1)
                .take(4)
                .map(
                  (deadline) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DeadlineCard(deadline: deadline),
                  ),
                ),
            if (deadlines.length > 5) ...[
              const SizedBox(height: 2),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AllDeadlinesScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: Text(localizations.viewAll),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class EmptyDeadlines extends StatelessWidget {
  const EmptyDeadlines({
    required this.localizations,
    required this.showAllCaughtUp,
    super.key,
  });

  final AppLocalizations localizations;
  final bool showAllCaughtUp;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.task_alt_rounded,
              size: 38,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 8),
            if (showAllCaughtUp)
              Text(
                localizations.allCaughtUp,
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            const SizedBox(height: 4),
            Text(localizations.noUpcomingDeadlines),
          ],
        ),
      ),
    );
  }
}

class DeadlineCard extends StatelessWidget {
  const DeadlineCard({
    required this.deadline,
    this.heading,
    this.prominent = false,
    super.key,
  });

  final HomeDeadline deadline;
  final String? heading;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final now = EgyptTime.now();
    final deadlineDay = DateTime(
      deadline.when.year,
      deadline.when.month,
      deadline.when.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    final days = deadlineDay.difference(today).inDays;
    final status = deadline.when.isBefore(now)
        ? localizations.overdue
        : days == 0
        ? localizations.today
        : days == 1
        ? localizations.tomorrow
        : '$days ${localizations.daysLeft}';

    final accent = deadline.isExam
        ? Colors.deepOrange
        : theme.colorScheme.primary;
    final surface = theme.colorScheme.surface;

    return Card(
      margin: EdgeInsets.zero,
      color: prominent ? theme.colorScheme.primaryContainer : surface,
      child: Padding(
        padding: EdgeInsets.all(prominent ? 18 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: prominent ? 48 : 42,
                  height: prominent ? 48 : 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .13),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    deadline.isExam
                        ? Icons.assignment_outlined
                        : Icons.task_alt_outlined,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (heading != null)
                        Text(
                          heading!,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      Text(
                        deadline.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        deadline.course,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: .62,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _TypeBadge(
                  label: _typeLabel(context, deadline),
                  color: accent,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _DateTimeTile(
                    icon: Icons.calendar_today_rounded,
                    label: _formatDate(context, deadline.when),
                    color: accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DateTimeTile(
                    icon: Icons.schedule_rounded,
                    label: _formatTime(context, deadline.when),
                    color: accent,
                  ),
                ),
                const SizedBox(width: 10),
                _CountdownBlock(
                  label: status,
                  color: accent,
                  prominent: prominent,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(BuildContext context, HomeDeadline deadline) {
    final l10n = AppLocalizations.of(context);
    if (deadline.isExam) return l10n.exam;
    return switch (deadline.type) {
      'quiz' => l10n.quiz,
      'personal_assignment' => l10n.personalAssignment,
      _ => l10n.assignment,
    };
  }

  String _formatDate(BuildContext context, DateTime date) {
    return MaterialLocalizations.of(context).formatFullDate(date);
  }

  String _formatTime(BuildContext context, DateTime date) {
    return MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(date));
  }
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _DateTimeTile extends StatelessWidget {
  const _DateTimeTile({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .045),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownBlock extends StatelessWidget {
  const _CountdownBlock({
    required this.label,
    required this.color,
    required this.prominent,
  });

  final String label;
  final Color color;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: prominent ? 78 : 70),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          height: 1.15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
