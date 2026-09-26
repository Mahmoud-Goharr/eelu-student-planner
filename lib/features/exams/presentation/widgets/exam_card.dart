import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../data/models/exam_model.dart';

class ExamCard extends StatelessWidget {
  const ExamCard({
    super.key,
    required this.exam,
    this.onDetails,
    this.completed = false,
    this.onCompletionChanged,
  });

  final ExamModel exam;
  final VoidCallback? onDetails;
  final bool completed;
  final ValueChanged<bool>? onCompletionChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onDetails,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(_icon(exam.type), color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: isArabic
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      exam.courseName,
                      textAlign: isArabic ? TextAlign.right : TextAlign.left,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.category_outlined,
                      label: isArabic ? 'نوع الامتحان' : 'Exam type',
                      value: _typeLabel(l10n),
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.calendar_today_outlined,
                      label: isArabic ? 'اليوم والتاريخ' : 'Date',
                      value: MaterialLocalizations.of(context).formatFullDate(exam.date),
                    ),
                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.access_time_outlined,
                      label: isArabic ? 'وقت البداية' : 'Start time',
                      value: _time(context, exam.startTime),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Checkbox(
                value: completed,
                onChanged: onCompletionChanged == null
                    ? null
                    : (value) {
                        if (value != null) onCompletionChanged!(value);
                      },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _typeLabel(AppLocalizations l10n) {
    return switch (exam.type.toLowerCase()) {
      'quiz' => l10n.quiz,
      'midterm' => l10n.midterm,
      _ => l10n.finalExam,
    };
  }

  String _time(BuildContext context, DateTime value) {
    return MaterialLocalizations.of(context)
        .formatTimeOfDay(TimeOfDay.fromDateTime(value));
  }

  IconData _icon(String type) {
    return switch (type.toLowerCase()) {
      'quiz' => Icons.quiz_outlined,
      'midterm' => Icons.assignment_outlined,
      _ => Icons.school_outlined,
    };
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    return Row(
      children: [
        Icon(icon, size: 18, color: colors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            style: TextStyle(color: colors.onSurfaceVariant),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: isArabic ? TextAlign.left : TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
