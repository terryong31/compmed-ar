import 'package:compmedar/user_profile_setup_page.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_login.dart';
import 'user_dashboard.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // While waiting for authentication state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        // If user is not logged in
        if (!snapshot.hasData) {
          User? user = snapshot.data;

          // After user logs in, fetch and store the FCM token
          _fetchAndStoreFcmToken(user);
          return const UserLoginPage();
        }

        // If user is logged in, check Firestore for profile completion
        final User? user = snapshot.data;
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(user?.uid).get(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
              // If the user document doesn't exist, create it with the required fields
              FirebaseFirestore.instance.collection('users').doc(user!.uid).set({
                'email': user.email,
                'status': 'Active',  // Set to Active for new users
                'is_user_profile_completed': 'no',
              });

              return const UserProfileSetupPage();
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>?;

            // Check if the user profile is completed
            if (userData != null && userData['is_user_profile_completed'] != 'yes') {
              return const UserProfileSetupPage();
            }

            // If profile is completed, navigate to dashboard
            return const UserDashboard();
          },
        );
      },
    );
  }
}

// Function to fetch and store the FCM token
Future<void> _fetchAndStoreFcmToken(User? user) async {
  if (user != null) {
    String? token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      // Store the FCM token in Firestore
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'fcm_token': token,
      });
    }
  }
}