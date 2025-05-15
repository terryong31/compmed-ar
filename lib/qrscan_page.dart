import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});

  @override
  QRScanScreenState createState() => QRScanScreenState();
}

class QRScanScreenState extends State<QRScanScreen> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  String qrCodeResult = "Scan QR to add subject";

  @override
  void reassemble() {
    super.reassemble();
    if (controller != null) {
      if (Platform.isAndroid) {
        controller!.pauseCamera();
      }
      controller!.resumeCamera();
    }
  }

  void onQRViewCreated(QRViewController controller) {
    this.controller = controller;

    controller.scannedDataStream.listen((scanData) async {
      if (scanData.code != null && scanData.code != qrCodeResult) {
        setState(() => qrCodeResult = scanData.code!);

        // Show processing message with floating behavior, overlapping the button
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Processing...'),
            behavior: SnackBarBehavior.floating, // Make SnackBar float above UI
            margin: const EdgeInsets.only(bottom: 48.0), // Reduced margin to allow overlap with the button
          ),
        );

        // Add the subject to Firestore
        await addSubjectToUser(qrCodeResult);

        // Delay to prevent immediate re-scanning of the same QR code
        await Future.delayed(const Duration(seconds: 2));

        // Resume camera to continue scanning
        controller.resumeCamera();
      }
    });
  }

  Future<void> addSubjectToUser(String subjectId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final userDoc = await userRef.get();

    if (userDoc.exists) {
      List<String> subjects = List<String>.from(userDoc.data()?['subjects'] ?? []);

      if (!subjects.contains(subjectId)) {
        subjects.add(subjectId);
        await userRef.update({'subjects': subjects});

        // Show success message with floating behavior, overlapping the button
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Subject added successfully!'),
            behavior: SnackBarBehavior.floating, // Make SnackBar float above UI
            margin: const EdgeInsets.only(bottom: 48.0), // Reduced margin to allow overlap with the button
          ),
        );
      } else {
        // Show already exists message with floating behavior, overlapping the button
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Subject already exists.'),
            behavior: SnackBarBehavior.floating, // Make SnackBar float above UI
            margin: const EdgeInsets.only(bottom: 48.0), // Reduced margin to allow overlap with the button
          ),
        );
      }
    } else {
      await userRef.set({'subjects': [subjectId]}, SetOptions(merge: true));

      // Show success message with floating behavior, overlapping the button
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Subject added successfully!'),
          behavior: SnackBarBehavior.floating, // Make SnackBar float above UI
          margin: const EdgeInsets.only(bottom: 48.0), // Reduced margin to allow overlap with the button
        ),
      );
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: <Widget>[
          QRView(key: qrKey, onQRViewCreated: onQRViewCreated),
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.white70,
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    qrCodeResult,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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