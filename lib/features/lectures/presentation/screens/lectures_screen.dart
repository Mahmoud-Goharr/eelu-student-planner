import 'package:flutter/material.dart';
import '../../../../core/utils/egypt_time.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/errors/app_error_localizer.dart';
import '../../../../core/services/supabase_service.dart';
import '../../data/datasources/lectures_remote_data_source.dart';
import '../../data/models/lecture_model.dart';
import '../../data/repositories/lectures_repository_impl.dart';
import '../viewmodels/lectures_cubit.dart';
import '../viewmodels/lectures_state.dart';
import '../widgets/lecture_card.dart';
import '../widgets/lecture_skeleton.dart';
import '../widgets/upcoming_lecture_card.dart';

import 'package:go_router/go_router.dart';

class LecturesScreen extends StatelessWidget {
  const LecturesScreen({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => LecturesCubit(
      LecturesRepositoryImpl(LecturesRemoteDataSource(SupabaseService())),
    )..getLectures(),
    child: const _LecturesView(),
  );
}

class _LecturesView extends StatefulWidget {
  const _LecturesView();
  @override
  State<_LecturesView> createState() => _LecturesViewState();
}

class _LecturesViewState extends State<_LecturesView> {
  String _course = 'All';
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(AppLocalizations.of(context).lecturesTitle),
      actions: [
        IconButton(
          onPressed: () => context.read<LecturesCubit>().getLectures(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),

    body: BlocConsumer<LecturesCubit, LecturesState>(
      listener: (context, state) {
        if (state.errorMessage == 'offline') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context).offlineUsingCachedData),
            ),
          );
        } else if (state.status == LecturesStatus.failure) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppErrorLocalizer.message(
                  context,
                  state.errorMessage,
                  fallback: 'Something went wrong',
                ),
              ),
            ),
          );
        }
      },
      builder: (context, state) {
        if (state.status == LecturesStatus.loading ||
            state.status == LecturesStatus.initial) {
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: 5,
            itemBuilder: (context, index) => const LectureSkeleton(),
          );
        }
        final filtered = _course == 'All'
            ? state.lectures
            : state.lectures.where((item) => item.courseId == _course).toList();
        final now = EgyptTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final todayItems = filtered
            .where((item) => _sameDay(item.date, today))
            .toList();
        final upcoming = filtered
            .where(
              (item) =>
                  item.date.isAfter(today) &&
                  item.date.difference(today).inDays <= 7,
            )
            .toList();
        final future = filtered
            .where((item) => item.date.difference(today).inDays > 7)
            .toList();
        final nextLecture =
            filtered
                .where(
                  (item) => item.date.add(_time(item.startTime)).isAfter(now),
                )
                .toList()
              ..sort(
                (a, b) => a.date
                    .add(_time(a.startTime))
                    .compareTo(b.date.add(_time(b.startTime))),
              );
        return RefreshIndicator(
          onRefresh: context.read<LecturesCubit>().getLectures,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
            children: [
              DropdownButtonFormField<String>(
                initialValue: _course,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context).filterByCourse,
                  prefixIcon: const Icon(Icons.filter_list),
                ),
                items: [
                  const DropdownMenuItem<String>(
                    value: 'All',
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        'All',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  ...<String, String>{
                    for (final lecture in state.lectures)
                      lecture.courseId: lecture.courseName,
                  }.entries.map(
                    (entry) => DropdownMenuItem<String>(
                      value: entry.key,
                      child: SizedBox(
                        width: double.infinity,
                        child: Text(
                          entry.value,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
                selectedItemBuilder: (context) => [
                  const SizedBox(
                    width: double.infinity,
                    child: Text(
                      'All',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...<String, String>{
                    for (final lecture in state.lectures)
                      lecture.courseId: lecture.courseName,
                  }.entries.map(
                    (entry) => SizedBox(
                      width: double.infinity,
                      child: Text(
                        entry.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _course = value);
                },
              ),
              const SizedBox(height: 20),
              if (nextLecture.isNotEmpty) ...[
                UpcomingLectureCard(
                  lecture: nextLecture.first,
                  onTap: () => context.pushNamed(
                    'lecture-details',
                    extra: nextLecture.first,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              ..._groupLecturesByDay(
                context,
                [...todayItems, ...upcoming, ...future],
              ),
              if (todayItems.isEmpty && upcoming.isEmpty && future.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(AppLocalizations.of(context).noLectures),
                  ),
                ),
            ],
          ),
        );
      },
    ),
  );
  List<Widget> _groupLecturesByDay(
    BuildContext context,
    List<LectureModel> lectures,
  ) {
    final groups = <DateTime, List<LectureModel>>{};
    for (final lecture in lectures) {
      final day = DateTime(lecture.date.year, lecture.date.month, lecture.date.day);
      groups.putIfAbsent(day, () => []).add(lecture);
    }

    final ordered = groups.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final widgets = <Widget>[];
    for (final entry in ordered) {
      entry.value.sort((a, b) => _time(a.startTime).compareTo(_time(b.startTime)));
      widgets.add(_DayGroupHeader(date: entry.key));
      widgets.addAll(entry.value.map(_card));
    }
    return widgets;
  }

  Widget _card(LectureModel item) => LectureCard(
    lecture: item,
    onDetails: () => context.pushNamed('lecture-details', extra: item),
  );

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Duration _time(String value) {
    final parts = value.split(':');
    return Duration(
      hours: int.tryParse(parts.first) ?? 0,
      minutes: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
  }
}

class _DayGroupHeader extends StatelessWidget {
  const _DayGroupHeader({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Row(
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        children: [
          Icon(Icons.calendar_today_outlined, size: 19, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$weekday • $formattedDate',
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
