import 'package:flutter/material.dart';
import '../../../../core/utils/egypt_time.dart';

import '../../../../core/utils/time_formatter.dart';
import '../../../../core/utils/chronological_sort.dart';

import '../../../schedule/data/models/schedule_model.dart';
import '../../../schedule/data/models/schedule_pause_model.dart';
import '../../../../core/localization/app_localizations.dart';

class TodayScheduleCard extends StatelessWidget {
  const TodayScheduleCard({
    required this.primaryColor,
    required this.textColor,
    required this.secondaryText,
    required this.schedule,
    required this.pauses,
    required this.loading,
    required this.hasError,
    super.key,
  });

  final Color primaryColor;
  final Color textColor;
  final Color secondaryText;
  final List<ScheduleModel> schedule;
  final List<SchedulePauseModel> pauses;
  final bool loading;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);
    final today = EgyptTime.now();
    final isPausedToday = pauses.any((pause) => pause.appliesTo(today));
    final todayEntries = isPausedToday
        ? <ScheduleModel>[]
        : schedule
        .where(
          (item) => item.day == _dayName(today.weekday),
        )
        .toList()
      ..sort((a, b) => compareTimeStrings(a.startTime, b.startTime));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101D30) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: .05)
              : Colors.grey.withValues(alpha: .10),
        ),
        boxShadow: [
          if (!isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: .04),
              blurRadius: 15,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: primaryColor,
                  size: 25,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      l10n.todaySchedule,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      MaterialLocalizations.of(context)
                          .formatMediumDate(today),
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: secondaryText,
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: CircularProgressIndicator(),
            )
          else if (hasError)
            _EmptyToday(
              primaryColor: primaryColor,
              secondaryText: secondaryText,
              label: l10n.failedToLoadSchedule,
            )
          else if (todayEntries.isEmpty)
            _EmptyToday(
              primaryColor: primaryColor,
              secondaryText: secondaryText,
              label: l10n.noLecturesToday,
            )
          else
            for (var index = 0; index < todayEntries.length; index++)
              _LectureItem(
                lecture: todayEntries[index],
                primaryColor: primaryColor,
                secondaryText: secondaryText,
                isFirst: index == 0,
              ),
        ],
      ),
    );
  }
}

class _LectureItem extends StatelessWidget {
  const _LectureItem({
    required this.lecture,
    required this.primaryColor,
    required this.secondaryText,
    required this.isFirst,
  });

  final ScheduleModel lecture;
  final Color primaryColor;
  final Color secondaryText;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final ended = _isEnded(lecture.endTime);
    final l10n = AppLocalizations.of(context);

    return SizedBox(
      height: 82,
      child: Row(
        children: [
          SizedBox(
            width: 58,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatTime(context, lecture.startTime),
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  _formatTime(context, lecture.endTime),
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: isFirst
                        ? primaryColor
                        : Colors.blueGrey.shade300,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isFirst)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      color: Colors.blueGrey.withValues(alpha: .25),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ended) ...[
                  Text(
                    l10n.lectureEnded,
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                Text(
                  lecture.courseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  lecture.instructor.isEmpty
                      ? AppLocalizations.of(context).notSet
                      : lecture.instructor,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (!ended)
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 17,
              color: secondaryText,
            ),
        ],
      ),
    );
  }

  bool _isEnded(String value) {
    final parts = value.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    final now = EgyptTime.now();
    return now.hour * 60 + now.minute >= hour * 60 + minute;
  }

  String _formatTime(BuildContext context, String value) =>
      TimeFormatter.format(value, arabic: Localizations.localeOf(context).languageCode == 'ar');
}

class _EmptyToday extends StatelessWidget {
  const _EmptyToday({
    required this.primaryColor,
    required this.secondaryText,
    required this.label,
  });

  final Color primaryColor;
  final Color secondaryText;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Column(
        children: [
          Icon(
            Icons.event_available_rounded,
            size: 38,
            color: primaryColor.withValues(alpha: .55),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: secondaryText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _dayName(int weekday) {
  const days = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  return days[weekday - 1];
}
