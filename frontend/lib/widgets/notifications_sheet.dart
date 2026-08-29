import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/notification_item.dart';
import '../theme/app_theme.dart';
import 'empty_state.dart';

class NotificationsSheet extends StatelessWidget {
  const NotificationsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final notifs = provider.notifications;

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Notifications',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    if (provider.unreadNotificationCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentRed,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${provider.unreadNotificationCount} new',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (notifs.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      provider.markAllNotificationsAsRead();
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Divider(),

          // List or Empty
          Expanded(
            child: notifs.isEmpty
                ? const EmptyState(
                    icon: Icons.notifications_off_outlined,
                    title: 'No Notifications Yet',
                    description:
                        'Stay tuned! Important arena match alerts, payouts, and match reminders will appear here.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    itemCount: notifs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (ctx, idx) {
                      final item = notifs[idx];
                      return _buildNotificationCard(context, provider, item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(
      BuildContext context, AppProvider provider, NotificationItem item) {
    Color bg = AppColors.surface;
    Color iconBg = AppColors.surfaceElevated;
    Color iconColor = AppColors.textPrimary;
    IconData icon = Icons.info_outline;

    switch (item.type) {
      case NotificationType.success:
        icon = Icons.check_circle_outline;
        iconColor = AppColors.accentGreen;
        iconBg = AppColors.accentGreenBg;
        break;
      case NotificationType.warning:
        icon = Icons.warning_amber_rounded;
        iconColor = AppColors.accentAmber;
        iconBg = AppColors.accentAmberBg;
        break;
      case NotificationType.win:
        icon = Icons.emoji_events;
        iconColor = AppColors.accentAmber;
        iconBg = AppColors.accentAmberBg;
        break;
      case NotificationType.info:
        icon = Icons.notifications_none;
        iconColor = AppColors.textPrimary;
        iconBg = AppColors.surfaceElevated;
        break;
    }

    return InkWell(
      onTap: () => provider.markNotificationAsRead(item.id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: item.read ? bg : AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: item.read ? AppColors.border : AppColors.primaryLight,
            width: item.read ? 1 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: item.read
                                        ? FontWeight.w700
                                        : FontWeight.w900,
                                  ),
                        ),
                      ),
                      if (!item.read)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.accentAmber,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
