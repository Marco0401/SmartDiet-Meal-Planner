import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'fcm_service.dart';

class MessageService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Create or get existing conversation between two users
  static Future<String> getOrCreateConversation(String otherUserId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      final userId = currentUser.uid;
      
      // Create a consistent conversation ID (sorted user IDs)
      final conversationId = userId.compareTo(otherUserId) < 0
          ? '${userId}_$otherUserId'
          : '${otherUserId}_$userId';

      // Check if conversation exists
      final conversationDoc = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .get();

      if (!conversationDoc.exists) {
        // Get both users' details
        final currentUserDoc = await _firestore.collection('users').doc(userId).get();
        final otherUserDoc = await _firestore.collection('users').doc(otherUserId).get();
        
        final currentUserData = currentUserDoc.data() ?? {};
        final otherUserData = otherUserDoc.data() ?? {};

        // Create new conversation
        await _firestore.collection('conversations').doc(conversationId).set({
          'participants': [userId, otherUserId],
          'participantDetails': {
            userId: {
              'name': currentUserData['fullName'] ?? currentUserData['name'] ?? 'User',
              'photo': currentUserData['profilePhoto'] ?? currentUserData['photoUrl'],
            },
            otherUserId: {
              'name': otherUserData['fullName'] ?? otherUserData['name'] ?? 'User',
              'photo': otherUserData['profilePhoto'] ?? otherUserData['photoUrl'],
            },
          },
          'lastMessage': '',
          'lastMessageTime': FieldValue.serverTimestamp(),
          'lastMessageSenderId': '',
          'unreadCount': {
            userId: 0,
            otherUserId: 0,
          },
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      return conversationId;
    } catch (e) {
      print('Error creating conversation: $e');
      rethrow;
    }
  }

  /// Send a message in a conversation
  static Future<void> sendMessage({
    required String conversationId,
    required String recipientId,
    required String message,
  }) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) throw Exception('User not logged in');

      final userId = currentUser.uid;

      // Add message to messages subcollection
      await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add({
        'senderId': userId,
        'recipientId': recipientId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'read': false,
      });

      // Update conversation last message
      await _firestore.collection('conversations').doc(conversationId).update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': userId,
        'unreadCount.$recipientId': FieldValue.increment(1),
      });

      // Get sender name for push notification
      final senderDoc = await _firestore.collection('users').doc(userId).get();
      final senderName = senderDoc.data()?['fullName'] ?? 
                        senderDoc.data()?['name'] ?? 
                        'Someone';

      // Send push notification to recipient
      await FCMService.sendNewMessageNotification(
        recipientUserId: recipientId,
        senderName: senderName,
        messagePreview: message.length > 50 ? '${message.substring(0, 50)}...' : message,
      );

      print('Message sent successfully');
    } catch (e) {
      print('Error sending message: $e');
      rethrow;
    }
  }

  /// Get messages stream for a conversation
  static Stream<List<Map<String, dynamic>>> getMessages(String conversationId) {
    return _firestore
        .collection('conversations')
        .doc(conversationId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Get user's conversations stream
  static Stream<List<Map<String, dynamic>>> getUserConversations() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      final conversations = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      // Sort by lastMessageTime in memory (descending)
      conversations.sort((a, b) {
        final aTime = a['lastMessageTime'] as Timestamp?;
        final bTime = b['lastMessageTime'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
      
      return conversations;
    });
  }

  /// Mark messages as read
  static Future<void> markMessagesAsRead(String conversationId, String senderId) async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return;

      final userId = currentUser.uid;

      // Get unread messages from the sender
      final unreadMessages = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .where('senderId', isEqualTo: senderId)
          .where('recipientId', isEqualTo: userId)
          .where('read', isEqualTo: false)
          .get();

      // Mark all as read
      final batch = _firestore.batch();
      for (var doc in unreadMessages.docs) {
        batch.update(doc.reference, {'read': true});
      }
      await batch.commit();

      // Reset unread count for current user
      await _firestore.collection('conversations').doc(conversationId).update({
        'unreadCount.$userId': 0,
      });

      print('Messages marked as read');
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  /// Get total unread message count for current user
  static Stream<int> getUnreadMessageCount() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return Stream.value(0);

    return _firestore
        .collection('conversations')
        .where('participants', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
      int totalUnread = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final unreadCount = data['unreadCount'] as Map<String, dynamic>?;
        if (unreadCount != null && unreadCount.containsKey(userId)) {
          totalUnread += (unreadCount[userId] as int?) ?? 0;
        }
      }
      return totalUnread;
    });
  }

  /// Delete a conversation
  static Future<void> deleteConversation(String conversationId) async {
    try {
      // Delete all messages
      final messages = await _firestore
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .get();

      final batch = _firestore.batch();
      for (var doc in messages.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Delete conversation
      await _firestore.collection('conversations').doc(conversationId).delete();

      print('Conversation deleted successfully');
    } catch (e) {
      print('Error deleting conversation: $e');
      rethrow;
    }
  }
}
