import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'dart:io';
import 'recipe_detail_page.dart';
import 'chat_page.dart';
import 'services/message_service.dart';
import 'services/fcm_service.dart';
import 'services/notification_service.dart';

class UserProfilePage extends StatefulWidget {
  final String userId;
  final bool isOwnProfile;

  const UserProfilePage({
    super.key,
    required this.userId,
    this.isOwnProfile = false,
  });

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isFollowing = false;
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  int _recipesCount = 0;
  int _followersCount = 0;
  int _followingCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.isOwnProfile ? 2 : 1, vsync: this);
    _loadUserData();
    _checkFollowStatus();
    _loadStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      setState(() {
        _userData = doc.data();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkFollowStatus() async {
    if (widget.isOwnProfile) return;

    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(widget.userId)
          .get();

      setState(() {
        _isFollowing = doc.exists;
      });
    } catch (e) {
      print('Error checking follow status: $e');
    }
  }

  Future<void> _loadStats() async {
    try {
      // Count recipes
      final recipesSnapshot = await FirebaseFirestore.instance
          .collection('community_recipes')
          .where('userId', isEqualTo: widget.userId)
          .get();

      // Count followers
      final followersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('followers')
          .get();

      // Count following
      final followingSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .collection('following')
          .get();

      setState(() {
        _recipesCount = recipesSnapshot.docs.length;
        _followersCount = followersSnapshot.docs.length;
        _followingCount = followingSnapshot.docs.length;
      });
    } catch (e) {
      print('Error loading stats: $e');
    }
  }

  Future<void> _toggleFollow() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      if (_isFollowing) {
        // Unfollow
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('following')
            .doc(widget.userId)
            .delete();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('followers')
            .doc(currentUserId)
            .delete();

        setState(() {
          _isFollowing = false;
          _followersCount--;
        });
      } else {
        // Follow
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('following')
            .doc(widget.userId)
            .set({
          'followedAt': FieldValue.serverTimestamp(),
        });

        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('followers')
            .doc(currentUserId)
            .set({
          'followedAt': FieldValue.serverTimestamp(),
        });

        // Send notifications to followed user
        final currentUserDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .get();
        final followerName = currentUserDoc.data()?['fullName'] ?? 
                            currentUserDoc.data()?['name'] ?? 
                            'Someone';
        
        // Send in-app notification
        await NotificationService.createNotification(
          userId: widget.userId,
          title: '👥 New Follower!',
          message: '$followerName started following you',
          type: 'follow',
          actionData: currentUserId,
          icon: Icons.person_add,
          color: Colors.blue,
        );
        
        // Send push notification
        await FCMService.sendNewFollowerNotification(
          followedUserId: widget.userId,
          followerName: followerName,
        );

        setState(() {
          _isFollowing = true;
          _followersCount++;
        });
      }
    } catch (e) {
      print('Error toggling follow: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final userName = _userData?['fullName'] ?? 'User';
    final profilePhoto = _userData?['profilePhoto'] ?? _userData?['photoUrl'];
    final bio = _userData?['bio'] ?? '';

    // Handle profile image
    ImageProvider? profileImage;
    if (profilePhoto != null && profilePhoto.isNotEmpty) {
      if (profilePhoto.startsWith('data:image')) {
        try {
          profileImage = MemoryImage(base64Decode(profilePhoto.split(',')[1]));
        } catch (e) {
          print('Error decoding base64: $e');
        }
      } else {
        profileImage = NetworkImage(profilePhoto);
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF2E7D32),
                Color(0xFF388E3C),
                Color(0xFF4CAF50),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: Text(
              userName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(0, 2),
                    blurRadius: 4,
                    color: Colors.black26,
                  ),
                ],
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.more_vert, color: Colors.white),
                onPressed: () {},
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // Profile Header - Instagram Style
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Picture + Stats Row
                Row(
                  children: [
                    // Profile Picture - Match Account Settings Style
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.white,
                        backgroundImage: profileImage,
                        child: profileImage == null
                            ? Text(
                                userName[0].toUpperCase(),
                                style: const TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4CAF50),
                                ),
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Stats
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatColumn(_recipesCount.toString(), 'recipes'),
                          _buildStatColumn(_followersCount.toString(), 'followers'),
                          _buildStatColumn(_followingCount.toString(), 'following'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Name
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                // Bio
                if (bio.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      bio,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                // Follow/Message Buttons (only for other users)
                if (!widget.isOwnProfile)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _toggleFollow,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isFollowing ? Colors.grey[300] : const Color(0xFF4CAF50),
                            foregroundColor: _isFollowing ? Colors.black : Colors.white,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: Icon(_isFollowing ? Icons.check : Icons.person_add, size: 18),
                          label: Text(_isFollowing ? 'Following' : 'Follow'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              final conversationId = await MessageService.getOrCreateConversation(widget.userId);
                              if (mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ChatPage(
                                      conversationId: conversationId,
                                      otherUserId: widget.userId,
                                      otherUserName: _userData?['fullName'] ?? _userData?['name'] ?? 'User',
                                      otherUserPhoto: _userData?['profilePhoto'] ?? _userData?['photoUrl'],
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error opening chat: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF4CAF50),
                            side: const BorderSide(color: Color(0xFF4CAF50), width: 2),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.message, size: 18),
                          label: const Text('Message'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Divider
          Divider(height: 1, color: Colors.grey[300]),
          // Tabs (only show if own profile)
          if (widget.isOwnProfile)
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF4CAF50),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF4CAF50),
                indicatorWeight: 3,
                tabs: const [
                  Tab(icon: Icon(Icons.grid_on), text: 'Recipes'),
                  Tab(icon: Icon(Icons.person), text: 'Info'),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.grid_on, color: Color(0xFF4CAF50), size: 28),
                ],
              ),
            ),
          // Content
          Expanded(
            child: widget.isOwnProfile
                ? TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSharedRecipes(),
                      _buildPersonalInfo(),
                    ],
                  )
                : _buildSharedRecipes(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String count, String label) {
    return Column(
      children: [
        Text(
          count,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            shadows: [
              Shadow(
                color: Colors.black12,
                blurRadius: 2,
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black54,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSharedRecipes() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('community_recipes')
          .where('userId', isEqualTo: widget.userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.restaurant_menu, size: 80, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No shared recipes yet',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        // Sort recipes by sharedAt client-side
        final recipes = snapshot.data!.docs;
        recipes.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aTime = aData['sharedAt'] as Timestamp?;
          final bTime = bData['sharedAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.75,
          ),
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            final doc = recipes[index];
            final recipe = doc.data() as Map<String, dynamic>;
            final recipeData = recipe['recipeData'] as Map<String, dynamic>? ?? {};
            final likes = recipe['likes'] ?? 0;
            final saves = recipe['saves'] ?? 0;
            final views = recipe['views'] ?? 0;
            
            // Get image from recipeData - check multiple possible fields
            String image = '';
            
            // Debug: Print the entire recipeData structure
            print('DEBUG UserProfile: Full recipeData keys: ${recipeData.keys.toList()}');
            print('DEBUG UserProfile: Recipe title: ${recipeData['title']}');
            
            // Check all possible image field names
            if (recipeData['image'] != null && recipeData['image'].toString().isNotEmpty) {
              image = recipeData['image'].toString();
              print('DEBUG: Found image in [image] field');
            } else if (recipeData['imageUrl'] != null && recipeData['imageUrl'].toString().isNotEmpty) {
              image = recipeData['imageUrl'].toString();
              print('DEBUG: Found image in [imageUrl] field');
            } else if (recipeData['strMealThumb'] != null && recipeData['strMealThumb'].toString().isNotEmpty) {
              image = recipeData['strMealThumb'].toString();
              print('DEBUG: Found image in [strMealThumb] field');
            } else if (recipeData['thumbnail'] != null && recipeData['thumbnail'].toString().isNotEmpty) {
              image = recipeData['thumbnail'].toString();
              print('DEBUG: Found image in [thumbnail] field');
            } else if (recipeData['img'] != null && recipeData['img'].toString().isNotEmpty) {
              image = recipeData['img'].toString();
              print('DEBUG: Found image in [img] field');
            }
            
            print('DEBUG UserProfile: Final image URL: $image');

            return _buildRecipeCard(recipeData, doc.id, likes, saves, views, image);
          },
        );
      },
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe, String recipeId, int likes, int saves, int views, String image) {
    final title = recipe['title'] ?? 'Untitled';
    final rating = recipe['rating'] ?? recipe['spoonacularScore'] ?? 0;
    final ratingValue = rating is int ? rating.toDouble() / 20 : (rating is double ? rating / 20 : 0.0);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeDetailPage(
              recipe: {...recipe, 'id': recipeId, 'source': 'community'},
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Background Image - Handle both local files and network URLs
              Positioned.fill(
                child: image.isNotEmpty
                    ? _buildRecipeImage(image)
                    : Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.green[300]!,
                              Colors.green[500]!,
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: const Center(
                          child: Icon(
                            Icons.restaurant,
                            size: 50,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.8),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
              ),
              // Recipe Info
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title - Match Account Settings font shadow style
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          shadows: [
                            Shadow(
                              color: Colors.black,
                              blurRadius: 8,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Rating
                      if (ratingValue > 0)
                        Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              ratingValue.toStringAsFixed(1),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 6),
                      // Stats
                      Row(
                        children: [
                          _buildStatBadge(Icons.favorite, likes, Colors.red),
                          const SizedBox(width: 8),
                          _buildStatBadge(Icons.bookmark, saves, Colors.green),
                          const SizedBox(width: 8),
                          _buildStatBadge(Icons.visibility, views, Colors.blue),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatBadge(IconData icon, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeImage(String imagePath) {
    // Check if it's a base64 image
    if (imagePath.startsWith('data:image')) {
      try {
        final base64Data = imagePath.split(',')[1];
        final bytes = base64Decode(base64Data);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            print('ERROR loading base64 image');
            print('ERROR details: $error');
            return _buildPlaceholder();
          },
        );
      } catch (e) {
        print('ERROR decoding base64 image: $e');
        return _buildPlaceholder();
      }
    }
    // Check if it's a local file path
    else if (imagePath.startsWith('/') || imagePath.startsWith('file://')) {
      final cleanPath = imagePath.replaceFirst('file://', '');
      return Image.file(
        File(cleanPath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('ERROR loading local file: $cleanPath');
          print('ERROR details: $error');
          return _buildPlaceholder();
        },
      );
    } 
    // Network URL
    else {
      return Image.network(
        imagePath,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            color: Colors.grey[300],
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
                color: const Color(0xFF4CAF50),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          print('ERROR loading network image: $imagePath');
          print('ERROR details: $error');
          return _buildPlaceholder();
        },
      );
    }
  }

  Widget _buildPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green[300]!,
            Colors.green[500]!,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.restaurant,
          size: 50,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildPersonalInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoCard(
            'Basic Information',
            Icons.person,
            [
              _buildInfoRow('Name', _userData?['fullName'] ?? 'N/A'),
              _buildInfoRow('Email', _userData?['email'] ?? 'N/A'),
              _buildInfoRow('Gender', _userData?['gender'] ?? 'N/A'),
              _buildInfoRow('Height', _userData?['height']?.toString() ?? 'N/A'),
              _buildInfoRow('Weight', _userData?['weight']?.toString() ?? 'N/A'),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            'Health Information',
            Icons.health_and_safety,
            [
              _buildInfoRow('Health Conditions',
                  (_userData?['healthConditions'] as List?)?.join(', ') ?? 'None'),
              _buildInfoRow(
                  'Allergies', (_userData?['allergies'] as List?)?.join(', ') ?? 'None'),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoCard(
            'Goals & Preferences',
            Icons.flag,
            [
              _buildInfoRow('Goal', _userData?['goal'] ?? 'N/A'),
              _buildInfoRow('Activity Level', _userData?['activityLevel'] ?? 'N/A'),
              _buildInfoRow('Dietary Preferences',
                  (_userData?['dietaryPreferences'] as List?)?.join(', ') ?? 'None'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF4CAF50)),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
