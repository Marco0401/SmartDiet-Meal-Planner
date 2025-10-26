import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/recipe_service.dart';
import 'services/filipino_recipe_service.dart';
import 'meal_favorites_page.dart';
import 'recipe_detail_page.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class MealSuggestionsPage extends StatefulWidget {
  const MealSuggestionsPage({super.key});

  @override
  State<MealSuggestionsPage> createState() => _MealSuggestionsPageState();
}

class _MealSuggestionsPageState extends State<MealSuggestionsPage> {
  List<Map<String, dynamic>> _suggestions = [];
  bool _isLoading = false;
  String? _error;
  String _selectedCategory = 'Quick & Easy';
  Map<String, dynamic>? _userProfile;
  String _searchQuery = '';
  TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _categories = [
    {
      'name': 'Quick & Easy',
      'icon': Icons.flash_on,
      'description': 'Meals ready in 30 minutes or less',
      'queries': ['quick meals', 'easy recipes', '30 minute meals'],
      'color': Colors.orange,
    },
    {
      'name': 'Healthy Options',
      'icon': Icons.favorite,
      'description': 'Nutritious and balanced meals',
      'queries': ['healthy recipes', 'low calorie', 'nutritious meals'],
      'color': Colors.green,
    },
    {
      'name': 'High Protein',
      'icon': Icons.fitness_center,
      'description': 'Perfect for muscle building and recovery',
      'queries': ['high protein', 'protein rich', 'muscle building meals'],
      'color': Colors.blue,
    },
    {
      'name': 'Low Carb',
      'icon': Icons.trending_down,
      'description': 'Great for weight management',
      'queries': ['low carb', 'keto friendly', 'low carbohydrate'],
      'color': Colors.purple,
    },
    {
      'name': 'Filipino Favorites',
      'icon': Icons.restaurant,
      'description': 'Traditional Filipino dishes',
      'queries': ['filipino', 'pinoy', 'traditional'],
      'color': Colors.red,
    },
    {
      'name': 'Comfort Food',
      'icon': Icons.home,
      'description': 'Soul-warming comfort meals',
      'queries': ['comfort food', 'hearty meals', 'soul food'],
      'color': Colors.brown,
    },
    {
      'name': 'Budget Friendly',
      'icon': Icons.attach_money,
      'description': 'Affordable meals for everyday',
      'queries': ['budget meals', 'cheap recipes', 'affordable'],
      'color': Colors.teal,
    },
    {
      'name': 'One Pot Meals',
      'icon': Icons.restaurant_menu,
      'description': 'Easy cleanup, delicious results',
      'queries': ['one pot', 'sheet pan', 'casserole'],
      'color': Colors.indigo,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadSuggestions();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          setState(() {
            _userProfile = doc.data();
          });
        }
      }
    } catch (e) {
      // Handle error silently for now
    }
  }

  Future<List<Map<String, dynamic>>> _fetchFromTheMealDB(String query) async {
    try {
      // Try multiple search strategies for better results
      List<Map<String, dynamic>> allResults = [];
      
      // Strategy 1: Search by name
      final nameUrl = 'https://www.themealdb.com/api/json/v1/1/search.php?s=$query';
      final nameResponse = await http.get(Uri.parse(nameUrl));
      
      if (nameResponse.statusCode == 200) {
        final data = json.decode(nameResponse.body);
        final meals = data['meals'] as List<dynamic>? ?? [];
        
        for (final meal in meals) {
          final instructions = meal['strInstructions']?.toString() ?? 'Delicious recipe from TheMealDB';
          final summary = instructions.length > 100 
              ? instructions.substring(0, 100) + '...'
              : instructions;
          
          // Try to get actual nutrition data from Filipino recipes if available
          Map<String, dynamic> nutritionData = {
            'calories': 400.0, // Default calories for TheMealDB recipes
            'protein': 20.0,
            'carbs': 30.0,
            'fat': 15.0,
            'fiber': 3.0,
            'sugar': 5.0,
            'sodium': 500.0,
          };
          
          // Check if there's a Filipino recipe with the same name
          try {
            final filipinoDetails = await FilipinoRecipeService.getRecipeDetails('curated_${meal['strMeal'].toString().toLowerCase().replaceAll(' ', '_')}');
            if (filipinoDetails != null && filipinoDetails['nutrition'] != null) {
              nutritionData = filipinoDetails['nutrition'];
              print('DEBUG: Found Filipino recipe for ${meal['strMeal']} with nutrition: $nutritionData');
            }
          } catch (e) {
            // Use default nutrition if no Filipino recipe found
            print('DEBUG: No Filipino recipe found for ${meal['strMeal']}, using default nutrition');
          }
              
          allResults.add({
            'id': 'themealdb_${meal['idMeal']}',
            'title': meal['strMeal'],
            'image': meal['strMealThumb'],
            'sourceUrl': meal['strSource'],
            'cuisine': 'International',
            'readyInMinutes': 30, // Default time
            'servings': 4, // Default servings
            'summary': summary,
            'nutrition': nutritionData,
          });
        }
      }
      
      // Strategy 2: If no results, try random meals
      if (allResults.isEmpty) {
        final randomUrl = 'https://www.themealdb.com/api/json/v1/1/random.php';
        final randomResponse = await http.get(Uri.parse(randomUrl));
        
        if (randomResponse.statusCode == 200) {
          final data = json.decode(randomResponse.body);
          final meals = data['meals'] as List<dynamic>? ?? [];
          
          for (final meal in meals.take(5)) { // Limit to 5 random meals
            final instructions = meal['strInstructions']?.toString() ?? 'Delicious recipe from TheMealDB';
            final summary = instructions.length > 100 
                ? instructions.substring(0, 100) + '...'
                : instructions;
            
            // Try to get actual nutrition data from TheMealDB or Filipino recipes
            Map<String, dynamic> nutritionData = {
              'calories': 400.0, // Default calories for TheMealDB recipes
              'protein': 20.0,
              'carbs': 30.0,
              'fat': 15.0,
              'fiber': 3.0,
              'sugar': 5.0,
              'sodium': 500.0,
            };
            
            // First, try to get actual nutrition data from TheMealDB by fetching the full recipe details
            try {
              final fullRecipeDetails = await RecipeService.fetchRecipeDetails('themealdb_${meal['idMeal']}');
              if (fullRecipeDetails != null && fullRecipeDetails['nutrition'] != null) {
                nutritionData = fullRecipeDetails['nutrition'];
                print('DEBUG: Found actual TheMealDB nutrition for ${meal['strMeal']}: $nutritionData');
              }
            } catch (e) {
              print('DEBUG: Could not fetch TheMealDB nutrition for ${meal['strMeal']}: $e');
              
              // Fallback: Check if there's a Filipino recipe with the same name
              try {
                final filipinoDetails = await FilipinoRecipeService.getRecipeDetails('curated_${meal['strMeal'].toString().toLowerCase().replaceAll(' ', '_')}');
                if (filipinoDetails != null && filipinoDetails['nutrition'] != null) {
                  nutritionData = filipinoDetails['nutrition'];
                  print('DEBUG: Found Filipino recipe for ${meal['strMeal']} with nutrition: $nutritionData');
                }
              } catch (e) {
                // Use default nutrition if no recipe found
                print('DEBUG: No recipe found for ${meal['strMeal']}, using default nutrition');
              }
            }
                
            allResults.add({
              'id': 'themealdb_${meal['idMeal']}',
              'title': meal['strMeal'],
              'image': meal['strMealThumb'],
              'sourceUrl': meal['strSource'],
              'cuisine': 'International',
              'readyInMinutes': 30, // Default time
              'servings': 4, // Default servings
              'summary': summary,
              'nutrition': nutritionData,
            });
          }
        }
      }
      
      return allResults;
    } catch (e) {
      print('TheMealDB fetch error: $e');
      return [];
    }
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      List<Map<String, dynamic>> suggestions = [];

      // If there's a search query, use it instead of category
      if (_searchQuery.isNotEmpty) {
        // Try TheMealDB first (most reliable)
        suggestions = await _fetchFromTheMealDB(_searchQuery);
        
        // If no results from TheMealDB, try RecipeService
        if (suggestions.isEmpty) {
          try {
            final recipes = await RecipeService.fetchRecipes(_searchQuery);
            suggestions = recipes.take(8).toList().cast<Map<String, dynamic>>();
          } catch (e) {
            print('RecipeService failed, using Filipino recipes as fallback: $e');
            final filipinoRecipes = await FilipinoRecipeService.fetchFilipinoRecipes('adobo');
            suggestions = filipinoRecipes.cast<Map<String, dynamic>>();
          }
        }
      } else {
      // Load Filipino recipes for Filipino Favorites category
      if (_selectedCategory == 'Filipino Favorites') {
        final recipes = await FilipinoRecipeService.fetchFilipinoRecipes('adobo');
        suggestions = recipes.cast<Map<String, dynamic>>();
      } else {
          // Load from TheMealDB first for other categories
          final category = _categories.firstWhere(
            (cat) => cat['name'] == _selectedCategory,
            orElse: () => _categories.first,
          );
        final queries = category['queries'] as List<String>;
        final query = queries.first;
          
          // Try TheMealDB first (most reliable)
          suggestions = await _fetchFromTheMealDB(query);
          
          // If no results from TheMealDB, try RecipeService
          if (suggestions.isEmpty) {
            try {
        final recipes = await RecipeService.fetchRecipes(query);
              suggestions = recipes.take(8).toList().cast<Map<String, dynamic>>();
            } catch (e) {
              print('RecipeService failed for ${_selectedCategory}, using Filipino recipes as fallback: $e');
              final filipinoRecipes = await FilipinoRecipeService.fetchFilipinoRecipes('adobo');
              suggestions = filipinoRecipes.cast<Map<String, dynamic>>();
            }
          }
        }
      }

      // If we still have no suggestions, try to get any Filipino recipes
      if (suggestions.isEmpty) {
        print('No suggestions found, loading all Filipino recipes as final fallback');
        final filipinoRecipes = await FilipinoRecipeService.fetchFilipinoRecipes('adobo');
        suggestions = filipinoRecipes.cast<Map<String, dynamic>>();
      }

      // Filter based on user preferences if available
      if (_userProfile != null) {
        suggestions = _filterByUserPreferences(suggestions);
      }

      setState(() {
        _suggestions = suggestions;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }




  Future<void> _addToFavorites(Map<String, dynamic> recipe) async {
    print('DEBUG: ===== _addToFavorites CALLED FROM MEAL SUGGESTIONS =====');
    print('DEBUG: Adding recipe to favorites: ${recipe['title']}');
    
    try {
      await FavoriteService.addToFavorites(context, recipe);
      print('DEBUG: Successfully added to favorites');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${recipe['title']} to favorites!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      print('DEBUG: Error adding to favorites: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add to favorites: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> _filterByUserPreferences(
    List<Map<String, dynamic>> recipes,
  ) {
    if (_userProfile == null) return recipes;

    final allergies = _userProfile!['allergies'] as List<dynamic>? ?? [];
    final dietaryRestrictions = _userProfile!['dietaryRestrictions'] as List<dynamic>? ?? [];

    return recipes.where((recipe) {
      // Basic filtering - in a real app, you'd want more sophisticated filtering
      final title = (recipe['title'] ?? '').toString().toLowerCase();
      
      // Filter out recipes with known allergens
      for (final allergy in allergies) {
        if (title.contains(allergy.toString().toLowerCase())) {
          return false;
        }
      }

      // Filter based on dietary restrictions
      for (final restriction in dietaryRestrictions) {
        final restrictionLower = restriction.toString().toLowerCase();
        if (restrictionLower == 'vegetarian' && title.contains('meat')) {
          return false;
        }
        if (restrictionLower == 'vegan' && (title.contains('cheese') || title.contains('milk'))) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Smart Meal Suggestions',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadSuggestions,
              tooltip: 'Refresh Suggestions',
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Header Section
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.green.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.lightbulb_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Text(
                        'Discover Your Perfect Meal',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search for specific meals...',
                      hintStyle: TextStyle(color: Colors.grey.shade600),
                      prefixIcon: Icon(Icons.search, color: Colors.green.shade600),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, color: Colors.grey.shade600),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchQuery = '';
                                });
                                _loadSuggestions();
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                      if (value.isNotEmpty) {
                        _loadSuggestions();
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Category Selection
          Container(
            height: 140,
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category['name'] == _selectedCategory;
                final color = category['color'] as Color;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category['name'];
                    });
                    _loadSuggestions();
                  },
                  child: Container(
                    width: 110,
                    margin: const EdgeInsets.only(right: 16),
                    decoration: BoxDecoration(
                      gradient: isSelected 
                          ? LinearGradient(
                              colors: [color, color.withOpacity(0.8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected ? null : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected ? color : Colors.grey.shade200,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isSelected 
                              ? color.withOpacity(0.3)
                              : Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? Colors.white.withOpacity(0.2)
                                : color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                          category['icon'],
                            color: isSelected ? Colors.white : color,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          category['name'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Category Description
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              _categories.firstWhere(
                (cat) => cat['name'] == _selectedCategory,
                orElse: () => _categories.first,
              )['description'],
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const Divider(),

          // Suggestions List
          Expanded(
            child: _isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Finding perfect meals for you...',
                          style: TextStyle(
                            color: Colors.grey.shade600,
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
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load suggestions',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _loadSuggestions,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      )
                    : _suggestions.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.restaurant_menu,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No suggestions found',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: _loadSuggestions,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('Try Again'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: _suggestions.length,
                            itemBuilder: (context, index) {
                              final recipe = _suggestions[index];
                              return _buildSuggestionCard(recipe);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(Map<String, dynamic> recipe) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Recipe Image
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RecipeDetailPage(recipe: recipe),
                  ),
                );
              },
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: recipe['image'] != null && recipe['image'].toString().isNotEmpty
                    ? _buildRecipeImage(recipe['image'], height: 200)
                    : _buildPlaceholderImage(),
              ),
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
                    style: const TextStyle(
                            fontSize: 20,
                      fontWeight: FontWeight.bold,
                            color: Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          recipe['cuisine'] ?? 'General',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Recipe Stats
                  Row(
                    children: [
                      if (recipe['readyInMinutes'] != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time, size: 14, color: Colors.blue.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe['readyInMinutes']} min',
                                style: TextStyle(color: Colors.blue.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (recipe['servings'] != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people, size: 14, color: Colors.orange.shade700),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe['servings']} servings',
                                style: TextStyle(color: Colors.orange.shade700, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  
                  if (recipe['summary'] != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _stripHtmlTags(recipe['summary']),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                        height: 1.4,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Add to Favorites
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _addToFavorites(recipe),
                      icon: const Icon(Icons.favorite_border, size: 18),
                      label: const Text('Add to Favorites', style: TextStyle(fontSize: 16)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
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

  Widget _buildRecipeImage(String imagePath, {double? width, double? height}) {
    if (imagePath.startsWith('assets/')) {
      // Local asset image
      return Image.asset(
        imagePath,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage();
        },
      );
    } else {
      // Network image
      return Image.network(
        imagePath,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildPlaceholderImage();
        },
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            height: height ?? 180,
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
      height: 180,
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

  String _stripHtmlTags(String htmlText) {
    return htmlText
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}
