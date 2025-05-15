import 'notification_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  NotificationHomeState? _notificationHomeState;

  void registerNotificationState(NotificationHomeState state) {
    _notificationHomeState = state;
  }

  void unregisterNotificationState() {
    _notificationHomeState = null;
  }

  Future<void> deliverNotification(String? title, String? body, String? messageId) async {
    // Check if NotificationHomeState is available and update it
    if (_notificationHomeState != null) {
      _notificationHomeState!.onNotificationReceived(title, body, messageId ?? DateTime.now().millisecondsSinceEpoch.toString());
      _notificationHomeState!.refreshNotifications(); // Force refresh the UI
    }

    final prefs = await SharedPreferences.getInstance();
    List<Map<String, String>> storedNotifications = [];

    final storedData = prefs.getString('notifications');
    if (storedData != null) {
      List<dynamic> decodedList = jsonDecode(storedData);
      storedNotifications = decodedList.map((item) {
        final Map<String, dynamic> castedItem = item as Map<String, dynamic>;
        return castedItem.map((key, value) => MapEntry(key, value.toString()));
      }).toList();
    }

    final newNotification = {
      'title': title ?? 'Notification',
      'body': body ?? 'No content available',
      'time': DateTime.now().toString(),
      'messageId': messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
    };

    storedNotifications = storedNotifications.where((existing) {
      return existing['messageId'] != newNotification['messageId'];
    }).toList();

    storedNotifications.insert(0, newNotification);

    await prefs.setString('notifications', jsonEncode(storedNotifications));
  }
}