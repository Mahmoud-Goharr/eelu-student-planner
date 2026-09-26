import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_error_localizer.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/shimmer/shimmer_card.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../../data/models/course_group_selection.dart';
import '../viewmodels/profile_cubit.dart';
import '../viewmodels/profile_state.dart';

class AcademicInformationScreen extends StatelessWidget {
  const AcademicInformationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          ProfileCubit(repository: ProfileRepositoryImpl())..getProfile(),
      child: const _AcademicInformationView(),
    );
  }
}

class _AcademicInformationView extends StatelessWidget {
  const _AcademicInformationView();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(localizations.academicInformationTitle)),
      body: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          if (state.status == ProfileStatus.initial ||
              state.status == ProfileStatus.loading) {
            return const AcademicInformationShimmer();
          }
          if (state.status == ProfileStatus.failure) {
            return Center(
              child: Text(
                AppErrorLocalizer.message(
                  context,
                  state.error,
                  fallback: localizations.failedToLoadProfile,
                ),
              ),
            );
          }
          final profile = state.profile;
          if (profile == null) {
            return Center(child: Text(localizations.profileNotFound));
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _AcademicCard(
                title: localizations.university,
                value: 'EELU',
                icon: Icons.school_outlined,
              ),
              _AcademicCard(
                title: localizations.major,
                value: localizations.informationTechnology,
                icon: Icons.computer_outlined,
              ),
              _AcademicCard(
                title: localizations.department,
                value: localizations.department,
                icon: Icons.account_tree_outlined,
              ),
              _AcademicCard(
                title: localizations.level,
                value: profile.level == null
                    ? localizations.notSet
                    : '${localizations.level} ${profile.level}',
                icon: Icons.layers_outlined,
              ),
              _AcademicCard(
                title: localizations.group,
                value: _groupSummary(localizations, state.courseGroups),
                icon: Icons.groups_outlined,
              ),
              _AcademicCard(
                title: localizations.academicYear,
                value: localizations.academicYear,
                icon: Icons.calendar_today_outlined,
              ),
            ],
          );
        },
      ),
    );
  }
}

String _groupSummary(
  AppLocalizations l10n,
  List<CourseGroupSelection> selections,
) {
  final groups = selections
      .map((selection) => selection.groupCode.trim().toUpperCase())
      .where((code) => code.isNotEmpty)
      .toSet()
      .toList()
    ..sort();

  if (groups.isEmpty) return l10n.noCourseGroupsSelected;
  if (groups.length == 1) return '${l10n.group} ${groups.first}';
  return '${l10n.group} ${groups.join(', ')}';
}

class _AcademicCard extends StatelessWidget {
  const _AcademicCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
