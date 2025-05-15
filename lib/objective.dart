import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ObjectiveQuizPage extends StatefulWidget {
  final String quizId;

  const ObjectiveQuizPage({required this.quizId, Key? key}) : super(key: key);

  @override
  _ObjectiveQuizPageState createState() => _ObjectiveQuizPageState();
}

class _ObjectiveQuizPageState extends State<ObjectiveQuizPage> {
  Map<String, List<String>> userAnswers = {};
  bool isSubmitted = false;
  int score = 0;
  bool isLoading = true;
  late PageController _pageController;
  int currentPage = 0;
  List<QueryDocumentSnapshot> questions = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _checkIfSubmitted();
  }

  Future<void> _checkIfSubmitted() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('No user logged in');
      setState(() => isLoading = false);
      return;
    }
    String userEmail = user.email!;

    try {
      DocumentSnapshot submissionDoc = await FirebaseFirestore.instance
          .collection('questions')
          .doc('objective_question')
          .collection('quizzes')
          .doc(widget.quizId)
          .collection('submittedBy')
          .doc(userEmail)
          .get();

      if (submissionDoc.exists) {
        final userData = submissionDoc.data() as Map<String, dynamic>;
        setState(() {
          isSubmitted = true;
          userAnswers = Map<String, List<String>>.from(
            (userData['answers'] as Map<String, dynamic>).map(
                  (key, value) => MapEntry(
                key,
                List<String>.from(value.map((e) => e.toString().trim())),
              ),
            ),
          );
          score = userData['score'] ?? 0;
          print('Loaded userAnswers from Firestore: $userAnswers');
          print('Loaded score from Firestore: $score');
        });
      } else {
        print('No prior submission for $userEmail');
      }
    } catch (e) {
      print('Error checking submission: $e');
    } finally {
      await _fetchQuestions();
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchQuestions() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('questions')
          .doc('objective_question')
          .collection('quizzes')
          .doc(widget.quizId)
          .collection('questions')
          .orderBy('questionNumber')
          .get();
      setState(() {
        questions = snapshot.docs;
        print('Fetched ${questions.length} questions');
        questions.forEach((q) => print('Q${q.id}: ${q.data()}'));
      });
    } catch (e) {
      print('Error fetching questions: $e');
    }
  }

  Future<void> _calculateScore() async {
    int tempScore = 0;
    for (var doc in questions) {
      String questionId = doc.id;
      List<String> correctAnswers = _parseToList(doc['correctAnswer']);
      List<String> userSelected = userAnswers[questionId] ?? [];

      print('Scoring Q$questionId:');
      print('  Correct Answers: $correctAnswers (length: ${correctAnswers.length})');
      print('  User Answers: $userSelected (length: ${userSelected.length})');
      if (_areAnswersCorrect(userSelected, correctAnswers)) {
        tempScore++;
        print('  Q$questionId: Correct!');
      } else {
        print('  Q$questionId: Incorrect');
      }
    }
    setState(() {
      score = tempScore;
      print('Final Score: $score / ${questions.length}');
    });
  }

  Future<void> _submitQuiz() async {
    bool allAnswered = questions.every((doc) {
      String questionId = doc.id;
      return userAnswers.containsKey(questionId) && userAnswers[questionId]!.isNotEmpty;
    });

    if (!allAnswered) {
      int firstUnansweredIndex = questions.indexWhere((doc) {
        String questionId = doc.id;
        return !userAnswers.containsKey(questionId) || userAnswers[questionId]!.isEmpty;
      });
      if (firstUnansweredIndex != -1) {
        _pageController.jumpToPage(firstUnansweredIndex);
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please answer all questions before submitting.')),
      );
      return;
    }

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to submit the quiz')),
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
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    String userEmail = user.email!;
    Map<String, List<String>> answersToSubmit = {};
    await _calculateScore();
    int finalScore = score;

    for (var doc in questions) {
      String questionId = doc.id;
      List<String> userSelected = userAnswers[questionId] ?? [];
      answersToSubmit[questionId] = userSelected;
      print('Submitting Q$questionId: $userSelected');
    }

    try {
      print('Saving to Firestore: submittedBy/$userEmail = $answersToSubmit, score = $finalScore');
      await FirebaseFirestore.instance
          .collection('questions')
          .doc('objective_question')
          .collection('quizzes')
          .doc(widget.quizId)
          .collection('submittedBy')
          .doc(userEmail)
          .set({
        'answers': answersToSubmit,
        'score': finalScore,
        'timestamp': FieldValue.serverTimestamp(),
      });

      DocumentSnapshot savedDoc = await FirebaseFirestore.instance
          .collection('questions')
          .doc('objective_question')
          .collection('quizzes')
          .doc(widget.quizId)
          .collection('submittedBy')
          .doc(userEmail)
          .get();
      print('Verified Saved Data: ${savedDoc.data()}');

      setState(() {
        isSubmitted = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Answers submitted successfully!')),
      );
    } catch (e) {
      print('Error submitting to Firestore: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submission failed: $e')),
      );
    }
  }

  bool _areAnswersCorrect(List<String> userAnswers, List<String> correctAnswers) {
    if (userAnswers.isEmpty && correctAnswers.isEmpty) return true;
    if (userAnswers.isEmpty || correctAnswers.isEmpty) return false;

    final userNormalized = userAnswers.map((e) => e.trim().toLowerCase()).toList()..sort();
    final correctNormalized = correctAnswers.map((e) => e.trim().toLowerCase()).toList()..sort();

    bool isCorrect = userNormalized.length == correctNormalized.length &&
        userNormalized.every((answer) => correctNormalized.contains(answer));

    print('  Comparison:');
    print('    User Normalized: $userNormalized');
    print('    Correct Normalized: $correctNormalized');
    print('    Is Correct: $isCorrect');
    return isCorrect;
  }

  List<String> _parseToList(dynamic input) {
    if (input == null) return [];
    if (input is String) {
      return input.split(',').map((e) => e.trim()).toList();
    }
    if (input is Iterable) {
      return List<String>.from(input.map((e) => e.toString().trim()));
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Objective Quiz'),
          backgroundColor: Colors.blue[100],
        ),
        backgroundColor: Colors.blue[50],
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Objective Quiz'),
          backgroundColor: Colors.blue[100],
        ),
        backgroundColor: Colors.blue[50],
        body: const Center(child: Text('No questions found or failed to load')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Objective Quiz'),
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
                  print('Page changed to: $currentPage');
                });
              },
              itemBuilder: (context, index) {
                final question = questions[index];
                final String questionId = question.id;
                final String questionText = question['questionText'] ?? 'No question';
                final List<String> options = _parseToList(question['options']);
                final List<String> correctAnswers = _parseToList(question['correctAnswer']);
                final bool isMultipleChoice = correctAnswers.length > 1;
                final bool isCorrect = isSubmitted &&
                    _areAnswersCorrect(userAnswers[questionId] ?? [], correctAnswers);

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question ${question['questionNumber']}: $questionText',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: Colors.blueAccent,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (!isMultipleChoice)
                        Column(
                          children: options.map((option) {
                            final isUserCorrect = isSubmitted &&
                                userAnswers[questionId]?.contains(option) == true &&
                                correctAnswers.contains(option);
                            final isUserWrong = isSubmitted &&
                                userAnswers[questionId]?.contains(option) == true &&
                                !correctAnswers.contains(option);
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 8.0),
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.blue[200]!),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                              ),
                              child: RadioListTile<String>(
                                title: Text(option),
                                value: option,
                                groupValue: userAnswers[questionId]?.isNotEmpty == true
                                    ? userAnswers[questionId]![0]
                                    : null,
                                onChanged: isSubmitted
                                    ? null
                                    : (value) {
                                  setState(() {
                                    userAnswers[questionId] = [value!];
                                    print('Updated userAnswers[$questionId]: ${userAnswers[questionId]}');
                                  });
                                },
                                activeColor: isSubmitted
                                    ? (isUserCorrect
                                    ? Colors.green
                                    : isUserWrong
                                    ? Colors.red
                                    : Colors.blue[800])
                                    : Colors.blue[800],
                                secondary: isSubmitted
                                    ? (isUserCorrect
                                    ? const Icon(Icons.check, color: Colors.green)
                                    : isUserWrong
                                    ? const Icon(Icons.close, color: Colors.red)
                                    : correctAnswers.contains(option)
                                    ? const Icon(Icons.check, color: Colors.green)
                                    : null)
                                    : null,
                              ),
                            );
                          }).toList(),
                        )
                      else
                        Column(
                          children: options.map((option) {
                            final isUserCorrect = isSubmitted &&
                                userAnswers[questionId]?.contains(option) == true &&
                                correctAnswers.contains(option);
                            final isUserWrong = isSubmitted &&
                                userAnswers[questionId]?.contains(option) == true &&
                                !correctAnswers.contains(option);
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 8.0),
                              padding: const EdgeInsets.all(8.0),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.blue[200]!),
                                borderRadius: BorderRadius.circular(8),
                                color: Colors.white,
                              ),
                              child: CheckboxListTile(
                                title: Text(option),
                                value: userAnswers[questionId]?.contains(option) ?? false,
                                onChanged: isSubmitted
                                    ? null
                                    : (value) {
                                  setState(() {
                                    userAnswers[questionId] ??= [];
                                    if (value == true) {
                                      userAnswers[questionId]!.add(option);
                                    } else {
                                      userAnswers[questionId]!.remove(option);
                                    }
                                    print('Updated userAnswers[$questionId]: ${userAnswers[questionId]}');
                                  });
                                },
                                activeColor: isSubmitted
                                    ? (isUserCorrect
                                    ? Colors.green
                                    : isUserWrong
                                    ? Colors.red
                                    : Colors.blue[800])
                                    : Colors.blue[800],
                                secondary: isSubmitted
                                    ? (isUserCorrect
                                    ? const Icon(Icons.check, color: Colors.green)
                                    : isUserWrong
                                    ? const Icon(Icons.close, color: Colors.red)
                                    : correctAnswers.contains(option)
                                    ? const Icon(Icons.check, color: Colors.green)
                                    : null)
                                    : null,
                              ),
                            );
                          }).toList(),
                        ),
                      if (isSubmitted && !isCorrect)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Text(
                            'Correct Answer(s): ${correctAnswers.join(', ')}',
                            style: const TextStyle(color: Colors.blue, fontSize: 16),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                if (isSubmitted)
                  Text(
                    'Score: $score / ${questions.length}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueAccent,
                    ),
                  ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (currentPage > 0)
                      ElevatedButton(
                        onPressed: () {
                          print('Previous clicked, moving to page ${currentPage - 1}');
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[100],
                          foregroundColor: Colors.blue[800],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Previous'),
                      )
                    else
                      const SizedBox(),
                    if (isSubmitted && currentPage < questions.length - 1)
                      ElevatedButton(
                        onPressed: () {
                          print('Next clicked, moving to page ${currentPage + 1}');
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[100],
                          foregroundColor: Colors.blue[800],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Next'),
                      )
                    else if (isSubmitted)
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[100],
                          foregroundColor: Colors.blue[800],
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Back'),
                      )
                    else if (currentPage < questions.length - 1)
                        ElevatedButton(
                          onPressed: () {
                            print('Next clicked, moving to page ${currentPage + 1}');
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[100],
                            foregroundColor: Colors.blue[800],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Next'),
                        )
                      else
                        ElevatedButton(
                          onPressed: _submitQuiz,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[100],
                            foregroundColor: Colors.blue[800],
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Submit'),
                        ),
                  ],
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