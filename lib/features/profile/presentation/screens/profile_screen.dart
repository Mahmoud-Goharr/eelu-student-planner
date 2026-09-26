import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/errors/app_error_localizer.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/shimmer/shimmer_card.dart';
import '../../data/models/course_group_selection.dart';
import '../../data/repositories/profile_repository_impl.dart';
import '../viewmodels/profile_cubit.dart';
import '../viewmodels/profile_state.dart';
import 'edit_profile_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          ProfileCubit(repository: ProfileRepositoryImpl())..getProfile(),
      child: const _ProfileView(),
    );
  }
}

class _ProfileView extends StatelessWidget {
  const _ProfileView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(AppLocalizations.of(context).profileTitle)),
      body: SafeArea(
        child: BlocBuilder<ProfileCubit, ProfileState>(
        builder: (context, state) {
          final localizations = AppLocalizations.of(context);

          switch (state.status) {
            case ProfileStatus.initial:
            case ProfileStatus.loading:
              return const ProfileShimmer();

            case ProfileStatus.updating:
              return const Center(child: CircularProgressIndicator());

            case ProfileStatus.failure:
              return _ErrorView(
                message: AppErrorLocalizer.message(
                  context,
                  state.error,
                  fallback: localizations.failedToLoadProfile,
                ),
                onRetry: () {
                  context.read<ProfileCubit>().getProfile();
                },
              );

            case ProfileStatus.success:
            case ProfileStatus.updateSuccess:
              final profile = state.profile;

              if (profile == null) {
                return Center(child: Text(localizations.profileNotFound));
              }

              return _ProfileContent(
                name: profile.name,
                email: profile.email ?? localizations.notSet,
                role: profile.role,
                level: profile.level,
                courseGroups: state.courseGroups,
                avatarUrl: profile.avatarUrl,
              );
          }
        },
      ),
    ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({
    required this.name,
    required this.email,
    required this.role,
    required this.level,
    required this.courseGroups,
    required this.avatarUrl,
  });

  final String name;
  final String email;
  final String role;
  final int? level;
  final List<CourseGroupSelection> courseGroups;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final localizations = AppLocalizations.of(context);

    final hasAvatar = avatarUrl != null && avatarUrl!.trim().isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          CircleAvatar(
            radius: 55,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            backgroundImage: hasAvatar ? NetworkImage(avatarUrl!) : null,
            child: hasAvatar
                ? null
                : Icon(
                    Icons.person,
                    size: 52,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
          ),

          const SizedBox(height: 16),

          Text(
            name,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            role,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 24),

          _InfoCard(
            title: localizations.academicInformationTitle,
            children: [
              _InfoRow(
                icon: Icons.school_outlined,
                title: localizations.university,
                value: 'EELU',
              ),
              _InfoRow(
                icon: Icons.layers_outlined,
                title: localizations.level,
                value: level?.toString() ?? localizations.notSet,
              ),
              _InfoRow(
                icon: Icons.computer_outlined,
                title: localizations.major,
                value: localizations.informationTechnology,
              ),
              if (courseGroups.isEmpty)
                _InfoRow(
                  icon: Icons.groups_outlined,
                  title: localizations.courseGroupsTitle,
                  value: localizations.noCourseGroupsSelected,
                )
              else
                _InfoRow(
                  icon: Icons.groups_outlined,
                  title: localizations.courseGroupsTitle,
                  value: _groupSummary(localizations, courseGroups),
                ),
            ],
          ),

          const SizedBox(height: 16),

          _InfoCard(
            title: localizations.profile,
            children: [
              _InfoRow(
                icon: Icons.person_outline,
                title: localizations.name,
                value: name,
              ),
              _CopyInfoRow(
                icon: Icons.email_outlined,
                title: localizations.email,
                value: email,
              ),
              _InfoRow(
                icon: Icons.badge_outlined,
                title: localizations.role,
                value: role,
              ),
            ],
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => BlocProvider.value(
                      value: context.read<ProfileCubit>(),
                      child: const EditProfileScreen(),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.edit_outlined),
              label: Text(localizations.editProfile),
            ),
          ),
        ],
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _CopyInfoRow extends StatelessWidget {
  const _CopyInfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  Future<void> _copy(BuildContext context) async {
    if (value.trim().isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم نسخ البريد الإلكتروني')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: theme.textTheme.bodyMedium)),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(child: Text(value, textAlign: TextAlign.end, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                IconButton(
                  tooltip: 'نسخ',
                  visualDensity: VisualDensity.compact,
                  onPressed: value == 'غير محدد' ? null : () => _copy(context),
                  icon: const Icon(Icons.copy_outlined, size: 18),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: theme.textTheme.bodyMedium)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context).failedToLoadProfile,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ),
      ),
    );
  }
}
