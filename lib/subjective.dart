import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SubjectiveQuizPage extends StatefulWidget {
  final String quizId;

  const SubjectiveQuizPage({required this.quizId, Key? key}) : super(key: key);

  @override
  _SubjectiveQuizPageState createState() => _SubjectiveQuizPageState();
}

class _SubjectiveQuizPageState extends State<SubjectiveQuizPage> {
  Map<String, String> userAnswers = {};
  Map<String, TextEditingController> controllers = {};
  bool isSubmitted = false;
  double totalScore = 0;
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
          .doc('subjective_question')
          .collection('quizzes')
          .doc(widget.quizId)
          .collection('submittedBy')
          .doc(userEmail)
          .get();

      if (submissionDoc.exists) {
        final userData = submissionDoc.data() as Map<String, dynamic>;
        setState(() {
          isSubmitted = true;
          userAnswers = Map<String, String>.from(userData['answers']);
          totalScore = (userData['score'] as num?)?.toDouble() ?? 0.0;
          print('Loaded userAnswers from Firestore: $userAnswers');
          print('Loaded totalScore from Firestore: $totalScore');
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
          .doc('subjective_question')
          .collection('quizzes')
          .doc(widget.quizId)
          .collection('questions')
          .orderBy('questionNumber')
          .get();
      setState(() {
        questions = snapshot.docs;
        for (var question in questions) {
          String questionId = question.id;
          controllers[questionId] = TextEditingController(text: userAnswers[questionId] ?? '');
        }
        print('Fetched ${questions.length} questions');
        questions.forEach((q) => print('Q${q.id}: ${q.data()}'));
      });
    } catch (e) {
      print('Error fetching questions: $e');
    }
  }

  Future<void> _calculateScore() async {
    double tempTotalScore = 0;

    for (var doc in questions) {
      String questionId = doc.id;
      final questionData = doc.data() as Map<String, dynamic>;
      List<String> expectedKeywords = List<String>.from(questionData['keywords'] ?? []);
      int marks = (questionData['marks'] as int?) ?? 0;
      String userAnswer = (userAnswers[questionId] ?? '').toLowerCase().trim();

      if (expectedKeywords.isEmpty) {
        continue;
      }

      int correctKeywords = expectedKeywords.where((keyword) => userAnswer.contains(keyword)).length;
      int expectedKeywordCount = expectedKeywords.length;
      double score = (correctKeywords / expectedKeywordCount) * marks;
      tempTotalScore += score;

      print('Q$questionId: Correct: $correctKeywords, Expected: $expectedKeywordCount, Marks: $marks, Score: $score');
    }

    setState(() {
      totalScore = tempTotalScore;
    });
  }

  Future<void> _submitQuiz() async {
    bool allAnswered = questions.every((doc) => userAnswers.containsKey(doc.id) && userAnswers[doc.id]!.trim().isNotEmpty);

    if (!allAnswered) {
      int firstUnansweredIndex = questions.indexWhere((doc) => !userAnswers.containsKey(doc.id) || userAnswers[doc.id]!.trim().isEmpty);
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
          content: const Text('Are you sure you want to submit your answers? You will not be able to change them after submission.'),
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
    await _calculateScore();
    double finalScore = totalScore;

    try {
      await FirebaseFirestore.instance
          .collection('questions')
          .doc('subjective_question')
          .collection('quizzes')
          .doc(widget.quizId)
          .collection('submittedBy')
          .doc(userEmail)
          .set({
        'answers': userAnswers,
        'score': finalScore,
        'timestamp': FieldValue.serverTimestamp(),
      });

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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Subjective Quiz'),
          backgroundColor: Colors.blue[100],
        ),
        backgroundColor: Colors.blue[50],
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Subjective Quiz'),
          backgroundColor: Colors.blue[100],
        ),
        backgroundColor: Colors.blue[50],
        body: const Center(child: Text('No questions found or failed to load')),
      );
    }

    double totalPossibleMarks = questions.fold(0.0, (sum, doc) => sum + ((doc.data() as Map<String, dynamic>)['marks'] as int? ?? 0).toDouble());

    // Calculate current question's score for the equation
    String equationText = '';
    if (isSubmitted && questions.isNotEmpty) {
      final question = questions[currentPage];
      final String questionId = question.id;
      final List<String> expectedKeywords = List<String>.from(question['keywords'] ?? []);
      final int marks = (question['marks'] as int?) ?? 0;
      final String userAnswer = (userAnswers[questionId] ?? '').toLowerCase().trim();
      final int correctKeywords = expectedKeywords.where((keyword) => userAnswer.contains(keyword)).length;
      final int expectedKeywordCount = expectedKeywords.length;
      final double score = expectedKeywordCount > 0 ? (correctKeywords / expectedKeywordCount) * marks : 0;
      equationText = '($correctKeywords / $expectedKeywordCount) * $marks = ${score.toStringAsFixed(2)}';
    }

