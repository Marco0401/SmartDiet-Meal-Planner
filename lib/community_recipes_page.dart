import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/recipe_sharing_service.dart';
import 'services/allergen_detection_service.dart';
import 'services/allergen_service.dart';
import 'services/message_service.dart';
import 'recipe_detail_page.dart';
import 'user_profile_page.dart';
import 'messages_page.dart';
import 'chat_page.dart';
import 'user_search_page.dart';
import 'widgets/allergen_warning_dialog.dart';
import 'widgets/app_bottom_nav.dart';
import 'main.dart';
import 'meal_planner_page.dart';
import 'meal_favorites_page.dart';
  import 'account_settings_page.dart';

class CommunityRecipesPage extends StatefulWidget {
  const CommunityRecipesPage({super.key});

  @override
  State<CommunityRecipesPage> createState() => _CommunityRecipesPageState();
}

class _CommunityRecipesPageState extends State<CommunityRecipesPage> with TickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _sortBy = 'recent';
  String? _selectedCuisine;
  String? _selectedDietType;
  String? _selectedGoal;

  final List<String> _cuisines = [
    'All',
    'Filipino',
    'Asian',
    'Mexican',
    'Italian',
    'American',
    'Indian',
    'Chinese',
    'Japanese',
    'Thai',
    'Mediterranean',
  ];

  final List<String> _dietTypes = [
    'All',
    'General',
    'Vegetarian',
    'Vegan',
    'Keto',
    'Paleo',
    'Mediterranean',
    'Low-Carb',
    'High-Protein',
    'Gluten-Free',
    'Dairy-Free'
  ];

  final List<String> _goals = [
    'All',
    'Weight Loss',
    'Weight Gain',
    'Muscle Building',
    'Diabetes Management',
    'Heart Health',
    'General Health',
    'Athletic Performance',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
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
            title: const Text(
              'Community Recipes',
              style: TextStyle(
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
              // Search Users Button
              IconButton(
                icon: const Icon(Icons.search, color: Colors.white),
                tooltip: 'Search Users',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserSearchPage(),
                    ),
                  );
                },
              ),
              // Messages Button with Badge
              StreamBuilder<int>(
                stream: MessageService.getUnreadMessageCount(),
                builder: (context, snapshot) {
                  final unreadCount = snapshot.data ?? 0;
                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const MessagesPage(),
                            ),
                          );
                        },
                      ),
                      if (unreadCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 1.5),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 18,
                              minHeight: 18,
                            ),
                            child: Text(
                              unreadCount > 9 ? '9+' : unreadCount.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Discover', icon: Icon(Icons.explore)),
                Tab(text: 'My Shared', icon: Icon(Icons.share)),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDiscoverTab(),
          _buildMySharedTab(),
        ],
      ),
      bottomNavigationBar: AppBottomNav(
        currentIndex: 3, // Community tab
        onTap: (index) {
          switch (index) {
            case 0:
              // Home
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MyHomePage(title: 'SmartDiet')),
              );
              break;
            case 1:
              // Plan
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MealPlannerPage()),
              );
              break;
            case 2:
              // My Recipes
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const MealFavoritesPage()),
              );
              break;
            case 3:
              // Already on Community
              break;
            case 4:
              // Account
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const AccountSettingsPage()),
              );
              break;
          }
        },
      ),
    );
  }

  Widget _buildDiscoverTab() {
    return Column(
      children: [
        // Filters
        _buildFilters(),
        // Recipe Feed
        Expanded(
          child: StreamBuilder<List<Map<String, dynamic>>>(
            stream: RecipeSharingService.getCommunityRecipesFeed(
              sortBy: _sortBy,
              cuisine: _selectedCuisine == 'All' ? null : _selectedCuisine,
              dietType: _selectedDietType == 'All' ? null : _selectedDietType,
              goal: _selectedGoal == 'All' ? null : _selectedGoal,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.green));
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text('Error loading recipes: ${snapshot.error}'),
                    ],
                  ),
                );
              }

              var recipes = snapshot.data ?? [];
              
              // Client-side filtering
              if (_selectedCuisine != null && _selectedCuisine != 'All') {
                recipes = recipes.where((r) {
                  final cuisine = r['recipeData']?['cuisine']?.toString() ?? '';
                  return cuisine.toLowerCase() == _selectedCuisine!.toLowerCase();
                }).toList();
              }
              
              if (_selectedDietType != null && _selectedDietType != 'All') {
                recipes = recipes.where((r) {
                  final dietType = r['recipeData']?['dietType']?.toString() ?? '';
                  return dietType.toLowerCase() == _selectedDietType!.toLowerCase();
                }).toList();
              }
              
              if (_selectedGoal != null && _selectedGoal != 'All') {
                recipes = recipes.where((r) {
                  final goal = r['recipeData']?['goal']?.toString() ?? '';
                  return goal.toLowerCase() == _selectedGoal!.toLowerCase();
                }).toList();
              }

              if (recipes.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.restaurant_menu, size: 80, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No recipes found',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Be the first to share!',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  return _buildRecipeCard(recipes[index]);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Sort By
          Row(
            children: [
              const Icon(Icons.sort, color: Colors.green),
              const SizedBox(width: 8),
              const Text('Sort by:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 12),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildSortChip('Recent', 'recent'),
                      _buildSortChip('Popular', 'popular'),
                      _buildSortChip('Most Saved', 'mostSaved'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  'Cuisine',
                  _selectedCuisine ?? 'All',
                  _cuisines,
                  (value) => setState(() => _selectedCuisine = value),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Diet',
                  _selectedDietType ?? 'All',
                  _dietTypes,
                  (value) => setState(() => _selectedDietType = value),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Goal',
                  _selectedGoal ?? 'All',
                  _goals,
                  (value) => setState(() => _selectedGoal = value),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final isSelected = _sortBy == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) setState(() => _sortBy = value);
        },
        selectedColor: Colors.green,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, List<String> options, Function(String?) onChanged) {
    return PopupMenuButton<String>(
      child: Chip(
        avatar: const Icon(Icons.filter_alt, size: 18),
        label: Text('$label: $value'),
        backgroundColor: value == 'All' ? Colors.grey[200] : Colors.green[100],
      ),
      itemBuilder: (context) {
        return options.map((option) {
          return PopupMenuItem<String>(
            value: option,
            child: Text(option),
          );
        }).toList();
      },
      onSelected: onChanged,
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> sharedRecipe) {
    final recipeData = sharedRecipe['recipeData'] as Map<String, dynamic>? ?? {};
    final userName = sharedRecipe['userName'] ?? 'Anonymous';
    final userPhoto = sharedRecipe['userPhoto'] as String?;
    final shareMessage = sharedRecipe['shareMessage'] as String?;
    final likes = sharedRecipe['likes'] ?? 0;
    final saves = sharedRecipe['saves'] ?? 0;
    final views = sharedRecipe['views'] ?? 0;
    final recipeId = sharedRecipe['id'] ?? '';
    final averageRating = (sharedRecipe['averageRating'] ?? 0.0) as num;
    final ratingCount = sharedRecipe['ratingCount'] ?? 0;
    final commentCount = sharedRecipe['commentCount'] ?? 0;
    final userId = sharedRecipe['userId'] ?? '';
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Handle user profile image (base64 or URL)
    ImageProvider? userProfileImage;
    if (userPhoto != null && userPhoto.isNotEmpty) {
      if (userPhoto.startsWith('data:image')) {
        try {
          userProfileImage = MemoryImage(base64Decode(userPhoto.split(',')[1]));
        } catch (e) {
          print('Error decoding user photo: $e');
        }
      } else {
        userProfileImage = NetworkImage(userPhoto);
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Profile + Follow Button
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UserProfilePage(
                          userId: userId,
                          isOwnProfile: userId == currentUserId,
                        ),
                      ),
                    );
                  },
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.green,
                    backgroundImage: userProfileImage,
                    child: userProfileImage == null
                        ? Text(
                            userName[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => UserProfilePage(
                            userId: userId,
                            isOwnProfile: userId == currentUserId,
                          ),
                        ),
                      );
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          userName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (shareMessage != null && shareMessage.isNotEmpty)
                          Text(
                            shareMessage,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ),
                // Show message and follow buttons if not own recipe
                if (userId != currentUserId) ...[
                  IconButton(
                    icon: const Icon(Icons.message_outlined, size: 20),
                    color: const Color(0xFF4CAF50),
                    tooltip: 'Send Message',
                    onPressed: () async {
                      try {
                        final conversationId = await MessageService.getOrCreateConversation(userId);
                        if (mounted) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ChatPage(
                                conversationId: conversationId,
                                otherUserId: userId,
                                otherUserName: userName,
                                otherUserPhoto: userPhoto,
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
                  ),
                  _FollowButton(userId: userId),
                ],
              ],
            ),
          ),
          
          // Full-Width Recipe Image with Title Overlay
          GestureDetector(
            onTap: () async {
              // Increment view count
              await RecipeSharingService.incrementViewCount(recipeId);
              
              // Navigate to recipe details
              if (mounted) {
                final communityRecipe = Map<String, dynamic>.from(recipeData);
                communityRecipe['source'] = 'community';
                communityRecipe['sharedBy'] = userName;
                communityRecipe['communityRecipeId'] = recipeId;
                
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecipeDetailPage(recipe: communityRecipe),
                  ),
                );
              }
            },
            child: Stack(
              children: [
                // Image
                _buildRecipeImage(recipeData['image']),
                
                // Dark gradient overlay at bottom
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.black.withOpacity(0.6),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Recipe Title
                        Text(
                          recipeData['title']?.toString().toUpperCase() ?? 'UNTITLED RECIPE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        // Tags
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (recipeData['goal'] != null)
                              _buildImageTag(recipeData['goal'], Icons.flag),
                            if (recipeData['dietType'] != null)
                              _buildImageTag(recipeData['dietType'], Icons.restaurant_menu),
                            if (recipeData['cuisine'] != null)
                              _buildImageTag(recipeData['cuisine'], Icons.public),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Rating badge (top-right corner)
                if (ratingCount > 0)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star, color: Colors.amber, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            averageRating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // Engagement Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                _buildEngagementButton(
                  icon: Icons.favorite_border,
                  filledIcon: Icons.favorite,
                  count: likes,
                  color: Colors.red,
                  onTap: () async {
                    await RecipeSharingService.toggleLike(recipeId);
                    setState(() {});
                  },
                ),
                const SizedBox(width: 16),
                _buildEngagementButton(
                  icon: Icons.send_outlined,
                  filledIcon: Icons.send,
                  count: 0, // Send button doesn't need a count
                  color: Colors.purple,
                  onTap: () async {
                    await _showForwardRecipeDialog(recipeId, recipeData);
                  },
                ),
                const SizedBox(width: 16),
                _buildEngagementButton(
                  icon: Icons.comment_outlined,
                  filledIcon: Icons.comment,
                  count: commentCount,
                  color: Colors.blue,
                  onTap: () => _showCommentsSheet(recipeId),
                ),
                const Spacer(),
                // Rate button
                InkWell(
                  onTap: () => _showRatingDialog(recipeId),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.amber, width: 1.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_border, color: Colors.amber, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          'Rate',
                          style: TextStyle(
                            color: Colors.grey[800],
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEngagementButton({
    required IconData icon,
    required IconData filledIcon,
    required int count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Row(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(width: 6),
          Text(
            count >= 1000 ? '${(count / 1000).toStringAsFixed(1)}k' : count.toString(),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildImageTag(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStatButton(IconData icon, String count, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(count, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _buildStat(IconData icon, String count) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(count, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildMySharedTab() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: RecipeSharingService.getUserSharedRecipes(
        FirebaseAuth.instance.currentUser?.uid ?? '',
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.green));
        }

        final recipes = snapshot.data ?? [];

        if (recipes.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.share, size: 80, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text(
                  'No shared recipes yet',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Share your first recipe!',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: recipes.length,
          itemBuilder: (context, index) {
            return _buildMyRecipeCard(recipes[index]);
          },
        );
      },
    );
  }

  Widget _buildMyRecipeCard(Map<String, dynamic> sharedRecipe) {
    final recipeData = sharedRecipe['recipeData'] as Map<String, dynamic>? ?? {};
    final likes = sharedRecipe['likes'] ?? 0;
    final saves = sharedRecipe['saves'] ?? 0;
    final views = sharedRecipe['views'] ?? 0;
    final recipeId = sharedRecipe['id'] ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    recipeData['title'] ?? 'Untitled Recipe',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                PopupMenuButton(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                  onSelected: (value) async {
                    if (value == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Recipe'),
                          content: const Text('Are you sure you want to delete this shared recipe?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await RecipeSharingService.deleteSharedRecipe(recipeId);
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildStat(Icons.favorite, likes.toString()),
                const SizedBox(width: 16),
                _buildStat(Icons.bookmark, saves.toString()),
                const SizedBox(width: 16),
                _buildStat(Icons.visibility, views.toString()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeImage(dynamic imagePath) {
    if (imagePath == null) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.green[100]!, Colors.green[200]!],
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: const Center(
          child: Icon(Icons.restaurant_menu, size: 64, color: Colors.green),
        ),
      );
    }

    final imageStr = imagePath.toString();
    
    // Check if it's a base64 encoded image (starts with data:image)
    if (imageStr.startsWith('data:image')) {
      try {
        final base64String = imageStr.split(',')[1];
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Image.memory(
            base64Decode(base64String),
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[100]!, Colors.green[200]!],
                ),
              ),
              child: const Center(
                child: Icon(Icons.restaurant_menu, size: 64, color: Colors.green),
              ),
            ),
          ),
        );
      } catch (e) {
        print('Error decoding base64 image: $e');
        return Container(
          height: 200,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green[100]!, Colors.green[200]!],
            ),
          ),
          child: const Center(
            child: Icon(Icons.restaurant_menu, size: 64, color: Colors.green),
          ),
        );
      }
    }
    
    // Check if it's a URL (starts with http)
    if (imageStr.startsWith('http')) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Image.network(
          imageStr,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[100]!, Colors.green[200]!],
              ),
            ),
            child: const Center(
              child: Icon(Icons.restaurant_menu, size: 64, color: Colors.green),
            ),
          ),
        ),
      );
    }
    
    // It's a file path - try to load as File
    final file = File(imageStr);
    if (file.existsSync()) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        child: Image.file(
          file,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            height: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green[100]!, Colors.green[200]!],
              ),
            ),
            child: const Center(
              child: Icon(Icons.restaurant_menu, size: 64, color: Colors.green),
            ),
          ),
        ),
      );
    }
    
    // File doesn't exist - show placeholder
    return Container(
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[100]!, Colors.green[200]!],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: const Center(
        child: Icon(Icons.restaurant_menu, size: 64, color: Colors.green),
      ),
    );
  }

  void _showRatingDialog(String recipeId) {
    double selectedRating = 0;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Rate this Recipe'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Tap to rate:'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    icon: Icon(
                      index < selectedRating ? Icons.star : Icons.star_border,
                      color: Colors.amber,
                      size: 36,
                    ),
                    onPressed: () {
                      setState(() {
                        selectedRating = (index + 1).toDouble();
                      });
                    },
                  );
                }),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedRating > 0
                  ? () async {
                      try {
                        await RecipeSharingService.rateRecipe(recipeId, selectedRating);
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Rating submitted!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveRecipeWithAllergenCheck(String recipeId, Map<String, dynamic> recipeData) async {
    try {
      // Check for user allergens
      final userAllergens = await AllergenDetectionService.getUserAllergens();
      bool hasAllergens = false;
      List<String> detectedAllergens = [];
      
      if (userAllergens.isNotEmpty) {
        // Extract ingredients for allergen checking
        List<dynamic> ingredients = [];
        if (recipeData['extendedIngredients'] != null) {
          ingredients = recipeData['extendedIngredients'];
        } else if (recipeData['ingredients'] != null) {
          ingredients = recipeData['ingredients'];
        }
        
        if (ingredients.isNotEmpty) {
          final allergenResult = AllergenService.checkAllergens(ingredients);
          
          // Check if any detected allergens match user allergens
          for (final userAllergen in userAllergens) {
            if (allergenResult.containsKey(userAllergen.toLowerCase())) {
              hasAllergens = true;
              detectedAllergens.add(userAllergen);
            }
          }
          
          // If allergens detected, show warning dialog
          if (hasAllergens) {
            bool shouldProceed = false;
            
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AllergenWarningDialog(
                recipe: recipeData,
                detectedAllergens: detectedAllergens,
                substitutionSuggestions: AllergenDetectionService.getSubstitutionSuggestions(detectedAllergens),
                riskLevel: detectedAllergens.length > 2 ? 'high' : detectedAllergens.length > 1 ? 'medium' : 'low',
                onContinue: () {
                  shouldProceed = true;
                  Navigator.of(context).pop();
                },
                onSubstitute: () async {
                  // For community recipes, we don't offer substitution - just warning
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Substitution not available for community recipes. Please contact the recipe creator.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  Navigator.of(context).pop();
                },
              ),
            );
            
            if (!shouldProceed) {
              // User cancelled
              return;
            }
          }
        }
      }
      
      // Save to favorites collection
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('favorites')
            .add({
          ...recipeData,
          'recipeId': recipeId,
          'source': 'community',
          'hasAllergens': hasAllergens,
          'detectedAllergens': detectedAllergens,
          'savedAt': FieldValue.serverTimestamp(),
        });
      }
      
      // Also increment save count in community recipe
      await RecipeSharingService.toggleSave(recipeId, recipeData);
      
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(hasAllergens 
                ? 'Recipe saved to favorites (contains allergens: ${detectedAllergens.join(", ")})'
                : 'Recipe saved to favorites!'),
            backgroundColor: hasAllergens ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error saving recipe: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving recipe: ${e.toString()}')),
        );
      }
    }
  }

  void _showCommentsSheet(String recipeId) {
    final commentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.comment, color: Colors.green),
                    const SizedBox(width: 8),
                    const Text(
                      'Comments',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(),
              // Comments List
              Expanded(
                child: StreamBuilder<List<Map<String, dynamic>>>(
                  stream: RecipeSharingService.getComments(recipeId),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: Colors.green));
                    }

                    final comments = snapshot.data ?? [];

                    if (comments.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.comment_outlined, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No comments yet',
                              style: TextStyle(color: Colors.grey, fontSize: 16),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Be the first to comment!',
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: scrollController,
                      itemCount: comments.length,
                      padding: const EdgeInsets.all(16),
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        final isOwnComment = comment['userId'] == FirebaseAuth.instance.currentUser?.uid;

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: Colors.green,
                                      child: Text(
                                        (comment['userName'] ?? 'A')[0].toUpperCase(),
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        comment['userName'] ?? 'Anonymous',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                    if (isOwnComment)
                                      IconButton(
                                        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                        onPressed: () async {
                                          try {
                                            await RecipeSharingService.deleteComment(recipeId, comment['id']);
                                          } catch (e) {
                                            if (mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Error: $e'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  comment['comment'] ?? '',
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              // Comment Input
              Container(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(top: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: commentController,
                        decoration: InputDecoration(
                          hintText: 'Add a comment...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        maxLines: null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () async {
                        if (commentController.text.trim().isEmpty) return;

                        try {
                          await RecipeSharingService.addComment(recipeId, commentController.text.trim());
                          commentController.clear();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.send),
                      color: Colors.green,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
    );
  }

  Future<void> _showForwardRecipeDialog(String recipeId, Map<String, dynamic> recipeData) async {
    // Show dialog to select users to forward the recipe to
    final selectedUsers = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) => _ForwardRecipeDialog(recipeData: recipeData),
    );

    if (selectedUsers != null && selectedUsers.isNotEmpty) {
      // Forward the recipe to selected users
      for (final user in selectedUsers) {
        await _forwardRecipeToUser(user, recipeData);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Recipe forwarded to ${selectedUsers.length} user(s)!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _forwardRecipeToUser(Map<String, dynamic> targetUser, Map<String, dynamic> recipeData) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Create or get conversation ID using MessageService
      final conversationId = await MessageService.getOrCreateConversation(targetUser['uid']);

      // Create a chat message with the recipe
      final messageData = {
        'senderId': currentUser.uid,
        'receiverId': targetUser['uid'],
        'message': '🍽️ Shared a recipe: ${recipeData['title']}',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'recipe_share',
        'recipeData': {
          // Basic info
          'id': recipeData['id'],
          'title': recipeData['title'],
          'image': recipeData['image'],
          'description': recipeData['description'] ?? recipeData['summary'] ?? '',
          'authorName': recipeData['authorName'] ?? recipeData['sourceName'] ?? 'Unknown',
          'authorId': recipeData['authorId'],
          
          // Essential recipe data
          'ingredients': recipeData['ingredients'] ?? [],
          'extendedIngredients': recipeData['extendedIngredients'] ?? [],
          'instructions': recipeData['instructions'] ?? recipeData['analyzedInstructions'] ?? '',
          'analyzedInstructions': recipeData['analyzedInstructions'] ?? [],
          
          // Nutrition info
          'nutrition': recipeData['nutrition'] ?? {},
          'calories': recipeData['calories'] ?? 0,
          'protein': recipeData['protein'] ?? 0,
          'carbs': recipeData['carbs'] ?? recipeData['carbohydrates'] ?? 0,
          'fat': recipeData['fat'] ?? 0,
          'fiber': recipeData['fiber'] ?? 0,
          'sugar': recipeData['sugar'] ?? 0,
          'sodium': recipeData['sodium'] ?? 0,
          
          // Additional info
          'servings': recipeData['servings'] ?? 1,
          'readyInMinutes': recipeData['readyInMinutes'] ?? recipeData['cookingTime'] ?? 0,
          'cookingTime': recipeData['cookingTime'] ?? recipeData['readyInMinutes'] ?? 0,
          'preparationTime': recipeData['preparationTime'] ?? 0,
          'cuisine': recipeData['cuisine'] ?? '',
          'dishTypes': recipeData['dishTypes'] ?? [],
          'diets': recipeData['diets'] ?? [],
          'sourceUrl': recipeData['sourceUrl'] ?? '',
          'sourceName': recipeData['sourceName'] ?? '',
          'summary': recipeData['summary'] ?? '',
          
          // Recipe sharing specific
          'originalRecipeId': recipeData['id'],
          'sharedBy': currentUser.uid,
          'sharedAt': FieldValue.serverTimestamp(),
        },
        'isRead': false,
      };

      // Add to the proper conversation messages collection
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .collection('messages')
          .add(messageData);

      // Update conversation's last message info so it appears in Messages page
      await FirebaseFirestore.instance
          .collection('conversations')
          .doc(conversationId)
          .update({
        'lastMessage': '🍽️ Shared a recipe: ${recipeData['title']}',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': currentUser.uid,
        'unreadCount.${targetUser['uid']}': FieldValue.increment(1),
      });

      print('DEBUG: Recipe forwarded to ${targetUser['name']} in conversation $conversationId');
    } catch (e) {
      print('ERROR forwarding recipe: $e');
    }
  }
}

// Follow Button Widget
class _FollowButton extends StatefulWidget {
  final String userId;

  const _FollowButton({required this.userId});

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  bool _isFollowing = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkFollowStatus();
  }

  Future<void> _checkFollowStatus() async {
    try {
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('following')
          .doc(widget.userId)
          .get();

      if (mounted) {
        setState(() {
          _isFollowing = doc.exists;
        });
      }
    } catch (e) {
      print('Error checking follow status: $e');
    }
  }

  Future<void> _toggleFollow() async {
    if (_isLoading) return;

    setState(() => _isLoading = true);

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

        if (mounted) {
          setState(() => _isFollowing = false);
        }
      } else {
        // Follow
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('following')
            .doc(widget.userId)
            .set({'followedAt': FieldValue.serverTimestamp()});

        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .collection('followers')
            .doc(currentUserId)
            .set({'followedAt': FieldValue.serverTimestamp()});

        if (mounted) {
          setState(() => _isFollowing = true);
        }
      }
    } catch (e) {
      print('Error toggling follow: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _isLoading ? null : _toggleFollow,
      style: TextButton.styleFrom(
        backgroundColor: _isFollowing ? Colors.grey[300] : Colors.green,
        foregroundColor: _isFollowing ? Colors.black : Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: _isLoading
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(
              _isFollowing ? 'Following' : 'Follow',
              style: const TextStyle(fontSize: 13),
            ),
    );
  }
}

class _ForwardRecipeDialog extends StatefulWidget {
  final Map<String, dynamic> recipeData;

  const _ForwardRecipeDialog({required this.recipeData});

  @override
  State<_ForwardRecipeDialog> createState() => _ForwardRecipeDialogState();
}

class _ForwardRecipeDialogState extends State<_ForwardRecipeDialog> {
  final List<Map<String, dynamic>> _selectedUsers = [];
  List<Map<String, dynamic>> _availableUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableUsers();
  }

  Future<void> _loadAvailableUsers() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      // Get users that the current user has chatted with or followed
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('uid', isNotEqualTo: currentUser.uid)
          .limit(20)
          .get();

      setState(() {
        _availableUsers = usersSnapshot.docs.map((doc) {
          final data = doc.data();
          // Try multiple fields for name
          String displayName = data['fullName'] ?? 
                              data['username'] ?? 
                              data['displayName'] ?? 
                              data['firstName'] ?? 
                              data['email']?.toString().split('@')[0] ??
                              'Unknown User';
          
          return {
            'uid': data['uid'] ?? doc.id,
            'name': displayName,
            'profileImage': data['profileImage'] ?? data['photoURL'],
            'email': data['email'],
          };
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('ERROR loading users: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Forward Recipe'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: Column(
          children: [
            Text(
              'Forward "${widget.recipeData['title']}" to:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _availableUsers.isEmpty
                      ? const Center(
                          child: Text('No users available to forward to'),
                        )
                      : ListView.builder(
                          itemCount: _availableUsers.length,
                          itemBuilder: (context, index) {
                            final user = _availableUsers[index];
                            final isSelected = _selectedUsers.any((u) => u['uid'] == user['uid']);
                            
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundImage: user['profileImage'] != null
                                    ? NetworkImage(user['profileImage'])
                                    : null,
                                child: user['profileImage'] == null
                                    ? Text(user['name'][0].toUpperCase())
                                    : null,
                              ),
                              title: Text(user['name']),
                              subtitle: Text(user['email'] ?? ''),
                              trailing: Checkbox(
                                value: isSelected,
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      _selectedUsers.add(user);
                                    } else {
                                      _selectedUsers.removeWhere((u) => u['uid'] == user['uid']);
                                    }
                                  });
                                },
                              ),
                              onTap: () {
                                setState(() {
                                  if (isSelected) {
                                    _selectedUsers.removeWhere((u) => u['uid'] == user['uid']);
                                  } else {
                                    _selectedUsers.add(user);
                                  }
                                });
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _selectedUsers.isEmpty
              ? null
              : () => Navigator.of(context).pop(_selectedUsers),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: Text('Forward (${_selectedUsers.length})'),
        ),
      ],
    );
  }
}
