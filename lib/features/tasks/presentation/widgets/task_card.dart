import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';

import '../../data/models/task_model.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.task,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
    this.onDetails,
  });

  final TaskModel task;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback? onDetails;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onDetails,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (task.canToggleCompletion)
                Checkbox(
                  value: task.isCompleted,
                  onChanged: (value) {
                    if (value != null) onToggle(value);
                  },
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                )
              else
                const SizedBox(width: 48),
              const SizedBox(width: 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _typeIcon(task.type),
                            size: 19,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(
                              task.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                decoration: task.isCompleted
                                    ? TextDecoration.lineThrough
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (task.courseId.trim().isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Text(
                          task.courseId,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _Tag(
                            icon: Icons.event_outlined,
                            label: MaterialLocalizations.of(context)
                                .formatMediumDate(task.dueDate),
                          ),
                          _Tag(
                            icon: task.isPersonal
                                ? Icons.person_outline
                                : Icons.school_outlined,
                            label: _typeLabel(task.type, l10n),
                          ),
                          if (task.isCompleted)
                            _Tag(
                              icon: Icons.check_circle_outline,
                              label: l10n.completed,
                              color: colors.primary,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (task.canEdit || task.canDelete)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      onEdit();
                    } else if (value == 'delete') {
                      onDelete();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'edit',
                      child: Text(l10n.edit),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(l10n.delete),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.icon, this.color});

  final String label;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = color ?? theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: foreground),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

String _typeLabel(String type, AppLocalizations l10n) {
  if (type == 'quiz') return l10n.quiz;
  if (type == 'personal_assignment') return l10n.personalTask;
  return l10n.universityAssignment;
}

IconData _typeIcon(String type) {
  return switch (type) {
    'quiz' => Icons.quiz_outlined,
    'personal_assignment' => Icons.person_outline,
    _ => Icons.assignment_outlined,
  };
}
