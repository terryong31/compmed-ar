import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

class ThreeDModelQuizPage extends StatefulWidget {
  final String quizId;

  const ThreeDModelQuizPage({required this.quizId, super.key});

  @override
  ThreeDModelQuizPageState createState() => ThreeDModelQuizPageState();
}

class ThreeDModelQuizPageState extends State<ThreeDModelQuizPage> {
  Map<String, String?> userAnswers = {};
  late PageController _pageController;
  int currentPage = 0;
  bool hasSubmitted = false;
  List<QueryDocumentSnapshot> questions = [];
  bool isLoading = true;
  Map<String, int> scores = {};

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _fetchQuestions();
  }

  Future<void> _fetchQuestions() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('questions')
          .doc('3Dmodel_question')
          .collection('quizzes')
          .doc(widget.quizId)
          .collection('3Dquestions')
          .get();
      setState(() {
        questions = snapshot.docs;
        isLoading = false;
        if (kDebugMode) {
          print('Fetched ${questions.length} questions');
        }
        for (var q in questions) {
          if (kDebugMode) {
            print('Question ${q.id}: ${q.data()}');
          }
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching questions: $e');
      }
      setState(() => isLoading = false);
    }
  }

  Future<void> _submitAnswers(BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || hasSubmitted) return;

    bool allAnswered = true;
    for (var question in questions) {
      final String questionId = question.id;
      final List<dynamic> annotations = question['annotations'] ?? [];
      for (var annotation in annotations) {
        final String id = annotation['id'] ?? '';
        if (userAnswers['$questionId-$id'] == null) {
          allAnswered = false;
          break;
        }
      }
      if (!allAnswered) break;
    }

    if (!allAnswered) {
      int firstUnansweredIndex = -1;
      for (int i = 0; i < questions.length; i++) {
        final String questionId = questions[i].id;
        final List<dynamic> annotations = questions[i]['annotations'] ?? [];
        for (var annotation in annotations) {
          final String id = annotation['id'] ?? '';
          if (userAnswers['$questionId-$id'] == null) {
            firstUnansweredIndex = i;
            break;
          }
        }
        if (firstUnansweredIndex != -1) break;
      }
      if (firstUnansweredIndex != -1) {
        _pageController.jumpToPage(firstUnansweredIndex);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete all puzzle pieces before submitting.')),
      );
      return;
    }

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Submission'),
          content: const Text(
            'Are you sure you want to submit your answers? You will not be able to change them after submission.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
          ],
        );
      },
    );

    if (confirm != true) return;

    scores.clear();
    for (int i = 0; i < questions.length; i++) {
      final String questionId = questions[i].id;
      final List<dynamic> annotations = questions[i]['annotations'] ?? [];
      int correctCount = 0;
      for (var annotation in annotations) {
        final String id = annotation['id'] ?? '';
        final String correctAnswer = annotation['description'] ?? '';
        final String userAnswer = userAnswers['$questionId-$id'] ?? '';
        if (userAnswer == correctAnswer) {
          correctCount++;
        }
      }
      scores[questionId] = correctCount;
    }

    final answersMap = Map<String, String?>.from(userAnswers);
    await FirebaseFirestore.instance
        .collection('questions')
        .doc('3Dmodel_question')
        .collection('quizzes')
        .doc(widget.quizId)
        .set({
      'submittedBy': {
        user.email: {
          'answers': answersMap,
          'scores': scores,
          'timestamp': FieldValue.serverTimestamp(),
        },
      },
    }, SetOptions(merge: true));

    setState(() {
      hasSubmitted = true;
    });

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Quiz Results'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: questions.map((question) {
                final String questionId = question.id;
                final List<dynamic> annotations = question['annotations'] ?? [];
                final int score = scores[questionId] ?? 0;
                final int total = annotations.length;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question: ${question['question']}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text('Score: $score/$total'),
                      const SizedBox(height: 4),
                      ...annotations.map((annotation) {
                        final String id = annotation['id'] ?? '';
                        final String correctAnswer = annotation['description'] ?? '';
                        final String userAnswer = userAnswers['$questionId-$id'] ?? 'Not answered';
                        return Text(
                          'Hotspot $id: Your answer: $userAnswer, Correct answer: $correctAnswer',
                          style: TextStyle(
                            color: userAnswer == correctAnswer ? Colors.green : Colors.red,
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Answers submitted successfully!')),
    );
  }

  String _generateHotspots(List<dynamic> annotations, String questionId) {
    String hotspotsHtml = '';
    annotations.forEach((annotation) {
      final String position = annotation['position'] ?? '0 0 0';
      final String normal = annotation['normal'] ?? '0 0 1';
      final String id = annotation['id'] ?? '';
      final String answer = userAnswers['$questionId-$id'] ?? '';
      hotspotsHtml += '''
        <button slot="hotspot-$id" class="hotspot" data-position="$position" data-normal="$normal" style="width: 16px; height: 16px; border-radius: 50%; background-color: red; border: none;"></button>
        <div slot="hotspot-$id-drop" data-position="$position" data-normal="$normal" style="width: 100px; height: 30px; background-color: white; border: 1px solid #90CAF9; border-radius: 4px; margin-left: 20px; display: flex; align-items: center; justify-content: center; color: grey; font-size: 12px;">${answer.isEmpty ? 'Drop here' : answer}</div>
      ''';
    });
    return hotspotsHtml;
  }

  // Improved 2D screen position mapping for hotspots
  Offset _getHotspotOffset(String position, BuildContext context) {
    final parts = position.split(' ').map(double.parse).toList();
    final x = parts[0]; // -1 to 1 range
    final y = parts[1]; // -1 to 1 range
    final screenWidth = MediaQuery.of(context).size.width - 32; // Padding
    final screenHeight = 300.0; // ModelViewer height
    final dx = (x + 1) / 2 * screenWidth; // Map -1..1 to 0..width
    final dy = (1 - y) / 2 * screenHeight; // Map -1..1 to 0..height (inverted y)
    return Offset(dx.clamp(0, screenWidth), dy.clamp(0, screenHeight));
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('3D Model Puzzle Quiz'),
          backgroundColor: Colors.blue[100],
        ),
        backgroundColor: Colors.blue[50],
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('3D Model Puzzle Quiz'),
          backgroundColor: Colors.blue[100],
        ),
        backgroundColor: Colors.blue[50],
        body: const Center(child: Text('No questions found.', style: TextStyle(color: Colors.blueAccent))),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('3D Model Puzzle Quiz'),
        backgroundColor: Colors.blue[100],
      ),
      backgroundColor: Colors.blue[50],
      body: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              itemCount: questions.length,
              onPageChanged: (index) {
                setState(() {
                  currentPage = index;
                  if (kDebugMode) {
                    print('Page changed to: $currentPage');
                  }
                });
              },
              itemBuilder: (context, index) {
                final question = questions[index];
                final String questionText = question['question'] ?? 'No question';
                final String questionId = question.id;
                final String modelUrl = question['modelUrl'] ?? '';
                final List<dynamic> annotations = question['annotations'] ?? [];
                final String hotspotsHtml = _generateHotspots(annotations, questionId);

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        questionText,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 300,
                        width: double.infinity,
                        child: Stack(
                          children: [
                            ModelViewer(
                              src: modelUrl,
                              alt: '3D Model',
                              autoRotate: false,
                              cameraControls: true,
                              backgroundColor: Colors.transparent,
                              innerModelViewerHtml: hotspotsHtml,
                            ),
                            // Overlay DragTargets beside hotspot positions (covering red dot and drop area)
                            ...annotations.map((annotation) {
                              final String id = annotation['id'] ?? '';
                              final String position = annotation['position'] ?? '0 0 0';
                              final Offset offset = _getHotspotOffset(position, context);
                              return Positioned(
                                left: offset.dx - 10, // Slightly left of red dot to cover it
                                top: offset.dy - 15,  // Center vertically with 30px height
                                child: DragTarget<String>(
                                  onAccept: (data) {
                                    final parts = data.split('|');
                                    final droppedId = parts[0];
                                    final answer = parts[1];
                                    setState(() {
                                      userAnswers['$questionId-$id'] = answer;
                                      if (kDebugMode) {
                                        print('Dropped $answer on hotspot-$id');
                                      }
                                    });
                                  },
                                  builder: (context, candidateData, rejectedData) {
                                    return Container(
                                      width: 136, // Cover red dot (16px) + drop box (100px) + margin (20px)
                                      height: 30, // Match drop box height
                                      color: Colors.transparent, // Invisible target
                                    );
                                  },
                                ),
                              );
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (!questions.isEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue[200]!),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: (questions[currentPage]['annotations'] as List<dynamic>? ?? []).map((annotation) {
                  final String questionId = questions[currentPage].id;
                  final String puzzlePiece = annotation['description'] ?? '';
                  final String id = annotation['id'] ?? '';
                  userAnswers.putIfAbsent('$questionId-$id', () => null);

                  return Draggable<String>(
                    data: '$questionId-$id|$puzzlePiece',
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        puzzlePiece,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.blueAccent,
                        ),
                      ),
                    ),
                    feedback: Material(
                      elevation: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        color: Colors.blue[100],
                        child: Text(
                          puzzlePiece,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        puzzlePiece,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (currentPage > 0)
                  ElevatedButton(
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                      if (kDebugMode) {
                        print('Previous button clicked, moving to page ${currentPage - 1}');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[100],
                      foregroundColor: Colors.blue[800],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Previous'),
                  )
                else
                  const SizedBox(),
                if (hasSubmitted)
                  if (currentPage < questions.length - 1)
                    ElevatedButton(
                      onPressed: () {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                        print('Next button clicked, moving to page ${currentPage + 1}');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[100],
                        foregroundColor: Colors.blue[800],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Next'),
                    )
                  else
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[100],
                        foregroundColor: Colors.blue[800],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Back'),
                    )
                else if (currentPage < questions.length - 1)
                  ElevatedButton(
                    onPressed: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                      print('Next button clicked, moving to page ${currentPage + 1}');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[100],
                      foregroundColor: Colors.blue[800],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Next'),
                  )
                else
                  ElevatedButton(
                    onPressed: () => _submitAnswers(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[100],
                      foregroundColor: Colors.blue[800],
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Submit'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}