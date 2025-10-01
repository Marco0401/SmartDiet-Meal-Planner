import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'services/recipe_service.dart';
import 'services/filipino_recipe_service.dart';
import 'recipe_detail_page.dart';

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

  final List<Map<String, dynamic>> _categories = [
    {
      'name': 'Quick & Easy',
      'icon': Icons.flash_on,
      'description': 'Meals ready in 30 minutes or less',
      'queries': ['quick meals', 'easy recipes', '30 minute meals'],
    },
    {
      'name': 'Healthy Options',
      'icon': Icons.favorite,
      'description': 'Nutritious and balanced meals',
      'queries': ['healthy recipes', 'low calorie', 'nutritious meals'],
    },
    {
      'name': 'High Protein',
      'icon': Icons.fitness_center,
      'description': 'Perfect for muscle building and recovery',
      'queries': ['high protein', 'protein rich', 'muscle building meals'],
    },
    {
      'name': 'Low Carb',
      'icon': Icons.trending_down,
      'description': 'Great for weight management',
      'queries': ['low carb', 'keto friendly', 'low carbohydrate'],
    },
    {
      'name': 'Filipino Favorites',
      'icon': Icons.restaurant,
      'description': 'Traditional Filipino dishes',
      'queries': ['filipino', 'pinoy', 'traditional'],
    },
    {
      'name': 'Comfort Food',
      'icon': Icons.home,
      'description': 'Soul-warming comfort meals',
      'queries': ['comfort food', 'hearty meals', 'soul food'],
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

  Future<void> _loadSuggestions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final category = _categories.firstWhere(
        (cat) => cat['name'] == _selectedCategory,
        orElse: () => _categories.first,
      );

      List<Map<String, dynamic>> suggestions = [];

      // Load Filipino recipes for Filipino Favorites category
      if (_selectedCategory == 'Filipino Favorites') {
        final recipes = await FilipinoRecipeService.fetchFilipinoRecipes('adobo');
        suggestions = recipes.cast<Map<String, dynamic>>();
      } else {
        // Load from external API for other categories
        final queries = category['queries'] as List<String>;
        final query = queries.first;
        final recipes = await RecipeService.fetchRecipes(query);
        suggestions = recipes.take(6).toList().cast<Map<String, dynamic>>();
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
      appBar: AppBar(
        title: const Text('Meal Suggestions'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Category Selection
          Container(
            height: 120,
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final category = _categories[index];
                final isSelected = category['name'] == _selectedCategory;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category['name'];
                    });
                    _loadSuggestions();
                  },
                  child: Container(
                    width: 100,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.green : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? Colors.green : Colors.grey[300]!,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          category['icon'],
                          color: isSelected ? Colors.white : Colors.green,
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          category['name'],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.green[800],
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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _categories.firstWhere(
                (cat) => cat['name'] == _selectedCategory,
                orElse: () => _categories.first,
              )['description'],
              style: TextStyle(
                color: Colors.grey[600],
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
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Failed to load suggestions',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: _loadSuggestions,
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
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No suggestions found',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton(
                                  onPressed: _loadSuggestions,
                                  child: const Text('Try Again'),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecipeDetailPage(recipe: recipe),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: recipe['image'] != null && recipe['image'].toString().isNotEmpty
                  ? _buildRecipeImage(recipe['image'], height: 180)
                  : _buildPlaceholderImage(),
            ),

            // Recipe Info
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    recipe['title'] ?? 'Unknown Recipe',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  
                  // Recipe Stats
                  Row(
                    children: [
                      if (recipe['readyInMinutes'] != null) ...[
                        Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe['readyInMinutes']} min',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                        const SizedBox(width: 16),
                      ],
                      if (recipe['servings'] != null) ...[
                        Icon(Icons.people, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '${recipe['servings']} servings',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ],
                  ),
                  
                  if (recipe['summary'] != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _stripHtmlTags(recipe['summary']),
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
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
          return Container(
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
