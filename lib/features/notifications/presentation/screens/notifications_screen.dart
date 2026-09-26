import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/supabase_service.dart';
import '../../data/datasources/notifications_remote_data_source.dart';
import '../../data/repositories/notifications_repository_impl.dart';
import '../viewmodels/notifications_cubit.dart';
import '../viewmodels/notifications_state.dart';
import '../sync/notifications_sync_bus.dart';
import '../widgets/notification_card.dart';
import '../widgets/notification_skeleton.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => NotificationsCubit(
      NotificationsRepositoryImpl(
        NotificationsRemoteDataSource(SupabaseService()),
      ),
    )..load(),
    child: const _NotificationsContent(),
  );
}

class _NotificationsContent extends StatefulWidget {
  const _NotificationsContent();

  @override
  State<_NotificationsContent> createState() => _NotificationsContentState();
}

class _NotificationsContentState extends State<_NotificationsContent> {
  StreamSubscription<void>? _syncSubscription;

  @override
  void initState() {
    super.initState();

    // If a new notification arrives while this screen is already open,
    // reload it immediately instead of waiting for a restart/manual refresh.
    _syncSubscription = NotificationsSyncBus.instance.stream.listen((_) {
      if (!mounted) return;
      context.read<NotificationsCubit>().load();
    });
  }

  @override
  void dispose() {
    _syncSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.notifications),
        actions: [
          BlocBuilder<NotificationsCubit, NotificationsState>(
            builder: (_, state) => PopupMenuButton<String>(
              onSelected: (value) {
                final cubit = context.read<NotificationsCubit>();
                if (value == 'read') {
                  cubit.markAllRead();
                } else if (state.notifications.isNotEmpty) {
                  _confirmDeleteAll(context, cubit, l);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'read', child: Text(l.markAllRead)),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(l.deleteAllNotifications),
                ),
              ],
            ),
          ),
        ],
      ),
      body: BlocBuilder<NotificationsCubit, NotificationsState>(
        builder: (context, state) {
          if (state.status == NotificationsStatus.loading) {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: 5,
              itemBuilder: (_, index) => const NotificationSkeleton(),
            );
          }
          if (state.status == NotificationsStatus.failure) {
            return Center(child: Text(l.notificationsError));
          }
          return RefreshIndicator(
            onRefresh: context.read<NotificationsCubit>().load,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                SegmentedButton<NotificationsFilter>(
                  segments: [
                    ButtonSegment(
                      value: NotificationsFilter.all,
                      label: Text('${l.all} (${state.notifications.length})'),
                    ),
                    ButtonSegment(
                      value: NotificationsFilter.unread,
                      label: Text('${l.unread} (${state.unreadCount})'),
                    ),
                  ],
                  selected: {state.filter},
                  onSelectionChanged: (s) =>
                      context.read<NotificationsCubit>().setFilter(s.first),
                ),
                const SizedBox(height: 16),
                if (state.visibleNotifications.isEmpty)
                  _EmptyNotifications(filter: state.filter)
                else
                  ...state.visibleNotifications.map(
                    (notification) => NotificationCard(
                      notification: notification,
                      onDelete: () => context.read<NotificationsCubit>().delete(
                        notification.id,
                      ),
                      onTap: () {
                        context.read<NotificationsCubit>().markRead(
                          notification.id,
                        );
                        final route = notification.route;
                        const allowedRoutes = {
                          '/notifications',
                          '/exams',
                          '/lectures',
                          '/profile',
                          '/academic-information',
                          '/course-details',
                          '/task-details',
                          '/quizzes',
                          '/assignments',
                        };
                        if (route != null && allowedRoutes.contains(route)) {
                          context.push(
                            route == '/assignments' ? '/tasks' : route,
                          );
                        }
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _confirmDeleteAll(
    BuildContext context,
    NotificationsCubit cubit,
    AppLocalizations l,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.deleteAllNotifications),
        content: Text(l.deleteAllNotificationsConfirmation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () {
              cubit.deleteAll();
              Navigator.pop(context);
            },
            child: Text(l.delete),
          ),
        ],
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  const _EmptyNotifications({required this.filter});
  final NotificationsFilter filter;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 100),
      child: Center(
        child: Column(
          children: [
            Icon(
              Icons.notifications_off_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.primary
                  .withValues(alpha: .6),
            ),
            const SizedBox(height: 16),
            Text(
              filter == NotificationsFilter.unread
                  ? l.noUnreadNotifications
                  : l.noNotifications,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
