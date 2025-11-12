import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'recipe_detail_page.dart';
import 'recipe_search_page.dart';
import 'manual_meal_entry_page.dart';
import 'services/recipe_service.dart';
import 'services/filipino_recipe_service.dart';
import 'services/health_warning_service.dart';
import 'widgets/health_warning_dialog.dart';
import 'services/allergen_detection_service.dart';
import 'widgets/allergen_warning_dialog.dart';
import 'widgets/substitution_dialog_helper.dart';

class MealFavoritesPage extends StatefulWidget {
  const MealFavoritesPage({super.key});

  @override
  State<MealFavoritesPage> createState() => _MealFavoritesPageState();
}

class _MealFavoritesPageState extends State<MealFavoritesPage> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _favorites = [];
  List<Map<String, dynamic>> _manualEntries = [];
  List<Map<String, dynamic>> _favoriteRecipes = [];
  bool _isLoading = true;
  String? _error;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {}); // Rebuild to show/hide FAB based on tab
    });
    _loadFavorites();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final favoritesQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .orderBy('addedAt', descending: true)
          .get();

      setState(() {
        _favorites = favoritesQuery.docs.map((doc) {
          final data = doc.data();
          data['docId'] = doc.id;
          return data;
        }).toList();
        
        // Separate manual entries from other favorites
        _manualEntries = _favorites.where((fav) {
          final recipe = fav['recipe'] as Map<String, dynamic>? ?? {};
          return recipe['source'] == 'manual_entry';
        }).toList();
        
        _favoriteRecipes = _favorites.where((fav) {
          final recipe = fav['recipe'] as Map<String, dynamic>? ?? {};
          return recipe['source'] != 'manual_entry';
        }).toList();
        
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _showDeleteConfirmation(Map<String, dynamic> favorite) async {
    final recipe = favorite['recipe'] as Map<String, dynamic>? ?? {};
    final recipeTitle = recipe['title'] ?? 'this recipe';
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recipe'),
        content: Text('Are you sure you want to delete "$recipeTitle"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _removeFavorite(favorite['docId']);
    }
  }

  Future<void> _removeFavorite(String docId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(docId)
          .delete();

      setState(() {
        _favorites.removeWhere((favorite) => favorite['docId'] == docId);
        _manualEntries.removeWhere((favorite) => favorite['docId'] == docId);
        _favoriteRecipes.removeWhere((favorite) => favorite['docId'] == docId);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recipe deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting recipe: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _rateRecipe(Map<String, dynamic> recipe, double rating) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final docId = recipe['docId'];
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .doc(docId)
          .update({
        'rating': rating,
        'ratedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        final index = _favorites.indexWhere((fav) => fav['docId'] == docId);
        if (index != -1) {
          _favorites[index]['rating'] = rating;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rated ${rating.toStringAsFixed(1)} stars'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error rating recipe: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(130),
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
            centerTitle: true,
            title: const Text(
              'My Recipes',
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
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
              ),
              tabs: const [
                Tab(
                  icon: Icon(Icons.edit_note),
                  text: 'Manual Entries',
                ),
                Tab(
                  icon: Icon(Icons.favorite),
                  text: 'Favorites',
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.green[600]!),
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Loading your recipes...',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red[400],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Oops! Something went wrong',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Error: $_error',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadFavorites,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Try Again'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[600],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Manual Entries Tab
                    _buildRecipeList(_manualEntries, 'Manual Entries', Icons.edit_note),
                    // Favorites Tab
                    _buildRecipeList(_favoriteRecipes, 'Favorites', Icons.favorite),
                  ],
                ),
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ManualMealEntryPage(
                      selectedDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
                      saveToFavoritesOnly: true,
                    ),
                  ),
                ).then((_) => _loadFavorites());
              },
              icon: const Icon(Icons.add),
              label: const Text('Create Manual Entry'),
              backgroundColor: Colors.green[600],
              foregroundColor: Colors.white,
            )
          : null,
    );
  }

  Widget _buildRecipeList(List<Map<String, dynamic>> recipes, String emptyTitle, IconData emptyIcon) {
    if (recipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.green[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                emptyIcon,
                size: 80,
                color: Colors.green[300],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'No $emptyTitle yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              emptyTitle == 'Manual Entries' 
                  ? 'Create manual meal entries\nand they\'ll appear here!'
                  : 'Start adding meals to your favorites\nand they\'ll appear here!',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                if (emptyTitle == 'Manual Entries') {
                  // Navigate to Manual Meal Entry Page
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ManualMealEntryPage(
                        selectedDate: DateFormat('yyyy-MM-dd').format(DateTime.now()),
                        saveToFavoritesOnly: true,
                      ),
                    ),
                  ).then((_) => _loadFavorites());
                } else {
                  // Navigate to Recipe Search Page
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RecipeSearchPage(),
                    ),
                  ).then((_) => _loadFavorites());
                }
              },
              icon: const Icon(Icons.add),
              label: Text(emptyTitle == 'Manual Entries' ? 'Create Manual Entry' : 'Add Favorites'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[600],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFavorites,
      color: Colors.green[600],
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: recipes.length,
        itemBuilder: (context, index) {
          final favorite = recipes[index];
          return AnimatedContainer(
            duration: Duration(milliseconds: 300 + (index * 100)),
            curve: Curves.easeOutBack,
            child: _buildFavoriteCard(favorite, index),
          );
        },
      ),
    );
  }

  Widget _buildFavoriteCard(Map<String, dynamic> favorite, int index) {
    final recipe = favorite['recipe'] as Map<String, dynamic>? ?? {};
    final rating = favorite['rating']?.toDouble();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        color: Colors.white,
      child: InkWell(
        onTap: () {
            print('DEBUG: Opening favorite recipe: ${recipe['title']}');
            print('DEBUG: Recipe keys: ${recipe.keys.toList()}');
            print('DEBUG: Recipe source: ${recipe['source']}');
            print('DEBUG: Ingredients type: ${recipe['ingredients']?.runtimeType}');
            print('DEBUG: Ingredients content: ${recipe['ingredients']}');
            print('DEBUG: ExtendedIngredients type: ${recipe['extendedIngredients']?.runtimeType}');
            print('DEBUG: ExtendedIngredients content: ${recipe['extendedIngredients']}');
            
          // Add docId to recipe for edit functionality
          final recipeWithDocId = Map<String, dynamic>.from(recipe);
          recipeWithDocId['docId'] = favorite['docId'];
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecipeDetailPage(recipe: recipeWithDocId),
            ),
          );
        },
          borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(20),
              ),
              child: recipe['image'] != null && recipe['image'].toString().isNotEmpty
                  ? _buildRecipeImage(recipe['image'])
                  : _buildPlaceholderImage(),
            ),

            // Recipe Info
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          recipe['title'] ?? 'Unknown Recipe',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () => _showDeleteConfirmation(favorite),
                          icon: Icon(Icons.delete_outline, color: Colors.red[600]),
                          tooltip: 'Delete recipe',
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                  
                  // Badges for substituted or allergen warnings
                  if (recipe['substituted'] == true || recipe['hasAllergens'] == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          if (recipe['substituted'] == true)
                            Tooltip(
                              message: 'Substituted ingredients: ${(recipe['substitutions'] as Map?)?.values.map((v) => v.toString()).join(', ') ?? 'N/A'}',
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.swap_horiz, size: 14, color: Colors.blue[700]),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Substituted',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          if (recipe['hasAllergens'] == true)
                            Tooltip(
                              message: 'Contains allergens: ${(recipe['detectedAllergens'] as List?)?.join(', ') ?? 'N/A'}',
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning_amber_rounded, size: 14, color: Colors.orange[700]),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Contains Allergens',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange[700],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 12),
                  
                  // Rating Section
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.amber[50],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                    children: [
                        Text(
                          'Rate: ',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ...List.generate(5, (starIndex) {
                        return GestureDetector(
                          onTap: () => _rateRecipe(favorite, starIndex + 1.0),
                            child: Container(
                              padding: const EdgeInsets.all(2),
                          child: Icon(
                            starIndex < (rating ?? 0) ? Icons.star : Icons.star_border,
                                color: Colors.amber[600],
                                size: 20,
                              ),
                          ),
                        );
                      }),
                      if (rating != null) ...[
                        const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber[100],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                          rating.toStringAsFixed(1),
                          style: TextStyle(
                                color: Colors.amber[800],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Recipe Stats
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      if (recipe['readyInMinutes'] != null) ...[
                        _buildStatChip(
                          icon: Icons.access_time,
                          label: '${recipe['readyInMinutes']} min',
                          color: Colors.blue,
                        ),
                      ],
                      if (recipe['servings'] != null) ...[
                        _buildStatChip(
                          icon: Icons.people,
                          label: '${recipe['servings']} servings',
                          color: Colors.green,
                        ),
                      ],
                      if (recipe['cuisine'] != null) ...[
                        _buildStatChip(
                          icon: Icons.public,
                          label: recipe['cuisine'],
                          color: Colors.orange,
                        ),
                      ],
                    ],
                  ),
                  
                  if (favorite['notes'] != null && favorite['notes'].toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.note, size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              favorite['notes'],
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeImage(String imagePath) {
    if (imagePath.startsWith('data:image')) {
      // Base64 encoded image
      try {
        final base64String = imagePath.split(',')[1];
        return Image.memory(
          base64Decode(base64String),
          height: 160,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _buildPlaceholderImage();
          },
        );
      } catch (e) {
        print('Error decoding base64 image: $e');
        return _buildPlaceholderImage();
      }
    } else if (imagePath.startsWith('assets/')) {
      // Local asset image
      return Image.asset(
        imagePath,
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage();
        },
      );
    } else if (imagePath.startsWith('/') || imagePath.startsWith('file://') || imagePath.contains('/storage/') || imagePath.contains('/data/')) {
      // Local file image
      return Image.file(
        File(imagePath),
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage();
        },
      );
    } else {
      // Network image
      return Image.network(
        imagePath,
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            height: 160,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.green),
            ),
          );
        },
      );
    }
  }

  Widget _buildPlaceholderImage() {
    return Container(
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green[50]!, Colors.green[100]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 48,
              color: Colors.green,
            ),
            SizedBox(height: 8),
            Text(
              'Recipe Image',
              style: TextStyle(
                color: Colors.green,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper function to add recipes to favorites (to be used in other pages)
class FavoriteService {
  static Future<void> addToFavorites(
    BuildContext context,
    Map<String, dynamic> recipe, {
    String? notes,
  }) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Check if already favorited
      final existingQuery = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .where('recipe.id', isEqualTo: recipe['id'])
          .get();

      if (existingQuery.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipe is already in favorites'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Check for health warnings first (based on health conditions)
      print('DEBUG: Checking health warnings for favorite recipe: ${recipe['title']}');
      final healthWarnings = await HealthWarningService.checkMealHealth(
        mealData: recipe,
        customTitle: recipe['title'],
      );
      
      if (healthWarnings.isNotEmpty) {
        print('DEBUG: Health warnings detected for favorite: ${healthWarnings.length} warnings');
        
        // Show health warning dialog
        final shouldContinue = await showHealthWarningDialog(
          context: context,
          warnings: healthWarnings,
          mealTitle: recipe['title'] ?? 'Unknown Recipe',
        );
        
        if (!shouldContinue) {
          print('DEBUG: User cancelled adding to favorites due to health warnings');
          return; // User chose to cancel
        }
        
        print('DEBUG: User chose to continue adding to favorites despite health warnings');
      }

      // Create a copy of the recipe to work with
      Map<String, dynamic> fullRecipe = Map<String, dynamic>.from(recipe);
      
      // Check if this is a basic search result (missing extendedIngredients/analyzedInstructions)
      // Skip fetching for community recipes and manual entries - they're already complete
      final isCommunityOrManual = fullRecipe['source'] == 'community' || 
                                   fullRecipe['source'] == 'manual_entry';
      
      final needsFullDetails = !isCommunityOrManual &&
                                (fullRecipe['extendedIngredients'] == null || 
                                fullRecipe['analyzedInstructions'] == null ||
                                (fullRecipe['extendedIngredients'] is List && 
                                 (fullRecipe['extendedIngredients'] as List).isEmpty));
      
      // Fetch full recipe details if needed (not for community or manual recipes)
      if (needsFullDetails && fullRecipe['id'] != null) {
        print('DEBUG: Fetching full recipe details for: ${fullRecipe['title']}');
        try {
          final details = await RecipeService.fetchRecipeDetails(fullRecipe['id']);
          // Merge with existing data, preserving any existing fields
          fullRecipe = {...details, ...fullRecipe};
          print('DEBUG: Successfully fetched full recipe details');
        } catch (e) {
          print('DEBUG: Error fetching full details: $e');
          // Continue with basic recipe if fetch fails
        }
      }

      // Check for user allergens
      final userAllergens = await AllergenDetectionService.getUserAllergens();
      bool hasAllergens = false;
      List<String> detectedAllergens = [];
      
      if (userAllergens.isNotEmpty) {
        // Extract ingredients for allergen checking
        List<dynamic> ingredients = [];
        if (fullRecipe['extendedIngredients'] != null) {
          ingredients = fullRecipe['extendedIngredients'];
        } else if (fullRecipe['ingredients'] != null) {
          ingredients = fullRecipe['ingredients'];
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
            print('DEBUG: Allergens detected: $detectedAllergens');
            
            bool shouldProceed = false;
            bool shouldSubstitute = false;
            
            await showDialog(
              context: context,
              barrierDismissible: false,
              builder: (context) => AllergenWarningDialog(
                recipe: fullRecipe,
                detectedAllergens: detectedAllergens,
                substitutionSuggestions: AllergenDetectionService.getSubstitutionSuggestions(detectedAllergens),
                riskLevel: detectedAllergens.length > 2 ? 'high' : detectedAllergens.length > 1 ? 'medium' : 'low',
                onContinue: () {
                  print('DEBUG: User chose to continue with allergens');
                  shouldProceed = true;
                  Navigator.of(context).pop();
                },
                onSubstitute: () async {
                  print('DEBUG: User chose to find substitutes');
                  shouldSubstitute = true;
                  Navigator.of(context).pop();
                },
              ),
            );
            
            if (!shouldProceed && !shouldSubstitute) {
              // User cancelled (closed dialog)
              return;
            }
            
            if (shouldSubstitute) {
              // User chose to substitute ingredients
              print('DEBUG: Showing substitution dialog');
              
              final substitutionResult = await SubstitutionDialogHelper.showSubstitutionDialog(
                context,
                fullRecipe,
                detectedAllergens,
              );
              
              if (substitutionResult != null && substitutionResult['substituted'] == true) {
                // Apply substitutions to the recipe
                fullRecipe = substitutionResult;
                fullRecipe['hasAllergens'] = false;
                fullRecipe['substituted'] = true;
                fullRecipe['originalAllergens'] = detectedAllergens;
                print('DEBUG: Substitutions applied successfully');
              } else {
                // User cancelled substitution
                return;
              }
            } else if (shouldProceed) {
              // User chose to proceed despite allergens
              fullRecipe['hasAllergens'] = true;
              fullRecipe['detectedAllergens'] = detectedAllergens;
            }
          }
        }
      }

      // Convert TimeOfDay to string if present
      if (fullRecipe['mealTime'] is TimeOfDay) {
        final mealTime = fullRecipe['mealTime'] as TimeOfDay;
        fullRecipe['mealTime'] = '${mealTime.hour}:${mealTime.minute}';
      }

      // Remove meal planner specific fields to avoid confusion with meal planner edits
      // These fields should not exist in favorites as they're meal planner metadata
      fullRecipe.remove('date'); // Remove meal planner date
      fullRecipe.remove('mealType'); // Remove meal type from planner
      fullRecipe.remove('meal_type'); // Remove alternate meal type field
      
      // Store the original meal planner ID separately if it exists
      final originalMealId = fullRecipe['id'];
      
      // Remove meal planner document ID to avoid conflicts
      // The recipe will get its own favorites document ID
      if (fullRecipe.containsKey('id') && fullRecipe['date'] == null) {
        // Only keep 'id' if it's a recipe ID (not a meal planner doc ID)
        // Recipe IDs are typically numeric or have specific prefixes
      } // else keep the recipe ID for API lookups

      // Save to Firestore
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .add({
        'recipe': fullRecipe,
        'notes': notes,
        'addedAt': FieldValue.serverTimestamp(),
        'rating': null,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(fullRecipe['substituted'] == true 
              ? 'Added to favorites with substitutions!' 
              : 'Added to favorites!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('DEBUG: Error in addToFavorites: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding to favorites: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  static Future<bool> isFavorited(String recipeId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .where('recipe.id', isEqualTo: recipeId)
          .get();

      return query.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  static Future<void> removeFromFavorites(String recipeId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final query = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('favorites')
          .where('recipe.id', isEqualTo: recipeId)
          .get();

      for (final doc in query.docs) {
        await doc.reference.delete();
      }
    } catch (e) {
      // Handle error silently
    }
  }
}
