import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../domain/entities/course.dart';
import '../../domain/entities/course_details.dart';
import 'course_image.dart';

class CourseInfoCard extends StatelessWidget {
  const CourseInfoCard({
    super.key,
    required this.course,
    this.instructors = const [],
  });

  final Course course;
  final List<CourseInstructor> instructors;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CourseImage(url: course.imageUrl, size: 82),
                const SizedBox(width: 14),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(child: _Info(l10n.levelLabel, '${course.level}')),
                      Expanded(
                        child: _Info(
                          l10n.groupLabel,
                          course.groupCode.isEmpty ? '-' : course.groupCode,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (instructors.isNotEmpty) ...[
              const SizedBox(height: 18),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  l10n.instructors,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ...instructors.map((instructor) => _InstructorTile(instructor: instructor)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _chooseInstructorResource(
                        context,
                        instructors,
                        resource: _Resource.youtube,
                      ),
                      icon: const Icon(Icons.play_circle_outline),
                      label: Text(l10n.youtubePlaylist),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _chooseInstructorResource(
                        context,
                        instructors,
                        resource: _Resource.materials,
                      ),
                      icon: const Icon(Icons.folder_open_outlined),
                      label: Text(l10n.courseMaterials),
                    ),
                  ),
                ],
              ),
            ] else ...[
              const SizedBox(height: 14),
              _Info(l10n.doctor, course.instructor),
              if ((course.instructorEmail ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                _EmailTile(email: course.instructorEmail!),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _chooseInstructorResource(
    BuildContext context,
    List<CourseInstructor> values, {
    required _Resource resource,
  }) async {
    final l10n = AppLocalizations.of(context);
    final available = values.where((item) {
      final url = resource == _Resource.youtube
          ? item.youtubePlaylistUrl
          : item.materialsUrl;
      return (url ?? '').trim().isNotEmpty;
    }).toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noResourceAvailable)),
      );
      return;
    }

    if (available.length == 1) {
      await _open(available.first, resource);
      return;
    }

    if (!context.mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                resource == _Resource.youtube
                    ? l10n.chooseInstructorForPlaylist
                    : l10n.chooseInstructorForMaterials,
                style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              ...available.map(
                (item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Icon(
                      item.isStudentInstructor
                          ? Icons.person
                          : Icons.person_outline,
                    ),
                  ),
                  title: Text(item.name),
                  subtitle: Text(_groupsText(sheetContext, item)),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _open(item, resource);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _groupsText(BuildContext context, CourseInstructor item) {
    final l10n = AppLocalizations.of(context);
    final groups = item.groupCodes.isEmpty ? '-' : item.groupCodes.join(', ');
    return '${item.isStudentInstructor ? l10n.yourInstructor : l10n.otherInstructor} • ${l10n.groupLabel}: $groups';
  }

  Future<void> _open(CourseInstructor instructor, _Resource resource) async {
    final value = resource == _Resource.youtube
        ? instructor.youtubePlaylistUrl
        : instructor.materialsUrl;
    final url = Uri.tryParse(value ?? '');
    if (url != null) await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

enum _Resource { youtube, materials }

class _InstructorTile extends StatelessWidget {
  const _InstructorTile({required this.instructor});

  final CourseInstructor instructor;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final groups = instructor.groupCodes.isEmpty ? '-' : instructor.groupCodes.join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(14),
        border: instructor.isStudentInstructor
            ? Border.all(color: theme.colorScheme.primary.withValues(alpha: .35))
            : null,
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 21,
                child: Icon(
                  instructor.isStudentInstructor
                      ? Icons.person
                      : Icons.person_outline,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            instructor.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (instructor.isStudentInstructor)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              l10n.yourInstructor,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text('${l10n.groupLabel}: $groups'),
                  ],
                ),
              ),
            ],
          ),
          if ((instructor.email ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _EmailTile(email: instructor.email!),
          ],
        ],
      ),
    );
  }
}

class _EmailTile extends StatelessWidget {
  const _EmailTile({required this.email});

  final String email;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: email));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context).copied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .4),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.email_outlined, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.doctorEmail, style: theme.textTheme.labelMedium),
                const SizedBox(height: 2),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: l10n.copy,
            visualDensity: VisualDensity.compact,
            onPressed: () => _copy(context),
            icon: const Icon(Icons.copy_outlined, size: 19),
          ),
        ],
      ),
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}
