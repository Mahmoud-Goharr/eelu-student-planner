import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/cache/planner_cache.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/widgets/shimmer/shimmer_card.dart';
import '../../data/datasources/tasks_remote_data_source.dart';
import '../../data/models/task_model.dart';
import '../../data/repositories/tasks_repository_impl.dart';
import '../viewmodels/tasks_cubit.dart';
import '../viewmodels/tasks_state.dart';
import '../widgets/add_task_sheet.dart';
import '../widgets/task_card.dart';
import '../widgets/task_filter_chip.dart';

class TasksScreen extends StatelessWidget {
  const TasksScreen({
    this.tasksCubit,
    this.initialTypeFilter = 'All',
    this.quizOnly = false,
    super.key,
  });

  final TasksCubit? tasksCubit;
  final String initialTypeFilter;
  final bool quizOnly;

  @override
  Widget build(BuildContext context) {
    if (tasksCubit != null) {
      return BlocProvider.value(
        value: tasksCubit!,
        child: _TasksView(initialTypeFilter: initialTypeFilter, quizOnly: quizOnly),
      );
    }

    return BlocProvider(
      create: (_) => TasksCubit(
        TasksRepositoryImpl(TasksRemoteDataSource(SupabaseService())),
      )..getTasks(),
      child: _TasksView(initialTypeFilter: initialTypeFilter, quizOnly: quizOnly),
    );
  }
}

class _TasksView extends StatefulWidget {
  const _TasksView({required this.initialTypeFilter, required this.quizOnly});

  final String initialTypeFilter;
  final bool quizOnly;

  @override
  State<_TasksView> createState() => _TasksViewState();
}

class _TasksViewState extends State<_TasksView> {
  String _completionFilter = 'Pending';
  late String _typeFilter;

  @override
  void initState() {
    super.initState();
    _typeFilter = widget.quizOnly ? 'Quizzes' : (widget.initialTypeFilter == 'Assignments' ? 'All' : widget.initialTypeFilter);
  }

  bool get isArabic => Localizations.localeOf(context).languageCode == 'ar';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<TasksCubit, TasksState>(
          listener: (context, state) {
            if (state.status == TasksStatus.createSuccess ||
                state.status == TasksStatus.updateSuccess ||
                state.status == TasksStatus.deleteSuccess) {
              final message = isArabic
                  ? 'تم حفظ التغييرات'
                  : 'Changes saved successfully';

              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(message)));
            }

