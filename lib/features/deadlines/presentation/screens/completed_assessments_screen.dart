import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/cache/planner_cache.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/errors/app_error_localizer.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/widgets/shimmer/shimmer_card.dart';
import '../../../tasks/data/datasources/tasks_remote_data_source.dart';
import '../../../tasks/data/repositories/tasks_repository_impl.dart';
import '../../../tasks/presentation/viewmodels/tasks_cubit.dart';
import '../../../tasks/presentation/viewmodels/tasks_state.dart';

class CompletedAssessmentsScreen extends StatelessWidget {
  const CompletedAssessmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TasksCubit(
        TasksRepositoryImpl(TasksRemoteDataSource(SupabaseService())),
      )..getTasks(),
      child: const _CompletedAssessmentsView(),
    );
  }
}

class _CompletedAssessmentsView extends StatelessWidget {
  const _CompletedAssessmentsView();

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(title: Text(isArabic ? 'المنتهي' : 'Completed deadlines')),
      body: SafeArea(
        child: BlocBuilder<TasksCubit, TasksState>(
          builder: (context, state) {
            if (state.status == TasksStatus.initial ||
                state.status == TasksStatus.loading) {
              return const TasksShimmer();
            }

            if (state.status == TasksStatus.failure && state.history.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    AppErrorLocalizer.message(
                      context,
                      state.errorMessage,
                      fallback: isArabic ? 'حدث خطأ.' : 'Something went wrong.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            final items =
                state.history
                    .where(
                      (item) =>
                          item.type == 'quiz' || item.type == 'assignment',
                    )
                    .toList()
                  ..sort((a, b) => b.dueDate.compareTo(a.dueDate));

            if (items.isEmpty) {
              return _EmptyState(isArabic: isArabic);
            }

            final grouped = <String, List<PlannerHistoryItem>>{};
            for (final item in items) {
              final course = item.course.trim().isEmpty
                  ? (isArabic ? 'مقرر غير محدد' : 'Unknown course')
                  : item.course.trim();
              grouped.putIfAbsent(course, () => []).add(item);
            }

            final groups = grouped.entries.toList()
              ..sort(
                (a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()),
              );

            return RefreshIndicator(
              onRefresh: () => context.read<TasksCubit>().getTasks(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                children: [
                  Text(
                    isArabic
                        ? 'الكويزات والاسيمنتات التي انتهى موعدها'
                        : 'Quizzes and assignments whose deadlines have passed',
                    style: Theme.of(context).textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  for (final group in groups) ...[
                    _CourseHeader(title: group.key),
                    const SizedBox(height: 8),
                    for (final item in group.value) ...[
                      _HistoryCard(item: item),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 8),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CourseHeader extends StatelessWidget {
  const _CourseHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.menu_book_outlined, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item});

  final PlannerHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final theme = Theme.of(context);
    final completed = item.isCompleted;

    final type = item.type == 'quiz'
        ? (isArabic ? 'كويز' : 'Quiz')
        : (isArabic ? 'اسيمنت' : 'Assignment');

    final status = completed
        ? (isArabic
              ? 'عملت $type قبل الديدلاين'
              : 'Completed before the deadline')
        : (isArabic
              ? 'معملتش $type قبل الديدلاين'
              : 'Not completed before the deadline');

    final statusColor = completed
        ? theme.colorScheme.primary
        : theme.colorScheme.error;

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                completed ? Icons.check_circle_outline : Icons.history_outlined,
                color: statusColor,
              ),
            ),
            const SizedBox(width: 12),
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
                  const SizedBox(height: 6),
                  Text(
                    type,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${isArabic ? 'الديدلاين' : 'Deadline'}: '
                    '${MaterialLocalizations.of(context).formatMediumDate(item.dueDate)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    status,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w800,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isArabic});

  final bool isArabic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.history_outlined,
              size: 60,
              color: theme.colorScheme.primary.withValues(alpha: .65),
            ),
            const SizedBox(height: 14),
            Text(
              isArabic
                  ? 'لا توجد كويزات أو اسيمنتات منتهية'
                  : 'No expired quizzes or assignments',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
