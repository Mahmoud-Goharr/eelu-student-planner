import 'package:flutter/material.dart';
import '../../../../core/utils/egypt_time.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/time_formatter.dart';
import '../../data/models/lecture_model.dart';

class UpcomingLectureCard extends StatelessWidget {
  const UpcomingLectureCard({super.key, required this.lecture, this.onTap});

  final LectureModel lecture;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: colors.primaryContainer,
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppLocalizations.of(context).upcomingLectures,
                style: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(color: colors.onPrimaryContainer),
              ),
              const SizedBox(height: 8),
              Text(
                lecture.courseName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                lecture.title,
                style: TextStyle(color: colors.onPrimaryContainer),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 8,
                children: [
                  _Detail(icon: Icons.person_outline, text: lecture.instructor),
                  _Detail(
                    icon: Icons.schedule,
                    text: '${TimeFormatter.format(lecture.startTime, arabic: Localizations.localeOf(context).languageCode == 'ar')} - ${TimeFormatter.format(lecture.endTime, arabic: Localizations.localeOf(context).languageCode == 'ar')}',
                  ),
                  _Detail(
                    icon: Icons.location_on_outlined,
                    text: lecture.location,
                  ),
                  _Detail(
                    icon: Icons.calendar_today_outlined,
                    text: _formatLectureDate(context, lecture.date),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatLectureDate(BuildContext context, DateTime date) {
    final l10n = AppLocalizations.of(context);
    final now = EgyptTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final lectureDay = DateTime(date.year, date.month, date.day);

    if (lectureDay.difference(today).inDays == 1) {
      return l10n.tomorrow;
    }

    return MaterialLocalizations.of(context).formatMediumDate(date);
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [Icon(icon, size: 16), const SizedBox(width: 4), Text(text)],
  );
}
