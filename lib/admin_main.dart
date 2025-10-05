import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'admin/admin_main.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load();

  // Initialize Firebase with your existing project configuration
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBHy5ToXX9ksTuG4oNWFD381W67MAma4AQ",
        authDomain: "smartdiet-3fc8b.firebaseapp.com",
        projectId: "smartdiet-3fc8b",
        storageBucket: "smartdiet-3fc8b.firebasestorage.app",
        messagingSenderId: "6652139548",
        appId: "1:6652139548:web:78c87494a7596ec762a7d9",
        measurementId: "G-0X926KNZKM",
      ),
    );
  } catch (e) {
    print('Firebase initialization error: $e');
    // Continue anyway for development
  }

  runApp(const AdminApp());
}
