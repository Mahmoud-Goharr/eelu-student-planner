import 'package:flutter/material.dart';

import '../../../../core/utils/time_formatter.dart';
import '../../../../core/utils/chronological_sort.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_error_localizer.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/widgets/shimmer/shimmer_card.dart';
import '../../data/datasources/schedule_remote_data_source.dart';
import '../../data/models/schedule_model.dart';
import '../../data/models/schedule_pause_model.dart';
import '../../data/repositories/schedule_repository_impl.dart';
import '../viewmodels/schedule_cubit.dart';
import '../viewmodels/schedule_state.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ScheduleCubit(
        ScheduleRepositoryImpl(ScheduleRemoteDataSource(SupabaseService())),
      )..watchSchedule(),
      child: const _ScheduleContent(),
    );
  }
}

class _ScheduleContent extends StatefulWidget {
  const _ScheduleContent();

  @override
  State<_ScheduleContent> createState() => _ScheduleContentState();
}

class _ScheduleContentState extends State<_ScheduleContent> {
  DateTime selectedDate = DateTime.now();
  DateTime displayedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ScheduleCubit, ScheduleState>(
      listener: (context, state) {
        if (state.errorMessage == 'offline') {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context).offlineUsingCachedData),
              ),
            );
        }
      },
      builder: (context, state) {
        if (state.status == ScheduleStatus.loading ||
            state.status == ScheduleStatus.initial) {
          return const ScheduleShimmer();
        }

        if (state.status == ScheduleStatus.failure) {
          return _ScheduleError(
            message: AppErrorLocalizer.message(
              context,
              state.errorMessage,
              fallback: AppLocalizations.of(context).failedToLoadSchedule,
            ),
            onRetry: () => context.read<ScheduleCubit>().getSchedule(),
          );
        }

        return _ScheduleLoaded(
          schedule: state.schedule,
          pauses: state.pauses,
          selectedDate: selectedDate,
          displayedMonth: displayedMonth,
          onPreviousMonth: () {
            setState(() {
              displayedMonth = DateTime(
                displayedMonth.year,
                displayedMonth.month - 1,
              );
            });
          },
          onNextMonth: () {
            setState(() {
              displayedMonth = DateTime(
                displayedMonth.year,
                displayedMonth.month + 1,
              );
            });
          },
          onDateSelected: (date) {
            setState(() {
              selectedDate = date;
            });
          },
        );
      },
    );
  }
}

class _ScheduleLoaded extends StatelessWidget {
  const _ScheduleLoaded({
    required this.schedule,
    required this.pauses,
    required this.selectedDate,
    required this.displayedMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDateSelected,
  });

