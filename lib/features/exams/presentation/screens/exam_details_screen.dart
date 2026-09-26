import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../data/models/exam_model.dart';

class ExamDetailsScreen extends StatelessWidget {
  const ExamDetailsScreen({required this.exam, super.key});

  final ExamModel exam;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final ml = MaterialLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.examDetails)),
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
                  const Icon(Icons.event_outlined, size: 38),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      exam.courseName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _Row(label: l10n.date, value: ml.formatFullDate(exam.date)),
          _Row(
            label: l10n.startTime,
            value: ml.formatTimeOfDay(TimeOfDay.fromDateTime(exam.startTime)),
          ),
          if (exam.description?.trim().isNotEmpty == true)
            _Row(label: l10n.content, value: exam.description!.trim()),
        ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Card(
        elevation: 0,
        child: ListTile(
          title: Text(label, style: Theme.of(context).textTheme.labelMedium),
          subtitle: Text(value),
        ),
      );
}
