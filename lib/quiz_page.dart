import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'quiz_list_page.dart'; // Ensure this file exists

class QuizPage extends StatelessWidget {
  // References to the quizzes subcollections
  final CollectionReference subjectiveQuizzes = FirebaseFirestore.instance
      .collection('questions')
      .doc('subjective_question')
      .collection('quizzes');
  final CollectionReference objectiveQuizzes = FirebaseFirestore.instance
      .collection('questions')
      .doc('objective_question')
      .collection('quizzes');
  final CollectionReference modelQuizzes = FirebaseFirestore.instance
      .collection('questions')
      .doc('3Dmodel_question')
      .collection('quizzes');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Quiz Categories"),
        backgroundColor: Colors.blue[100], // Light blue AppBar
      ),
      backgroundColor: Colors.blue[50], // Very light blue background for the page
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Objective Questions Button
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 15.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuizListPage(
                        title: 'Objective Quizzes',
                        collection: objectiveQuizzes,
                        quizType: 'objective',
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[100], // Light blue background
                  foregroundColor: Colors.blue[800], // Darker blue text/icon
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), // Rounded corners
                  ),
                  elevation: 5, // Slight shadow for depth
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.check_circle_outline, size: 24), // Icon for objective
                    SizedBox(width: 10), // Space between icon and text
                    Text('Objective Questions'),
                  ],
                ),
              ),
            ),
            // Subjective Questions Button
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 15.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuizListPage(
                        title: 'Subjective Quizzes',
                        collection: subjectiveQuizzes,
                        quizType: 'subjective',
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[100], // Light blue background
                  foregroundColor: Colors.blue[800], // Darker blue text/icon
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.edit, size: 24), // Icon for subjective
                    SizedBox(width: 10),
                    Text('Subjective Questions'),
                  ],
                ),
              ),
            ),
            // 3D Model Questions Button
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 15.0),
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => QuizListPage(
                        title: '3D Model Quizzes',
                        collection: modelQuizzes,
                        quizType: '3Dmodel',
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[100], // Light blue background
                  foregroundColor: Colors.blue[800], // Darker blue text/icon
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.threed_rotation, size: 24), // Icon for 3D model
                    SizedBox(width: 10),
                    Text('3D Model Questions'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}