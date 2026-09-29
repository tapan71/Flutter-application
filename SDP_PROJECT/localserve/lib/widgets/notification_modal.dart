import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/notification_model.dart';
import '../services/database_service.dart';
import '../screens/service_details_screen.dart';

class NotificationModal extends StatelessWidget {
  final AppUser currentUser;

  const NotificationModal({super.key, required this.currentUser});

  static void show(BuildContext context, {required AppUser currentUser}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NotificationModal(currentUser: currentUser),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case 'worker_applied':
        return Icons.handyman;
      case 'customer_accepted':
        return Icons.verified;
      case 'worker_rejected':
        return Icons.person_remove_outlined;
      case 'job_completed':
        return Icons.task_alt;
      case 'review_received':
        return Icons.star;
      default:
        return Icons.notifications;
    }
  }

  Color _getColorForType(String type, BuildContext context) {
    switch (type) {
      case 'worker_applied':
        return Colors.blue;
      case 'customer_accepted':
        return Colors.green;
      case 'worker_rejected':
        return Colors.orange;
      case 'job_completed':
        return Colors.teal;
      case 'review_received':
        return Colors.amber.shade800;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dbService = context.watch<DatabaseService>();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.notifications_active_outlined),
                        const SizedBox(width: 8),
                        const Text(
                          'Notifications',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () async {
                        await dbService.markAllNotificationsAsRead(currentUser.uid);
                      },
                      child: const Text('Mark all as read'),
                    ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Notifications List
              Expanded(
                child: StreamBuilder<List<AppNotification>>(
                  stream: dbService.streamNotifications(currentUser.uid),
                  builder: (context, snapshot) {
                    final notifs = snapshot.data ?? dbService.getNotifications(currentUser.uid);

                    if (notifs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_none,
                              size: 56,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'No notifications yet',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              currentUser.isWorker
                                  ? 'You will be notified when customers confirm your applications.'
                                  : 'You will be notified when workers accept your service requests.',
                              style: const TextStyle(color: Colors.grey, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: notifs.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final notif = notifs[index];
                        final color = _getColorForType(notif.type, context);

                        return ListTile(
                          tileColor: notif.isRead
                              ? null
                              : theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: 0.15),
                            child: Icon(_getIconForType(notif.type), color: color, size: 20),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  notif.title,
                                  style: TextStyle(
                                    fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              if (!notif.isRead)
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(notif.message, style: const TextStyle(fontSize: 13)),
                              const SizedBox(height: 4),
                              Text(
                                '${notif.createdAt.hour.toString().padLeft(2, "0")}:${notif.createdAt.minute.toString().padLeft(2, "0")} • ${notif.createdAt.day}/${notif.createdAt.month}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          onTap: () async {
                            await dbService.markNotificationAsRead(notif.id);
                            if (notif.requestId != null && context.mounted) {
                              final req = dbService.allRequests
                                  .where((r) => r.id == notif.requestId)
                                  .firstOrNull;
                              if (req != null) {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ServiceDetailsScreen(
                                      request: req,
                                      currentUser: currentUser,
                                    ),
                                  ),
                                );
                              }
                            }
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
