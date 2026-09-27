import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_error_localizer.dart';
import '../../../../core/localization/app_localizations.dart';

import '../../data/models/course_lecture_progress_model.dart';
import '../../data/models/lecture_progress_model.dart';
import '../../data/repositories/lecture_progress_repository_impl.dart';

import '../../domain/usecases/get_lecture_progress.dart';
import '../../domain/usecases/toggle_lecture_progress.dart';

import '../viewmodels/lecture_progress_cubit.dart';
import '../viewmodels/lecture_progress_state.dart';

class LectureProgressScreen extends StatelessWidget {
  const LectureProgressScreen({super.key, this.courseId});

  final String? courseId;

  bool get isCourseDetails => courseId != null;

  @override
  Widget build(BuildContext context) {
    final repository = LectureProgressRepositoryImpl();

    return BlocProvider(
      create: (_) => LectureProgressCubit(
        getLectureProgress: GetLectureProgress(repository),
        toggleLectureProgress: ToggleLectureProgress(repository),
      )..load(),
      child: _LectureProgressView(courseId: courseId),
    );
  }
}

class _LectureProgressView extends StatelessWidget {
  const _LectureProgressView({this.courseId});

  final String? courseId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<LectureProgressCubit, LectureProgressState>(
          builder: (context, state) {
            if (courseId == null) {
              return Text(l10n.lectureProgress);
            }

            return Text(
              state.courseById(courseId!)?.courseName ??
                  l10n.lectureProgress,
            );
          },
        ),
      ),
      body: BlocBuilder<LectureProgressCubit, LectureProgressState>(
        builder: (context, state) {
          if (state.status == LectureProgressStatus.initial ||
              state.status == LectureProgressStatus.loading) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (state.status == LectureProgressStatus.failure &&
              state.courses.isEmpty) {
            return _ErrorView(
              message: AppErrorLocalizer.message(
                context,
                state.error,
                fallback: l10n.failedToLoadLectureProgress,
              ),
              onRetry: () {
                context.read<LectureProgressCubit>().load();
              },
            );
          }

          if (courseId != null) {
            final course = state.courseById(courseId!);

            if (course == null) {
              return _EmptyView(
                title: l10n.noCoursesProgress,
              );
            }

            return _CourseDetailsView(
              course: course,
              primary: theme.colorScheme.primary,
            );
          }

          return _CoursesProgressView(
            state: state,
            primary: theme.colorScheme.primary,
          );
        },
      ),
    );
  }
}

class _CoursesProgressView extends StatelessWidget {
  const _CoursesProgressView({
    required this.state,
    required this.primary,
  });

  final LectureProgressState state;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return RefreshIndicator(
      onRefresh: () => context.read<LectureProgressCubit>().load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          _OverallProgressCard(
            completed: state.completedCount,
            total: state.totalCount,
            progress: state.progress,
            primary: primary,
          ),
          const SizedBox(height: 22),
          Text(
            l10n.courses,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          if (state.courses.isEmpty)
            _EmptyView(
              title: l10n.noCoursesProgress,
            )
          else
            for (final course in state.courses)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _CourseProgressCard(
                  course: course,
                  primary: primary,
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => LectureProgressScreen(
                          courseId: course.courseId,
                        ),
                      ),
                    );

                    // Refresh the parent progress screen after returning from
                    // the course details screen so the overall percentage
                    // reflects the latest completed lecture immediately.
                    if (!context.mounted) return;
                    await context.read<LectureProgressCubit>().load();
                  },
                ),
              ),
        ],
      ),
    );
  }
}

class _CourseDetailsView extends StatelessWidget {
  const _CourseDetailsView({
    required this.course,
    required this.primary,
  });

  final CourseLectureProgressModel course;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    final grouped = <DateTime, List<LectureProgressModel>>{};

    for (final lecture in course.lectures) {
      final date = DateTime(
        lecture.lectureDate.year,
        lecture.lectureDate.month,
        lecture.lectureDate.day,
      );

      grouped
          .putIfAbsent(
            date,
            () => <LectureProgressModel>[],
          )
          .add(lecture);
    }

    /*
     * The datasource already returns lectures sorted by:
     * 1. lecture date
     * 2. start time
     *
     * We use that order to generate:
     * Lecture 1
     * Lecture 2
     * Lecture 3
     * ...
     *
     * The number is only for display.
     */

    final sections = <Widget>[];
    var lectureNumber = 1;

