import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Firebase Cloud Messaging Service for Push Notifications
class FCMService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Initialize FCM and request permissions
  static Future<void> initialize() async {
    try {
      // Request permission for iOS
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        print('FCM: User granted permission');
        
        // Get FCM token
        await _updateFCMToken();
        
        // Listen for token refresh
        _messaging.onTokenRefresh.listen(_saveFCMToken);
        
        // Setup message handlers
        _setupMessageHandlers();
      } else {
        print('FCM: User declined or has not accepted permission');
      }
    } catch (e) {
      print('FCM: Error initializing: $e');
    }
  }

  /// Update FCM token for current user
  static Future<void> _updateFCMToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveFCMToken(token);
      }
    } catch (e) {
      print('FCM: Error getting token: $e');
    }
  }

  /// Save FCM token to Firestore
  static Future<void> _saveFCMToken(String token) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': token,
        'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      });
      
      print('FCM: Token saved successfully');
    } catch (e) {
      print('FCM: Error saving token: $e');
    }
  }

  /// Setup message handlers for foreground and background
  static void _setupMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('FCM: Foreground message received');
      print('Title: ${message.notification?.title}');
      print('Body: ${message.notification?.body}');
      
      // Handle notification display in foreground
      _handleForegroundMessage(message);
    });

    // Background messages (when app is in background but not terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('FCM: Background message opened');
      _handleMessageTap(message);
    });
  }

  /// Handle foreground message display
  static void _handleForegroundMessage(RemoteMessage message) {
    // You can show a local notification here using flutter_local_notifications
    // For now, the in-app notification is already created in Firestore
    print('FCM: Handling foreground message: ${message.messageId}');
  }

  /// Handle message tap (navigation)
  static void _handleMessageTap(RemoteMessage message) {
    print('FCM: User tapped notification');
    final data = message.data;
    
    // Handle navigation based on notification type
    if (data.containsKey('type')) {
      final type = data['type'];
      print('FCM: Notification type: $type');
      
      // Add navigation logic here based on type
      // This will be handled by the app's navigation system
    }
  }

  /// Check if user has enabled push notifications for a specific type
  static Future<bool> _shouldSendPushNotification(
    String userId,
    String notificationType,
  ) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      
      if (!userDoc.exists) return false;
      
      final userData = userDoc.data()!;
      final preferences = userData['notificationPreferences'] as List<dynamic>? ??
                         userData['notifications'] as List<dynamic>?;
      
      // If no preferences set, send all notifications
      if (preferences == null || preferences.isEmpty) return true;
      
      // If "None" is selected, don't send any push notifications
      if (preferences.contains('None')) return false;
      
      // Check if the specific type is enabled
      return preferences.contains(notificationType);
    } catch (e) {
      print('FCM: Error checking preferences: $e');
      return false;
    }
  }

  /// Send push notification for new message
  static Future<void> sendNewMessageNotification({
    required String recipientUserId,
    required String senderName,
    required String messagePreview,
  }) async {
    try {
      // Check if user wants message notifications
      if (!await _shouldSendPushNotification(recipientUserId, 'Messages')) {
        print('FCM: User disabled message notifications');
        return;
      }

      final recipientDoc = await _firestore.collection('users').doc(recipientUserId).get();
      final fcmToken = recipientDoc.data()?['fcmToken'] as String?;
      
      if (fcmToken == null) {
        print('FCM: No token for user $recipientUserId');
        return;
      }

      // Create notification data for backend to send
      await _firestore.collection('fcm_notifications').add({
        'token': fcmToken,
        'title': 'New Message from $senderName',
        'body': messagePreview,
        'type': 'message',
        'senderId': _auth.currentUser?.uid,
        'recipientId': recipientUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      
      print('FCM: Message notification queued');
    } catch (e) {
      print('FCM: Error sending message notification: $e');
    }
  }

  /// Send push notification for new like
  static Future<void> sendNewLikeNotification({
    required String recipeOwnerUserId,
    required String likerName,
    required String recipeTitle,
  }) async {
    try {
      // Check if user wants like notifications (using 'Updates' category)
      if (!await _shouldSendPushNotification(recipeOwnerUserId, 'Updates')) {
        print('FCM: User disabled like notifications');
        return;
      }

      final ownerDoc = await _firestore.collection('users').doc(recipeOwnerUserId).get();
      final fcmToken = ownerDoc.data()?['fcmToken'] as String?;
      
      if (fcmToken == null) return;

      await _firestore.collection('fcm_notifications').add({
        'token': fcmToken,
        'title': '❤️ New Like!',
        'body': '$likerName liked your recipe "$recipeTitle"',
        'type': 'like',
        'senderId': _auth.currentUser?.uid,
        'recipientId': recipeOwnerUserId,
        'recipeTitle': recipeTitle,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      
      print('FCM: Like notification queued');
    } catch (e) {
      print('FCM: Error sending like notification: $e');
    }
  }

  /// Send push notification for new follower
  static Future<void> sendNewFollowerNotification({
    required String followedUserId,
    required String followerName,
  }) async {
    try {
      // Check if user wants follower notifications (using 'Updates' category)
      if (!await _shouldSendPushNotification(followedUserId, 'Updates')) {
        print('FCM: User disabled follower notifications');
        return;
      }

      final followedDoc = await _firestore.collection('users').doc(followedUserId).get();
      final fcmToken = followedDoc.data()?['fcmToken'] as String?;
      
      if (fcmToken == null) return;

      await _firestore.collection('fcm_notifications').add({
        'token': fcmToken,
        'title': '👥 New Follower!',
        'body': '$followerName started following you',
        'type': 'follow',
        'senderId': _auth.currentUser?.uid,
        'recipientId': followedUserId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      
      print('FCM: Follower notification queued');
    } catch (e) {
      print('FCM: Error sending follower notification: $e');
    }
  }

  /// Send push notification for new comment
  static Future<void> sendNewCommentNotification({
    required String recipeOwnerUserId,
    required String commenterName,
    required String recipeTitle,
    required String commentPreview,
  }) async {
    try {
      // Check if user wants comment notifications (using 'Updates' category)
      if (!await _shouldSendPushNotification(recipeOwnerUserId, 'Updates')) {
        print('FCM: User disabled comment notifications');
        return;
      }

      final ownerDoc = await _firestore.collection('users').doc(recipeOwnerUserId).get();
      final fcmToken = ownerDoc.data()?['fcmToken'] as String?;
      
      if (fcmToken == null) return;

      await _firestore.collection('fcm_notifications').add({
        'token': fcmToken,
        'title': '💬 New Comment!',
        'body': '$commenterName commented on "$recipeTitle": $commentPreview',
        'type': 'comment',
        'senderId': _auth.currentUser?.uid,
        'recipientId': recipeOwnerUserId,
        'recipeTitle': recipeTitle,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      
      print('FCM: Comment notification queued');
    } catch (e) {
      print('FCM: Error sending comment notification: $e');
    }
  }

  /// Send push notification for allergen warning
  static Future<void> sendAllergenWarningNotification({
    required String userId,
    required String recipeTitle,
    required List<String> allergens,
  }) async {
    try {
      // Always send allergen warnings regardless of preferences (safety)
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;
      
      if (fcmToken == null) return;

      await _firestore.collection('fcm_notifications').add({
        'token': fcmToken,
        'title': '⚠️ Allergen Alert!',
        'body': '$recipeTitle contains: ${allergens.join(', ')}',
        'type': 'allergen',
        'recipientId': userId,
        'recipeTitle': recipeTitle,
        'allergens': allergens,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'priority': 'high', // High priority for safety
      });
      
      print('FCM: Allergen warning notification queued');
    } catch (e) {
      print('FCM: Error sending allergen notification: $e');
    }
  }

  /// Send push notification for meal reminder
  static Future<void> sendMealReminderNotification({
    required String userId,
    required String mealTitle,
    required int minutesBefore,
  }) async {
    try {
      // Check if user wants meal reminders
      if (!await _shouldSendPushNotification(userId, 'Meal reminders')) {
        print('FCM: User disabled meal reminder notifications');
        return;
      }

      final userDoc = await _firestore.collection('users').doc(userId).get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;
      
      if (fcmToken == null) return;

      await _firestore.collection('fcm_notifications').add({
        'token': fcmToken,
        'title': '🍽️ Meal Reminder',
        'body': '$mealTitle is scheduled in $minutesBefore minutes!',
        'type': 'meal_reminder',
        'recipientId': userId,
        'mealTitle': mealTitle,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      
      print('FCM: Meal reminder notification queued');
    } catch (e) {
      print('FCM: Error sending meal reminder notification: $e');
    }
  }

  /// Send push notification for nutrition tip
  static Future<void> sendNutritionTipNotification({
    required String userId,
    required String tipTitle,
    required String tipMessage,
  }) async {
    try {
      // Check if user wants tips
      if (!await _shouldSendPushNotification(userId, 'Tips')) {
        print('FCM: User disabled tip notifications');
        return;
      }

      final userDoc = await _firestore.collection('users').doc(userId).get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;
      
      if (fcmToken == null) return;

      await _firestore.collection('fcm_notifications').add({
        'token': fcmToken,
        'title': tipTitle,
        'body': tipMessage,
        'type': 'tip',
        'recipientId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      
      print('FCM: Nutrition tip notification queued');
    } catch (e) {
      print('FCM: Error sending nutrition tip notification: $e');
    }
  }

  /// Send push notification for nutrition progress
  static Future<void> sendNutritionProgressNotification({
    required String userId,
    required String title,
    required String message,
  }) async {
    try {
      // Check if user wants progress notifications (using 'Tips' category)
      if (!await _shouldSendPushNotification(userId, 'Tips')) {
        print('FCM: User disabled progress notifications');
        return;
      }

      final userDoc = await _firestore.collection('users').doc(userId).get();
      final fcmToken = userDoc.data()?['fcmToken'] as String?;
      
      if (fcmToken == null) return;

      await _firestore.collection('fcm_notifications').add({
        'token': fcmToken,
        'title': title,
        'body': message,
        'type': 'nutrition_progress',
        'recipientId': userId,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
      
      print('FCM: Nutrition progress notification queued');
    } catch (e) {
      print('FCM: Error sending nutrition progress notification: $e');
    }
  }

  /// Clear FCM token on logout
  static Future<void> clearFCMToken() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('users').doc(user.uid).update({
        'fcmToken': FieldValue.delete(),
      });
      
      // Delete FCM token from Firebase
      await _messaging.deleteToken();
      
      print('FCM: Token cleared');
    } catch (e) {
      print('FCM: Error clearing token: $e');
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('FCM: Handling background message: ${message.messageId}');
  // Background messages are already handled by FCM
  // Just log the message
}