            if (state.errorMessage == 'offline') {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                      AppLocalizations.of(context).offlineUsingCachedData,
                    ),
                  ),
                );
            } else if (state.status == TasksStatus.failure &&
                state.errorMessage != null) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(SnackBar(content: Text(state.errorMessage!)));
            }
          },
          builder: (context, state) {
            if (state.status == TasksStatus.initial ||
                state.status == TasksStatus.loading) {
              return const TasksShimmer();
            }

            if (state.status == TasksStatus.failure && state.tasks.isEmpty) {
              return _ErrorView(
                message:
                    state.errorMessage ??
                    (isArabic ? 'حدث خطأ.' : 'Something went wrong.'),
                onRetry: () => context.read<TasksCubit>().getTasks(),
              );
            }

            final filtered = _filteredTasks(state.tasks);
            final filteredHistory = state.history.where((item) {
              if (item.type != 'quiz' && item.type != 'assignment') {
                return false;
              }
              return widget.quizOnly
                  ? item.type == 'quiz'
                  : item.type == 'assignment';
            }).toList();

            return _TasksContent(
              tasks: filtered,
              history: filteredHistory,
              isBusy:
                  state.status == TasksStatus.creating ||
                  state.status == TasksStatus.updating ||
                  state.status == TasksStatus.deleting,
              completionFilter: _completionFilter,
              typeFilter: _typeFilter,
              quizOnly: widget.quizOnly,
              onCompletionChanged: (value) {
                setState(() => _completionFilter = value);
              },
              onTypeChanged: (value) {
                setState(() => _typeFilter = value);
              },
              onToggle: (task, value) {
                context.read<TasksCubit>().toggleTaskCompletion(
                  task: task,
                  isCompleted: value,
                );
              },
              onDelete: _confirmDelete,
              onEdit: _openTaskSheet,
              onDetails: (task) {
                context.pushNamed('task-details', extra: task);
              },
            );
          },
        ),
      ),
      floatingActionButton: widget.quizOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openTaskSheet(),
              icon: const Icon(Icons.add),
              label: Text(AppLocalizations.of(context).addPersonalTask),
            ),
    );
  }

  List<TaskModel> _filteredTasks(List<TaskModel> tasks) {
    return tasks.where((task) {
      final completionMatches = switch (_completionFilter) {
        'Pending' => !task.isCompleted,
        'Completed' => task.isCompleted,
        _ => true,
      };

      // The Tasks screen is intentionally limited to student tasks:
      // university assignments + personal tasks. Quizzes have their own screen.
      if (!widget.quizOnly && task.type == 'quiz') return false;

      final typeMatches = switch (_typeFilter) {
        'UniversityAssignments' => task.type == 'assignment',
        'PersonalTasks' => task.type == 'personal_assignment',
        'Quizzes' => task.type == 'quiz',
        _ => task.type == 'assignment' || task.type == 'personal_assignment',
      };

      return completionMatches && typeMatches;
    }).toList();
  }

  Future<void> _openTaskSheet([TaskModel? task]) async {
    if (task != null && !task.isPersonal) {
      return;
    }

    final draft = await showModalBottomSheet<TaskDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => AddTaskSheet(task: task),
    );

    if (!mounted || draft == null) return;

    final cubit = context.read<TasksCubit>();

    if (task == null) {
      await cubit.createPersonalAssignment(
        title: draft.title,
        description: draft.description,
        dueDate: draft.dueDate,
      );
    } else {
      await cubit.updatePersonalAssignment(
        task.copyWith(
          title: draft.title,
          description: draft.description,
          dueDate: draft.dueDate,
        ),
      );
    }
  }

  Future<void> _confirmDelete(TaskModel task) async {
    if (!task.isPersonal) return;

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).deletePersonalTask),
        content: Text(
          '${AppLocalizations.of(context).deletePersonalTaskConfirmation}\n"${task.title}"',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isArabic ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete == true && mounted) {
      await context.read<TasksCubit>().deleteTask(task.id);
    }
  }
}

class _TasksContent extends StatelessWidget {
  const _TasksContent({
    required this.tasks,
    required this.history,
    required this.isBusy,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
    required this.onDetails,
    required this.onCompletionChanged,
    required this.onTypeChanged,
    required this.completionFilter,
    required this.typeFilter,
    required this.quizOnly,
  });

  final List<TaskModel> tasks;
  final List<PlannerHistoryItem> history;
  final bool isBusy;
  final void Function(TaskModel, bool) onToggle;
  final ValueChanged<TaskModel> onDelete;
  final ValueChanged<TaskModel> onEdit;
  final ValueChanged<TaskModel> onDetails;
  final ValueChanged<String> onCompletionChanged;
  final ValueChanged<String> onTypeChanged;
  final String completionFilter;
  final String typeFilter;
  final bool quizOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final localizations = AppLocalizations.of(context);

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Text(
              quizOnly ? localizations.quizzesLabel : localizations.tasksLabel,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
          sliver: SliverToBoxAdapter(
            child: Text(
              quizOnly
                  ? localizations.quizzesForSelectedCourses
                  : localizations.tasksSubtitle,
              textAlign: isArabic ? TextAlign.right : TextAlign.left,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        if (!quizOnly)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
            sliver: SliverToBoxAdapter(
              child: _FilterSection(
                completionFilter: completionFilter,
                typeFilter: typeFilter,
                onCompletionChanged: onCompletionChanged,
                onTypeChanged: onTypeChanged,
              ),
            ),
          ),
        if (tasks.isEmpty)
          SliverToBoxAdapter(child: _EmptyState(quizOnly: quizOnly))
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            sliver: SliverList.builder(
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];

                return IgnorePointer(
                  ignoring: isBusy,
                  child: TaskCard(
                    task: task,
                    onToggle: (value) => onToggle(task, value),
                    onDelete: () => onDelete(task),
                    onEdit: () => onEdit(task),
                    onDetails: () => onDetails(task),
                  ),
                );
              },
            ),
          ),
        if (history.isNotEmpty) ...[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  const Icon(Icons.history_outlined),
                  const SizedBox(width: 8),
                  Text(
                    isArabic ? 'المواعيد المنتهية' : 'Past Deadlines',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 90),
            sliver: SliverList.builder(
              itemCount: history.length,
              itemBuilder: (context, index) =>
                  _PastDeadlineCard(item: history[index]),
            ),
          ),
        ] else
          const SliverPadding(padding: EdgeInsets.only(bottom: 90)),
      ],
    );
  }
}

