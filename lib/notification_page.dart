import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// Global reference to access the notification state from anywhere
NotificationHomeState? currentNotificationState;

class NotificationHome extends StatefulWidget {
  const NotificationHome({Key? key}) : super(key: key);

  @override
  NotificationHomeState createState() => NotificationHomeState();
}

class NotificationHomeState extends State<NotificationHome> {
  List<Map<String, String>> notifications = [];
  bool _isLoading = false; // Flag to prevent redundant loading

  @override
  void initState() {
    super.initState();
    currentNotificationState = this;
    _loadNotifications(); // Load notifications on initialization
    if (kDebugMode) {
      print("NotificationHome initialized, currentNotificationState set to $this");
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Load or refresh notifications only if not already loading and on app launch
    if (!_isLoading) {
      _loadNotifications();
    }
  }

  @override
  void dispose() {
    if (currentNotificationState == this) {
      currentNotificationState = null;
      if (kDebugMode) {
        print("NotificationHome disposed, currentNotificationState cleared");
      }
    }
    super.dispose();
  }

  // Force refresh notifications, but prevent redundant calls
  void refreshNotifications() {
    if (!_isLoading) {
      _loadNotifications();
      if (kDebugMode) {
        print("Forcing refresh of notifications");
      }
    }
  }

  Future<void> _loadNotifications() async {
    if (_isLoading) return; // Prevent concurrent or redundant loading
    _isLoading = true;
    if (kDebugMode) {
      print("Starting to load notifications...");
    }

    final prefs = await SharedPreferences.getInstance();
    final storedNotifications = prefs.getString('notifications');
    if (storedNotifications != null) {
      List<dynamic> decodedList = jsonDecode(storedNotifications);

      setState(() {
        notifications = decodedList.map((item) {
          final Map<String, dynamic> castedItem = item as Map<String, dynamic>;
          return castedItem.map((key, value) => MapEntry(key, value.toString()));
        }).toList();
      });
    } else {
      setState(() {
        notifications = [];
      });
    }
    _isLoading = false;
    if (kDebugMode) {
      print("Finished loading notifications: $notifications");
    }
  }

  Future<void> _saveNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('notifications', jsonEncode(notifications));
  }

  void onNotificationReceived(String? title, String? body, String? messageId) {
    final String effectiveMessageId = messageId ?? DateTime.now().millisecondsSinceEpoch.toString();

    setState(() {
      final newNotification = {
        'title': title ?? 'Notification',
        'body': body ?? 'No content available',
        'time': DateTime.now().toString(),
        'messageId': effectiveMessageId,
      };

      // Remove duplicates based on messageId
      notifications = notifications.where((existing) {
        return existing['messageId'] != newNotification['messageId'];
      }).toList();

      if (kDebugMode) {
        print("Adding notification: $newNotification");
        print("Current notifications count: ${notifications.length}");
      }

      // Add the new notification
      notifications.insert(0, newNotification);
    });
    _saveNotifications();
  }

  Future<void> _clearAllNotifications() async {
    setState(() {
      notifications.clear();
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notifications');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (notifications.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
            child: Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: _clearAllNotifications,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.delete, color: Colors.redAccent),
                    const SizedBox(width: 6),
                    Text(
                      "Clear All",
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(
          child: notifications.isEmpty
              ? const Center(
            child: Text(
              'No notifications yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notification = notifications[index];
              return _buildNotificationCard(notification);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNotificationCard(Map<String, String> notification) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(
                Icons.notifications_active,
                color: Colors.blueAccent,
                size: 30,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification['title']!,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification['body']!,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                  const SizedBox(height: 6),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      _formatTime(notification['time']!),
                      style: TextStyle(color: Colors.grey[600], fontSize: 12, fontStyle: FontStyle.italic),
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

  String _formatTime(String timeString) {
    final time = DateTime.parse(timeString);
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}