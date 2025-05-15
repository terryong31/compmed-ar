import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'dart:convert';

// State class for 3D model puzzle page
class ThreeDModelPuzzlePage extends StatefulWidget {
  final String quizId;
  final String questionId;

  const ThreeDModelPuzzlePage({
    Key? key,
    required this.quizId,
    required this.questionId,
  }) : super(key: key);

  @override
  _ThreeDModelPuzzlePageState createState() => _ThreeDModelPuzzlePageState();
}

class QuizStateManager {
  // Singleton pattern to maintain state across navigation
  static final QuizStateManager _instance = QuizStateManager._internal();
  factory QuizStateManager() => _instance;
  QuizStateManager._internal();

  // Store answers for all questions in a quiz
  Map<String, dynamic> quizAnswers = {};

  void saveQuestionAnswer(String quizId, String questionId, Map<int, String?> slots, int score) {
    if (!quizAnswers.containsKey(quizId)) {
      quizAnswers[quizId] = {};
    }
    quizAnswers[quizId][questionId] = {
      'slots': slots,
      'score': score
    };
  }

  Map<int, String?>? getQuestionAnswers(String quizId, String questionId) {
    return quizAnswers[quizId]?[questionId]?['slots'];
  }
}


class _ThreeDModelPuzzlePageState extends State<ThreeDModelPuzzlePage> {
  // State variables
  String? quizTitle;
  String? questionText;
  List<Map<String, dynamic>> annotations = [];
  Map<int, String?> puzzleSlots = {};
  List<String> puzzlePieces = [];
  String? modelUrl;
  bool isLoading = true;
  String? errorMessage;
  String? selectedPiece;

  // Navigation variables
  String? nextQuestionId;
  String? previousQuestionId;
  List<QueryDocumentSnapshot> sortedQuestions = []; // Store sorted questions for navigation

  // Scores
  int score = 0;
  int totalPossibleScore = 0; // Track total possible score for the question
  int quizTotalScore = 0; // Track total score across the quiz
  bool isSubmitted = false;

  @override
  void initState() {
    super.initState();
    _fetchPuzzleData();
  }

