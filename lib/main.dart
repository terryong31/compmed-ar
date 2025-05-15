import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compmedar/qrscan_page.dart';
import 'package:compmedar/quiz_page.dart';
import 'package:compmedar/subjects.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:compmedar/3d_anatomy.dart';
import 'package:compmedar/notification_page.dart'; // Assuming this is where notifications are shown
import 'package:compmedar/skeletal_system.dart';
import 'package:compmedar/human_organs.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:compmedar/auth_wrapper.dart';
import 'package:compmedar/user_profile_setup_page.dart';
import 'package:compmedar/profile_page.dart';
import 'package:google_api_availability/google_api_availability.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  runApp(const MyApp());
}

// ✅ **Fix: Add Background Message Handler as a Top-Level Function**
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print("Background Notification Received: ${message.notification?.title}");
  await _storeNotification(message.notification?.title, message.notification?.body, message.messageId);
}

// ✅ **Fix: Store Notifications Even When the App is Closed**
Future<void> _storeNotification(String? title, String? body, String? messageId) async {
  if (messageId == null) {
    print("Warning: No messageId in notification payload, deduplication may fail");
    return; // Skip if no messageId to avoid duplicates
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

  // Check for duplicates using messageId
  final newNotification = {
    'title': title ?? 'Notification',
    'body': body ?? 'No content available',
    'time': DateTime.now().toString(),
    'messageId': messageId,
  };

  storedNotifications = storedNotifications.where((existing) {
    return existing['messageId'] != newNotification['messageId'];
  }).toList();

  storedNotifications.insert(0, newNotification);

  await prefs.setString('notifications', jsonEncode(storedNotifications));

  // If NotificationHome is open, update the UI immediately
  if (currentNotificationState != null) {
    currentNotificationState!.onNotificationReceived(title, body, messageId);
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  MyAppState createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _setupPushNotifications();
    _checkInitialUser(); // Check user profile on app startup
  }

  void ensureProviderInstaller(BuildContext context) async {
    try {
      final availability = await GoogleApiAvailability.instance.checkGooglePlayServicesAvailability();
      if (availability != GooglePlayServicesAvailability.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google Play Services are not up-to-date.')),
        );
      }
    } catch (e) {
      debugPrint('ProviderInstaller failed: $e');
    }
  }

  // Method to set up push notifications
  Future<void> _setupPushNotifications() async {
    FirebaseMessaging messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await messaging.subscribeToTopic('all-users');

    String? token = await messaging.getToken();
    if (token != null) {
      if (kDebugMode) {
        print("FCM Token: $token");
      }

      // Assuming the user is authenticated
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Store the FCM token in Firestore under the user document
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'fcm_token': token,
        });
      }
    }

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print("Foreground Notification: ${message.notification?.title}");
      _storeNotification(message.notification?.title, message.notification?.body, message.messageId);
    });

    // When the app is opened from a background notification (notification tapped)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("Notification Clicked!");
      _storeNotification(message.notification?.title, message.notification?.body, message.messageId);
    });
  }

  Future<void> _checkInitialUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (!userDoc.exists || userDoc['is_user_profile_completed'] != 'yes') {
        // Redirect to UserProfileSetupPage if profile is not completed
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const UserProfileSetupPage()),
          );
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CompMed AR',
      theme: ThemeData(primarySwatch: Colors.blue),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const AuthWrapper(),
        '/qrscan': (context) => const QRScanScreen(),
        '/subjects': (context) => const StudentLearningMaterialsPage(),
        '/threed_anatomy': (context) => const ThreeDAnatomyPage(),
        '/skeletal_system': (context) => const InteractiveSkeletalPage(),
        '/human_organs': (context) => const OrganModelsPage(),
        '/organ_models': (context) => const OrganModelsPage(),
        '/user_profile_setup_page': (context) => const UserProfileSetupPage(),
        '/profile_page': (context) => const ProfileScreen(),
        '/notification_page': (context) => const NotificationHome(), // Ensure this is correct
        '/quiz_page': (context) => QuizPage(),
      },
    );
  }
}