import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../data/models/notification_model.dart';

class NotificationCard extends StatelessWidget {
  const NotificationCard({
    required this.notification,
    required this.onTap,
    required this.onDelete,
    super.key,
  });
  final NotificationModel notification;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final title = isArabic
        ? (notification.titleAr ?? notification.title)
        : notification.title;
    final body = isArabic
        ? (notification.bodyAr ?? notification.body)
        : notification.body;
    final color = Theme.of(context).colorScheme.primary;
    return Dismissible(
      key: ValueKey(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        alignment: AlignmentDirectional.centerEnd,
        padding: const EdgeInsetsDirectional.only(end: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade400,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: notification.isRead ? 0 : 1,
        color: notification.isRead
            ? Theme.of(context).colorScheme.surface
            : color.withValues(alpha: .08),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          onLongPress: () => _showActions(context, l),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: .14),
                  child: Icon(_icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        body,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface
                              .withValues(alpha: .7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _dateLabel(notification.createdAt, isArabic),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _dateLabel(DateTime date, bool arabic) {
    final value =
        '${date.year}/${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    return arabic ? value : value;
  }

  IconData get _icon => switch (notification.type) {
    NotificationType.exam => Icons.assignment_outlined,
    NotificationType.task => Icons.task_alt,
    NotificationType.quiz => Icons.quiz_outlined,
    NotificationType.lecture => Icons.menu_book_outlined,
    NotificationType.system => Icons.notifications_none,
  };
  void _showActions(BuildContext context, AppLocalizations l) =>
      showModalBottomSheet<void>(
        context: context,
        builder: (_) => SafeArea(
          child: ListTile(
            leading: const Icon(Icons.delete_outline),
            title: Text(l.delete),
            onTap: () {
              Navigator.pop(context);
              onDelete();
            },
          ),
        ),
      );
}
