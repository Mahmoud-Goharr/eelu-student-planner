import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';

class AboutAppScreen extends StatelessWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final items = [
      localizations.coursesLabel,
      localizations.scheduleLabel,
      localizations.tasksLabel,
      localizations.examsLabel,
      localizations.lecturesLabel,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(localizations.aboutAppTitle)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  Icon(
                    Icons.school_rounded,
                    size: 54,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'EELU Student Planner',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    localizations.appDescription,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),
                  ...items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text('• $item'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    localizations.appVersion,
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
