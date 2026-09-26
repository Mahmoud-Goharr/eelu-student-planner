import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../data/models/task_model.dart';

class TaskDetailsScreen extends StatelessWidget {
  const TaskDetailsScreen({required this.task, super.key});

  final TaskModel task;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final title = switch (task.type) {
      'quiz' => l10n.quizDetails,
      'personal_assignment' => l10n.personalAssignmentDetails,
      'assignment' => l10n.assignmentDetails,
      _ => l10n.taskDetails,
    };

    final date = MaterialLocalizations.of(context).formatMediumDate(task.dueDate);
    final time = MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(task.dueDate));

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Icon(
                    _icon(task.type),
                    size: 38,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (task.courseId.trim().isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(task.courseId),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Info(label: l10n.date, value: '$date • $time'),
          if (task.description?.trim().isNotEmpty == true)
            _Info(label: l10n.content, value: task.description!.trim()),
        ],
        ),
      ),
    );
  }

  IconData _icon(String type) => switch (type) {
        'quiz' => Icons.quiz_outlined,
        'personal_assignment' => Icons.person_outline,
        _ => Icons.assignment_outlined,
      };
}

class _Info extends StatelessWidget {
  const _Info({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        title: Text(label, style: Theme.of(context).textTheme.labelMedium),
        subtitle: Text(value),
      ),
    );
  }
}