  // Data Fetching Methods
  Future<void> _fetchPuzzleData() async {
    if (!mounted) return; // Check if widget is still mounted
    try {
      await _checkIfSubmitted();
      await _fetchQuizTitle();
      await _ensureStartWithQuestionOne(); // Ensure we start with question 1
      await _fetchQuestionData();
      await _fetchNavigationData();
      if (mounted) setState(() => isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          errorMessage = 'Error: ${e.toString()}';
          isLoading = false;
        });
      }
    }
  }

  Future<void> _fetchQuizTitle() async {
    final quizDoc = await FirebaseFirestore.instance
        .collection('questions')
        .doc('3Dmodel_question')
        .collection('quizzes')
        .doc(widget.quizId)
        .get();

    if (quizDoc.exists) {
      quizTitle = quizDoc.data()?['title'] as String? ?? '3D Model Quiz';
    }
  }

  Future<void> _fetchQuestionData() async {
    final docSnapshot = await FirebaseFirestore.instance
        .collection('questions')
        .doc('3Dmodel_question')
        .collection('quizzes')
        .doc(widget.quizId)
        .collection('3Dquestions')
        .doc(widget.questionId)
        .get();

    if (docSnapshot.exists) {
      final data = docSnapshot.data() as Map<String, dynamic>?;
      if (data != null) {
        questionText = data['question'] as String?;
        modelUrl = await _fetchModelUrl(data['modelUrl'] as String?);
        _processAnnotations(data['annotations'] as List<dynamic>?);
      } else {
        throw Exception('No data found in document');
      }
    } else {
      throw Exception('Document not found');
    }
  }

  Future<String?> _fetchModelUrl(String? storedModelUrl) async {
    if (storedModelUrl != null) {
      if (storedModelUrl.startsWith('gs://')) {
        final storageRef = FirebaseStorage.instance.refFromURL(storedModelUrl);
        return await storageRef.getDownloadURL();
      }
      return storedModelUrl;
    }
    throw Exception('Model URL is null');
  }

  void _processAnnotations(List<dynamic>? annotationsData) {
    if (annotationsData == null || annotationsData.isEmpty) {
      throw Exception('Annotations are missing or empty in Firestore');
    }

    final descriptions = <String>[];
    for (int i = 0; i < annotationsData.length; i++) {
      final ann = annotationsData[i];
      final description = (ann['description'] as String?) ?? 'Unknown Part';

      annotations.add({
        'id': i,
        'description': description,
        'position': {
          'x': (ann['x'] as num?)?.toDouble() ?? 0.0,
          'y': (ann['y'] as num?)?.toDouble() ?? 0.0,
          'z': (ann['z'] as num?)?.toDouble() ?? 0.0
        },
        'normal': {
          'nx': (ann['nx'] as num?)?.toDouble() ?? 0.0,
          'ny': (ann['ny'] as num?)?.toDouble() ?? 1.0,
          'nz': (ann['nz'] as num?)?.toDouble() ?? 0.0
        }
      });

      descriptions.add(description);
      puzzleSlots[i] = null;
    }

    totalPossibleScore = annotations.length; // Each annotation is worth 1 point
    if (!isSubmitted) {
      puzzlePieces = List.from(descriptions)..shuffle();
    }
  }

  Future<void> _checkIfSubmitted() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user logged in');
      return;
    }

    final userEmail = user.email!;
    try {
      final submissionDoc = await FirebaseFirestore.instance
          .collection('questions')
          .doc('3Dmodel_question')
          .collection('quizzes')
          .doc(widget.quizId)
          .collection('submittedBy')
          .doc(userEmail)
          .get();

      if (submissionDoc.exists) {
        final userData = submissionDoc.data() as Map<String, dynamic>;
        if (userData['answers'] is Map &&
            (userData['answers'] as Map).containsKey(widget.quizId)) {
          // Lock submission if the entire quiz is submitted
          final quizData = userData['answers'][widget.quizId];
          if (mounted) {
            setState(() {
              isSubmitted = true;
              if (quizData['slots'] is Map) {
                (quizData['slots'] as Map).forEach((key, value) {
                  final slotIndex = int.tryParse(key.toString()) ?? -1;
                  if (slotIndex >= 0) {
                    puzzleSlots[slotIndex] = value as String?;
                  }
                });
              }
              score = quizData['slots'][widget.questionId]?['score'] ?? 0;
              quizTotalScore = userData['totalScore'] ?? 0; // Load total quiz score
              _showResults(); // Show results immediately when loading submitted data
              print('Loaded previous submission for quiz ${widget.quizId}, question ${widget.questionId}');
              print('Score: $score / $totalPossibleScore, Quiz Total: $quizTotalScore');
            });
          }
        }
      } else {
        print('No prior submission for $userEmail');
      }
    } catch (e) {
      print('Error checking submission: $e');
    }
  }

  Future<void> _fetchNavigationData() async {
    if (!mounted) return; // Check if widget is still mounted
    try {
      if (sortedQuestions.isEmpty) {
        // If sortedQuestions isn’t populated yet, fetch it
        final querySnapshot = await FirebaseFirestore.instance
            .collection('questions')
            .doc('3Dmodel_question')
            .collection('quizzes')
            .doc(widget.quizId)
            .collection('3Dquestions')
            .orderBy('questionNumber') // Sort by questionNumber for consistent ordering
            .get();

        final questionDocs = querySnapshot.docs;
        sortedQuestions = questionDocs.where((doc) {
          final number = doc['questionNumber'];
          return number != null && (number is int || (number is String && int.tryParse(number) != null));
        }).toList();

        if (sortedQuestions.isEmpty) {
          throw Exception('No valid questions with questionNumber found');
        }

        // Sort by questionNumber (convert to int if string)
        sortedQuestions.sort((a, b) {
          final numA = a['questionNumber'] is int
              ? a['questionNumber'] as int
              : int.parse(a['questionNumber'] as String);
          final numB = b['questionNumber'] is int
              ? b['questionNumber'] as int
              : int.parse(b['questionNumber'] as String);
          return numA.compareTo(numB);
        });
      }

      // Find the current question’s index in the sorted list
      final currentIndex = sortedQuestions.indexWhere((doc) => doc.id == widget.questionId);

      if (currentIndex == -1) {
        throw Exception('Current question ID ${widget.questionId} not found in sorted questions');
      }

      // Set previous and next question IDs with detailed logging
      if (mounted) {
        setState(() {
          previousQuestionId = currentIndex > 0 ? sortedQuestions[currentIndex - 1].id : null; // Disabled for Question 1
          nextQuestionId = currentIndex < sortedQuestions.length - 1 ? sortedQuestions[currentIndex + 1].id : null;
        });
      }

      print('Current Question ID: ${widget.questionId}, Index: $currentIndex');
      print('Previous Question ID: $previousQuestionId');
      print('Next Question ID: $nextQuestionId');
      print('Sorted Questions: ${sortedQuestions.map((doc) => '${doc.id} (Number: ${doc['questionNumber']})').join(', ')}');
    } catch (e) {
      print('Error fetching navigation data: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Navigation error: ${e.toString()}';
          nextQuestionId = null; // Ensure next is disabled on error
          previousQuestionId = null;
        });
      }
    }
  }

  Future<void> _ensureStartWithQuestionOne() async {
    if (!mounted) return;
    try {
      final questionsSnapshot = await FirebaseFirestore.instance
          .collection('questions')
          .doc('3Dmodel_question')
          .collection('quizzes')
          .doc(widget.quizId)
          .collection('3Dquestions')
          .orderBy('questionNumber')
          .get();

      final questionDocs = questionsSnapshot.docs;
      if (questionDocs.isNotEmpty) {
        final sortedDocs = questionDocs.where((doc) {
          final number = doc['questionNumber'];
          return number != null && (number is int || (number is String && int.tryParse(number) != null));
        }).toList();

        if (sortedDocs.isEmpty) {
          throw Exception('No valid questions with questionNumber found');
        }

        sortedDocs.sort((a, b) {
          final numA = a['questionNumber'] is int
              ? a['questionNumber'] as int
              : int.parse(a['questionNumber'] as String);
          final numB = b['questionNumber'] is int
              ? b['questionNumber'] as int
              : int.parse(b['questionNumber'] as String);
          return numA.compareTo(numB);
        });

        final firstQuestion = sortedDocs.first;
        final firstQuestionId = firstQuestion.id;
        final firstQuestionNumber = firstQuestion['questionNumber'] is int
            ? firstQuestion['questionNumber'] as int
            : int.parse(firstQuestion['questionNumber'] as String);

        print('First question ID: $firstQuestionId (Question Number: $firstQuestionNumber)');
        print('Current questionId: ${widget.questionId}');

        // Remove or modify this redirection logic
        if (firstQuestionId == widget.questionId) {
          // Only log if we are on the first question, don't redirect
          print('Starting with first question: $firstQuestionId');
        }
      }
    } catch (e) {
      print('Error ensuring start with question 1: $e');
      if (mounted) {
        setState(() {
          errorMessage = 'Navigation error: ${e.toString()}';
        });
      }
    }
  }

  // Interaction Methods
  void _selectPiece(String piece) {
    if (!mounted) return;
    setState(() => selectedPiece = piece);
  }

  void _placePiece(int slotIndex) {
    if (!mounted) return;
    if (selectedPiece == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a puzzle piece first')),
      );
      return;
    }

    if (mounted) {
      setState(() {
        puzzleSlots[slotIndex] = selectedPiece;
        puzzlePieces.remove(selectedPiece);
        selectedPiece = null;
      });
    }
  }

  void _removePiece(int slotIndex) {
    if (!mounted) return;
    if (mounted) {
      setState(() {
        final piece = puzzleSlots[slotIndex];
        if (piece != null) {
          puzzlePieces.add(piece);
          puzzleSlots[slotIndex] = null;
        }
      });
    }
  }

  void _navigateToQuestion(String questionId) {
    print('Navigating to question: $questionId');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => ThreeDModelPuzzlePage(
          quizId: widget.quizId,
          questionId: questionId,
        ),
      ),
    ).then((_) {
      // After navigation, ensure the new page loads correctly
      if (mounted) {
        setState(() {
          isLoading = true; // Trigger reload of new question
        });
      }
    });
  }

  // Scoring and Submission Methods
  void _calculateScore() {
    if (!mounted) return;
    int tempScore = 0;
    for (int i = 0; i < annotations.length; i++) {
      final correctDescription = annotations[i]['description'] as String;
      final userPlacement = puzzleSlots[i];
      if (userPlacement == correctDescription) {
        tempScore++;
      } else {
        print('Slot ${i + 1} incorrect: Placed "$userPlacement", should be "$correctDescription"');
      }
    }
    if (mounted) {
      setState(() => score = tempScore);
    }
    print('Score calculated for Q${widget.questionId}: $score / $totalPossibleScore');
  }

  Future<void> _submitPuzzle() async {
    if (!mounted) return;
    if (isSubmitted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You have already submitted this quiz.')),
        );
        _showResults(); // Show results immediately for submitted quiz
      }
      return;
    }

    if (!puzzleSlots.values.every((piece) => piece != null)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please place all puzzle pieces before submitting')),
        );
      }
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please log in to submit your answers')),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Submission'),
        content: const Text(
          'Are you sure you want to submit your answers? You will not be able to change them after submission.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Submit'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    _calculateScore();
    final slotsData = {for (var entry in puzzleSlots.entries) entry.key.toString(): entry.value};
    final userEmail = user.email!;

    try {
      final userSubmissionRef = FirebaseFirestore.instance
          .collection('questions')
          .doc('3Dmodel_question')
          .collection('quizzes')
          .doc(widget.quizId)
          .collection('submittedBy')
          .doc(userEmail);

      final existingSubmission = await userSubmissionRef.get();
      final submissionData = existingSubmission.exists && existingSubmission.data() is Map<String, dynamic>
          ? Map<String, dynamic>.from(existingSubmission.data() as Map<String, dynamic>)
          : {
        'timestamp': FieldValue.serverTimestamp(),
        'answers': {},
      };

      // Store answers for the entire quiz under quizId
      if (mounted) {
        (submissionData['answers'] as Map)[widget.quizId] ??= {'slots': {}, 'score': 0};
        (submissionData['answers'][widget.quizId] as Map)['slots'][widget.questionId] = {
          'slots': slotsData,
          'score': score,
        };
        (submissionData['answers'][widget.quizId] as Map)['score'] =
            (submissionData['answers'][widget.quizId]['score'] as int? ?? 0) + score;

        // Calculate total quiz score across all questions
        int totalQuizScore = 0;
        final allQuestionsSnapshot = await FirebaseFirestore.instance
            .collection('questions')
            .doc('3Dmodel_question')
            .collection('quizzes')
            .doc(widget.quizId)
            .collection('3Dquestions')
            .orderBy('questionNumber')
            .get();
        totalPossibleScore = allQuestionsSnapshot.docs.length; // Total questions in quiz

        (submissionData['answers'][widget.quizId]['slots'] as Map).forEach((qId, qData) {
          if (qData is Map && qData.containsKey('score')) {
            totalQuizScore += (qData['score'] as int);
          }
        });
        submissionData['totalScore'] = totalQuizScore;

        await userSubmissionRef.set(submissionData);
        setState(() => isSubmitted = true);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Submission successful! Score: $score/$totalPossibleScore, Quiz Total: $totalQuizScore/$totalPossibleScore')),
        );
        _showResults();
      }
    } catch (e) {
      print('Error submitting puzzle: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting: $e')),
        );
      }
    }
  }

  void _showResults() {
    if (!mounted) return;
    final results = <int, bool>{};
    for (int i = 0; i < annotations.length; i++) {
      final correctDescription = annotations[i]['description'] as String;
      final userPlacement = puzzleSlots[i];
      results[i] = userPlacement == correctDescription;
    }

    final currentQuestionDoc = sortedQuestions.firstWhere(
          (doc) => doc.id == widget.questionId,
      orElse: () => throw Exception('Current question not found'),
    );
    final questionNumber = currentQuestionDoc['questionNumber'] is int
        ? currentQuestionDoc['questionNumber'] as int
        : int.parse(currentQuestionDoc['questionNumber'] as String);

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Results for Question $questionNumber (Q${widget.questionId})'),
          content: Container(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Question Score: $score / $totalPossibleScore',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Quiz Total Score: $quizTotalScore / $totalPossibleScore',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...results.entries.map((entry) {
                          final slotIndex = entry.key;
                          final isCorrect = entry.value;
                          final placedPiece = puzzleSlots[slotIndex];
                          final correctPiece = annotations[slotIndex]['description'];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(
                                  isCorrect ? Icons.check_circle : Icons.cancel,
                                  color: isCorrect ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    isCorrect
                                        ? 'Slot ${slotIndex + 1}: Correct'
                                        : 'Slot ${slotIndex + 1}: You placed "$placedPiece", should be "$correctPiece"',
                                    style: TextStyle(color: isCorrect ? Colors.green[800] : Colors.red[800]),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                        const SizedBox(height: 16),
                        Text(
                          'Quiz Scores by Question:',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        ...sortedQuestions.map((questionDoc) {
                          final qId = questionDoc.id;
                          final qData = questionDoc.data() as Map<String, dynamic>;
                          final qNumber = qData['questionNumber'] is int
                              ? qData['questionNumber'] as int
                              : int.parse(qData['questionNumber'] as String);
                          final slotsData = qData['slots'] as Map<String, dynamic>? ?? {};
                          final userSubmission = slotsData[qId] as Map<String, dynamic>? ?? {};
                          final qScore = userSubmission['score'] ?? 0;
                          final qTotal = (qData['annotations'] as List<dynamic>?)?.length ?? 0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Icon(
                                  qScore == qTotal ? Icons.check_circle : Icons.cancel,
                                  color: qScore == qTotal ? Colors.green : Colors.red,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Question $qNumber: $qScore / $qTotal',
                                    style: TextStyle(color: qScore == qTotal ? Colors.green[800] : Colors.red[800]),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Close'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            if (nextQuestionId != null)
              TextButton(
                child: const Text('Next Question'),
                onPressed: () {
                  Navigator.of(context).pop();
                  _navigateToQuestion(nextQuestionId!);
                },
              ),
          ],
        ),
      );
    }
  }

  String _generateAnnotationHtml() {
    final annotationsJson = jsonEncode(annotations);
    return '''
    <style>
      .annotation-marker {
        display: block !important;
        width: 30px !important;
        height: 30px !important;
        border-radius: 50% !important;
        border: 2px solid white !important;
        background-color: rgba(0, 100, 255, 0.8) !important;
        box-shadow: 0 0 4px rgba(0, 0, 0, 0.8) !important;
        color: white !important;
        font-weight: bold !important;
        display: flex !important;
        justify-content: center !important;
        align-items: center !important;
        opacity: 1 !important;
        visibility: visible !important;
        pointer-events: none !important;
      }
    </style>
    
    <script>
      var markersCreated = false;
      
      function createAnnotationMarkers() {
        if (markersCreated) {
          console.log('Markers already created, skipping');
          return;
        }

        var annotations = $annotationsJson;
        var modelViewer = document.querySelector('model-viewer');

        var existingMarkers = document.querySelectorAll('.annotation-marker');
        for (var m = 0; m < existingMarkers.length; m++) {
          existingMarkers[m].remove();
        }

        for (var i = 0; i < annotations.length; i++) {
          var annotation = annotations[i];
          var marker = document.createElement('div');
          marker.slot = "hotspot-" + annotation.id;
          marker.className = 'annotation-marker';
          marker.textContent = (i + 1).toString();
          marker.style.visibility = 'visible';
          marker.style.opacity = '1';

          marker.dataset.position = annotation.position.x + " " + annotation.position.y + " " + annotation.position.z;
          marker.dataset.normal = annotation.normal.nx + " " + annotation.normal.ny + " " + annotation.normal.nz;

          console.log('Adding annotation marker:', i + 1);
          modelViewer.appendChild(marker);
        }

        markersCreated = true;
      }

      window.addEventListener('load', function() {
        var modelViewer = document.querySelector('model-viewer');
        if (modelViewer) {
          modelViewer.addEventListener('load', function() {
            console.log('Model loaded, creating annotation markers');
            setTimeout(createAnnotationMarkers, 500);
          });

          // Backup in case the load event doesn't fire
          setTimeout(function() {
            console.log('Backup timer creating annotation markers');
            if (!markersCreated) {
              createAnnotationMarkers();
            }
          }, 2000);
        }
      });
    </script>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(quizTitle ?? '3D Puzzle')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (errorMessage != null || modelUrl == null) {
      return Scaffold(
        appBar: AppBar(title: Text(quizTitle ?? '3D Puzzle')),
        body: Center(child: Text(errorMessage ?? 'No model URL')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(quizTitle ?? '3D Model Quiz'),
        actions: [
          IconButton(
            icon: Icon(Icons.check),
            onPressed: _submitPuzzle,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Question
            if (questionText != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  questionText!,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),

            // 3D Model with annotations
            AspectRatio(
              aspectRatio: 4/3, // Adjust as needed for your model
              child: ModelViewer(
                src: modelUrl!,
                ar: true,
                autoRotate: true,
                cameraControls: true,
                autoPlay: true,
                cameraOrbit: '0deg 75deg 2.0m', // Default camera position
                innerModelViewerHtml: _generateAnnotationHtml(),
              ),
            ),

            // Puzzle slots
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Place Pieces in Slots',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      if (isSubmitted)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green[100],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.green),
                          ),
                          child: Text(
                            'Score: $score/$totalPossibleScore, Quiz Total: $quizTotalScore/$totalPossibleScore',
                            style: TextStyle(
                              color: Colors.green[800],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: puzzleSlots.length,
                    itemBuilder: (context, index) {
                      final slotIndex = index;
                      final placedPiece = puzzleSlots[slotIndex];
                      final hasPlacedPiece = placedPiece != null;

                      bool? isCorrect;
                      if (isSubmitted && hasPlacedPiece) {
                        final correctDescription = annotations[slotIndex]['description'] as String;
                        isCorrect = placedPiece == correctDescription;
                      }

                      return DragTarget<String>(
                        onWillAccept: (data) => !isSubmitted && !hasPlacedPiece,
                        onAccept: (piece) {
                          if (mounted) {
                            setState(() {
                              puzzleSlots[slotIndex] = piece;
                              puzzlePieces.remove(piece);
                            });
                          }
                        },
                        builder: (context, candidateData, rejectedData) {
                          return Card(
                            color: isSubmitted
                                ? (isCorrect == true
                                ? Colors.green[50]
                                : isCorrect == false
                                ? Colors.red[50]
                                : Colors.white)
                                : (candidateData.isNotEmpty
                                ? Colors.green[100]
                                : hasPlacedPiece
                                ? Colors.blue[50]
                                : Colors.white),
                            child: InkWell(
                              onTap: isSubmitted
                                  ? null
                                  : hasPlacedPiece
                                  ? () => _removePiece(slotIndex)
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: isSubmitted
                                          ? (isCorrect == true
                                          ? Colors.green
                                          : isCorrect == false
                                          ? Colors.red
                                          : Colors.blue)
                                          : (hasPlacedPiece ? Colors.blue : Colors.grey[600]),
                                      child: Text(
                                        '${slotIndex + 1}',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            hasPlacedPiece
                                                ? placedPiece!
                                                : 'Slot ${slotIndex + 1}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: isSubmitted
                                                  ? (isCorrect == true
                                                  ? Colors.green[800]
                                                  : isCorrect == false
                                                  ? Colors.red[800]
                                                  : Colors.grey[700])
                                                  : (hasPlacedPiece
                                                  ? Colors.blue[800]
                                                  : Colors.grey[700]),
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            isSubmitted
                                                ? (isCorrect == true
                                                ? 'Correct!'
                                                : isCorrect == false
                                                ? 'Incorrect'
                                                : 'Not graded')
                                                : (hasPlacedPiece
                                                ? 'Tap to remove'
                                                : candidateData.isNotEmpty
                                                ? 'Release to drop'
                                                : 'Drag piece here'),
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (hasPlacedPiece)
                                      Icon(Icons.cancel, color: Colors.red[300], size: 20),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            // Available puzzle pieces
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Available Pieces',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  if (puzzlePieces.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text(
                          'All pieces placed!',
                          style: TextStyle(
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: puzzlePieces.map((piece) {
                        return Draggable<String>(
                          data: piece,
                          feedback: Material(
                            elevation: 4.0,
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.blue[700],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                piece,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                          childWhenDragging: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[400],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              piece,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              piece,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.normal,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: previousQuestionId != null
                        ? () => _navigateToQuestion(previousQuestionId!)
                        : null, // Disabled for Question 1
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Previous'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[800],
                      foregroundColor: Colors.white,
                    ),
                  ),

                  ElevatedButton.icon(
                    onPressed: nextQuestionId != null
                        ? () => _navigateToQuestion(nextQuestionId!)
                        : null, // Disabled if no next question
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Next'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[800],
                      foregroundColor: Colors.white,
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
}