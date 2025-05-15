import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

class StudentLearningMaterialsPage extends StatelessWidget {
  const StudentLearningMaterialsPage({super.key});

  Future<List<String>> getUserSubjects() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final userDoc = await userRef.get();

    if (userDoc.exists) {
      return List<String>.from(userDoc['subjects'] ?? []);
    }
    return [];
  }

  void _showAddSubjectDialog(BuildContext context) {
    TextEditingController subjectController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Subject"),
          content: TextField(
            controller: subjectController,
            decoration: const InputDecoration(hintText: "Enter subject code"),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                String subjectCode = subjectController.text.trim();
                if (subjectCode.isNotEmpty) {
                  await _addSubjectToFirestore(subjectCode, context);
                  Navigator.pop(context);
                }
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _addSubjectToFirestore(String subjectCode, BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Reference to the subjects collection
    final subjectsRef = FirebaseFirestore.instance.collection('subjects');

    // Check if the subject exists in the 'subjects' collection
    final subjectDoc = await subjectsRef.doc(subjectCode).get();

    if (!subjectDoc.exists) {
      // Notify user that the subject doesn't exist with floating behavior, overlapping the button
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Subject does not exist. Please check the subject code.'),
          behavior: SnackBarBehavior.floating, // Make SnackBar float above UI
          margin: const EdgeInsets.only(bottom: 0.0), // Reduced margin to allow overlap with the button
        ),
      );
      return;
    }

    // If subject exists, proceed with adding it to user's subjects
    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final userDoc = await userRef.get();

    if (userDoc.exists) {
      // Get the current subjects list or initialize it if it doesn't exist
      final subjects = List<String>.from(userDoc.data()?['subjects'] ?? []);

      if (!subjects.contains(subjectCode)) {
        subjects.add(subjectCode);
        await userRef.update({'subjects': subjects});

        // Show success message with floating behavior, overlapping the button
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Subject added successfully!'),
            behavior: SnackBarBehavior.floating, // Make SnackBar float above UI
            margin: const EdgeInsets.only(bottom: 0.0), // Reduced margin to allow overlap with the button
          ),
        );
      } else {
        // Show already exists message with floating behavior, overlapping the button
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Subject already exists.'),
            behavior: SnackBarBehavior.floating, // Make SnackBar float above UI
            margin: const EdgeInsets.only(bottom: 0.0), // Reduced margin to allow overlap with the button
          ),
        );
      }
    } else {
      // If user document doesn't exist, create it with subjects
      await userRef.set({
        'email': user.email,
        'subjects': [subjectCode], // Initialize subjects with the first added subject
        'status': 'Active',
        'is_user_profile_completed': 'no',
      });

      // Show success message with floating behavior, overlapping the button
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Subject added successfully!'),
          behavior: SnackBarBehavior.floating, // Make SnackBar float above UI
          margin: const EdgeInsets.only(bottom: 0.0), // Reduced margin to allow overlap with the button
        ),
      );
    }
  }

  // Function to delete subject
  Future<void> _deleteSubject(BuildContext context, String subjectCode) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final userDoc = await userRef.get();

    if (userDoc.exists) {
      final subjects = List<String>.from(userDoc['subjects'] ?? []);
      subjects.remove(subjectCode);
      await userRef.update({'subjects': subjects});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Subject deleted successfully!'),
          behavior: SnackBarBehavior.floating, // Make SnackBar float above UI
          margin: const EdgeInsets.only(bottom: 0.0), // Reduced margin to allow overlap with the button
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: getUserSubjects(),
      builder: (context, userSubjectsSnapshot) {
        if (userSubjectsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!userSubjectsSnapshot.hasData || userSubjectsSnapshot.data!.isEmpty) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'No subjects scanned yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => _showAddSubjectDialog(context),
                    child: const Text('Add Subject'),
                  ),
                ],
              ),
            ),
          );
        }

        final userSubjects = userSubjectsSnapshot.data!;
        CollectionReference subjectsRef = FirebaseFirestore.instance.collection('subjects');

        return Scaffold(
          body: StreamBuilder<QuerySnapshot>(
            stream: subjectsRef.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    "No subjects found.",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                );
              }

              final subjects = snapshot.data!.docs.where((subject) => userSubjects.contains(subject.id)).toList();

              if (subjects.isEmpty) {
                return const Center(
                  child: Text(
                    "No subjects scanned yet.",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                itemCount: subjects.length,
                itemBuilder: (context, index) {
                  final subjectDoc = subjects[index];
                  final subjectName = subjectDoc['name'] ?? 'Unnamed Subject';
                  final subjectPreviewImage = subjectDoc['previewImage'] ?? '';  // Fetch the preview image URL

                  return GestureDetector(
                    onLongPress: () {
                      // Confirm delete
                      showDialog(
                        context: context,
                        builder: (context) {
                          return AlertDialog(
                            title: const Text('Delete Subject'),
                            content: const Text('Are you sure you want to delete this subject?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                onPressed: () async {
                                  await _deleteSubject(context, subjectDoc.id);
                                  Navigator.pop(context);
                                },
                                child: const Text('Delete'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    child: Card(
                      margin: const EdgeInsets.all(10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          children: [
                            // Display preview image
                            if (subjectPreviewImage.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  subjectPreviewImage,
                                  height: 80,
                                  width: 80,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    subjectName,
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton(
                                    onPressed: () {
                                      final String subjectId = subjectDoc.id;
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => TopicsListPage(
                                            subjectId: subjectId,
                                            subjectName: subjectName,
                                          ),
                                        ),
                                      );
                                    },
                                    child: const Text('View Subject'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            heroTag: 'addSubjectButton',  // Assign a unique tag
            onPressed: () => _showAddSubjectDialog(context),
            backgroundColor: Colors.white,
            child: const Icon(Icons.add, color: Colors.blueAccent, size: 32),
          ),
        );
      },
    );
  }
}

class TopicsListPage extends StatelessWidget {
  final String subjectId;
  final String subjectName;

  const TopicsListPage({super.key, required this.subjectId, required this.subjectName});

  @override
  Widget build(BuildContext context) {
    CollectionReference topicsRef = FirebaseFirestore.instance.collection('subjects').doc(subjectId).collection('topics');

    return Scaffold(
      appBar: AppBar(
        title: Text(subjectName, style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,  // Set the app bar color to blue
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: topicsRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final topics = snapshot.data!.docs;

          return ListView.builder(
            itemCount: topics.length,
            itemBuilder: (context, index) {
              final topicDoc = topics[index];
              final String topicId = topicDoc.id;
              final String topicName = topicDoc['name'] ?? 'Unknown Topic';

              return Card(
                margin: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                color: Colors.blue.shade50, // Set a light blue background for the card
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  title: Text(
                    topicName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black, // Set the topic name color to blue
                    ),
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.blue, // Set the arrow icon color to blue
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TopicContentPage(
                          subjectId: subjectId,
                          topicId: topicId,
                          topicName: topicName,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class TopicContentPage extends StatefulWidget {
  final String subjectId;
  final String topicId;
  final String topicName;

  const TopicContentPage({
    super.key,
    required this.subjectId,
    required this.topicId,
    required this.topicName,
  });

  @override
  TopicContentPageState createState() => TopicContentPageState();
}

class TopicContentPageState extends State<TopicContentPage> {
  String topicText = "Loading content...";
  String? documentUrl;
  String? videoUrl;
  List<String> images = [];

  @override
  void initState() {
    super.initState();
    fetchTopicContent();
  }

  Future<void> fetchTopicContent() async {
    final topicRef = FirebaseFirestore.instance
        .collection('subjects')
        .doc(widget.subjectId)
        .collection('topics')
        .doc(widget.topicId);

    final topicDoc = await topicRef.get();
    final Map<String, dynamic>? topicDetails = topicDoc.data() as Map<String, dynamic>?;

    if (topicDetails != null) {
      // Load description text from file
      final String? descriptionUrl = topicDetails['description'];
      if (descriptionUrl != null && descriptionUrl.isNotEmpty) {
        try {
          final response = await http.get(Uri.parse(descriptionUrl));
          if (response.statusCode == 200) {
            setState(() {
              topicText = response.body;
            });
          } else {
            setState(() {
              topicText = "Failed to load content.";
            });
          }
        } catch (e) {
          setState(() {
            topicText = "Error loading content.";
          });
        }
      } else {
        setState(() {
          topicText = "No description available.";
        });
      }

      // Load video URL, document URL, and images
      setState(() {
        videoUrl = topicDetails['video'];
        documentUrl = topicDetails['document'];
        images = topicDetails['images'] != null ? List<String>.from(topicDetails['images']) : [];
      });
    }
  }

  void _downloadDocument() async {
    if (documentUrl != null && documentUrl!.isNotEmpty) {
      final Uri url = Uri.parse(documentUrl!);
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open document')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Clean, bright background
      appBar: AppBar(
        title: Text(
          widget.topicName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: Colors.blue, // Richer blue for branding
        elevation: 4, // Slight shadow for depth
      ),
      body: Stack(
        children: [
          // Main scrollable content with a gradient background for depth
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.blueAccent[100]!.withOpacity(0.1),
                  Colors.white,
                ],
              ),
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Animated Video Section (with fade-in animation)
                  if (videoUrl != null && videoUrl!.isNotEmpty)
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 500),
                      opacity: 1.0,
                      child: Container(
                        width: double.infinity,
                        height: 250, // Slightly larger for better visibility
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              offset: const Offset(0, 0),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: VideoWidget(videoUrl: videoUrl!),
                        ),
                      ),
                    ),
                  const SizedBox(height: 1),

                  // Topic Description with Styling
                  Text(
                    topicText,
                    textAlign: TextAlign.justify,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.5,
                      color: Colors.black87,
                      fontFamily: 'Roboto', // Modern font for readability
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Images Section with Animated Cards
                  if (images.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Related Images',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.blueAccent,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...images.map((imageUrl) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  imageUrl,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      height: 200,
                                      color: Colors.grey[300],
                                      child: const Center(
                                        child: Text(
                                          'Image failed to load',
                                          style: TextStyle(color: Colors.black54),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ],
                    ),
                  const SizedBox(height: 80), // Extra space for the button
                ],
              ),
            ),
          ),

          // Floating Download Button (Animated)
          if (documentUrl != null && documentUrl!.isNotEmpty)
            Positioned(
              bottom: 20,
              right: 20,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: 1.0,
                child: ElevatedButton.icon(
                  onPressed: _downloadDocument,
                  icon: const Icon(Icons.download, color: Colors.white),
                  label: const Text(
                    "Download Document",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent[700],
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 6, // Slight shadow for depth
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Keep the VideoWidget and FullScreenVideo classes as they are, or update them similarly for consistency.

class VideoWidget extends StatefulWidget {
  final String videoUrl;

  const VideoWidget({super.key, required this.videoUrl});

  @override
  VideoWidgetState createState() => VideoWidgetState();
}

class VideoWidgetState extends State<VideoWidget> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      _isPlaying ? _controller.play() : _controller.pause();
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _toggleControls, // Show/hide controls on tap
          child: Container(
            width: double.infinity, // Take full width
            height: 220, // Fixed height like movie sites
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black,
            ),
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Video Player
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: _controller.value.aspectRatio,
                    child: VideoPlayer(_controller),
                  ),
                ),

                // Play/Pause Icon (Center)
                if (_showControls)
                  Positioned(
                    child: GestureDetector(
                      onTap: _togglePlayPause,
                      child: Icon(
                        _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                        color: Colors.white,
                        size: 50,
                      ),
                    ),
                  ),

                // Bottom Controls
                if (_showControls)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Play Button
                          IconButton(
                            icon: Icon(
                              _isPlaying ? Icons.pause : Icons.play_arrow,
                              color: Colors.white,
                            ),
                            onPressed: _togglePlayPause,
                          ),

                          // Progress Bar
                          Expanded(
                            child: VideoProgressIndicator(
                              _controller,
                              allowScrubbing: true,
                              colors: VideoProgressColors(
                                playedColor: Colors.red,
                                bufferedColor: Colors.grey,
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ),

                          // Full Screen Button
                          IconButton(
                            icon: const Icon(Icons.fullscreen, color: Colors.white),
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => FullScreenVideo(videoUrl: widget.videoUrl),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class FullScreenVideo extends StatefulWidget {
  final String videoUrl;

  const FullScreenVideo({super.key, required this.videoUrl});

  @override
  FullScreenVideoState createState() => FullScreenVideoState();
}

class FullScreenVideoState extends State<FullScreenVideo> {
  late VideoPlayerController _controller;
  bool _isPlaying = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        setState(() {
          _controller.play();
          _isPlaying = true;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      _isPlaying = !_isPlaying;
      _isPlaying ? _controller.play() : _controller.pause();
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Full-Screen Video
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),

            // Play/Pause Button
            if (_showControls)
              Positioned(
                child: GestureDetector(
                  onTap: _togglePlayPause,
                  child: Icon(
                    _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              ),

            // Bottom Controls (Progress Bar, Exit Button)
            if (_showControls)
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Column(
                  children: [
                    VideoProgressIndicator(
                      _controller,
                      allowScrubbing: true,
                      colors: const VideoProgressColors(
                        playedColor: Colors.red,
                        bufferedColor: Colors.grey,
                        backgroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Exit Full-Screen Button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: _togglePlayPause,
                        ),
                        IconButton(
                          icon: const Icon(Icons.fullscreen_exit, color: Colors.white, size: 30),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}