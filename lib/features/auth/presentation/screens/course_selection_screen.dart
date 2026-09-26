import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../profile/presentation/sync/profile_sync_bus.dart';
import '../../domain/entities/course_selection_option.dart';
import '../viewmodels/auth_cubit.dart';

class CourseSelectionScreen extends StatefulWidget {
  const CourseSelectionScreen({super.key});

  @override
  State<CourseSelectionScreen> createState() => _CourseSelectionScreenState();
}

class _CourseSelectionScreenState extends State<CourseSelectionScreen> {
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<CourseSelectionOption> _options = const [];
  final Map<String, String> _selectedOfferingByCourse = <String, String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cubit = context.read<AuthCubit>();
      final options = await cubit.getCourseSelectionOptions();
      final selected = await cubit.getSelectedCourseOfferingIds();

      final byOffering = <String, CourseSelectionOption>{
        for (final option in options) option.offeringId: option,
      };
      final selectedByCourse = <String, String>{};

      for (final offeringId in selected) {
        final option = byOffering[offeringId];
        if (option != null) {
          selectedByCourse[option.courseId] = option.offeringId;
        }
      }

      if (!mounted) return;
      setState(() {
        _options = options;
        _selectedOfferingByCourse
          ..clear()
          ..addAll(selectedByCourse);
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  List<CourseSelectionOption> _optionsForCourse(String courseId) {
    final result = _options
        .where((option) => option.courseId == courseId)
        .toList();
    result.sort((a, b) => a.groupCode.compareTo(b.groupCode));
    return result;
  }

  List<CourseSelectionOption> get _courses {
    final seen = <String>{};
    final result = <CourseSelectionOption>[];

    for (final option in _options) {
      if (seen.add(option.courseId)) {
        result.add(option);
      }
    }

    result.sort((a, b) => a.courseName.compareTo(b.courseName));
    return result;
  }

  void _selectOffering(CourseSelectionOption option) {
    setState(() {
      _selectedOfferingByCourse[option.courseId] = option.offeringId;
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context);

    if (_selectedOfferingByCourse.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(l10n.selectAtLeastOneCourse),
            behavior: SnackBarBehavior.floating,
          ),
        );
      return;
    }

    setState(() => _saving = true);

    await context.read<AuthCubit>().saveCourseSelections(
          _selectedOfferingByCourse.values.toList(),
        );

    ProfileSyncBus.instance.notify();

    if (!mounted) return;
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    final courses = _courses;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  Icons.menu_book_rounded,
                  size: 32,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.selectCoursesTitle,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.selectCoursesDescription,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 80),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                _ErrorCard(message: _error!, onRetry: _load)
              else if (courses.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 70),
                  child: Center(
                    child: Text(
                      l10n.noCourseOfferingsAvailable,
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else ...[
                Text(
                  '${l10n.selectedCoursesCount}${_selectedOfferingByCourse.length}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                for (final course in courses)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CourseOptionCard(
                      course: course,
                      options: _optionsForCourse(course.courseId),
                      selectedOfferingId:
                          _selectedOfferingByCourse[course.courseId],
                      enabled: !_saving,
                      onChanged: _selectOffering,
                    ),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 54,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(l10n.saveCourses),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseOptionCard extends StatelessWidget {
  const _CourseOptionCard({
    required this.course,
    required this.options,
    required this.selectedOfferingId,
    required this.enabled,
    required this.onChanged,
  });

  final CourseSelectionOption course;
  final List<CourseSelectionOption> options;
  final String? selectedOfferingId;
  final bool enabled;
  final ValueChanged<CourseSelectionOption> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final l10n = AppLocalizations.of(context);
    final selected = selectedOfferingId != null;
    final selectedOption = options.cast<CourseSelectionOption?>().firstWhere(
          (option) => option?.offeringId == selectedOfferingId,
          orElse: () => null,
        );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: selected
            ? primary.withValues(alpha: .07)
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected ? primary : theme.colorScheme.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.menu_book_outlined,
                color: selected
                    ? primary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  course.courseName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            l10n.chooseGroupForCourse,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          DropdownButtonFormField<String>(
            initialValue: selectedOption?.offeringId,
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.groups_rounded),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                ),
              ),
            ),
            hint: Text(l10n.groupLabel),
            items: options.map((option) {
              return DropdownMenuItem<String>(
                value: option.offeringId,
                child: Text(
                  '${l10n.groupLabel} ${option.groupCode}',
                ),
              );
            }).toList(),
            onChanged: !enabled
                ? null
                : (offeringId) {
                    if (offeringId == null) return;
                    final option = options.firstWhere(
                      (item) => item.offeringId == offeringId,
                    );
                    onChanged(option);
                  },
          ),
          if (selectedOption != null &&
              selectedOption.instructor.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              selectedOption.instructor,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 50),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 48),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(AppLocalizations.of(context).retry),
          ),
        ],
      ),
    );
  }
}
