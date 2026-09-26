import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../notifications/data/datasources/notifications_remote_data_source.dart';
import '../../../notifications/data/repositories/notifications_repository_impl.dart';
import '../../../notifications/presentation/sync/notifications_sync_bus.dart';
import '../../../notifications/presentation/viewmodels/notifications_cubit.dart';
import '../../../notifications/presentation/viewmodels/notifications_state.dart';

import '../../../../core/constants/asset_paths.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/supabase_service.dart';

class HomeHeader extends StatefulWidget {
  const HomeHeader({super.key});

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  late final NotificationsCubit _notificationsCubit;
  StreamSubscription<void>? _notificationsSubscription;

  @override
  void initState() {
    super.initState();

    _notificationsCubit = NotificationsCubit(
      NotificationsRepositoryImpl(
        NotificationsRemoteDataSource(SupabaseService()),
      ),
    );

    _notificationsCubit.load();

    _notificationsSubscription = NotificationsSyncBus.instance.stream.listen((
      _,
    ) {
      if (!mounted) {
        return;
      }

      // Re-read the notification state from Supabase.
      _notificationsCubit.load();
    });
  }

  @override
  void dispose() {
    _notificationsSubscription?.cancel();
    _notificationsCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface.withValues(alpha: .72)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outline.withValues(alpha: .08)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? .08 : .04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          BlocBuilder<NotificationsCubit, NotificationsState>(
            bloc: _notificationsCubit,
            builder: (context, state) {
              final unread = state.unreadCount;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  IconButton(
                    onPressed: () {
                      context.push('/notifications');
                    },
                    tooltip: AppLocalizations.of(context).notifications,
                    style: IconButton.styleFrom(
                      backgroundColor: colorScheme.primary.withValues(
                        alpha: .10,
                      ),
                      foregroundColor: colorScheme.primary,
                      fixedSize: const Size(46, 46),
                    ),
                    icon: const Icon(
                      Icons.notifications_none_rounded,
                      size: 24,
                    ),
                  ),

                  // Red unread badge.
                  if (unread > 0)
                    PositionedDirectional(
                      top: -2,
                      end: -2,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.error,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: colorScheme.onError,
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),

          const Spacer(),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'جدولي',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.0,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'خطتك الدراسية في مكان واحد',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface.withValues(alpha: .58),
                ),
              ),
            ],
          ),

          const SizedBox(width: 12),

          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: .12),
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(AssetPaths.appLogo, fit: BoxFit.cover),
          ),
        ],
      ),
    );
  }
}
