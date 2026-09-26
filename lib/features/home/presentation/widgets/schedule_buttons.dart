import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/widgets/main_shell.dart';
import '../../../tasks/data/datasources/tasks_remote_data_source.dart';
import '../../../tasks/data/repositories/tasks_repository_impl.dart';
import '../../../tasks/presentation/viewmodels/tasks_cubit.dart';
import '../../../tasks/presentation/viewmodels/tasks_state.dart';
import '../../../tasks/presentation/screens/tasks_screen.dart';
import '../../../tasks/presentation/widgets/add_task_sheet.dart';

/* -------------------------------------------------------------------------- */
/* SCHEDULE BUTTONS                                                           */
/* -------------------------------------------------------------------------- */

class ScheduleButtons extends StatelessWidget {
  const ScheduleButtons({required this.primaryColor, super.key});

  final Color primaryColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            title: AppLocalizations.of(context).addTask,
            icon: Icons.add_task_rounded,
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            onPressed: () => _openAddTask(context),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _ActionButton(
            title: AppLocalizations.of(context).viewSchedule,
            icon: Icons.calendar_view_week_rounded,
            backgroundColor: Theme.of(context).cardColor,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            onPressed: () =>
                MainShellController.maybeOf(context)?.onTabSelected(2),
          ),
        ),
      ],
    );
  }

  Future<void> _openAddTask(BuildContext context) async {
    final draft = await showModalBottomSheet<TaskDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const AddTaskSheet(),
    );
    if (!context.mounted || draft == null) return;
    final cubit = TasksCubit(
      TasksRepositoryImpl(TasksRemoteDataSource(SupabaseService())),
    );
    await cubit.getTasks();
    await cubit.createTask(
      title: draft.title,
      description: draft.description,
      courseId: draft.courseId,
      dueDate: draft.dueDate,
      type: draft.type,
      priority: draft.priority,
    );
    if (!context.mounted) {
      await cubit.close();
      return;
    }
    if (cubit.state.status == TasksStatus.createSuccess) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => TasksScreen(tasksCubit: cubit)),
      );
    }
    await cubit.close();
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.title,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    this.onPressed,
  });

  final String title;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              if (backgroundColor == Theme.of(context).cardColor)
                BoxShadow(
                  color: Colors.black.withValues(alpha: .03),
                  blurRadius: 10,
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: foregroundColor, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: foregroundColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
