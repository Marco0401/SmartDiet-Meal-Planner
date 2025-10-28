import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'dart:async';
import 'login_page.dart';
import 'main.dart';
import 'onboarding/onboarding_page.dart';
import 'services/google_signin_service.dart';
import 'utils/error_handler.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _showVerify = false;

  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

  User? _newUser;

  Future<void> _register() async {
    if (_isLoading) return; // Prevent multiple taps

    // Check internet connectivity first
    final hasInternet = await ErrorHandler.hasInternetConnection();
    if (!hasInternet && mounted) {
      ErrorHandler.showOfflineSnackbar(context);
      setState(() {
        _error = 'No internet connection. Please check your network.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
      _showVerify = false;
    });

    // Validate passwords match
    if (_passwordController.text != _confirmController.text) {
      setState(() {
        _isLoading = false;
        _error = 'Passwords do not match';
      });
      return;
    }

    try {
      print('DEBUG: Creating new account...');
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          );

      if (userCredential.user == null) {
        throw Exception('Registration failed - no user returned');
      }

      _newUser = userCredential.user;
      print('DEBUG: Sending verification email...');
      await _newUser!.sendEmailVerification();

      setState(() {
        _showVerify = true;
      });
      print('DEBUG: Verification email sent successfully');
    } on FirebaseAuthException catch (e) {
      print('DEBUG: FirebaseAuthException: ${e.code} - ${e.message}');
      final errorMessage = ErrorHandler.getAuthErrorMessage(e);
      setState(() {
        _error = errorMessage;
      });
    } on SocketException catch (_) {
      print('DEBUG: Network error during registration');
      setState(() {
        _error = 'No internet connection. Please check your network.';
      });
      if (mounted) {
        ErrorHandler.showOfflineSnackbar(context);
      }
    } on TimeoutException catch (_) {
      print('DEBUG: Timeout during registration');
      setState(() {
        _error = 'Request timeout. Please try again.';
      });
    } catch (e) {
      print('DEBUG: Unknown error during registration: $e');
      setState(() {
        _error = ErrorHandler.getGeneralErrorMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _checkVerification() async {
    await _newUser?.reload();
    _newUser = FirebaseAuth.instance.currentUser;
    if (_newUser != null && _newUser!.emailVerified) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Success'),
            content: const Text('Email verified! You can now log in.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context); // Go back to login
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } else {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Not Verified'),
            content: const Text(
              'Your email is not verified yet. Please check your inbox and click the verification link.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _signUpWithGoogle() async {
    if (_isLoading) return; // Prevent multiple taps
    
    setState(() {
      _isLoading = true;
      _error = null;
      _showVerify = false;
    });

    try {
      // Step 1: Sign in with Google
      print('DEBUG: Starting Google Sign-Up...');
      final googleSignInService = GoogleSignInService();
      final GoogleSignInAccount? googleUser = await googleSignInService.signIn();
      
      // User cancelled the sign-in
      if (googleUser == null) {
        print('DEBUG: Google Sign-Up cancelled by user');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      print('DEBUG: Google account selected: ${googleUser.email}');

      // Step 2: Get authentication credentials
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      if (googleAuth.accessToken == null || googleAuth.idToken == null) {
        throw Exception('Failed to get Google authentication tokens');
      }

      // Step 3: Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Step 4: Sign in to Firebase (or create account if it doesn't exist)
      print('DEBUG: Authenticating with Firebase...');
      final userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      
      if (userCredential.user == null) {
        throw Exception('Failed to authenticate with Firebase');
      }

      final user = userCredential.user!;
      print('DEBUG: Firebase authentication successful: ${user.uid}');

      // Step 5: Check/Create user profile in Firestore
      final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final doc = await docRef.get();

      if (!doc.exists) {
        print('DEBUG: Creating new user profile for: ${user.email}');
        // Create user document for new users
        await docRef.set({
          'email': user.email,
          'displayName': user.displayName,
          'photoURL': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'provider': 'google',
        });

        // Navigate to onboarding for new users
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => OnboardingPage(uid: user.uid),
            ),
          );
        }
      } else {
        print('DEBUG: User already exists, navigating to home...');
        // User already exists, navigate to home
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => const MyHomePage(title: 'SmartDiet'),
            ),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      print('DEBUG: FirebaseAuthException: ${e.code} - ${e.message}');
      String errorMessage;
      
      switch (e.code) {
        case 'account-exists-with-different-credential':
          errorMessage = 'An account already exists with this email using a different sign-in method. Please try signing in with email and password.';
          break;
        case 'invalid-credential':
          errorMessage = 'Invalid Google credentials. Please try again.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Google sign-up is not enabled. Please contact support.';
          break;
        case 'user-disabled':
          errorMessage = 'This account has been disabled.';
          break;
        case 'network-request-failed':
          errorMessage = 'Network error. Please check your internet connection.';
          break;
        default:
          errorMessage = e.message ?? 'An error occurred during Google sign-up.';
      }
      
      setState(() {
        _error = errorMessage;
      });
    } catch (e) {
      print('DEBUG: General exception: $e');
      setState(() {
        _error = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF2E7D32),
                  Color(0xFF388E3C),
                  Color(0xFF4CAF50),
                  Color(0xFF66BB6A),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo/Icon
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.green[50]!,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                          width: 60,
                          height: 60,
                          fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'SmartDiet',
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.5,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 3),
                            blurRadius: 8,
                            color: Colors.black26,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your SmartDiet account',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      elevation: 15,
                      shadowColor: Colors.green.withOpacity(0.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white,
                              Colors.green[50]!,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: Colors.green[200]!,
                            width: 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(28.0),
                        child: Column(
                          children: [
                            TextField(
                              controller: _emailController,
                              decoration: InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(
                                  Icons.email_outlined,
                                  color: Colors.green[600],
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(color: Colors.green[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(color: Colors.green[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(color: Colors.green[600]!, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                              ),
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _passwordController,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  color: Colors.green[600],
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(color: Colors.green[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(color: Colors.green[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(color: Colors.green[600]!, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _passwordVisible ? Icons.visibility : Icons.visibility_off,
                                    color: Colors.green[600],
                                  ),
                                  onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                                ),
                              ),
                              obscureText: !_passwordVisible,
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'At least 6 characters.',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _confirmController,
                              decoration: InputDecoration(
                                labelText: 'Confirm Password',
                                prefixIcon: Icon(
                                  Icons.lock_outline,
                                  color: Colors.green[600],
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(color: Colors.green[300]!),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(color: Colors.green[300]!),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(color: Colors.green[600]!, width: 2),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _confirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                    color: Colors.green[600],
                                  ),
                                  onPressed: () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
                                ),
                              ),
                              obscureText: !_confirmPasswordVisible,
                            ),
                            const SizedBox(height: 24),
                            if (_error != null)
                              AnimatedOpacity(
                                opacity: 1.0,
                                duration: Duration(milliseconds: 300),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  margin: const EdgeInsets.only(bottom: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.red[50],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error, color: Colors.red),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(_error!, style: const TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            if (!_showVerify)
                              SizedBox(
                                width: double.infinity,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E7D32),
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  elevation: 8,
                                  shadowColor: Colors.green.withOpacity(0.4),
                                ),
                                onPressed: _isLoading ? null : _register,
                                child: _isLoading
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Text(
                                        'Register',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            // Divider with "OR" text
                            Row(
                              children: [
                                Expanded(child: Divider(color: Colors.grey[300])),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'OR',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Expanded(child: Divider(color: Colors.grey[300])),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Google Sign-In Button
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                icon: Image.asset(
                                  'assets/icon/google_logo.png',
                                  height: 20,
                                  width: 20,
                                  fit: BoxFit.contain,
                                ),
                                label: const Text(
                                  'Sign up with Google',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                                onPressed: _isLoading
                                    ? null
                                    : _signUpWithGoogle,
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                    horizontal: 16,
                                  ),
                                  side: const BorderSide(
                                    color: Color(0xFF2E7D32),
                                    width: 2,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  backgroundColor: Colors.white,
                                ),
                              ),
                            ),
                            if (_showVerify)
                              Column(
                                children: [
                                  const SizedBox(height: 16),
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'A verification link has been sent to your email. Please verify your email before logging in.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF388E3C),
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                      onPressed: _checkVerification,
                                      child: const Text(
                                        'I have verified my email',
                                        style: TextStyle(fontSize: 18, color: Colors.white),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Already have an account? Log in'),
                            ),
                          ],
                        ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.2),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