class _PastDeadlineCard extends StatelessWidget {
  const _PastDeadlineCard({required this.item});

  final PlannerHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final status = item.isCompleted
        ? (isArabic ? 'تم الإنجاز قبل الموعد' : 'Completed before deadline')
        : (isArabic ? 'لم يتم الإنجاز' : 'Not completed');
    final type = switch (item.type) {
      'quiz' => isArabic ? 'كويز' : 'Quiz',
      'assignment' => isArabic ? 'اسيمنت' : 'Assignment',
      'personal_assignment' => isArabic ? 'تاسك شخصي' : 'Personal Assignment',
      'exam' => isArabic ? 'امتحان' : 'Exam',
      _ => item.type,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(item.isCompleted ? Icons.check : Icons.history),
        ),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '$type • ${item.course.isEmpty ? (isArabic ? 'بدون مقرر' : 'No course') : item.course}\n'
          '${MaterialLocalizations.of(context).formatMediumDate(item.dueDate)} • $status',
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.completionFilter,
    required this.typeFilter,
    required this.onCompletionChanged,
    required this.onTypeChanged,
  });

  final String completionFilter;
  final String typeFilter;
  final ValueChanged<String> onCompletionChanged;
  final ValueChanged<String> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final localizations = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          localizations.type,
          textAlign: isArabic ? TextAlign.right : TextAlign.left,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              TaskFilterChip(
                label: localizations.all,
                selected: typeFilter == 'All',
                onSelected: () => onTypeChanged('All'),
              ),
              const SizedBox(width: 8),
              TaskFilterChip(
                label: localizations.universityAssignment,
                selected: typeFilter == 'UniversityAssignments',
                onSelected: () => onTypeChanged('UniversityAssignments'),
              ),
              const SizedBox(width: 8),
              TaskFilterChip(
                label: localizations.personalTask,
                selected: typeFilter == 'PersonalTasks',
                onSelected: () => onTypeChanged('PersonalTasks'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          localizations.status,
          textAlign: isArabic ? TextAlign.right : TextAlign.left,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              TaskFilterChip(
                label: localizations.pending,
                selected: completionFilter == 'Pending',
                onSelected: () => onCompletionChanged('Pending'),
              ),
              const SizedBox(width: 8),
              TaskFilterChip(
                label: localizations.completed,
                selected: completionFilter == 'Completed',
                onSelected: () => onCompletionChanged('Completed'),
              ),
              const SizedBox(width: 8),
              TaskFilterChip(
                label: localizations.all,
                selected: completionFilter == 'All',
                onSelected: () => onCompletionChanged('All'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.quizOnly});

  final bool quizOnly;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final localizations = AppLocalizations.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_outlined, size: 52, color: colors.primary),
            const SizedBox(height: 12),
            Text(
              quizOnly
                  ? localizations.quizzesLabel
                  : localizations.noUniversityAssignmentsOrPersonalTasks,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              quizOnly
                  ? localizations.noQuizzesAvailable
                  : localizations.noPersonalTasksHint,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
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
    final colors = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colors.error),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              child: Text(
                Localizations.localeOf(context).languageCode == 'ar'
                    ? 'إعادة المحاولة'
                    : 'Retry',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
