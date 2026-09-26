import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/egypt_time.dart';
import '../../../../core/widgets/shimmer/shimmer_card.dart';
import '../../data/datasources/exams_remote_data_source.dart';
import '../../data/models/exam_model.dart';
import '../../data/repositories/exams_repository_impl.dart';
import '../viewmodels/exams_cubit.dart';
import '../viewmodels/exams_state.dart';
import '../widgets/exam_card.dart';

class ExamsScreen extends StatelessWidget {
  const ExamsScreen({super.key});

  @override
  Widget build(BuildContext context) => BlocProvider(
        create: (_) => ExamsCubit(
          ExamsRepositoryImpl(
            ExamsRemoteDataSource(SupabaseService()),
          ),
        )..getExams(),
        child: const _ExamsView(),
      );
}

class _ExamsView extends StatefulWidget {
  const _ExamsView();

  @override
  State<_ExamsView> createState() => _ExamsViewState();
}

class _ExamsViewState extends State<_ExamsView> {
  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: BlocConsumer<ExamsCubit, ExamsState>(
            listener: (context, state) {
              final l10n = AppLocalizations.of(context);

              if ({
                ExamsStatus.createSuccess,
                ExamsStatus.updateSuccess,
                ExamsStatus.deleteSuccess,
              }.contains(state.status)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.examSaved),
                  ),
                );
              }

              if (state.errorMessage == 'offline') {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.offlineUsingCachedData),
                  ),
                );
              } else if (state.status == ExamsStatus.failure &&
                  state.errorMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(state.errorMessage!),
                  ),
                );
              }
            },
            builder: (context, state) {
              if (state.status == ExamsStatus.initial ||
                  state.status == ExamsStatus.loading) {
                return const ExamsShimmer();
              }

              final upcoming = _byDate(
                state.exams,
                upcoming: true,
              );

              final past = _byDate(
                state.exams,
                upcoming: false,
              );

              final next = _next(state.exams);
              final l10n = AppLocalizations.of(context);

              return CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 4),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        l10n.examsTitle,
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        l10n.examsSubtitle,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                  ),
                  if (next != null)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                      sliver: SliverToBoxAdapter(
                        child: Card(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          child: ListTile(
                            leading: const Icon(
                              Icons.event_available,
                            ),
                            title: Text(
                              l10n.nextExam,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${next.courseName} • '
                              '${next.date.day}/${next.date.month}/${next.date.year}\n'
                              '${_countdown(next, l10n)}',
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (upcoming.isEmpty && past.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: Text(l10n.noExams),
                      ),
                    )
                  else ...[
                    _sectionHeader(l10n.upcomingExams),
                    _examList(upcoming),
                    _sectionHeader(l10n.pastExams),
                    _examList(past),
                  ],
                ],
              );
            },
          ),
        ),
      );

  SliverPadding _sectionHeader(String title) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        sliver: SliverToBoxAdapter(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      );

  SliverPadding _examList(List<ExamModel> exams) => SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        sliver: SliverList.builder(
          itemCount: exams.length,
          itemBuilder: (_, index) {
            final exam = exams[index];

            return ExamCard(
              exam: exam,
              completed: context
                      .read<ExamsCubit>()
                      .state
                      .completed['exam:${exam.id}'] ??
                  false,
              onCompletionChanged: (value) => context
                  .read<ExamsCubit>()
                  .toggleExamCompletion(exam, value),
              onDetails: () => context.pushNamed(
                'exam-details',
                extra: exam,
              ),
            );
          },
        ),
      );

  List<ExamModel> _byDate(
    List<ExamModel> exams, {
    required bool upcoming,
  }) {
    final now = EgyptTime.now();

    final result = exams
        .where(
          (e) => upcoming
              ? !e.startTime.isBefore(now)
              : !e.startTime.isAfter(now),
        )
        .toList();

    result.sort(
      (a, b) => upcoming
          ? a.startTime.compareTo(b.startTime)
          : b.startTime.compareTo(a.startTime),
    );

    return result;
  }

  String _countdown(
    ExamModel exam,
    AppLocalizations l10n,
  ) {
    final now = EgyptTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final examDay = DateTime(
      exam.date.year,
      exam.date.month,
      exam.date.day,
    );

    final days = examDay.difference(today).inDays;

    if (days == 0) {
      return l10n.today;
    }

    if (days == 1) {
      return l10n.tomorrow;
    }

    return l10n.examDaysLeft(days);
  }

  ExamModel? _next(List<ExamModel> exams) {
    final now = EgyptTime.now();

    final upcoming = exams
        .where(
          (e) => !e.startTime.isBefore(now),
        )
        .toList()
      ..sort(
        (a, b) => a.startTime.compareTo(b.startTime),
      );

    return upcoming.isEmpty ? null : upcoming.first;
  }
}