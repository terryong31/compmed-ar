import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';
import 'subjects.dart';
import 'qrscan_page.dart';
import 'notification_page.dart';
import 'profile_page.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  UserDashboardState createState() => UserDashboardState();
}

class UserDashboardState extends State<UserDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomeScreen(),
    const StudentLearningMaterialsPage(),
    const QRScanScreen(),
    const NotificationHome(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _checkAndNavigateToNotifications(); // Check for pending notifications on launch
  }

  void _checkAndNavigateToNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final storedNotifications = prefs.getString('notifications');
    if (storedNotifications != null && jsonDecode(storedNotifications).isNotEmpty) {
      if (kDebugMode) {
        print("Pending notifications found, navigating to Notifications tab");
      }
      setSelectedIndex(3); // Switch to Notifications tab (index 3)
      final notificationState = currentNotificationState;
      if (notificationState != null) {
        notificationState.refreshNotifications();
        if (kDebugMode) {
          print("Refreshed notifications due to pending notifications");
        }
      }
    }
  }

  void setSelectedIndex(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 3 && _pages[index] is NotificationHome) { // Notifications tab
        (currentNotificationState as NotificationHomeState?)?.refreshNotifications();
        if (kDebugMode) {
          print("Refreshed notifications in UserDashboard Notifications tab");
        }
      }
    });
  }

  void _onItemTapped(int index) {
    setSelectedIndex(index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: true,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.purple],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              _getAppBarTitle(),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            centerTitle: true,
          ),
        ),
      ),
      body: SafeArea(child: _pages[_selectedIndex]),
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home, "Home", 0),
            _buildNavItem(Icons.class_rounded, "Subjects", 1),
            const SizedBox(width: 48),
            _buildNavItem(Icons.notifications, "Notifs", 3),
            _buildNavItem(Icons.person, "Profile", 4),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _onItemTapped(2),
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.qr_code_scanner, color: Colors.white),
      ),
    );
  }

  String _getAppBarTitle() {
    switch (_selectedIndex) {
      case 0:
        return 'Home';
      case 1:
        return 'Subjects';
      case 2:
        return 'Scan QR';
      case 3:
        return 'Notifications';
      case 4:
        return 'Profile';
      default:
        return 'CompMed AR';
    }
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    bool isSelected = _selectedIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? Colors.blue : Colors.grey),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.blue : Colors.grey,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}