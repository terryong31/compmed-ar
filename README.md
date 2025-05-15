# 🧠 CompMed AR – Human Anatomy Augmented Reality Learning App

**CompMed AR** is an educational mobile application designed to enhance the learning and assessment of human anatomy using Augmented Reality (AR) technology. Developed for medical students, this app provides an interactive and immersive 3D experience of real human organ models.

## 📱 Features

- 🔬 **3D Organ Viewer**: View real captured 3D models of human organs in Augmented Reality.
- 📚 **Interactive Learning**: Rotate, zoom, and explore anatomical structures in detail.
- ✅ **Assessment Module**: Built-in quizzes and learning assessments for self-evaluation.
- 🔐 **Admin Dashboard**: Secure admin portal for uploading and managing 3D content.
- 🔒 **OAuth 2.0 Login**: Only users with `@qiu.edu.my` emails can access the admin panel.

## 🚀 Tech Stack

- **Frontend (Mobile App)**: Flutter, ARCore (Android), ARKit (iOS)
- **Backend**: Firebase Firestore, Firebase Storage, Firebase Authentication
- **3D Rendering**: Unity (for model preparation), GLTF/GLB format for WebAR compatibility
- **Authentication**: Google OAuth 2.0 restricted to `@qiu.edu.my` domain

## 🎓 Target Users

- Medical Students (Anatomy Learning)
- Medical Lecturers and Educators
- Institutions aiming to adopt AR in their curriculum

## 🛠️ How to Run (Dev Setup)

1. **Clone the Repository**
   ```bash
   git clone https://github.com/yourusername/compmed-ar.git
   cd compmed-ar
