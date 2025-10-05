import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'admin_login_page.dart';
import 'admin_dashboard.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartDiet App Admin Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const AdminAuthWrapper(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AdminAuthWrapper extends StatelessWidget {
  const AdminAuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasData) {
          // Check if user is admin
          return FutureBuilder<bool>(
            future: _isAdmin(snapshot.data!.uid),
            builder: (context, adminSnapshot) {
              if (adminSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (adminSnapshot.data == true) {
                return const AdminDashboard();
              } else {
                return const AdminLoginPage(
                  errorMessage: 'Access denied. Admin privileges required.',
                );
              }
            },
          );
        }

        return const AdminLoginPage();
      },
    );
  }

  Future<bool> _isAdmin(String uid) async {
    try {
      print('DEBUG: Checking admin status for UID: $uid');
      
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      print('DEBUG: Document exists: ${doc.exists}');
      
      if (doc.exists) {
        final data = doc.data();
        print('DEBUG: User data: $data');
        
        final isAdmin = data?['role'] == 'admin' || data?['isAdmin'] == true;
        print('DEBUG: Is admin: $isAdmin');
        print('DEBUG: Role: ${data?['role']}');
        print('DEBUG: isAdmin field: ${data?['isAdmin']}');
        
        return isAdmin;
      }
      
      print('DEBUG: Document does not exist');
      return false;
    } catch (e) {
      print('DEBUG: Error checking admin status: $e');
      return false; // Secure by default - deny access on error
    }
  }
}
