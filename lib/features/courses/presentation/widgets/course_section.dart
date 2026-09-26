import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/course_details.dart';

class CourseSection extends StatelessWidget {
  const CourseSection({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
    this.isLectureSection = false,
  });

  final String title;
  final IconData icon;
  final List<CourseDetailsItem> items;
  final bool isLectureSection;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isLectureSection)
              _GroupedLectures(items: items, primary: theme.colorScheme.primary)
            else
              ...items.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(icon, size: 19),
                  title: Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    item.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: _CompletionBadge(isCompleted: item.isCompleted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


class _GroupedLectures extends StatelessWidget {
  const _GroupedLectures({required this.items, required this.primary});

  final List<CourseDetailsItem> items;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final groups = <DateTime, List<CourseDetailsItem>>{};
    for (final item in items) {
      if (item.date == null) continue;
      final key = DateTime(item.date!.year, item.date!.month, item.date!.day);
      groups.putIfAbsent(key, () => []).add(item);
    }

    final ordered = groups.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      children: [
        for (final entry in ordered) ...[
          _DayHeader(date: entry.key),
          for (final item in entry.value)
            _LectureItem(item: item, primary: primary),
        ],
      ],
    );
  }
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).languageCode;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    const arabicWeekdays = <int, String>{
      DateTime.saturday: 'السبت',
      DateTime.sunday: 'الأحد',
      DateTime.monday: 'الاثنين',
      DateTime.tuesday: 'الثلاثاء',
      DateTime.wednesday: 'الأربعاء',
      DateTime.thursday: 'الخميس',
      DateTime.friday: 'الجمعة',
    };
    final weekday = isArabic
        ? (arabicWeekdays[date.weekday] ?? '')
        : MaterialLocalizations.of(context).formatFullDate(date).split(',').first;
    final formattedDate = MaterialLocalizations.of(context).formatMediumDate(date);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 5, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today_outlined, size: 17, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$weekday • $formattedDate',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionBadge extends StatelessWidget {
  const _CompletionBadge({required this.isCompleted});

  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final theme = Theme.of(context);
    final color = isCompleted
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompleted
                ? Icons.check_circle_outline
                : Icons.radio_button_unchecked,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            isCompleted
                ? (isArabic ? 'مكتمل' : 'Completed')
                : (isArabic ? 'غير مكتمل' : 'Not completed'),
            style: theme.textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LectureItem extends StatelessWidget {
  const _LectureItem({required this.item, required this.primary});

  final CourseDetailsItem item;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    final parts = item.subtitle.split(' • ');
    final time = parts.isNotEmpty ? parts.first : '';
    final instructor = parts.length > 1 ? parts[1] : '';
    final mode = parts.length > 2 ? parts[2] : '';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.menu_book_rounded, color: primary, size: 21),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (time.isNotEmpty)
                  _Line(icon: Icons.schedule_outlined, text: time),
                if (instructor.isNotEmpty)
                  _Line(icon: Icons.person_outline, text: instructor),
                if (mode.isNotEmpty)
                  _Line(
                    icon: Icons.cast_connected_outlined,
                    text: mode == 'online' ? l10n.online : mode == 'offline' ? l10n.offline : mode,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
