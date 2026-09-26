import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/viewmodels/auth_cubit.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/locale_cubit.dart';
import '../../../../core/theme/theme_cubit.dart';
import '../../../profile/data/models/profile_model.dart';
import '../../../profile/data/models/course_group_selection.dart';
import '../../../profile/data/repositories/profile_repository_impl.dart';
import '../../../profile/presentation/viewmodels/profile_cubit.dart';
import '../../../profile/presentation/viewmodels/profile_state.dart';
import '../viewmodels/settings_cubit.dart';
import '../viewmodels/settings_state.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => SettingsCubit()),
        BlocProvider(
          create: (_) =>
              ProfileCubit(repository: ProfileRepositoryImpl())..getProfile(),
        ),
      ],
      child: const _SettingsContent(),
    );
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onSurface;
    final secondaryText = textColor.withValues(alpha: .6);
    final l10n = AppLocalizations.of(context);
    final darkModeEnabled =
        context.watch<ThemeCubit>().state.themeMode == ThemeMode.dark;

    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settingsState) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.settings,
                style: TextStyle(
                  color: textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                l10n.managePreferences,
                style: TextStyle(color: secondaryText, fontSize: 13),
              ),
              const SizedBox(height: 24),

              BlocBuilder<ProfileCubit, ProfileState>(
                builder: (context, profileState) {
                  return _ProfileCard(
                    primary: primary,
                    profile: profileState.profile,
                    courseGroups: profileState.courseGroups,
                  );
                },
              ),

              const SizedBox(height: 24),
              _SectionTitle(title: l10n.preferences, textColor: textColor),
              const SizedBox(height: 10),
              _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: Icons.notifications_none_rounded,
                    iconColor: Colors.orange,
                    title: l10n.notifications,
                    subtitle: l10n.receiveReminders,
                    trailing: Switch(
                      value: settingsState.notificationsEnabled,
                      activeThumbColor: primary,
                      onChanged: context
                          .read<SettingsCubit>()
                          .setNotificationsEnabled,
                    ),
                  ),
                  const _Divider(),
                  _SettingsTile(
                    icon: Icons.dark_mode_outlined,
                    iconColor: Colors.deepPurple,
                    title: l10n.darkMode,
                    subtitle: l10n.useDarkAppearance,
                    trailing: Switch(
                      value: darkModeEnabled,
                      activeThumbColor: primary,
                      onChanged: (value) {
                        context.read<ThemeCubit>().setThemeMode(
                          value ? ThemeMode.dark : ThemeMode.light,
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _SectionTitle(title: l10n.account, textColor: textColor),
              const SizedBox(height: 10),
              _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: Icons.person_outline_rounded,
                    iconColor: Colors.blue,
                    title: l10n.profile,
                    subtitle: l10n.editPersonalInformation,
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                    ),
                    onTap: () => context.push('/profile'),
                  ),
                  const _Divider(),
                  BlocBuilder<ProfileCubit, ProfileState>(
                    builder: (context, profileState) {
                      final profile = profileState.profile;

                      final academicSubtitle = profile == null
                          ? l10n.levelAndGroup
                          : '${l10n.level} ${profile.level ?? l10n.notSet} • '
                                '${_groupSummary(l10n, profileState.courseGroups)}';

                      return _SettingsTile(
                        icon: Icons.school_outlined,
                        iconColor: Colors.green,
                        title: l10n.academicInformation,
                        subtitle: academicSubtitle,
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                        ),
                        onTap: () => context.push('/academic-information'),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              _SectionTitle(title: l10n.general, textColor: textColor),
              const SizedBox(height: 10),
              _SettingsCard(
                children: [
                  _SettingsTile(
                    icon: Icons.language_rounded,
                    iconColor: Colors.cyan,
                    title: l10n.language,
                    subtitle:
                        context
                                .watch<LocaleCubit>()
                                .state
                                .locale
                                .languageCode ==
                            'ar'
                        ? l10n.arabic
                        : l10n.english,
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                    ),
                    onTap: () => _selectLanguage(context),
                  ),
                  const _Divider(),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    iconColor: Colors.blueGrey,
                    title: l10n.aboutApp,
                    subtitle: l10n.appName,
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                    ),
                    onTap: () => context.push('/about'),
                  ),
                  const _Divider(),
                  _SettingsTile(
                    icon: Icons.link_rounded,
                    iconColor: Colors.indigo,
                    title: l10n.contactAndLinks,
                    subtitle: l10n.contactAndLinksTitle,
                    trailing: const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                    ),
                    onTap: () => context.push('/contact'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _LogoutButton(label: l10n.logout),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectLanguage(BuildContext context) async {
    final localeCubit = context.read<LocaleCubit>();
    final selected = await showModalBottomSheet<Locale>(
      context: context,
      builder: (context) {
        final current = localeCubit.state.locale.languageCode;

        return SafeArea(
          child: RadioGroup<Locale>(
            groupValue: Locale(current),
            onChanged: (value) => Navigator.pop(context, value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Radio<Locale>(value: Locale('en')),
                  title: Text(AppLocalizations.of(context).english),
                  onTap: () => Navigator.pop(context, const Locale('en')),
                ),
                ListTile(
                  leading: const Radio<Locale>(value: Locale('ar')),
                  title: Text(AppLocalizations.of(context).arabic),
                  onTap: () => Navigator.pop(context, const Locale('ar')),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selected != null) {
      await localeCubit.setLocale(selected);
    }
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

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.primary,
    required this.profile,
    required this.courseGroups,
  });

  final Color primary;
  final ProfileModel? profile;
  final List<CourseGroupSelection> courseGroups;

  String _profileSubtitle(AppLocalizations l10n, ProfileModel? profile) {
    if (profile == null) {
      return l10n.levelAndGroup;
    }

    final level = '${l10n.level} ${profile.level ?? l10n.notSet}';
    return '$level • ${_groupSummary(l10n, courseGroups)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final avatarUrl = profile?.avatarUrl;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [primary, Color.lerp(primary, Colors.blue, .35)!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: .18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white.withValues(alpha: .18),
            backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                ? NetworkImage(avatarUrl)
                : null,
            child: avatarUrl == null || avatarUrl.isEmpty
                ? const Icon(Icons.person, color: Colors.white, size: 30)
                : null,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile?.name ?? l10n.student,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _profileSubtitle(l10n, profile),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          InkWell(
            borderRadius: BorderRadius.circular(13),
            onTap: () => context.push('/profile'),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .15),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.edit_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.textColor});

  final String title;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: textColor,
        fontSize: 18,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: textColor.withValues(alpha: .5),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 70,
      endIndent: 14,
      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .06),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => context.read<AuthCubit>().signOut(),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded, color: Colors.red, size: 21),
            const SizedBox(width: 9),
            Text(
              label,
              style: TextStyle(
                color: Colors.red.shade600,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
