import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/utils/time_formatter.dart';
import '../../data/models/lecture_model.dart';

class LectureDetailsScreen extends StatelessWidget {
  const LectureDetailsScreen({required this.lecture, super.key});
  final LectureModel lecture;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.lectureDetails)),
      body: SafeArea(
        child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.menu_book_outlined, size: 34),
              title: Text(
                lecture.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(lecture.courseName),
            ),
          ),
          const SizedBox(height: 16),
          _Row(
            label: l.date,
            value: MaterialLocalizations.of(context)
                .formatMediumDate(lecture.date),
          ),
          _Row(label: l.instructor, value: lecture.instructor),
          _Row(label: l.starts, value: TimeFormatter.format(lecture.startTime, arabic: Localizations.localeOf(context).languageCode == 'ar')),
          _Row(label: l.ends, value: TimeFormatter.format(lecture.endTime, arabic: Localizations.localeOf(context).languageCode == 'ar')),
          _Row(
            label: l.location,
            value: lecture.location.isEmpty ? l.notSet : lecture.location,
          ),
          _Row(label: l.level, value: '${lecture.level}'),
          _Row(label: l.section, value: lecture.section),
          if (lecture.description?.trim().isNotEmpty == true)
            _Row(label: l.description, value: lecture.description!),
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
