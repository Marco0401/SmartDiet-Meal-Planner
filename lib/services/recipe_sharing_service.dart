import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'fcm_service.dart';
import 'notification_service.dart';

class RecipeSharingService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Share a recipe to the community
  static Future<String> shareRecipe({
    required Map<String, dynamic> recipe,
    String? shareMessage,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Get user details
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      
      // Try multiple field names for user name
      final userName = userData['fullName'] ?? userData['name'] ?? userData['displayName'] ?? user.displayName ?? 'Anonymous User';
      final userPhoto = userData['profilePhoto'] ?? userData['photoUrl'] ?? user.photoURL;

      // Convert local file path images to base64 before sharing
      final recipeToShare = Map<String, dynamic>.from(recipe);
      if (recipeToShare['image'] != null) {
        final imagePath = recipeToShare['image'].toString();
        // Check if it's a local file path (not already base64 or network URL)
        if ((imagePath.startsWith('/') || imagePath.startsWith('file://')) && 
            !imagePath.startsWith('data:image') &&
            !imagePath.startsWith('http')) {
          try {
            final cleanPath = imagePath.replaceFirst('file://', '');
            final imageFile = File(cleanPath);
            if (await imageFile.exists()) {
              final bytes = await imageFile.readAsBytes();
              final base64String = 'data:image/jpeg;base64,${base64Encode(bytes)}';
              recipeToShare['image'] = base64String;
              print('DEBUG: Converted local image to base64 for sharing (${bytes.length} bytes)');
            } else {
              print('WARNING: Image file does not exist: $cleanPath');
              recipeToShare['image'] = null; // Remove invalid path
            }
          } catch (e) {
            print('ERROR converting image to base64 for sharing: $e');
            recipeToShare['image'] = null; // Remove invalid image
          }
        }
      }

      final sharedRecipe = {
        'recipeData': recipeToShare,
        'userId': user.uid,
        'userName': userName,
        'userEmail': user.email,
        'userPhoto': userPhoto,
        'shareMessage': shareMessage,
        'sharedAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'saves': 0,
        'views': 0,
        'averageRating': 0.0,
        'ratingCount': 0,
        'commentCount': 0,
        'visibility': 'public',
        'isApproved': true, // Auto-approve for now
      };

      final docRef = await _firestore
          .collection('community_recipes')
          .add(sharedRecipe);

      // Also add to user's shared recipes collection
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('shared_recipes')
          .doc(docRef.id)
          .set({
            'recipeId': docRef.id,
            'sharedAt': FieldValue.serverTimestamp(),
          });

      print('Recipe shared successfully with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('Error sharing recipe: $e');
      rethrow;
    }
  }

  /// Get community recipes feed
  static Stream<List<Map<String, dynamic>>> getCommunityRecipesFeed({
    int limit = 20,
    String? cuisine,
    String? dietType,
    String? goal,
    String sortBy = 'recent', // recent, popular, mostSaved
  }) {
    Query query = _firestore
        .collection('community_recipes');
    // Removed filters to avoid Firestore composite index requirements
    // Filtering will be done client-side instead

    // Apply sorting
    switch (sortBy) {
      case 'popular':
        query = query.orderBy('likes', descending: true);
        break;
      case 'mostSaved':
        query = query.orderBy('saves', descending: true);
        break;
      case 'recent':
      default:
        query = query.orderBy('sharedAt', descending: true);
    }

    query = query.limit(limit);

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Like/Unlike a recipe
  static Future<void> toggleLike(String recipeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final likeRef = _firestore
          .collection('recipe_interactions')
          .doc(recipeId)
          .collection('likes')
          .doc(user.uid);

      final likeDoc = await likeRef.get();

      if (likeDoc.exists) {
        // Unlike
        await likeRef.delete();
        await _firestore.collection('community_recipes').doc(recipeId).update({
          'likes': FieldValue.increment(-1),
        });
      } else {
        // Like
        await likeRef.set({
          'userId': user.uid,
          'likedAt': FieldValue.serverTimestamp(),
        });
        await _firestore.collection('community_recipes').doc(recipeId).update({
          'likes': FieldValue.increment(1),
        });

        // Send push notification to recipe owner
        final recipeDoc = await _firestore.collection('community_recipes').doc(recipeId).get();
        if (recipeDoc.exists) {
          final recipeData = recipeDoc.data()!;
          final recipeOwnerId = recipeData['userId'] as String?;
          final recipeTitle = recipeData['title'] as String? ?? 'your recipe';
          
          // Don't send notification if user likes their own recipe
          if (recipeOwnerId != null && recipeOwnerId != user.uid) {
            final userDoc = await _firestore.collection('users').doc(user.uid).get();
            final userName = userDoc.data()?['fullName'] ?? userDoc.data()?['name'] ?? 'Someone';
            
            // Send in-app notification
            await NotificationService.createNotification(
              userId: recipeOwnerId,
              title: '❤️ New Like!',
              message: '$userName liked your recipe "$recipeTitle"',
              type: 'like',
              actionData: recipeId,
              icon: Icons.favorite,
              color: Colors.red,
            );
            
            // Send push notification
            await FCMService.sendNewLikeNotification(
              recipeOwnerUserId: recipeOwnerId,
              likerName: userName,
              recipeTitle: recipeTitle,
            );
          }
        }
      }
    } catch (e) {
      print('Error toggling like: $e');
      rethrow;
    }
  }

  /// Check if user has liked a recipe
  static Future<bool> hasLiked(String recipeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final likeDoc = await _firestore
          .collection('recipe_interactions')
          .doc(recipeId)
          .collection('likes')
          .doc(user.uid)
          .get();

      return likeDoc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Save/Unsave a recipe to favorites
  static Future<void> toggleSave(String recipeId, Map<String, dynamic> recipeData) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      final saveRef = _firestore
          .collection('recipe_interactions')
          .doc(recipeId)
          .collection('saves')
          .doc(user.uid);

      final saveDoc = await saveRef.get();

      if (saveDoc.exists) {
        // Unsave
        await saveRef.delete();
        await _firestore.collection('community_recipes').doc(recipeId).update({
          'saves': FieldValue.increment(-1),
        });
      } else {
        // Save
        await saveRef.set({
          'userId': user.uid,
          'savedAt': FieldValue.serverTimestamp(),
        });
        await _firestore.collection('community_recipes').doc(recipeId).update({
          'saves': FieldValue.increment(1),
        });
      }
    } catch (e) {
      print('Error toggling save: $e');
      rethrow;
    }
  }

  /// Check if user has saved a recipe
  static Future<bool> hasSaved(String recipeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final saveDoc = await _firestore
          .collection('recipe_interactions')
          .doc(recipeId)
          .collection('saves')
          .doc(user.uid)
          .get();

      return saveDoc.exists;
    } catch (e) {
      return false;
    }
  }

  /// Increment view count
  static Future<void> incrementViewCount(String recipeId) async {
    try {
      await _firestore.collection('community_recipes').doc(recipeId).update({
        'views': FieldValue.increment(1),
      });
    } catch (e) {
      print('Error incrementing view count: $e');
    }
  }

  /// Get user's shared recipes
  static Stream<List<Map<String, dynamic>>> getUserSharedRecipes(String userId) {
    return _firestore
        .collection('community_recipes')
        .where('userId', isEqualTo: userId)
        // Removed orderBy to avoid index requirement - will sort client-side
        .snapshots()
        .map((snapshot) {
      final recipes = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      // Sort by sharedAt client-side
      recipes.sort((a, b) {
        final aTime = a['sharedAt'] as Timestamp?;
        final bTime = b['sharedAt'] as Timestamp?;
        if (aTime == null || bTime == null) return 0;
        return bTime.compareTo(aTime); // Descending order
      });
      
      return recipes;
    });
  }

  /// Delete shared recipe
  static Future<void> deleteSharedRecipe(String recipeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Check if user owns this recipe
      final recipeDoc = await _firestore.collection('community_recipes').doc(recipeId).get();
      if (!recipeDoc.exists) throw Exception('Recipe not found');

      final recipeData = recipeDoc.data();
      if (recipeData!['userId'] != user.uid) {
        throw Exception('You can only delete your own recipes');
      }

      // Delete recipe
      await _firestore.collection('community_recipes').doc(recipeId).delete();

      // Delete from user's shared recipes
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('shared_recipes')
          .doc(recipeId)
          .delete();

      print('Recipe deleted successfully');
    } catch (e) {
      print('Error deleting recipe: $e');
      rethrow;
    }
  }

  /// Search community recipes
  static Future<List<Map<String, dynamic>>> searchCommunityRecipes(String query) async {
    try {
      final snapshot = await _firestore
          .collection('community_recipes')
          .where('isApproved', isEqualTo: true)
          .get();

      final queryLower = query.toLowerCase();
      final results = snapshot.docs.where((doc) {
        final data = doc.data();
        final title = (data['recipeData']?['title'] ?? '').toString().toLowerCase();
        final cuisine = (data['recipeData']?['cuisine'] ?? '').toString().toLowerCase();
        return title.contains(queryLower) || cuisine.contains(queryLower);
      }).map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();

      return results;
    } catch (e) {
      print('Error searching recipes: $e');
      return [];
    }
  }

  /// Add or update rating for a recipe
  static Future<void> rateRecipe(String recipeId, double rating) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');
      
      if (rating < 1 || rating > 5) {
        throw Exception('Rating must be between 1 and 5');
      }

      // Save user's rating
      await _firestore
          .collection('community_recipes')
          .doc(recipeId)
          .collection('ratings')
          .doc(user.uid)
          .set({
        'userId': user.uid,
        'rating': rating,
        'ratedAt': FieldValue.serverTimestamp(),
      });

      // Recalculate average rating
      final ratingsSnapshot = await _firestore
          .collection('community_recipes')
          .doc(recipeId)
          .collection('ratings')
          .get();

      final ratings = ratingsSnapshot.docs.map((doc) => doc.data()['rating'] as double).toList();
      final averageRating = ratings.isEmpty ? 0.0 : ratings.reduce((a, b) => a + b) / ratings.length;
      final ratingCount = ratings.length;

      // Update recipe with average rating
      await _firestore
          .collection('community_recipes')
          .doc(recipeId)
          .update({
        'averageRating': averageRating,
        'ratingCount': ratingCount,
      });

      print('Rating saved successfully');
    } catch (e) {
      print('Error rating recipe: $e');
      rethrow;
    }
  }

  /// Get user's rating for a recipe
  static Future<double?> getUserRating(String recipeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;

      final doc = await _firestore
          .collection('community_recipes')
          .doc(recipeId)
          .collection('ratings')
          .doc(user.uid)
          .get();

      if (!doc.exists) return null;
      return doc.data()?['rating'] as double?;
    } catch (e) {
      print('Error getting user rating: $e');
      return null;
    }
  }

  /// Add a comment to a recipe
  static Future<void> addComment(String recipeId, String comment) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      if (comment.trim().isEmpty) {
        throw Exception('Comment cannot be empty');
      }

      // Get user details
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final userName = userData['fullName'] ?? userData['name'] ?? user.displayName ?? 'Anonymous';
      final userPhoto = userData['profilePhoto'] ?? userData['photoUrl'] ?? user.photoURL;

      // Add comment
      await _firestore
          .collection('community_recipes')
          .doc(recipeId)
          .collection('comments')
          .add({
        'userId': user.uid,
        'userName': userName,
        'userPhoto': userPhoto,
        'comment': comment.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
      });

      // Update comment count on recipe
      await _firestore
          .collection('community_recipes')
          .doc(recipeId)
          .update({
        'commentCount': FieldValue.increment(1),
      });

      // Send push notification to recipe owner
      final recipeDoc = await _firestore.collection('community_recipes').doc(recipeId).get();
      if (recipeDoc.exists) {
        final recipeData = recipeDoc.data()!;
        final recipeOwnerId = recipeData['userId'] as String?;
        final recipeTitle = recipeData['title'] as String? ?? 'your recipe';
        
        // Don't send notification if user comments on their own recipe
        if (recipeOwnerId != null && recipeOwnerId != user.uid) {
          final commentPreview = comment.trim().length > 50 
              ? '${comment.trim().substring(0, 50)}...' 
              : comment.trim();
          
          // Send in-app notification
          await NotificationService.createNotification(
            userId: recipeOwnerId,
            title: '💬 New Comment!',
            message: '$userName commented on "$recipeTitle": $commentPreview',
            type: 'comment',
            actionData: recipeId,
            icon: Icons.comment,
            color: Colors.blue,
          );
          
          // Send push notification
          await FCMService.sendNewCommentNotification(
            recipeOwnerUserId: recipeOwnerId,
            commenterName: userName,
            recipeTitle: recipeTitle,
            commentPreview: commentPreview,
          );
        }
      }

      print('Comment added successfully');
    } catch (e) {
      print('Error adding comment: $e');
      rethrow;
    }
  }

  /// Get comments for a recipe
  static Stream<List<Map<String, dynamic>>> getComments(String recipeId) {
    return _firestore
        .collection('community_recipes')
        .doc(recipeId)
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    });
  }

  /// Delete a comment (only by comment owner)
  static Future<void> deleteComment(String recipeId, String commentId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Check if user owns the comment
      final commentDoc = await _firestore
          .collection('community_recipes')
          .doc(recipeId)
          .collection('comments')
          .doc(commentId)
          .get();

      if (!commentDoc.exists) throw Exception('Comment not found');

      final commentData = commentDoc.data();
      if (commentData!['userId'] != user.uid) {
        throw Exception('You can only delete your own comments');
      }

      // Delete comment
      await commentDoc.reference.delete();

      // Update comment count
      await _firestore
          .collection('community_recipes')
          .doc(recipeId)
          .update({
        'commentCount': FieldValue.increment(-1),
      });

      print('Comment deleted successfully');
    } catch (e) {
      print('Error deleting comment: $e');
      rethrow;
    }
  }
}
