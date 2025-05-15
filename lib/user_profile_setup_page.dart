import 'package:compmedar/user_dashboard.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:io';

class UserProfileSetupPage extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const UserProfileSetupPage({super.key, this.initialData});

  @override
  UserProfileSetupPageState createState() => UserProfileSetupPageState();
}

class UserProfileSetupPageState extends State<UserProfileSetupPage> {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _formKey = GlobalKey<FormState>();

  String? firstName;
  String? lastName;
  DateTime? dateOfBirth;
  String? studyCourse;
  File? profileImage;
  String? profileImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchUserData(); // Fetch user data from Firestore
    _requestPermissions(); // Request permissions
  }

  Future<void> _fetchUserData() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugPrint('No user is signed in!');
        return;
      }

      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (doc.exists) {
        final data = doc.data();
        setState(() {
          firstName = data?['first_name'] ?? '';
          lastName = data?['last_name'] ?? '';
          studyCourse = data?['study_course'] ?? '';
          if (data?['date_of_birth'] != null) {
            dateOfBirth = (data?['date_of_birth'] as Timestamp).toDate();
          }
          profileImageUrl = data?['profile_image_url'];
        });
      } else {
        debugPrint('User document does not exist.');
      }
    } catch (e) {
      debugPrint('Failed to fetch user data: $e');
    }
  }

  Future<void> _requestPermissions() async {
    var status = await Permission.storage.request();
    if (status.isGranted) {
      // Permission granted; proceed as needed
    } else if (status.isDenied) {
      _showPermissionDeniedMessage(context);
    } else if (status.isPermanentlyDenied) {
      // If the user permanently denies the permission, open app settings
      openAppSettings();
    }
  }

  void _showPermissionDeniedMessage(BuildContext context) {
  }

  void _selectDate(BuildContext context) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: dateOfBirth ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        dateOfBirth = picked;
      });
    }
  }

  // Function to pick and crop image
  Future<void> _pickAndCropImage() async {
    try {
      final picker = ImagePicker();
      final pickedImage = await picker.pickImage(source: ImageSource.gallery);

      if (pickedImage == null) {
        debugPrint("No image selected.");
        return; // Exit if no image is picked
      }

      // Crop the image
      CroppedFile? croppedImage = await ImageCropper().cropImage(
        sourcePath: pickedImage.path,
        aspectRatio: const CropAspectRatio(ratioX: 1.0, ratioY: 1.0),
        maxWidth: 500,
        maxHeight: 500,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: Colors.blue,
            toolbarWidgetColor: Colors.white,
            lockAspectRatio: true,
            activeControlsWidgetColor: Colors.blueAccent,
          ),
          IOSUiSettings(
            title: 'Crop Image',
          ),
        ],
      );

      if (croppedImage == null) {
        debugPrint("Cropping canceled.");
        return; // Exit if cropping is canceled
      }

      // Compress the image
      final compressedImage = await FlutterImageCompress.compressAndGetFile(
        croppedImage.path, // Input file path
        '${croppedImage.path}_compressed.jpg', // Output file path
        quality: 85, // Adjust quality as needed (1-100)
      );

      if (compressedImage == null) {
        debugPrint("Image compression failed.");
        return;
      }

      setState(() {
        profileImage = File(compressedImage.path); // Set the compressed image
      });

      // Upload the compressed image
      await uploadProfileImage(profileImage!);
    } catch (e) {
      debugPrint("Error picking or cropping image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick and crop image: $e')),
      );
    }
  }

  Future<void> uploadProfileImage(File profileImage) async {
    try {
      // Reference to Firebase Storage location
      final ref = FirebaseStorage.instance
          .ref()
          .child('user_profiles')
          .child(
          '${_auth.currentUser!.uid}.jpg'); // Filename is user UID + .jpg

      // Upload the file
      final uploadTask = ref.putFile(profileImage);
      await uploadTask;

      // Get the download URL of the uploaded file
      final downloadURL = await ref.getDownloadURL();
      debugPrint("File uploaded successfully. URL: $downloadURL");

      // Update Firestore with the download URL
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({'profile_image_url': downloadURL});

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile image uploaded successfully.')),
      );
    } catch (e) {
      debugPrint("Failed to upload image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $e')),
      );
      rethrow;
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      try {
        String? uploadedImageUrl = profileImageUrl;

        if (profileImage != null) {
          final ref = FirebaseStorage.instance
              .ref()
              .child('user_profiles')
              .child('${_auth.currentUser!.uid}.jpg');

          await ref.putFile(profileImage!);
          uploadedImageUrl = await ref.getDownloadURL();
        }

        // Save the user's profile data
        await _firestore.collection('users').doc(_auth.currentUser!.uid).set({
          'first_name': firstName,
          'last_name': lastName,
          'study_course': studyCourse,
          'date_of_birth': dateOfBirth != null ? Timestamp.fromDate(
              dateOfBirth!) : null,
          'profile_image_url': uploadedImageUrl,
        }, SetOptions(merge: true));

        // Update profile completion status
        await FirebaseFirestore.instance.collection('users').doc(
            FirebaseAuth.instance.currentUser!.uid).update({
          'is_user_profile_completed': 'yes', // Mark the profile as completed
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!')),
        );

        // Redirect to the dashboard after saving the profile
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const UserDashboard()),
        );
      } catch (e) {
        showDialog(
          context: context,
          builder: (context) =>
              AlertDialog(
                title: const Text('Error'),
                content: Text('Failed to save profile: $e'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: const Text('User Profile Setup', style: TextStyle(color: Colors.white)),
          centerTitle: true,
          backgroundColor: Colors.blueAccent,
          elevation: 5,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Profile Image Section
                CircleAvatar(
                  radius: 60,
                  backgroundImage: profileImage != null
                      ? FileImage(profileImage!)
                      : (profileImageUrl != null
                      ? NetworkImage(profileImageUrl!)
                      : const AssetImage('assets/default_profile.png')) as ImageProvider,
                  child: profileImage == null
                      ? IconButton(
                    icon: const Icon(Icons.camera_alt, size: 30, color: Colors.white),
                    onPressed: _pickAndCropImage, // Trigger image selection and cropping
                  )
                      : null,
                ),
                const SizedBox(height: 20),

                // First Name Text Field
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'First Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  initialValue: firstName,
                  validator: (value) => value!.isEmpty ? 'Enter your first name' : null,
                  onSaved: (value) => firstName = value,
                ),
                const SizedBox(height: 20),

                // Last Name Text Field
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Last Name',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  initialValue: lastName,
                  validator: (value) => value!.isEmpty ? 'Enter your last name' : null,
                  onSaved: (value) => lastName = value,
                ),
                const SizedBox(height: 20),

                // Date of Birth Field
                GestureDetector(
                  onTap: () => _selectDate(context),
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Date of Birth',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        prefixIcon: const Icon(Icons.calendar_today),
                      ),
                      controller: TextEditingController(
                        text: dateOfBirth == null
                            ? ''
                            : DateFormat('MMM dd, yyyy').format(dateOfBirth!),
                      ),
                      validator: (value) => dateOfBirth == null ? 'Select your date of birth' : null,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Study Course Field
                TextFormField(
                  decoration: InputDecoration(
                    labelText: 'Study Course',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.book),
                  ),
                  initialValue: studyCourse,
                  validator: (value) => value!.isEmpty ? 'Enter your study course' : null,
                  onSaved: (value) => studyCourse = value,
                ),
                const SizedBox(height: 30),

                // Save Profile Button
                ElevatedButton(
                  onPressed: _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    backgroundColor: Colors.blueAccent,
                  ),
                  child: const Text(
                    'Save Profile',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
  }
}