import 'dart:developer' as developer; // Add this import for logging
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:compmedar/user_profile_setup_page.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:compmedar/user_dashboard.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                color: Color(0xFF4CAF50), // Medical-themed green for loading
              ),
            ),
          );
        } else if (snapshot.hasData) {
          return const UserDashboard();
        } else {
          return const UserLoginPage();
        }
      },
    );
  }
}

class UserLoginPage extends StatefulWidget {
  const UserLoginPage({super.key});

  @override
  State<UserLoginPage> createState() => _UserLoginPageState();
}

class _UserLoginPageState extends State<UserLoginPage> {
  bool isLoading = false;
  String errorMessage = '';

  Future<void> _signInWithGoogle() async {
    setState(() {
      isLoading = true;
      errorMessage = '';
    });

    try {
      await GoogleSignIn().signOut(); // Clear previous session

      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() {
          errorMessage = 'Login cancelled by user.';
          isLoading = false;
        });
        developer.log('Google Sign-In cancelled by user.', name: 'Auth');
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        // Log successful sign-in
        developer.log('User signed in: ${user.email}, UID: ${user.uid}', name: 'Auth');

        // Check if the email is from "qiu.edu.my"
        // if (!user.email!.endsWith('@qiu.edu.my')) {
        //   setState(() {
        //     errorMessage = 'Only @qiu.edu.my accounts are allowed.';
        //     isLoading = false;
        //   });
        //   developer.log('Unauthorized domain: ${user.email}', name: 'Auth');
        //   await FirebaseAuth.instance.signOut(); // Sign out the user if not allowed
        //   return;
        // }

        // Fetch the user's Firestore document
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        developer.log('Fetched user document for UID: ${user.uid}, exists: ${userDoc.exists}', name: 'Firestore');

        if (userDoc.exists) {
          final userData = userDoc.data();
          developer.log('User data: $userData', name: 'Firestore');

          // Check if the user profile is completed
          if (userData != null && userData['is_user_profile_completed'] != 'yes') {
            developer.log('Profile incomplete, redirecting to setup page', name: 'Navigation');
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const UserProfileSetupPage()),
            );
          } else {
            developer.log('Profile complete, redirecting to dashboard', name: 'Navigation');
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const UserDashboard()),
            );
          }
        } else {
          // New user, no document exists
          developer.log('New user detected, redirecting to profile setup', name: 'Firestore');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const UserProfileSetupPage()),
          );
        }

        // Save the user's email and status to Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {
            'email': user.email,
            'status': 'Active',
            'last_login': DateTime.now(),
          },
          SetOptions(merge: true),
        );
        developer.log('User data saved to Firestore for UID: ${user.uid}', name: 'Firestore');

        // Retrieve and store FCM token
        String? fcmToken = await FirebaseMessaging.instance.getToken();
        if (fcmToken != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
            {'fcm_token': fcmToken},
          );
          developer.log('FCM token stored: $fcmToken', name: 'FCM');
        } else {
          developer.log('FCM token retrieval failed', name: 'FCM', level: 900); // Warning level
        }

        // Save login status locally
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        developer.log('Login status saved locally', name: 'SharedPreferences');
      }
    } catch (e, stackTrace) {
      // Log the error with stack trace for debugging
      developer.log(
        'Login failed',
        name: 'Auth',
        error: e,
        stackTrace: stackTrace,
        level: 1000, // Error level
      );

      // Set a user-friendly error message based on the exception type
      String detailedErrorMessage;
      if (e is FirebaseAuthException) {
        detailedErrorMessage = 'Authentication error: ${e.message} (Code: ${e.code})';
      } else if (e is FirebaseException) {
        detailedErrorMessage = 'Firestore error: ${e.message} (Code: ${e.code})';
      } else if (e is PlatformException) {
        detailedErrorMessage = 'Platform error: ${e.message} (Code: ${e.code})';
        if (e.code == 'sign_in_failed' && e.message?.contains('ApiException: 10') == true) {
          detailedErrorMessage += '\nThis is likely a configuration issue (SHA-1 fingerprint or OAuth Client ID mismatch). Check Firebase/Google Cloud Console.';
        }
      } else {
        detailedErrorMessage = 'Unexpected error: $e';
      }

      // Only call setState if the widget is still mounted
      if (mounted) {
        setState(() {
          errorMessage = 'Login failed: $detailedErrorMessage';
        });
      }
    } finally {
      // Only call setState if the widget is still mounted
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background image with 60% transparency
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/background_image.png'),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.1),
                  BlendMode.dstATop,
                ),
              ),
            ),
          ),

          // Background decorations (blue clouds in corners)
          Positioned(
            top: -100,
            right: -70,
            child: Container(
              width: 240,
              height: 240,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue,
              ),
            ),
          ),
          Positioned(
            top: -60,
            right: 120,
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue,
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -70,
            child: Container(
              width: 240,
              height: 240,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue,
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            right: 150,
            child: Container(
              width: 120,
              height: 120,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue,
              ),
            ),
          ),

          // Main content (centered login page)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon
                  Container(
                    padding: const EdgeInsets.all(15),
                    child: Image.asset(
                      'assets/icon2.png',
                      width: 100,
                      height: 100,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Welcome Message
                  const Text(
                    'Welcome to CompMed AR',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Explore the human body in augmented reality.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Color(0xFF777777),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),

                  // Error Message
                  if (errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        errorMessage,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // Google Sign-In Button
                  isLoading
                      ? const CircularProgressIndicator(
                    color: Color(0xFFADD8E6),
                    strokeWidth: 5.0,
                  )
                      : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: const BorderSide(
                          color: Color(0xFFADD8E6),
                          width: 2,
                        ),
                      ),
                      elevation: 5,
                    ),
                    onPressed: _signInWithGoogle,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Image.asset(
                            'assets/google_logo.png',
                            height: 24,
                            width: 24,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'Sign in with Google',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF68bbe3),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Text(
                    'Only @qiu.edu.my accounts are allowed.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}