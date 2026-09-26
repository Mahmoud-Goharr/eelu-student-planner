import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/widgets/main_shell.dart';
import '../../../lecture_progress/presentation/screens/lecture_progress_screen.dart';
import '../../../tasks/presentation/screens/tasks_screen.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({
    required this.primaryColor,
    required this.isDark,
    super.key,
  });

  final Color primaryColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final actions = [
      QuickActionItem(
        title: AppLocalizations.of(context).scheduleLabel,
        icon: Icons.bar_chart_rounded,
        iconColor: Colors.blue,
        primaryColor: primaryColor,
        isDark: isDark,
        onTap: () => MainShellController.maybeOf(context)?.onTabSelected(2),
      ),
      QuickActionItem(
        title: AppLocalizations.of(context).examsLabel,
        icon: Icons.assignment_rounded,
        iconColor: Colors.deepOrange,
        primaryColor: primaryColor,
        isDark: isDark,
        onTap: () => context.push('/exams'),
      ),
      QuickActionItem(
        title: AppLocalizations.of(context).tasksLabel,
        icon: Icons.description_rounded,
        iconColor: Colors.deepPurple,
        primaryColor: primaryColor,
        isDark: isDark,
        onTap: () => _openScreen(context, const TasksScreen()),
      ),
      QuickActionItem(
        title: AppLocalizations.of(context).quizzesLabel,
        icon: Icons.quiz_rounded,
        iconColor: Colors.deepOrange,
        primaryColor: primaryColor,
        isDark: isDark,
        onTap: () => _openScreen(
          context,
          const TasksScreen(initialTypeFilter: 'Quizzes', quizOnly: true),
        ),
      ),
      QuickActionItem(
        title: AppLocalizations.of(context).coursesLabel,
        icon: Icons.storefront_rounded,
        iconColor: Colors.green,
        primaryColor: primaryColor,
        isDark: isDark,
        onTap: () => MainShellController.maybeOf(context)?.onTabSelected(1),
      ),
      QuickActionItem(
        title: AppLocalizations.of(context).lecturesLabel,
        icon: Icons.menu_book_rounded,
        iconColor: Colors.teal,
        primaryColor: primaryColor,
        isDark: isDark,
        onTap: () => context.push('/lectures'),
      ),
      QuickActionItem(
        title: AppLocalizations.of(context).profile,
        icon: Icons.person_rounded,
        iconColor: Colors.orange,
        primaryColor: primaryColor,
        isDark: isDark,
        onTap: () => context.push('/profile'),
      ),
      QuickActionItem(
        title: AppLocalizations.of(context).lectureProgress,
        icon: Icons.task_alt_rounded,
        iconColor: Colors.cyan,
        primaryColor: primaryColor,
        isDark: isDark,
        onTap: () => _openScreen(context, const LectureProgressScreen()),
      ),
      QuickActionItem(
        title: isArabic(context)
            ? 'المنتهي'
            : 'Completed',
        icon: Icons.history_rounded,
        iconColor: Colors.brown,
        primaryColor: primaryColor,
        isDark: isDark,
        onTap: () => context.push('/completed-assessments'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 360 ? 3 : 4;

        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 10,
          childAspectRatio: columns == 3 ? 1.0 : .82,
          children: actions,
        );
      },
    );
  }

  bool isArabic(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'ar';

  void _openScreen(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

class QuickActionItem extends StatelessWidget {
  const QuickActionItem({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.primaryColor,
    required this.isDark,
    this.onTap,
    super.key,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Color primaryColor;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF101D30) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: .04)
                  : Colors.grey.withValues(alpha: .08),
            ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: Colors.black.withValues(alpha: .025),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(height: 9),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
