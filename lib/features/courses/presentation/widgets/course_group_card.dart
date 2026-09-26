import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';

class CourseGroupCard extends StatelessWidget {
  const CourseGroupCard({super.key, required this.groupCode});

  final String groupCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: primary.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primary.withValues(alpha: .12)),
      ),
      child: Row(
        children: [
          Icon(Icons.groups_outlined, color: primary, size: 30),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context).yourGroup, style: theme.textTheme.bodySmall),
              const SizedBox(height: 3),
              Text(
                '${AppLocalizations.of(context).groupLabel} ${groupCode.isEmpty ? '-' : groupCode}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
