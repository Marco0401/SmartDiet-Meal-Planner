import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class NotificationService {
  static const String _collectionName = 'notifications';
  
  /// Create a new notification
  static Future<void> createNotification({
    required String title,
    required String message,
    required String type,
    String? actionData,
    IconData? icon,
    Color? color,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection(_collectionName)
          .add({
        'title': title,
        'message': message,
        'type': type,
        'actionData': actionData,
        'icon': icon?.codePoint,
        'color': color?.value,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error creating notification: $e');
    }
  }

  /// Get user's notification preferences
  static Future<List<String>> getUserNotificationPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return ['None'];

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        // Check both 'notificationPreferences' and 'notifications' fields
        final preferences = data['notificationPreferences'] as List<dynamic>? ??
                           data['notifications'] as List<dynamic>?;
        return preferences?.map((e) => e.toString()).toList() ?? ['None'];
      }
    } catch (e) {
      print('Error getting notification preferences: $e');
    }

    return ['None'];
  }

  /// Update user's notification preferences
  static Future<void> updateUserNotificationPreferences(List<String> preferences) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'notificationPreferences': preferences,
        'notifications': preferences, // Also save to the field used by Account Settings
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error updating notification preferences: $e');
    }
  }

  /// Get notifications for user (including nutritionist/admin notifications)
  static Future<List<Map<String, dynamic>>> getUserNotifications({
    String? type,
    bool? isRead,
    int limit = 50,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      // Get all notifications first (to avoid Firestore index issues)
      Query userQuery = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection(_collectionName)
          .orderBy('createdAt', descending: true)
          .limit(limit * 2); // Get more to account for filtering

      final userSnapshot = await userQuery.get();
      List<Map<String, dynamic>> allNotifications = userSnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'source': 'user',
          ...data,
          'icon': data['icon'] != null ? IconData(data['icon'], fontFamily: 'MaterialIcons') : Icons.notifications,
          'color': data['color'] != null ? Color(data['color']) : Colors.green,
        };
      }).toList();

      // Apply client-side filtering
      if (type != null && type != 'All') {
        allNotifications = allNotifications.where((notification) {
          return notification['type'] == type;
        }).toList();
      }

      if (isRead != null) {
        allNotifications = allNotifications.where((notification) {
          return notification['isRead'] == isRead;
        }).toList();
      }

      // Sort by creation date and limit
      allNotifications.sort((a, b) {
        final aTime = a['createdAt'] as Timestamp?;
        final bTime = b['createdAt'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });

      return allNotifications.take(limit).toList();
    } catch (e) {
      print('Error getting notifications: $e');
      return [];
    }
  }

  /// Mark notification as read
  static Future<void> markAsRead(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Mark as read in user's notifications (includes nutritionist notifications)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection(_collectionName)
          .doc(notificationId)
          .update({'isRead': true});

      // Update read count in nutritionist notifications if this was sent by nutritionist
      await _updateNutritionistNotificationReadCount(notificationId);
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }

  /// Mark all notifications as read
  static Future<void> markAllAsRead() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Mark all notifications as read (user + nutritionist notifications are in same collection)
      final batch = FirebaseFirestore.instance.batch();
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection(_collectionName)
          .where('isRead', isEqualTo: false)
          .get();

      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
        // Update read count for nutritionist notifications
        await _updateNutritionistNotificationReadCount(doc.id);
      }

      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
    }
  }

  /// Delete notification
  static Future<void> deleteNotification(String notificationId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection(_collectionName)
          .doc(notificationId)
          .delete();
    } catch (e) {
      print('Error deleting notification: $e');
    }
  }

  /// Delete all notifications
  static Future<void> deleteAllNotifications() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final batch = FirebaseFirestore.instance.batch();
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection(_collectionName)
          .get();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      print('Error deleting all notifications: $e');
    }
  }

  /// Get unread notification count (including nutritionist/admin notifications)
  static Future<int> getUnreadCount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return 0;

    try {
      // Get all unread notifications (user + nutritionist notifications are in same collection)
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection(_collectionName)
          .where('isRead', isEqualTo: false)
          .get();

      return snapshot.docs.length;
    } catch (e) {
      print('Error getting unread count: $e');
      return 0;
    }
  }

  /// Generate meal reminder notifications
  static Future<void> generateMealReminders() async {
    // Always generate in-app notifications, regardless of user preferences
    // User preferences only control push notifications

    final now = DateTime.now();
    final currentHour = now.hour;

    // Check if it's meal time (7-9 AM, 12-2 PM, 6-8 PM)
    bool isMealTime = (currentHour >= 7 && currentHour <= 9) || // Breakfast
                      (currentHour >= 12 && currentHour <= 14) || // Lunch
                      (currentHour >= 18 && currentHour <= 20); // Dinner

    if (isMealTime) {
      String mealType = '';
      if (currentHour >= 7 && currentHour <= 9) {
        mealType = 'Breakfast';
      } else if (currentHour >= 12 && currentHour <= 14) {
        mealType = 'Lunch';
      } else if (currentHour >= 18 && currentHour <= 20) {
        mealType = 'Dinner';
      }

        await createNotification(
          title: '$mealType Reminder',
          message: 'Time for $mealType! Don\'t forget to log your meal.',
          type: 'Meal reminders',
          icon: Icons.restaurant,
          color: Colors.orange,
        );
    }
  }

  /// Generate nutrition tips
  static Future<void> generateNutritionTips() async {
    // Always generate in-app notifications, regardless of user preferences
    // User preferences only control push notifications

    final tips = [
      {
        'title': 'Hydration Tip',
        'message': 'Drink a glass of water before each meal to help with portion control.',
        'icon': Icons.water_drop,
        'color': Colors.blue,
      },
      {
        'title': 'Protein Power',
        'message': 'Include protein in every meal to keep you feeling full longer.',
        'icon': Icons.fitness_center,
        'color': Colors.green,
      },
      {
        'title': 'Fiber Focus',
        'message': 'Aim for 25-30g of fiber daily for better digestion and heart health.',
        'icon': Icons.eco,
        'color': Colors.brown,
      },
      {
        'title': 'Colorful Plate',
        'message': 'Fill half your plate with colorful vegetables for maximum nutrients.',
        'icon': Icons.local_dining,
        'color': Colors.purple,
      },
      {
        'title': 'Mindful Eating',
        'message': 'Take time to chew your food slowly and enjoy each bite.',
        'icon': Icons.psychology,
        'color': Colors.indigo,
      },
    ];

    // Randomly select a tip
    final randomTip = tips[DateTime.now().day % tips.length];
    
    await createNotification(
      title: randomTip['title'] as String,
      message: randomTip['message'] as String,
      type: 'Tips',
      icon: randomTip['icon'] as IconData,
      color: randomTip['color'] as Color,
    );
  }

  /// Generate allergy warning notifications
  static Future<void> generateAllergyWarnings(List<String> detectedAllergens, String recipeTitle) async {
    // Always generate in-app notifications, regardless of user preferences
    // User preferences only control push notifications

    if (detectedAllergens.isNotEmpty) {
      await createNotification(
        title: 'Allergy Alert',
        message: '$recipeTitle contains: ${detectedAllergens.join(', ')}. Consider substitutions.',
        type: 'Updates',
        icon: Icons.warning,
        color: Colors.red,
        actionData: 'recipe:$recipeTitle',
      );
    }
  }

  /// Generate new recipe notifications
  static Future<void> generateNewRecipeNotification(String recipeTitle) async {
    // Always generate in-app notifications, regardless of user preferences
    // User preferences only control push notifications

    await createNotification(
      title: 'New Recipe Available',
      message: 'Check out this healthy recipe: $recipeTitle',
      type: 'News',
      icon: Icons.restaurant_menu,
      color: Colors.green,
      actionData: 'recipe:$recipeTitle',
    );
  }

  /// Generate nutrition goal achievement notifications
  static Future<void> generateGoalAchievementNotification(String goal, double achieved, double target) async {
    // Always generate in-app notifications, regardless of user preferences
    // User preferences only control push notifications

    final percentage = (achieved / target * 100).round();
    
    await createNotification(
      title: 'Goal Achievement!',
      message: 'You\'ve reached ${percentage}% of your $goal goal! Keep it up!',
      type: 'Tips',
      icon: Icons.emoji_events,
      color: Colors.amber,
    );
  }

  /// Generate weekly progress notifications
  static Future<void> generateWeeklyProgressNotification(Map<String, double> weeklyStats) async {
    // Always generate in-app notifications, regardless of user preferences
    // User preferences only control push notifications

    final avgCalories = weeklyStats['calories'] ?? 0;
    final avgProtein = weeklyStats['protein'] ?? 0;
    
    await createNotification(
      title: 'Weekly Progress',
      message: 'This week you averaged ${avgCalories.round()} calories and ${avgProtein.round()}g protein per day.',
      type: 'Tips',
      icon: Icons.trending_up,
      color: Colors.blue,
    );
  }

  /// Schedule periodic notifications based on user preferences
  static Future<void> schedulePeriodicNotifications() async {
    // Generate meal reminders
    await generateMealReminders();
    
    // Generate nutrition tips (once per day)
    final now = DateTime.now();
    if (now.hour == 10) { // 10 AM daily
      await generateNutritionTips();
    }
    
    // Schedule meal time reminders based on user's meal plan
    await _scheduleMealTimeReminders();
  }

  /// Schedule meal time reminders based on user's meal plan
  static Future<void> _scheduleMealTimeReminders() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get today's meals
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final mealsQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meals')
          .where('date', isEqualTo: today)
          .get();

      for (final mealDoc in mealsQuery.docs) {
        final mealData = mealDoc.data();
        final mealTime = mealData['mealTime'];
        
        if (mealTime != null && mealTime['hour'] != null && mealTime['minute'] != null) {
          final mealTimeOfDay = TimeOfDay(
            hour: mealTime['hour'],
            minute: mealTime['minute'],
          );
          
          // Schedule reminder 15 minutes before meal time
          final reminderTime = _getReminderTime(mealTimeOfDay);
          final now = DateTime.now();
          final reminderDateTime = DateTime(
            now.year,
            now.month,
            now.day,
            reminderTime.hour,
            reminderTime.minute,
          );
          
          // Only schedule if the reminder time hasn't passed today
          if (reminderDateTime.isAfter(now)) {
            await createNotification(
              title: 'Meal Reminder',
              message: '${mealData['title']} is scheduled in 15 minutes!',
              type: 'Meal reminders',
              icon: Icons.restaurant,
              color: Colors.orange,
            );
          }
        }
      }
    } catch (e) {
      print('Error scheduling meal time reminders: $e');
    }
  }

  /// Get reminder time (15 minutes before meal time)
  static TimeOfDay _getReminderTime(TimeOfDay mealTime) {
    final totalMinutes = mealTime.hour * 60 + mealTime.minute;
    final reminderMinutes = totalMinutes - 15;
    
    if (reminderMinutes < 0) {
      // If reminder would be negative, set to 6 AM
      return const TimeOfDay(hour: 6, minute: 0);
    }
    
    final reminderHour = reminderMinutes ~/ 60;
    final reminderMinute = reminderMinutes % 60;
    
    return TimeOfDay(hour: reminderHour, minute: reminderMinute);
  }

  /// Update read count in nutritionist notifications
  static Future<void> _updateNutritionistNotificationReadCount(String userNotificationId) async {
    try {
      // Get the user notification to check if it was sent by nutritionist
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final userNotificationDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection(_collectionName)
          .doc(userNotificationId)
          .get();

      if (!userNotificationDoc.exists) return;

      final userNotificationData = userNotificationDoc.data()!;
      final sentBy = userNotificationData['sentBy'];

      // Only update if this was sent by nutritionist
      if (sentBy == 'nutritionist') {
        // Find the corresponding nutritionist notification
        final nutritionistNotifications = await FirebaseFirestore.instance
            .collection('notifications')
            .where('title', isEqualTo: userNotificationData['title'])
            .where('message', isEqualTo: userNotificationData['message'])
            .where('status', isEqualTo: 'sent')
            .get();

        for (final doc in nutritionistNotifications.docs) {
          // Increment read count
          await FirebaseFirestore.instance
              .collection('notifications')
              .doc(doc.id)
              .update({
            'readCount': FieldValue.increment(1),
          });
        }
      }
    } catch (e) {
      print('Error updating nutritionist notification read count: $e');
    }
  }

}
