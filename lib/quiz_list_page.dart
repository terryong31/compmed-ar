import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'objective.dart'; // Ensure this file exists
import 'subjective.dart'; // Ensure this file exists
import 'three_d_model_question.dart'; // Ensure this file exists

class QuizListPage extends StatelessWidget {
  final String title;
  final CollectionReference collection;
  final String quizType;

  const QuizListPage({
    required this.title,
    required this.collection,
    required this.quizType,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.blue[100], // Light blue AppBar
      ),
      backgroundColor: Colors.blue[50], // Light blue background
      body: FutureBuilder<QuerySnapshot>(
        future: collection.get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.blueAccent),
              ),
            );
          }

          final List<DocumentSnapshot> quizzes = snapshot.data?.docs ?? [];

          if (quizzes.isEmpty) {
            return const Center(
              child: Text(
                'No quizzes found for this category.',
                style: TextStyle(color: Colors.blueAccent, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: quizzes.length,
            itemBuilder: (context, index) {
              final quiz = quizzes[index];
              final String quizTitle = quiz['quizTitle'] ?? 'Untitled Quiz';
              final String quizId = quiz.id;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue[200]!), // Light blue border
                    borderRadius: BorderRadius.circular(8), // Rounded corners
                    color: Colors.white, // White background for contrast
                  ),
                  child: ListTile(
                    title: Text(
                      quizTitle,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.blueAccent, // Darker blue text
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onTap: () async {
                      if (quizType == '3Dmodel') {
                        try {
                          // Fetch the first questionId from Firestore
                          QuerySnapshot querySnapshot = await FirebaseFirestore.instance
                              .collection('questions')
                              .doc('3Dmodel_question')
                              .collection('quizzes')
                              .doc(quizId)
                              .collection('3Dquestions')
                              .orderBy('questionNumber') // Add ordering
                              .limit(1) // Limit to the first question
                              .get();

                          if (querySnapshot.docs.isNotEmpty) {
                            String questionId = querySnapshot.docs.first.id;

                            // Navigate to ThreeDModelPage with both quizId and questionId
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ThreeDModelPuzzlePage(
                                  quizId: quizId,
                                  questionId: questionId,
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("No questions found for this quiz.")),
                            );
                          }
                        } catch (e) {
                          print("Error fetching questionId: $e");
                        }
                      } else if (quizType == 'objective') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ObjectiveQuizPage(quizId: quizId),
                          ),
                        );
                      } else if (quizType == 'subjective') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SubjectiveQuizPage(quizId: quizId),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const Scaffold(
                              body: Center(child: Text('Unknown quiz type')),
                            ),
                          ),
                        );
                      }
                    },

                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}