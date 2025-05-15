import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  SettingsPageState createState() => SettingsPageState();
}

class SettingsPageState extends State<SettingsPage> {
  bool _isNotificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Load notification preference from SharedPreferences
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isNotificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  // Save notification preference and enable/disable Firebase notifications
  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', _isNotificationsEnabled);

    if (_isNotificationsEnabled) {
      // ✅ Subscribe to Firebase topic & allow token registration
      await FirebaseMessaging.instance.subscribeToTopic('all-users');
      await FirebaseMessaging.instance.setAutoInitEnabled(true); // Ensure notifications are received
      if (kDebugMode) {
        print("✅ Notifications ENABLED: Subscribed to Firebase topic");
      }
    } else {
      // ❌ Completely disable push notifications
      await FirebaseMessaging.instance.unsubscribeFromTopic('all-users');
      await FirebaseMessaging.instance.deleteToken(); // **This stops direct push messages**
      await FirebaseMessaging.instance.setAutoInitEnabled(false); // Prevent re-enabling
      if (kDebugMode) {
        print("❌ Notifications DISABLED: Unsubscribed & Token Deleted");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings", style: TextStyle(fontSize: 20, color: Colors.white)),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Receive push notifications",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Switch(
                  value: _isNotificationsEnabled,
                  onChanged: (bool value) {
                    setState(() {
                      _isNotificationsEnabled = value;
                    });
                    _saveSettings(); // Save setting & update Firebase subscriptions
                  },
                  activeColor: Colors.blue,
                ),
              ],
            ),
            const SizedBox(height: 40),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  "App Version",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  "v1.0",
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
