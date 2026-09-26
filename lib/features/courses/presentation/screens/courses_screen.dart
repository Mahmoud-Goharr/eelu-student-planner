import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';

import '../../../../core/widgets/shimmer/shimmer_card.dart';
import '../../data/repositories/courses_repository_impl.dart';
import '../../domain/entities/course.dart';
import '../viewmodels/courses_cubit.dart';
import '../viewmodels/courses_state.dart';
import '../widgets/course_card.dart';

class CoursesScreen extends StatelessWidget {
  const CoursesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CoursesCubit(CoursesRepositoryImpl())..getCourses(),
      child: const _CoursesView(),
    );
  }
}

class _CoursesView extends StatelessWidget {
  const _CoursesView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocBuilder<CoursesCubit, CoursesState>(
          builder: (context, state) {
            if (state.status == CoursesStatus.loading ||
                state.status == CoursesStatus.initial) {
              return const CoursesShimmer();
            }
            if (state.status == CoursesStatus.failure) {
              return _Error(
                message: state.errorMessage ?? AppLocalizations.of(context).failedToLoadCourses,
                onRetry: context.read<CoursesCubit>().getCourses,
              );
            }
            return _Content(courses: state.courses);
          },
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.courses});

  final List<Course> courses;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          sliver: SliverToBoxAdapter(child: const _Header()),
        ),
        if (courses.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: Text(AppLocalizations.of(context).noCourses)),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            sliver: SliverList.separated(
              itemCount: courses.length,
              itemBuilder: (_, i) => CourseCard(
                course: courses[i],
                index: i,
              ),
              separatorBuilder: (_, _) => const SizedBox(height: 14),
            ),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.courses,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.courseGroupsCanDiffer,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Error extends StatelessWidget {
  const _Error({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(AppLocalizations.of(context).retry),
              ),
            ],
          ),
        ),
      );
}
