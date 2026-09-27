import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../exams/data/datasources/exams_remote_data_source.dart';
import '../../../exams/data/repositories/exams_repository_impl.dart';
import '../../../schedule/data/datasources/schedule_remote_data_source.dart';
import '../../../schedule/data/repositories/schedule_repository_impl.dart';
import '../../../schedule/presentation/viewmodels/schedule_cubit.dart';
import '../../../schedule/presentation/viewmodels/schedule_state.dart';
import '../../../tasks/data/datasources/tasks_remote_data_source.dart';
import '../../../tasks/data/repositories/tasks_repository_impl.dart';
import '../viewmodels/home_cubit.dart';
import '../widgets/deadline_overview.dart';
import '../widgets/home_header.dart';
import '../widgets/quick_actions.dart';
import '../widgets/schedule_buttons.dart';
import '../widgets/today_schedule.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheduleRepository = ScheduleRepositoryImpl(
      ScheduleRemoteDataSource(SupabaseService()),
    );

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => HomeCubit(
            tasksRepository: TasksRepositoryImpl(
              TasksRemoteDataSource(SupabaseService()),
            ),
            examsRepository: ExamsRepositoryImpl(
              ExamsRemoteDataSource(SupabaseService()),
            ),
          )..load(),
        ),
        BlocProvider(
          create: (_) => ScheduleCubit(scheduleRepository)..watchSchedule(),
        ),
      ],
      child: const _HomeContent(),
    );
  }
}

class _HomeContent extends StatelessWidget {
  const _HomeContent();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final l10n = AppLocalizations.of(context);

    final primaryColor = theme.colorScheme.primary;
    final textColor = theme.colorScheme.onSurface;
    final secondaryText = textColor.withValues(alpha: .65);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const HomeHeader(),

            const SizedBox(height: 18),

            const DeadlineOverview(),

            const SizedBox(height: 18),

            BlocBuilder<ScheduleCubit, ScheduleState>(
              builder: (context, scheduleState) {
                return TodayScheduleCard(
                  primaryColor: primaryColor,
                  textColor: textColor,
                  secondaryText: secondaryText,
                  schedule: scheduleState.schedule,
                  pauses: scheduleState.pauses,
                  loading:
                      scheduleState.status == ScheduleStatus.initial ||
                      scheduleState.status == ScheduleStatus.loading,
                  hasError: scheduleState.status == ScheduleStatus.failure,
                );
              },
            ),

            const SizedBox(height: 14),

            ScheduleButtons(primaryColor: primaryColor),

            const SizedBox(height: 24),

            Text(
              l10n.quickActions,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: textColor,
              ),
            ),

            const SizedBox(height: 14),

            QuickActions(primaryColor: primaryColor, isDark: isDark),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
