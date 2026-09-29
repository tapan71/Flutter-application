import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../models/notification_model.dart';
import '../services/database_service.dart';
import 'notification_modal.dart';

class NotificationBadgeButton extends StatelessWidget {
  final AppUser user;

  const NotificationBadgeButton({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final dbService = context.watch<DatabaseService>();

    return StreamBuilder<List<AppNotification>>(
      stream: dbService.streamNotifications(user.uid),
      builder: (context, snapshot) {
        final notifs = snapshot.data ?? dbService.getNotifications(user.uid);
        final unreadCount = notifs.where((n) => !n.isRead).length;

        return IconButton(
          tooltip: 'Notifications',
          icon: Badge(
            isLabelVisible: unreadCount > 0,
            label: Text('$unreadCount'),
            child: const Icon(Icons.notifications_outlined),
          ),
          onPressed: () {
            NotificationModal.show(context, currentUser: user);
          },
        );
      },
    );
  }
}