    for (final entry in grouped.entries) {
      sections.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: _DateSection(
            date: entry.key,
            lectures: entry.value,
            startingNumber: lectureNumber,
          ),
        ),
      );

      lectureNumber += entry.value.length;
    }

    return RefreshIndicator(
      onRefresh: () => context.read<LectureProgressCubit>().load(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 28),
        children: [
          _CourseProgressHeader(
            course: course,
            primary: primary,
          ),
          const SizedBox(height: 22),
          if (course.lectures.isEmpty)
            _EmptyView(
              title: l10n.noLecturesFound,
            )
          else
            ...sections,
        ],
      ),
    );
  }
}

class _OverallProgressCard extends StatelessWidget {
  const _OverallProgressCard({
    required this.completed,
    required this.total,
    required this.progress,
    required this.primary,
  });

  final int completed;
  final int total;
  final double progress;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _BlueProgressCard(
      primary: primary,
      title: l10n.overallLectureProgress,
      mainValue: '${(progress * 100).round()}%',
      subtitle: '$completed / $total ${l10n.studied}',
      progress: progress,
    );
  }
}

class _CourseProgressHeader extends StatelessWidget {
  const _CourseProgressHeader({
    required this.course,
    required this.primary,
  });

  final CourseLectureProgressModel course;
  final Color primary;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return _BlueProgressCard(
      primary: primary,
      title: l10n.courseProgress,
      mainValue: '${(course.progress * 100).round()}%',
      subtitle:
          '${course.completedCount} / '
          '${course.totalCount} '
          '${l10n.lecturesCount}',
      progress: course.progress,
    );
  }
}

class _BlueProgressCard extends StatelessWidget {
  const _BlueProgressCard({
    required this.primary,
    required this.title,
    required this.mainValue,
    required this.subtitle,
    required this.progress,
  });

  final Color primary;
  final String title;
  final String mainValue;
  final String subtitle;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            primary,
            Color.lerp(primary, Colors.blue, .35)!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            mainValue,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .86),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: Colors.white.withValues(alpha: .20),
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).round()}%',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .82),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseProgressCard extends StatelessWidget {
  const _CourseProgressCard({
    required this.course,
    required this.primary,
    required this.onTap,
  });

  final CourseLectureProgressModel course;
  final Color primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: .11),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.menu_book_rounded,
                      color: primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.courseName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${course.completedCount} / '
                          '${course.totalCount} '
                          '${l10n.lecturesCount}',
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(course.progress * 100).round()}%',
                    style: TextStyle(
                      color: primary,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: LinearProgressIndicator(
                  value: course.progress,
                  minHeight: 7,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHighest,
                  color: primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateSection extends StatelessWidget {
  const _DateSection({
    required this.date,
    required this.lectures,
    required this.startingNumber,
  });

  final DateTime date;
  final List<LectureProgressModel> lectures;
  final int startingNumber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          MaterialLocalizations.of(context)
              .formatMediumDate(date),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        for (var index = 0;
            index < lectures.length;
            index++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _LectureCard(
              lecture: lectures[index],
              lectureNumber: startingNumber + index,
            ),
          ),
      ],
    );
  }
}

class _LectureCard extends StatelessWidget {
  const _LectureCard({
    required this.lecture,
    required this.lectureNumber,
  });

  final LectureProgressModel lecture;
  final int lectureNumber;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final isArabic =
        Localizations.localeOf(context).languageCode == 'ar';

    final lectureLabel = isArabic
        ? 'المحاضرة $lectureNumber'
        : 'Lecture $lectureNumber';

    return Material(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          context
              .read<LectureProgressCubit>()
              .toggleLecture(lecture);
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(
                  milliseconds: 180,
                ),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: lecture.completed
                      ? primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: lecture.completed
                      ? null
                      : Border.all(
                          color:
                              theme.colorScheme.outlineVariant,
                        ),
                ),
                child: Icon(
                  lecture.completed
                      ? Icons.check_rounded
                      : Icons.circle_outlined,
                  size: 20,
                  color: lecture.completed
                      ? Colors.white
                      : theme
                          .colorScheme
                          .onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      lectureLabel,
                      style:
                          theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      lecture.courseName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${lecture.startTime} - '
                      '${lecture.endTime}',
                      style:
                          theme.textTheme.bodySmall?.copyWith(
                        color:
                            theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (lecture.instructor.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        lecture.instructor,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                lecture.completed
                    ? Icons.check_circle_rounded
                    : Icons.menu_book_rounded,
                color: lecture.completed
                    ? primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({
    required this.title,
  });

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 60,
              color:
                  Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Theme.of(context)
                  .colorScheme
                  .error,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.failedToLoadLectureProgress,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onRetry,
              child: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }
}