    return Scaffold(
        appBar: AppBar(
        title: const Text('Subjective Quiz'),
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
    });
    },
    itemBuilder: (context, index) {
    final question = questions[index];
    final String questionId = question.id;
    final String questionText = question['questionText'] ?? 'No question';
    final int marks = (question['marks'] as int?) ?? 0;
    final List<String> expectedKeywords = List<String>.from(question['keywords'] ?? []);
    final String userAnswer = (userAnswers[questionId] ?? '').toLowerCase().trim();
    final List<String> correctKeywords = isSubmitted
    ? expectedKeywords.where((keyword) => userAnswer.contains(keyword)).toList()
        : [];
    final List<String> missingKeywords = isSubmitted
    ? expectedKeywords.where((keyword) => !userAnswer.contains(keyword)).toList()
        : [];

    return SingleChildScrollView(
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    // Fixed section for question and answer input
    Padding(
    padding: const EdgeInsets.all(16.0),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    Text(
    'Question ${question['questionNumber']} ($marks marks): $questionText',
    style: const TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 20,
    color: Colors.blueAccent,
    ),
    ),
    const SizedBox(height: 20),
    TextField(
    controller: controllers[questionId],
    enabled: !isSubmitted,
    textAlign: TextAlign.left,
    textDirection: TextDirection.ltr,
    decoration: InputDecoration(
    labelText: 'Your Answer',
    border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(8),
    borderSide: BorderSide(color: Colors.blue[200]!),
    ),
    filled: true,
    fillColor: Colors.white,
    suffixIcon: isSubmitted
    ? Icon(
    Icons.check,
    color: Colors.green,
    )
        : null,
    ),
    maxLines: 5,
    onChanged: (value) {
    if (!isSubmitted) {
    setState(() {
    userAnswers[questionId] = value.trim();
    });
    }
    },
    ),
    ],
    ),
    ),
    if (isSubmitted) ...[
    Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0),
    child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
    const SizedBox(height: 20),
    Text(
    'Scoring Details:',
    style: const TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 18,
    color: Colors.blueAccent,
    ),
    ),
    const SizedBox(height: 10),
    // Scrollable List of Correct Keywords
    Container(
    constraints: const BoxConstraints(maxHeight: 200), // Limit height for scrolling
    child: ListView.builder(
    shrinkWrap: true,
    physics: const ClampingScrollPhysics(),
    itemCount: correctKeywords.length,
    itemBuilder: (context, i) {
    return ListTile(
    tileColor: Colors.green[50],
    leading: const Icon(Icons.check_circle, color: Colors.green),
    title: Text(correctKeywords[i], style: const TextStyle(color: Colors.green)),
    );
    },
    ),
    ),
    if (correctKeywords.isEmpty)
    const Text('None', style: TextStyle(color: Colors.green)),
    const SizedBox(height: 10),
    // Scrollable List of Missing Keywords
    Container(
    constraints: const BoxConstraints(maxHeight: 200), // Limit height for scrolling
    child: ListView.builder(
    shrinkWrap: true,
    physics: const ClampingScrollPhysics(),
    itemCount: missingKeywords.length,
    itemBuilder: (context, i) {
    return ListTile(
    tileColor: Colors.red[50],
    leading: const Icon(Icons.cancel, color: Colors.red),
    title: Text(missingKeywords[i], style: const TextStyle(color: Colors.red)),
    );
    },
    ),
    ),
    if (missingKeywords.isEmpty)
    const Text('None', style: TextStyle(color: Colors.green)),
    ],
    ),
    ),
    ],
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
    if (isSubmitted && equationText.isNotEmpty)
    Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Text(
    equationText,
    style: const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.blueAccent,
    ),
    ),
    ),
    Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
    if (currentPage > 0)
    ElevatedButton(
    onPressed: () {
    _pageController.previousPage(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
    );
    },
    style: ElevatedButton.styleFrom(
    backgroundColor: Colors.blue[100],
    foregroundColor: Colors.blue[800],
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: const Text('Previous'),
    )
    else
    const SizedBox(width: 0),
    Column(
    children: [
    if (isSubmitted)
    Text(
    'Total Score: ${totalScore.toStringAsFixed(2)} / $totalPossibleMarks',
    style: const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
    color: Colors.blueAccent,
    ),
    ),
    ],
    ),
    if (isSubmitted && currentPage < questions.length - 1)
    ElevatedButton(
    onPressed: () {
    _pageController.nextPage(
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
    );
    },
    style: ElevatedButton.styleFrom(
    backgroundColor: Colors.blue[100],
    foregroundColor: Colors.blue[800],
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: const Text('Next'),
    )
    else if (isSubmitted)
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
    onPressed: _submitQuiz,
    style: ElevatedButton.styleFrom(
    backgroundColor: Colors.blue[100],
    foregroundColor: Colors.blue[800],
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    child: const Text('Submit'),
    ),
    ],
    ),
    ],
    ),
    ),
    ],
    )
    );
  }


  @override
  void dispose() {
    _pageController.dispose();
    controllers.values.forEach((controller) => controller.dispose());
    super.dispose();
  }
}