import 'package:flutter/material.dart';

class NotificationsStep extends StatelessWidget {
  final List<String> notifications;
  final void Function(List<String>) onChanged;

  const NotificationsStep({
    super.key,
    required this.notifications,
    required this.onChanged,
  });

  static const List<String> notificationTypes = [
    'None',
    'Meal reminders',
    'Tips',
    'Updates',
    'News',
  ];

  @override
  Widget build(BuildContext context) {
    List<String> selectedNotifications = List.from(notifications);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.notifications, color: Colors.green),
              SizedBox(width: 8),
              Text('Notifications', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 24),
          ...notificationTypes.map((n) => CheckboxListTile(
                value: selectedNotifications.contains(n),
                title: Text(n),
                onChanged: (v) {
                  if (n == 'None') {
                    if (v == true) {
                      selectedNotifications.clear();
                      selectedNotifications.add('None');
                    } else {
                      selectedNotifications.remove('None');
                    }
                  } else {
                    if (v == true) {
                      selectedNotifications.remove('None');
                      selectedNotifications.add(n);
                    } else {
                      selectedNotifications.remove(n);
                    }
                  }
                  onChanged(selectedNotifications);
                },
              )),
        ],
      ),
    );
  }
} 