import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/errors/app_error_localizer.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/egypt_time.dart';
import '../../../exams/data/datasources/exams_remote_data_source.dart';
import '../../../exams/data/models/exam_model.dart';
import '../../../exams/data/repositories/exams_repository_impl.dart';
import '../../../tasks/data/datasources/tasks_remote_data_source.dart';
import '../../../tasks/data/models/task_model.dart';
import '../../../tasks/data/repositories/tasks_repository_impl.dart';
import '../viewmodels/all_deadlines_cubit.dart';
import '../viewmodels/all_deadlines_state.dart';

class AllDeadlinesScreen extends StatelessWidget {
  const AllDeadlinesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AllDeadlinesCubit(
        tasksRepository: TasksRepositoryImpl(
          TasksRemoteDataSource(SupabaseService()),
        ),
        examsRepository: ExamsRepositoryImpl(
          ExamsRemoteDataSource(SupabaseService()),
        ),
      )..load(),
      child: const _AllDeadlinesView(),
    );
  }
}

class _AllDeadlinesView extends StatefulWidget {
  const _AllDeadlinesView();

  @override
  State<_AllDeadlinesView> createState() => _AllDeadlinesViewState();
}

class _AllDeadlinesViewState extends State<_AllDeadlinesView> {
  _DeadlineFilter _filter = _DeadlineFilter.all;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.upcomingDeadlines),
      ),
      body: BlocConsumer<AllDeadlinesCubit, AllDeadlinesState>(
        listener: (context, state) {
          if (state.errorMessage == 'offline') {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(content: Text(l10n.offlineUsingCachedData)),
              );
          }
        },
        builder: (context, state) {
          if (state.status == AllDeadlinesStatus.initial ||
              state.status == AllDeadlinesStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == AllDeadlinesStatus.failure) {
            return _ErrorView(
              message: AppErrorLocalizer.message(
                context,
                state.errorMessage,
                fallback: isArabic ? 'حدث خطأ.' : 'Something went wrong.',
              ),
              onRetry: () => context.read<AllDeadlinesCubit>().load(),
            );
          }

          final items = _buildItems(context, state);

          return RefreshIndicator(
            onRefresh: () => context.read<AllDeadlinesCubit>().load(),
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
                  sliver: SliverToBoxAdapter(
                    child: _FilterBar(
                      filter: _filter,
                      onChanged: (value) => setState(() => _filter = value),
                      l10n: l10n,
                    ),
                  ),
                ),
                if (items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyView(l10n: l10n),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 28),
                    sliver: SliverList.builder(
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DeadlineItemCard(item: item),
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<_DeadlineItem> _buildItems(
    BuildContext context,
    AllDeadlinesState state,
  ) {
    final tasks = state.tasks
        .where((task) => !task.isCompleted && task.dueDate.isAfter(EgyptTime.now()))
        .where((task) {
          return switch (_filter) {
            _DeadlineFilter.all => true,
            _DeadlineFilter.assignments =>
              task.type == 'assignment' || task.type == 'personal_assignment',
            _DeadlineFilter.quizzes => task.type == 'quiz',
            _DeadlineFilter.exams => false,
          };
        })
        .map(_DeadlineItem.task);

    final exams = state.exams
        .where((exam) => exam.startTime.isAfter(EgyptTime.now()))
        .where((_) => _filter == _DeadlineFilter.all || _filter == _DeadlineFilter.exams)
        .map(_DeadlineItem.exam);

    final items = [...tasks, ...exams]
      ..sort((a, b) => a.when.compareTo(b.when));

    return items;
  }
}

enum _DeadlineFilter { all, assignments, quizzes, exams }

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.filter, required this.onChanged, required this.l10n});

  final _DeadlineFilter filter;
  final ValueChanged<_DeadlineFilter> onChanged;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(label: l10n.all, selected: filter == _DeadlineFilter.all, onTap: () => onChanged(_DeadlineFilter.all)),
          _FilterChip(label: l10n.assignment, selected: filter == _DeadlineFilter.assignments, onTap: () => onChanged(_DeadlineFilter.assignments)),
          _FilterChip(label: l10n.quiz, selected: filter == _DeadlineFilter.quizzes, onTap: () => onChanged(_DeadlineFilter.quizzes)),
          _FilterChip(label: l10n.exam, selected: filter == _DeadlineFilter.exams, onTap: () => onChanged(_DeadlineFilter.exams)),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

