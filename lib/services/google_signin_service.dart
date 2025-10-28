import 'package:google_sign_in/google_sign_in.dart';

/// Singleton service for Google Sign-In
/// Ensures we always use the same GoogleSignIn instance across the app
class GoogleSignInService {
  // Private constructor
  GoogleSignInService._();
  
  // Singleton instance
  static final GoogleSignInService _instance = GoogleSignInService._();
  
  // Factory constructor returns the singleton
  factory GoogleSignInService() => _instance;
  
  // The actual GoogleSignIn instance (configured once)
  // Using the Web client ID (client_type 3) from google-services.json
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    // Web OAuth client ID - this fixes the unclickable account picker issue
    serverClientId: '6652139548-5po05ls29koq352hro9vhugalqp90tra.apps.googleusercontent.com',
  );
  
  /// Get the GoogleSignIn instance
  GoogleSignIn get instance => _googleSignIn;
  
  /// Sign in with Google
  Future<GoogleSignInAccount?> signIn() async {
    try {
      return await _googleSignIn.signIn();
    } catch (e) {
      print('Google Sign-In error: $e');
      rethrow;
    }
  }
  
  /// Sign out from Google
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
  
  /// Disconnect from Google (full cleanup)
  Future<void> disconnect() async {
    try {
      await _googleSignIn.disconnect();
    } catch (e) {
      print('Disconnect error (can be ignored): $e');
    }
  }
}
