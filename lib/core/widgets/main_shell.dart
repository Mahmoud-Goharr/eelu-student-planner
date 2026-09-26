import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../localization/app_localizations.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/courses/presentation/screens/courses_screen.dart';
import '../../features/schedule/presentation/screens/schedule_screen.dart';
import '../../features/settings/presentation/screens/settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class MainShellController extends InheritedWidget {
  const MainShellController({
    required this.onTabSelected,
    required super.child,
    super.key,
  });

  final ValueChanged<int> onTabSelected;

  static MainShellController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MainShellController>();
  }

  @override
  bool updateShouldNotify(MainShellController oldWidget) {
    return onTabSelected != oldWidget.onTabSelected;
  }
}

class _MainShellState extends State<MainShell> {
  int currentIndex = 0;

  final screens = const [
    HomeScreen(),
    CoursesScreen(),
    ScheduleScreen(),
    SettingsScreen(),
  ];

  void _selectTab(int index) {
    setState(() {
      currentIndex = index;
    });
  }

  void _handleBack() {
    if (currentIndex != 0) {
      setState(() {
        currentIndex = 0;
      });
      return;
    }

    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);

    return MainShellController(
      onTabSelected: _selectTab,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) {
            return;
          }

          _handleBack();
        },
        child: Scaffold(
          body: IndexedStack(index: currentIndex, children: screens),
          bottomNavigationBar: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: _selectTab,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home),
                label: localizations.home,
              ),
              NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined),
                selectedIcon: const Icon(Icons.menu_book),
                label: localizations.courses,
              ),
              NavigationDestination(
                icon: const Icon(Icons.calendar_month_outlined),
                selectedIcon: const Icon(Icons.calendar_month),
                label: localizations.calendar,
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: localizations.settings,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