class _DeadlineItem {
  const _DeadlineItem._({
    required this.id,
    required this.title,
    required this.course,
    required this.when,
    required this.type,
    this.task,
    this.exam,
  });

  factory _DeadlineItem.task(TaskModel task) => _DeadlineItem._(
        id: task.id,
        title: task.title,
        course: task.courseId,
        when: task.dueDate,
        type: task.type == 'quiz' ? _DeadlineType.quiz : _DeadlineType.assignment,
        task: task,
      );

  factory _DeadlineItem.exam(ExamModel exam) => _DeadlineItem._(
        id: 'exam:${exam.id}',
        title: _examTitle(exam),
        course: exam.courseName,
        when: exam.startTime,
        type: _DeadlineType.exam,
        exam: exam,
      );

  final String id;
  final String title;
  final String course;
  final DateTime when;
  final _DeadlineType type;
  final TaskModel? task;
  final ExamModel? exam;

  static String _examTitle(ExamModel exam) {
    return switch (exam.type.toLowerCase()) {
      'midterm' => 'Midterm Exam',
      'quiz' => 'Quiz',
      _ => 'Final Exam',
    };
  }
}

enum _DeadlineType { assignment, quiz, exam }

class _DeadlineItemCard extends StatelessWidget {
  const _DeadlineItemCard({required this.item});

  final _DeadlineItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final color = switch (item.type) {
      _DeadlineType.assignment => theme.colorScheme.primary,
      _DeadlineType.quiz => Colors.indigo,
      _DeadlineType.exam => Colors.deepOrange,
    };
    final typeLabel = switch (item.type) {
      _DeadlineType.assignment => l10n.assignment,
      _DeadlineType.quiz => l10n.quiz,
      _DeadlineType.exam => l10n.exam,
    };

    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          if (item.task != null) {
            context.pushNamed('task-details', extra: item.task);
          } else if (item.exam != null) {
            context.pushNamed('exam-details', extra: item.exam);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  switch (item.type) {
                    _DeadlineType.assignment => Icons.assignment_outlined,
                    _DeadlineType.quiz => Icons.quiz_outlined,
                    _DeadlineType.exam => Icons.event_note_outlined,
                  },
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      item.course.isEmpty ? 'EELU Student Planner' : item.course,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 15, color: color),
                        const SizedBox(width: 5),
                        Expanded(child: Text(_date(context, item.when))),
                        Icon(Icons.schedule_outlined, size: 15, color: color),
                        const SizedBox(width: 5),
                        Text(_time(context, item.when)),
                      ],
                    ),
                  ],
                ),
              ),
              if (item.task != null && item.task!.canToggleCompletion)
                const SizedBox(width: 8),
              if (item.task != null && item.task!.canToggleCompletion)
                IconButton(
                  tooltip: l10n.markAllRead,
                  onPressed: () async {
                    try {
                      await context.read<AllDeadlinesCubit>().toggleTask(item.task!, true);
                    } catch (_) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.notificationsError)),
                      );
                    }
                  },
                  icon: Icon(Icons.check_circle_outline, color: color),
                ),
            ],
          ),
        ),
      ),
    );
  }

  String _date(BuildContext context, DateTime date) {
    return MaterialLocalizations.of(context).formatFullDate(date);
  }

  String _time(BuildContext context, DateTime date) {
    return MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(date));
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.l10n});
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_available_outlined, size: 64, color: Theme.of(context).colorScheme.primary.withValues(alpha: .6)),
            const SizedBox(height: 14),
            Text(l10n.allCaughtUp, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(l10n.noUpcomingDeadlines, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton(onPressed: onRetry, child: Text(AppLocalizations.of(context).retry)),
          ],
        ),
      ),
    );
  }
}
