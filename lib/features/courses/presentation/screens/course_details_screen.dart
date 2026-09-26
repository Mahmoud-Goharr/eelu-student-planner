import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/course.dart';
import '../../domain/entities/course_details.dart';
import '../../data/repositories/course_details_repository_impl.dart';
import '../viewmodels/course_details_cubit.dart';
import '../viewmodels/course_details_state.dart';
import '../widgets/course_info_card.dart';
import '../widgets/course_section.dart';
import '../widgets/course_image.dart';

class CourseDetailsScreen extends StatelessWidget {
  const CourseDetailsScreen({required this.course, super.key});
  const CourseDetailsScreen.invalid({super.key}) : course = null;

  final Course? course;

  @override
  Widget build(BuildContext context) {
    final item = course;
    if (item == null) {
      return Scaffold(
        body: Center(child: Text(AppLocalizations.of(context).detailsUnavailable)),
      );
    }

    return BlocProvider(
      create: (_) => CourseDetailsCubit(CourseDetailsRepositoryImpl())
        ..load(courseId: item.id, courseName: item.name),
      child: _View(course: item),
    );
  }
}

class _View extends StatelessWidget {
  const _View({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.courseDetails)),
      body: BlocBuilder<CourseDetailsCubit, CourseDetailsState>(
        builder: (context, state) {
          if (state.status == CourseDetailsStatus.loading ||
              state.status == CourseDetailsStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == CourseDetailsStatus.failure) {
            return Center(child: Text(state.errorMessage ?? l10n.genericError));
          }

          final data = state.data!;
          return _Content(course: course, data: data);
        },
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.course, required this.data});

  final Course course;
  final CourseDetails data;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return CustomScrollView(
      slivers: [
        SliverPersistentHeader(
          pinned: true,
          delegate: _CourseHeroDelegate(course: course),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Text(
                l10n.courseInformation,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              CourseInfoCard(
                course: Course(
                  id: course.id,
                  code: course.code,
                  name: course.name,
                  level: course.level,
                  instructor: course.instructor,
                  instructorEmail: course.instructorEmail,
                  youtubePlaylistUrl: course.youtubePlaylistUrl,
                  materialsUrl: course.materialsUrl,
                  imageUrl: course.imageUrl,
                  groupCode: course.groupCode,
                ),
                instructors: data.instructors,
              ),
              const SizedBox(height: 18),
              CourseSection(
                title: l10n.upcomingTasks,
                icon: Icons.task_alt_outlined,
                items: data.tasks,
              ),
              CourseSection(
                title: l10n.quizzesLabel,
                icon: Icons.quiz_outlined,
                items: data.quizzes,
              ),
              CourseSection(
                title: l10n.upcomingExams,
                icon: Icons.event_available_outlined,
                items: data.exams,
              ),
              CourseSection(
                title: l10n.upcomingLectures,
                icon: Icons.menu_book_outlined,
                items: data.lectures,
                isLectureSection: true,
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _CourseHeroDelegate extends SliverPersistentHeaderDelegate {
  _CourseHeroDelegate({required this.course});

  final Course course;

  static const double _height = 108;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 6),
      child: _Hero(course: course),
    );
  }

  @override
  bool shouldRebuild(covariant _CourseHeroDelegate oldDelegate) {
    return oldDelegate.course.id != course.id ||
        oldDelegate.course.name != course.name ||
        oldDelegate.course.imageUrl != course.imageUrl;
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.course});

  final Course course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CourseImage(url: course.imageUrl, size: 70),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    course.code,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Flexible(
                    child: Text(
                      course.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
