import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';

import '../../domain/entities/course.dart';
import 'course_image.dart';

class CourseCard extends StatelessWidget {
  const CourseCard({
    super.key,
    required this.course,
    required this.index,
  });

  final Course course;
  final int index;

  @override
  Widget build(BuildContext context) {
    const icons = [
      Icons.memory_outlined,
      Icons.computer_outlined,
      Icons.psychology_outlined,
      Icons.developer_board_outlined,
      Icons.account_tree_outlined,
      Icons.lan_outlined,
    ];

    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.pushNamed(
          'course-details',
          extra: course,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CourseImage(
                url: course.imageUrl,
                size: 96,
                fallback: icons[index % icons.length],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      course.code,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      course.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      course.instructor,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (course.groupCode.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${AppLocalizations.of(context).groupLabel} ${course.groupCode}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 17,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
