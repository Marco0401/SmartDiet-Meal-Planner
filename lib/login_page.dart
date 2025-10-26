import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart';
import 'register_page.dart';
import 'onboarding/onboarding_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  bool _passwordVisible = false;

  @override
  void initState() {
    super.initState();
    _prefillEmailIfLoggedIn();
  }

  Future<void> _prefillEmailIfLoggedIn() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && user.email != null) {
      // User is already logged in, redirect to main page
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const MyHomePage(title: 'SmartDiet'),
              ),
            );
          }
        });
        return;
      }
    }
    
    // Try to get the last used email from SharedPreferences or Firestore
    await _loadLastUsedEmail();
  }

  Future<void> _loadLastUsedEmail() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastEmail = prefs.getString('last_email');
      if (lastEmail != null && lastEmail.isNotEmpty) {
        setState(() {
          _emailController.text = lastEmail;
        });
      }
    } catch (e) {
      print('Error loading last used email: $e');
    }
  }

  Future<void> _saveLastUsedEmail(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_email', email);
    } catch (e) {
      print('Error saving last used email: $e');
    }
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      print("Attempting sign in...");
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      print("Signed in: ${credential.user?.uid}");
      
      // Save the email for future use
      await _saveLastUsedEmail(credential.user!.email!);
      
      if (!credential.user!.emailVerified) {
        setState(() {
          _error = "Please verify your email before logging in.";
        });
        await FirebaseAuth.instance.signOut();
        return;
      }
      print("Email verified");
      // Check if user profile exists in Firestore
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid);
      final doc = await docRef.get();
      print("Firestore doc exists: ${doc.exists}");
      if (!doc.exists) {
        // --- CREATE USER DOCUMENT IF NOT EXISTS ---
        await docRef.set({
          'email': credential.user!.email,
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => OnboardingPage(uid: credential.user!.uid),
                ),
              );
            }
          });
        }
      } else {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyHomePage(title: 'SmartDiet'),
                ),
              );
            }
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'user-not-found') {
          _error = 'No account found for that email.';
        } else if (e.code == 'wrong-password') {
          _error = 'Incorrect password.';
        } else {
          _error = e.message;
        }
      });
      print("FirebaseAuthException: ${e.message}");
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      print("Unknown error: ${e.toString()}");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      print("Starting Google sign-in...");
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
          _error = "Google sign-in cancelled.";
        });
        print("Google sign-in cancelled by user.");
        return;
      }
      print("Google user: ${googleUser.email}");
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );
      print("Firebase user: ${userCredential.user?.uid}");
      
      // Save the email for future use
      await _saveLastUsedEmail(userCredential.user!.email!);
      // Check if user profile exists in Firestore
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid);
      final doc = await docRef.get();
      print("Firestore doc exists: ${doc.exists}");
      if (!doc.exists) {
        // --- CREATE USER DOCUMENT IF NOT EXISTS ---
        await docRef.set({
          'email': userCredential.user!.email,
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => OnboardingPage(uid: userCredential.user!.uid),
                ),
              );
            }
          });
        }
      } else {
        if (mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyHomePage(title: 'SmartDiet'),
                ),
              );
            }
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message;
      });
      print("FirebaseAuthException: ${e.message}");
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
      print("Unknown error: ${e.toString()}");
    } finally {
      setState(() {
        _isLoading = false;
      });
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
                      'Your Personal Nutrition Assistant',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),
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
                                onPressed: _isLoading ? null : _login,
                                child: _isLoading
                                    ? const CircularProgressIndicator(color: Colors.white)
                                    : const Text(
                                        'Login',
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(child: Divider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                  ),
                                  child: Text(
                                    'or',
                                    style: TextStyle(color: Colors.grey[700]),
                                  ),
                                ),
                                Expanded(child: Divider()),
                              ],
                            ),
                            const SizedBox(height: 16),
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
                                  'Sign in with Google',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                                onPressed: _isLoading
                                    ? null
                                    : _signInWithGoogle,
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
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const RegisterPage(),
                                  ),
                                );
                              },
                              child: const Text('Don\'t have an account? Register'),
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
