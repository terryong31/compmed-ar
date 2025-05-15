import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';

// Standalone StatefulWidget for real-time clock (unchanged)
class RealTimeClock extends StatefulWidget {
  const RealTimeClock({super.key});

  @override
  State<RealTimeClock> createState() => _RealTimeClockState();
}

class _RealTimeClockState extends State<RealTimeClock> {
  late String _currentTime;
  late Timer _timer;

  @override
  void initState() {
    super.initState();
    _currentTime = _getCurrentTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = _getCurrentTime();
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  String _getCurrentTime() {
    final now = DateTime.now();
    final formattedTime = DateFormat('EEE, dd MMM yyyy HH:mm:ss').format(now);
    return formattedTime;
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      _currentTime,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        color: Colors.white70,
      ),
    );
  }
}

// Updated HomeScreen to retrieve profile picture from Firebase Firestore
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final FirebaseAuth auth = FirebaseAuth.instance;
    final user = auth.currentUser;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return const Center(child: Text('Error fetching user data.'));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('No user data found.'));
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final String userName = userData['first_name'] ?? 'User';
        final int notificationsCount = userData['notifications'] ?? 0;
        final String? profileImageUrl = userData['profile_image_url']; // Fetch profile image URL from Firestore

        return Scaffold(
          backgroundColor: Colors.white, // Ensures the background color is white as a fallback
          body: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10),
            child: Stack(
              children: [
                // Background image with 60% transparency
                Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: AssetImage('assets/medical_background.png'), // Replace with your image path
                      fit: BoxFit.cover, // Adjusts the image to cover the entire area
                      colorFilter: ColorFilter.mode(
                        Colors.black.withOpacity(0.4), // 60% transparency (40% opacity)
                        BlendMode.dstATop,
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Welcome Card with Firebase profile picture (now scrollable)
                    _buildWelcomeCard(userName, notificationsCount, profileImageUrl, context),
                    const SizedBox(height: 20), // Spacing after welcome card
                    // Side-by-side buttons in a square box (scrollable)
                    _buildSquareButtonRow(context),
                    const SizedBox(height: 20), // Spacing before What's New
                    // What's New section with placeholder images (scrollable)
                    _buildWhatsNewSection(),
                    const SizedBox(height: 20), // Additional space at the bottom
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeCard(String userName, int notificationsCount, String? profileImageUrl, BuildContext context) {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(0), // Remove margin to avoid gap when scrolling
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blueAccent.shade700, Colors.blueAccent.shade100],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome Back, 👋',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.access_alarm_rounded,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 6),
                    RealTimeClock(),
                  ],
                ),
              ],
            ),
            // User profile picture (round border, retrieved from Firebase or default asset)
            Container(
              width: 70,  // Adjust the width as needed
              height: 70, // Adjust the height as needed
              decoration: BoxDecoration(
                shape: BoxShape.circle,  // Makes it circular
                border: Border.all(
                  color: Colors.white38,  // White border color
                  width: 4,  // Adjust the border width as needed
                ),
              ),
              child: CircleAvatar(
                radius: 30,  // Adjust the radius of the CircleAvatar to fit inside the container
                backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                    ? NetworkImage(profileImageUrl) // Load the image from Firebase
                    : AssetImage('assets/default_profile.png') as ImageProvider, // Default image if URL is missing
                backgroundColor: Colors.grey,
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildSquareButtonRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blueAccent, width: 1.5),
        borderRadius: BorderRadius.circular(12),
        color: Colors.blueAccent.withOpacity(0.05), // Subtle background
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildSquareButton(
            context: context,
            icon: Icons.health_and_safety,
            title: '3D Anatomy',
            onTap: () {
              Navigator.pushNamed(context, '/threed_anatomy');
            },
          ),
          _buildSquareButton(
            context: context,
            icon: Icons.assignment,
            title: 'Assessments',
            onTap: () {
              Navigator.pushNamed(context, '/quiz_page');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSquareButton({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.transparent, // No background for individual buttons, just the outer box
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 30,
                color: Colors.blueAccent, // Consistent with CompMed AR theme
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWhatsNewSection() {
    // Mock data for university news (replace with real data from your uni website)
    final List<Map<String, String>> newsItems = [
      {
        'title': 'New AR Lab Opens at QIU',
        'date': 'Feb 25, 2025',
        'description': 'Explore the latest augmented reality facilities for medical students.',
        'image': 'assets/news_placeholder1.png', // Placeholder image for news
      },
      {
        'title': 'QIU Medical Conference 2025',
        'date': 'Mar 10, 2025',
        'description': 'Join us for groundbreaking discussions on medical technology.',
        'image': 'assets/news_placeholder2.png', // Placeholder image for news
      },
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.blueAccent, width: 1),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white, // Clean white background for news section
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What’s New',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 12),
          ...newsItems.map((news) => _buildNewsItem(news)),
        ],
      ),
    );
  }

  Widget _buildNewsItem(Map<String, String> news) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Placeholder image on the left
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              image: DecorationImage(
                image: AssetImage(news['image']!), // Use the news placeholder image
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12), // Spacing between image and text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  news['title']!,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  news['date']!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  news['description']!,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}