  final List<ScheduleModel> schedule;
  final List<SchedulePauseModel> pauses;
  final DateTime selectedDate;
  final DateTime displayedMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onSurface;
    final secondaryText = textColor.withValues(alpha: .6);
    final selectedLectures = pauses.any((pause) => pause.appliesTo(selectedDate))
        ? <ScheduleModel>[]
        : schedule
            .where((item) =>
                !_isBeforeScheduleStart(selectedDate, item.scheduleStartDate) &&
                item.day == _dayName(selectedDate.weekday))
        .toList()
      ..sort((a, b) => compareTimeStrings(a.startTime, b.startTime));

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        AppLocalizations.of(context).calendarTitle,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        AppLocalizations.of(context).calendarSubtitle,
                        style: TextStyle(color: secondaryText, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(
                    Icons.calendar_month_rounded,
                    color: primary,
                    size: 25,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            _MonthHeader(
              month: displayedMonth,
              onPrevious: onPreviousMonth,
              onNext: onNextMonth,
            ),
            const SizedBox(height: 14),
            _CalendarCard(
              month: displayedMonth,
              selectedDate: selectedDate,
              primary: primary,
              schedule: schedule,
              pauses: pauses,
              onDateSelected: onDateSelected,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    MaterialLocalizations.of(context)
                        .formatMediumDate(selectedDate),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${selectedLectures.length} ${AppLocalizations.of(context).classesCount}',
                    style: TextStyle(
                      color: primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (selectedLectures.isEmpty)
              _EmptyDay(primary: primary)
            else
              ...selectedLectures.map(
                (lecture) => _LectureCard(lecture: lecture, primary: primary),
              ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleError extends StatelessWidget {
  const _ScheduleError({required this.message, required this.onRetry});

  final String? message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.failedToLoadSchedule,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                AppErrorLocalizer.message(
                  context,
                  message,
                  fallback: l10n.failedToLoadSchedule,
                ),
                style: TextStyle(color: colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 18),
            FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _MonthButton(icon: Icons.chevron_left_rounded, onTap: onPrevious),
          Expanded(
            child: Text(
              MaterialLocalizations.of(context).formatMonthYear(month),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: theme.colorScheme.onSurface,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _MonthButton(icon: Icons.chevron_right_rounded, onTap: onNext),
        ],
      ),
    );
  }
}

class _MonthButton extends StatelessWidget {
  const _MonthButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: primary),
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.month,
    required this.selectedDate,
    required this.primary,
    required this.schedule,
    required this.pauses,
    required this.onDateSelected,
  });

  final DateTime month;
  final DateTime selectedDate;
  final Color primary;
  final List<ScheduleModel> schedule;
  final List<SchedulePauseModel> pauses;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final firstWeekday = firstDay.weekday;
    final totalCells = ((firstWeekday - 1 + daysInMonth) / 7).ceil() * 7;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            children: List.generate(7, (index) {
              final weekdays = MaterialLocalizations.of(context).narrowWeekdays;
              final day = weekdays[(index + 1) % 7];
              return Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: totalCells,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1,
            ),
            itemBuilder: (context, index) {
              final dayNumber = index - (firstWeekday - 1) + 1;
              if (dayNumber < 1 || dayNumber > daysInMonth) {
                return const SizedBox();
              }

              final date = DateTime(month.year, month.month, dayNumber);
              final isSelected = _sameDate(date, selectedDate);
              final isPaused = pauses.any((pause) => pause.appliesTo(date));
              final hasLectures = !isPaused && schedule.any(
                (item) =>
                    !_isBeforeScheduleStart(date, item.scheduleStartDate) &&
                    item.day == _dayName(date.weekday),
              );

              return GestureDetector(
                onTap: () => onDateSelected(date),
                child: Center(
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isSelected ? primary : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '$dayNumber',
                          style: TextStyle(
                            color: isSelected ? Colors.white : textColor,
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                        if (hasLectures)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isSelected ? Colors.white : primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _LectureCard extends StatelessWidget {
  const _LectureCard({required this.lecture, required this.primary});

  final ScheduleModel lecture;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final secondary = theme.colorScheme.onSurface.withValues(alpha: .6);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: .08)),
      ),
      child: Row(
        children: [
          _CourseScheduleImage(
            imageUrl: lecture.imageUrl,
            primary: primary,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lecture.courseName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  lecture.instructor,
                  style: TextStyle(color: secondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _formatTime(context, lecture.startTime),
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _formatTime(context, lecture.endTime),
                style: TextStyle(color: secondary, fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay({required this.primary});

  final Color primary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 30),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available_rounded,
            size: 40,
            color: primary.withValues(alpha: .5),
          ),
          const SizedBox(height: 10),
          Text(
            AppLocalizations.of(context).noLecturesSelectedDay,
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: .6),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

String _dayName(int weekday) {
  const days = [
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

String _formatTime(BuildContext context, String value) =>
    TimeFormatter.format(value, arabic: Localizations.localeOf(context).languageCode == 'ar');

class _CourseScheduleImage extends StatelessWidget {
  const _CourseScheduleImage({
    required this.imageUrl,
    required this.primary,
  });

  final String imageUrl;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: SizedBox(
        width: 52,
        height: 52,
        child: imageUrl.trim().isEmpty
            ? Container(
                color: primary.withValues(alpha: .10),
                child: Icon(Icons.menu_book_rounded, color: primary),
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: primary.withValues(alpha: .10),
                  child: Icon(Icons.menu_book_rounded, color: primary),
                ),
              ),
      ),
    );
  }
}

bool _isBeforeScheduleStart(DateTime date, DateTime start) {
  final d = DateTime(date.year, date.month, date.day);
  final s = DateTime(start.year, start.month, start.day);
  return d.isBefore(s);
}

bool _sameDate(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}
