import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_page.dart';
import 'account_settings_page.dart';
import 'shopping_list_generator_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/recipe_service.dart';
import 'services/google_signin_service.dart';
import 'recipe_detail_page.dart';
import 'recipe_search_page.dart';
import 'meal_planner_page.dart';
import 'meal_suggestions_page.dart';
import 'meal_favorites_page.dart';
import 'notifications_page.dart';
import 'widgets/notification_badge.dart';
import 'ingredient_scanner_page.dart';
import 'about_smartdiet_page.dart';
import 'community_recipes_page.dart';
import 'utils/initialize_substitution_nutrition.dart';
import 'utils/migrate_substitution_nutrition.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Firebase.initializeApp();
  
  // Initialize substitution nutrition data
  await InitializeSubstitutionNutrition.initialize();
  
  // Run migration to convert existing substitutions to new format
  // Uncomment the line below to run migration
  // await MigrateSubstitutionNutrition.migrateAllSubstitutions();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SmartDiet',
      theme: ThemeData(
        primarySwatch: Colors.green,
        useMaterial3: true,
      ),
      home: const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String title;
  const MyHomePage({super.key, required this.title});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _currentBottomNavIndex = 0;
  final GlobalKey<NotificationBadgeState> _notificationBadgeKey = GlobalKey<NotificationBadgeState>();
  Future<void> _logout() async {
    // Show confirmation dialog
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    // If user confirmed, proceed with logout
    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      await GoogleSignInService().signOut();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
        );
      }
    }
  }

  // Recipe state
  List<dynamic> _recipes = [];
  List<dynamic> _allRecipes = []; // Store all fetched recipes before filtering
  List<String> _excludeIngredients = []; // Ingredients to exclude
  bool _isLoading = false;
  String? _error;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _fetchRecipes('chicken'); // Default query for Filipino dishes
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _fetchRecipes(String query) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Use comprehensive recipe service for all sources (Spoonacular + TheMealDB + Filipino)
      final recipes = await RecipeService.fetchRecipes(query);
      
      // Shuffle recipes based on current date for daily randomization
      final shuffledRecipes = _shuffleRecipesForToday(recipes);
      
      // Store all recipes before filtering
      final filteredRecipes = _excludeIngredients.isEmpty 
          ? shuffledRecipes 
          : _filterRecipesByExcludedIngredients(shuffledRecipes);
      
      setState(() {
        _allRecipes = shuffledRecipes;
        _recipes = filteredRecipes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }
  
  // Filter recipes that contain excluded ingredients
  List<dynamic> _filterRecipesByExcludedIngredients(List<dynamic> recipes) {
    print('DEBUG: Filtering recipes. Excluding: $_excludeIngredients');
    return recipes.where((recipe) {
      final ingredients = _getRecipeIngredients(recipe);
      final ingredientList = ingredients.map((ing) => ing.toLowerCase()).toList();
      final recipeTitle = recipe['title'] ?? 'Unknown';
      
      print('DEBUG: Checking recipe: $recipeTitle');
      print('DEBUG: Recipe ingredients: $ingredientList');
      
      // Check if any excluded ingredient is in this recipe
      for (final excluded in _excludeIngredients) {
        final excludedLower = excluded.toLowerCase();
        print('DEBUG: Checking against excluded ingredient: $excludedLower');
        
        // Enhanced matching: check if excluded word is in any ingredient name
        if (ingredientList.any((ing) => ing.contains(excludedLower) || excludedLower.contains(ing))) {
          print('DEBUG: Recipe "$recipeTitle" EXCLUDED - contains $excluded');
          return false; // Exclude this recipe
        }
        
        // Special cases for common allergen terms
        if (excludedLower == 'dairy') {
          final dairyIngredient = ingredientList.firstWhere((ing) => _isDairyIngredient(ing), orElse: () => '');
          if (dairyIngredient.isNotEmpty) {
            print('DEBUG: Recipe "$recipeTitle" EXCLUDED - contains dairy (via "$dairyIngredient")');
            return false;
          }
        }
        if (excludedLower == 'eggs') {
          final eggIngredient = ingredientList.firstWhere((ing) => _isEggIngredient(ing), orElse: () => '');
          if (eggIngredient.isNotEmpty) {
            print('DEBUG: Recipe "$recipeTitle" EXCLUDED - contains eggs (via "$eggIngredient")');
            return false;
          }
        }
        if (excludedLower == 'gluten') {
          final glutenIngredient = ingredientList.firstWhere((ing) => _isGlutenIngredient(ing), orElse: () => '');
          if (glutenIngredient.isNotEmpty) {
            print('DEBUG: Recipe "$recipeTitle" EXCLUDED - contains gluten (via "$glutenIngredient")');
            return false;
          }
        }
        if (excludedLower == 'nuts') {
          final nutsIngredient = ingredientList.firstWhere((ing) => _isNutsIngredient(ing), orElse: () => '');
          if (nutsIngredient.isNotEmpty) {
            print('DEBUG: Recipe "$recipeTitle" EXCLUDED - contains nuts (via "$nutsIngredient")');
            return false;
          }
        }
      }
      
      print('DEBUG: Recipe "$recipeTitle" INCLUDED');
      return true; // Include this recipe
    }).toList();
  }
  
  bool _isDairyIngredient(String ingredient) {
    final dairyKeywords = ['milk', 'cheese', 'butter', 'cream', 'yogurt', 'sour cream', 'whey', 'casein'];
    return dairyKeywords.any((keyword) => ingredient.contains(keyword));
  }
  
  bool _isEggIngredient(String ingredient) {
    final eggKeywords = ['egg', 'mayo'];
    return eggKeywords.any((keyword) => ingredient.contains(keyword));
  }
  
  bool _isGlutenIngredient(String ingredient) {
    final glutenKeywords = ['flour', 'wheat', 'bread', 'pasta', 'noodle', 'soy sauce'];
    return glutenKeywords.any((keyword) => ingredient.contains(keyword));
  }
  
  bool _isNutsIngredient(String ingredient) {
    final nutsKeywords = ['almond', 'walnut', 'cashew', 'pistachio', 'pecan', 'hazelnut', 'peanut', 'peanuts', 'macadamia', 'brazil nut', 'pine nut', 'chestnut'];
    return nutsKeywords.any((keyword) => ingredient.contains(keyword));
  }
  
  // Extract ingredients from recipe in various formats
  List<String> _getRecipeIngredients(Map<String, dynamic> recipe) {
    final ingredients = <String>[];
    
    // Check extendedIngredients (Spoonacular format)
    if (recipe['extendedIngredients'] is List) {
      for (var ing in recipe['extendedIngredients'] as List) {
        if (ing is Map) {
          if (ing['original'] != null) {
            ingredients.add(ing['original'].toString());
          } else if (ing['name'] != null) {
            ingredients.add(ing['name'].toString());
          }
        } else if (ing is String) {
          ingredients.add(ing);
        }
      }
    }
    
    // Check ingredients field
    if (recipe['ingredients'] is List) {
      for (var ing in recipe['ingredients'] as List) {
        if (ing is Map) {
          if (ing['name'] != null) {
            ingredients.add(ing['name'].toString());
          } else if (ing['original'] != null) {
            ingredients.add(ing['original'].toString());
          }
        } else if (ing is String) {
          ingredients.add(ing);
        }
      }
    }
    
    return ingredients;
  }
  
  // Add or remove excluded ingredient
  void _toggleExcludeIngredient(String ingredient) {
    setState(() {
      if (_excludeIngredients.contains(ingredient)) {
        _excludeIngredients.remove(ingredient);
        print('DEBUG: Removed "$ingredient" from exclusion list');
      } else {
        _excludeIngredients.add(ingredient);
        print('DEBUG: Added "$ingredient" to exclusion list. Total exclusions: $_excludeIngredients');
      }
      // Re-filter recipes
      _recipes = _excludeIngredients.isEmpty 
          ? _allRecipes 
          : _filterRecipesByExcludedIngredients(_allRecipes);
      print('DEBUG: Recipes filtered. Showing ${_recipes.length} recipes (from ${_allRecipes.length} total)');
    });
  }

  // Shuffle recipes based on current date for consistent daily randomization
  List<dynamic> _shuffleRecipesForToday(List<dynamic> recipes) {
    if (recipes.isEmpty) return recipes;
    
    // Use current date as seed for consistent randomization per day
    final today = DateTime.now();
    final seed = today.year * 10000 + today.month * 100 + today.day;
    
    // Create a copy of the list to avoid modifying the original
    final shuffled = List<dynamic>.from(recipes);
    
    // Simple shuffle algorithm using the date seed
    for (int i = shuffled.length - 1; i > 0; i--) {
      final j = (seed + i) % (i + 1);
      final temp = shuffled[i];
      shuffled[i] = shuffled[j];
      shuffled[j] = temp;
    }
    
    return shuffled;
  }

  Future<Map<String, dynamic>?> _fetchUserProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    return doc.data();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
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
          widget.title,
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
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.search,
                    color: Colors.white,
                  ),
                  tooltip: 'Search Recipes',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RecipeSearchPage(),
                      ),
                    );
                  },
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: NotificationBadge(
                  key: _notificationBadgeKey,
                  child: IconButton(
                    icon: const Icon(
                      Icons.notifications,
                      color: Colors.white,
                    ),
                    tooltip: 'Notifications',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotificationsPage(
                            onNotificationRead: () {
                              _notificationBadgeKey.currentState?.refreshCount();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.logout,
                    color: Colors.white,
                  ),
            tooltip: 'Logout',
            onPressed: _logout,
                ),
          ),
        ],
          ),
        ),
      ),
      drawer: Drawer(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(25),
            bottomRight: Radius.circular(25),
          ),
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
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
                  topRight: Radius.circular(25),
              ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                    Icons.restaurant_menu,
                        size: 24,
                    color: Colors.white,
                      ),
                  ),
                  const SizedBox(height: 8),
                    const Text(
                      'SmartDiet',
                      style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                        fontSize: 18,
                        shadows: [
                          Shadow(
                            offset: Offset(0, 2),
                            blurRadius: 4,
                            color: Colors.black26,
                  ),
                ],
              ),
            ),
                    const SizedBox(height: 2),
                    Text(
                      'Nutrition Assistant',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            _drawerOption(1, "Get Meal Suggestions", Icons.lightbulb),
            _drawerOption(2, "Shopping List", Icons.shopping_cart),
            _drawerOption(3, "App Settings", Icons.settings),
            _drawerOption(4, "About SmartDiet", Icons.info),
            const Divider(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const IngredientScannerPage()),
          );
        },
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 6,
        child: const Icon(Icons.qr_code_scanner, size: 28, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF8FFF4), Color(0xFFE8F5E9)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Main Content - Show home page
              ...[
                // Wrap main content in SingleChildScrollView for scrolling
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Profile Header with Quick Actions
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                          child: FutureBuilder<Map<String, dynamic>?>(
                            future: _fetchUserProfile(),
                            builder: (context, snapshot) {
                              final data = snapshot.data;
                              final name = data?['fullName'] ?? 'User';
                              final photoUrl = data?['profilePhoto'] ?? data?['photoUrl'];
                              String initials = '';
                              if (name is String && name.isNotEmpty) {
                                final parts = name.trim().split(' ');
                                initials = parts.length > 1
                                    ? (parts[0][0] + parts[1][0]).toUpperCase()
                                    : name[0].toUpperCase();
                              }
                              
                              // Handle base64 or URL images
                              ImageProvider? profileImage;
                              if (photoUrl != null && photoUrl.isNotEmpty) {
                                if (photoUrl.startsWith('data:image')) {
                                  // Base64 image
                                  try {
                                    profileImage = MemoryImage(base64Decode(photoUrl.split(',')[1]));
                                  } catch (e) {
                                    print('Error decoding base64 image: $e');
                                  }
                                } else {
                                  // URL image
                                  profileImage = NetworkImage(photoUrl);
                                }
                              }
                              
                              return Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.green.withOpacity(0.3),
                                      blurRadius: 20,
                                      offset: const Offset(0, 10),
                                      ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 3),
                                      ),
                                      child: CircleAvatar(
                                        radius: 32,
                                        backgroundColor: Colors.white,
                                        backgroundImage: profileImage,
                                        child: profileImage == null
                                            ? Text(
                                                initials,
                                                style: const TextStyle(
                                                  fontSize: 24,
                                                  color: Color(0xFF2E7D32),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              )
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Welcome back,',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              height: 1.2,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                        Icons.local_fire_department,
                                        color: Colors.orangeAccent,
                                        size: 32,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                        
                        // Featured Recipes Section
                        if (_recipes.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.orange[400]!, Colors.orange[600]!],
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.restaurant_menu,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Featured Recipe',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RecipeDetailPage(
                                      recipe: _recipes[0],
                                    ),
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(18),
                              child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.white, Colors.green[50]!],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.2),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(18),
                                    ),
                                    child:
                                        _recipes[0]['image'] != null &&
                                            _recipes[0]['image']
                                                .toString()
                                                .isNotEmpty
                                        ? _recipes[0]['image'].toString().startsWith('assets/')
                                            ? Image.asset(
                                                _recipes[0]['image'],
                                                height: 160,
                                                width: double.infinity,
                                                fit: BoxFit.cover,
                                                errorBuilder: (context, error, stackTrace) {
                                                  return Container(
                                                    height: 160,
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          Colors.green[50]!,
                                                          Colors.green[100]!,
                                                        ],
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
                                                },
                                              )
                                            : Image.network(
                                            _recipes[0]['image'],
                                            height: 160,
                                            width: double.infinity,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return Container(
                                                    height: 160,
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          Colors.green[50]!,
                                                          Colors.green[100]!,
                                                        ],
                                                        begin:
                                                            Alignment.topLeft,
                                                        end: Alignment
                                                            .bottomRight,
                                                      ),
                                                    ),
                                                    child: const Center(
                                                      child: Column(
                                                        mainAxisAlignment:
                                                            MainAxisAlignment
                                                                .center,
                                                        children: [
                                                          Icon(
                                                            Icons
                                                                .restaurant_menu,
                                                            size: 48,
                                                            color: Colors.green,
                                                          ),
                                                          SizedBox(height: 8),
                                                          Text(
                                                            'Recipe Image',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.green,
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  );
                                                },
                                            loadingBuilder:
                                                (
                                                  context,
                                                  child,
                                                  loadingProgress,
                                                ) {
                                                  if (loadingProgress == null) {
                                                    return child;
                                                  }
                                                  return Container(
                                                    height: 160,
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: [
                                                          Colors.green[50]!,
                                                          Colors.green[100]!,
                                                        ],
                                                        begin:
                                                            Alignment.topLeft,
                                                        end: Alignment
                                                            .bottomRight,
                                                      ),
                                                    ),
                                                    child: const Center(
                                                      child:
                                                          CircularProgressIndicator(
                                                            color: Colors.green,
                                                          ),
                                                    ),
                                                  );
                                                },
                                          )
                                        : Container(
                                            height: 160,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.green[50]!,
                                                  Colors.green[100]!,
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                            ),
                                            child: const Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
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
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.all(18.0),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            "Featured Recipe: ${_recipes[0]['title']}",
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(
                                            Icons.favorite_border,
                                            color: Colors.green,
                                          ),
                                          onPressed: () {},
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        // Recipes List Section - only show when not searching
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Recipes",
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: MediaQuery.of(context).size.width * 0.55 + 20, // Responsive height based on card height + margin
                                child: _isLoading
                                    ? const Center(
                                        child: CircularProgressIndicator(),
                                      )
                                    : _error != null
                                    ? Center(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(
                                            color: Colors.red,
                                          ),
                                        ),
                                      )
                                    : _recipes.isEmpty
                                    ? const Center(
                                        child: Text('No recipes found.'),
                                      )
                                    : ListView.builder(
                                        scrollDirection: Axis.horizontal,
                                        itemCount: _recipes.length,
                                        itemBuilder: (context, index) {
                                          final recipe = _recipes[index];
                                          return _recipeCard(recipe);
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Educational Content Section
                        _buildEducationalContentSection(),
                        const SizedBox(
                          height: 100,
                        ), // Bottom padding for keyboard
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white,
              Colors.green[50]!,
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.green.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            currentIndex: _currentBottomNavIndex,
            backgroundColor: Colors.transparent,
            elevation: 0,
            onTap: (index) {
              setState(() {
                _currentBottomNavIndex = index;
              });
              
              // Navigate to different pages based on selected tab
              switch (index) {
                case 0:
                  // Reset to home page - reload default recipes
                  setState(() {
                    _isLoading = false;
                    _error = null;
                  });
                  _fetchRecipes('chicken'); // Reload default recipes
                  break;
                case 1:
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MealPlannerPage()),
                  );
                  break;
                case 2:
                  // Navigate directly to Favorite Meals page
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const MealFavoritesPage()),
                  );
                  break;
                case 3:
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CommunityRecipesPage()),
                  );
                  break;
                case 4:
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const AccountSettingsPage()),
                  );
                  break;
              }
            },
            selectedItemColor: const Color(0xFF2E7D32),
            unselectedItemColor: Colors.grey[600],
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home, size: 24),
                label: 'Home',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.calendar_today, size: 24),
                label: 'Plan',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.restaurant, size: 24),
                label: 'My Recipes',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.people, size: 24),
                label: 'Community',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.account_circle, size: 24),
                label: 'Account',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recipeCard(dynamic recipe) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.45; // 45% of screen width
    final cardHeight = screenWidth * 0.55; // Responsive height based on width
    
    return Container(
      width: cardWidth,
      height: cardHeight,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeDetailPage(recipe: recipe),
          ),
        );
        
        // If a meal was added, navigate to meal planner
        if (result == true) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const MealPlannerPage(),
            ),
          );
        }
      },
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image container with responsive height
              SizedBox(
                height: cardHeight * 0.6, // 60% of card height
                width: double.infinity,
                child: _buildRecipeImage(recipe),
              ),
              // Content container with flexible height
              Expanded(
          child: Padding(
                  padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                      Text(
                        recipe['title'] ?? 'Unknown Recipe',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: screenWidth * 0.035, // Responsive font size
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (recipe['nutrition'] != null && recipe['nutrition']['calories'] != null)
                        Row(
                          children: [
                            const Icon(
                              Icons.local_fire_department,
                              size: 14,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                '${recipe['nutrition']['calories']} cal',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
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

  Widget _buildRecipeImage(dynamic recipe) {

    if (recipe['image'] != null && recipe['image'].toString().isNotEmpty) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(12),
        ),
        child: recipe['image'].toString().startsWith('assets/')
            ? Image.asset(
                          recipe['image'],
                width: double.infinity,
                height: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                  return _buildImagePlaceholder(Theme.of(context));
                },
              )
            : Image.network(
                recipe['image'],
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                cacheWidth: 400, // Limit cache size to reduce memory usage
                cacheHeight: 300,
                errorBuilder: (context, error, stackTrace) {
                  return _buildImagePlaceholder(Theme.of(context));
                },
              ),
      );
    }
    return _buildImagePlaceholder(Theme.of(context));
  }

  Widget _buildImagePlaceholder(ThemeData theme) {
                            return Container(
      width: double.infinity,
      height: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
            theme.colorScheme.surfaceContainerHighest,
            theme.colorScheme.surfaceContainerHighest.withOpacity(0.7),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(12),
                              ),
      ),
      child: Center(
                                child: Icon(
                                  Icons.restaurant_menu,
          size: 32,
          color: theme.colorScheme.primary,
                                ),
                              ),
                            );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _drawerOption(int number, String text, IconData icon) {
                            return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.grey[50],
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.green[100]!,
                Colors.green[200]!,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: Colors.green[700],
            size: 20,
          ),
        ),
        title: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          color: Colors.grey[400],
          size: 16,
        ),
        onTap: () {
          Navigator.pop(context);
          if (number == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MealSuggestionsPage()),
            );
          } else if (number == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ShoppingListGeneratorPage()),
            );
          } else if (number == 3) {
            _showAppSettingsDialog();
          } else if (number == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AboutSmartDietPage()),
            );
          }
        },
      ),
    );
  }
  
  void _showAppSettingsDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const Scaffold(
        body: Center(child: Text('App Settings coming soon!')),
      )),
    );
  }



  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(feature),
          content: Text('$feature will be available in a future update!'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }



  void _showMyRecipesOptionsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'My Recipes & Plans',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'What would you like to view?',
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              // Saved Recipes Option
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                  color: Colors.orange[50],
                  border: Border.all(color: Colors.orange[200]!),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const MealFavoritesPage()),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                          child: Icon(
                            Icons.restaurant_menu,
                            color: Colors.orange[600],
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Saved Recipes',
                                style: TextStyle(
                      fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'View your favorite recipes',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.grey[400],
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEducationalContentSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school, color: Colors.blue[600], size: 24),
              const SizedBox(width: 8),
              Text(
                "Educational Content",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  // TODO: Navigate to all content page
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('View all content coming soon!')),
                  );
                },
                child: Text(
                  'View All',
                  style: TextStyle(color: Colors.blue[600]),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 240, // Further increased height to prevent overflow
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('educational_content')
                  .orderBy('createdAt', descending: true)
                  .limit(10)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[300], size: 48),
                        const SizedBox(height: 8),
                        Text(
                          'Error loading content',
                          style: TextStyle(color: Colors.red[600]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${snapshot.error}',
                          style: TextStyle(color: Colors.red[400], fontSize: 12),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                
                final allContent = snapshot.data?.docs ?? [];
                final content = allContent.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return data['isPublished'] == true;
                }).toList();
                
                if (content.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.article_outlined, color: Colors.grey[400], size: 48),
                        const SizedBox(height: 8),
                        Text(
                          'No educational content yet',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Nutritionists are working on it!',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12),
                        ),
                      ],
                    ),
                  );
                }
                
                return LayoutBuilder(
                  builder: (context, constraints) {
                    // Calculate responsive card width based on screen size
                    final screenWidth = constraints.maxWidth;
                    final cardWidth = screenWidth > 600 
                        ? (screenWidth - 60) / 2.5  // Tablet: 2.5 cards visible
                        : screenWidth * 0.75;       // Mobile: 0.75 screen width
                    
                    return ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: content.length,
                      itemBuilder: (context, index) {
                        final doc = content[index];
                        final data = doc.data() as Map<String, dynamic>;
                        return Container(
                          width: cardWidth,
                          margin: const EdgeInsets.only(right: 16),
                          child: _buildContentCard(data, doc.id),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentCard(Map<String, dynamic> content, String contentId) {
    final type = content['type'] ?? 'tips';
    final title = content['title'] ?? 'Untitled';
    final description = content['description'] ?? '';
    final category = content['category'] ?? '';
    final author = content['author'] ?? 'Nutritionist';
    final createdAt = content['createdAt'] as Timestamp?;
    final contentSource = content['contentSource'] ?? 'text';
    
    // Get content type specific styling
    final typeInfo = _getContentTypeInfo(type);
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          _incrementContentView(contentId);
          _openContentDetail(content, contentId);
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              // Header with type icon and category
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: typeInfo['color'].withOpacity(0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: typeInfo['color'],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        typeInfo['icon'],
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            typeInfo['name'],
                            style: TextStyle(
                              color: typeInfo['color'],
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          if (category.isNotEmpty)
                            Text(
                              category,
                              style: TextStyle(
                                color: typeInfo['color'].withOpacity(0.7),
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15, // Slightly smaller font
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6), // Reduced spacing
                      Expanded(
                        child: Text(
                          description,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13, // Slightly smaller font
                          ),
                          maxLines: 2, // Reduced from 3 to 2
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 6), // Reduced spacing
                      
                      // Footer with author and date
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 14,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              author,
                              style: TextStyle(
                                color: Colors.grey[500],
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (createdAt != null)
                            Text(
                              _formatDate(createdAt.toDate()),
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 10,
                              ),
                            ),
                        ],
                      ),
                      
                      // Content source indicator
                      if (contentSource == 'url')
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.link,
                                size: 12,
                                color: Colors.blue[600],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'External Link',
                                style: TextStyle(
                                  color: Colors.blue[600],
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  Map<String, dynamic> _getContentTypeInfo(String type) {
    switch (type) {
      case 'tips':
        return {
          'name': 'Tip',
          'icon': Icons.lightbulb,
          'color': Colors.orange,
        };
      case 'articles':
        return {
          'name': 'Article',
          'icon': Icons.article,
          'color': Colors.blue,
        };
      case 'videos':
        return {
          'name': 'Video',
          'icon': Icons.video_library,
          'color': Colors.purple,
        };
      case 'recipes':
        return {
          'name': 'Recipe',
          'icon': Icons.restaurant,
          'color': Colors.green,
        };
      default:
        return {
          'name': 'Content',
          'icon': Icons.info,
          'color': Colors.grey,
        };
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 7) {
      return '${date.day}/${date.month}/${date.year}';
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return 'Just now';
    }
  }

  void _openContentDetail(Map<String, dynamic> content, String contentId) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with gradient background
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _getContentTypeInfo(content['type'] ?? 'tips')['color'],
                      _getContentTypeInfo(content['type'] ?? 'tips')['color'].withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getContentTypeInfo(content['type'] ?? 'tips')['icon'],
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            content['title'] ?? 'Untitled',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (content['category'] != null)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                content['category'],
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Content body
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Author and metadata
                      if (content['author'] != null) ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.person,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'By ${content['author']}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Main content
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Text(
                          content['description'] ?? '',
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Article content (if available)
                      if (content['type'] == 'articles' && content['content'] != null && content['content'].toString().isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.article, color: Colors.blue[600], size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Article Content',
                                    style: TextStyle(
                                      color: Colors.blue[600],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                content['content'],
                                style: const TextStyle(
                                  fontSize: 15,
                                  height: 1.6,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Video content (if available)
                      if (content['type'] == 'videos' && (content['videoFileName'] != null || content['youtubeVideoId'] != null || content['youtubeUrl'] != null)) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.1),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.play_circle_filled, color: Colors.purple[600], size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Video Content',
                                    style: TextStyle(
                                      color: Colors.purple[600],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildVideoPlayer(content),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Recipe content (if available)
                      if (content['type'] == 'recipes') ...[
                        _buildRecipeContent(content),
                        const SizedBox(height: 16),
                      ],
                      
                      // External link for articles or URL-based content
                      if (content['url'] != null && content['url'].toString().isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue[50]!,
                                Colors.blue[100]!,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.link, color: Colors.blue[600], size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'External Link',
                                    style: TextStyle(
                                      color: Colors.blue[600],
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                content['url'],
                                style: TextStyle(
                                  color: Colors.blue[700],
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      
                      // Additional content for non-articles
                      if (content['type'] != 'articles' && content['content'] != null && content['content'].toString().isNotEmpty) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Text(
                            content['content'],
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              
              // Action buttons
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    if (content['contentSource'] == 'url' && content['url'] != null)
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openExternalUrl(context, content['url']),
                          icon: const Icon(Icons.open_in_new),
                          label: const Text('Open Link'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    if (content['contentSource'] == 'url' && content['url'] != null)
                      const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _toggleContentLike(contentId),
                        icon: Icon(
                          Icons.favorite,
                          color: Colors.red[400],
                        ),
                        label: const Text('Like'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[50],
                          foregroundColor: Colors.red[600],
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
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

  Future<void> _incrementContentView(String contentId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('educational_content')
          .doc(contentId)
          .get();

      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      final viewedBy = List<String>.from(data['viewedBy'] ?? []);
      
      // Only increment if user hasn't viewed this content before
      if (!viewedBy.contains(user.uid)) {
        await FirebaseFirestore.instance
            .collection('educational_content')
            .doc(contentId)
            .update({
          'views': FieldValue.increment(1),
          'viewedBy': FieldValue.arrayUnion([user.uid]),
          'lastViewed': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Error incrementing view count: $e');
    }
  }

  Future<void> _toggleContentLike(String contentId) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('educational_content')
          .doc(contentId)
          .get();

      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      final likedBy = List<String>.from(data['likedBy'] ?? []);
      final isLiked = likedBy.contains(user.uid);

      if (isLiked) {
        // Unlike
        await FirebaseFirestore.instance
            .collection('educational_content')
            .doc(contentId)
            .update({
          'likes': FieldValue.increment(-1),
          'likedBy': FieldValue.arrayRemove([user.uid]),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Removed from favorites')),
        );
      } else {
        // Like
        await FirebaseFirestore.instance
            .collection('educational_content')
            .doc(contentId)
            .update({
          'likes': FieldValue.increment(1),
          'likedBy': FieldValue.arrayUnion([user.uid]),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to favorites!')),
        );
      }
    } catch (e) {
      print('Error toggling like: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Widget _buildVideoPlayer(Map<String, dynamic> content) {
    return VideoPlayerWidget(
      youtubeUrl: content['youtubeUrl'],
      youtubeVideoId: content['youtubeVideoId'],
      videoFileName: content['videoFileName'],
      videoFileSize: content['videoFileSize'],
      isWebFile: content['isWebFile'],
    );
  }

  Widget _buildRecipeContent(Map<String, dynamic> content) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recipe header
          Row(
            children: [
              Icon(Icons.restaurant, color: Colors.orange[600], size: 20),
              const SizedBox(width: 8),
              Text(
                'Recipe Details',
                style: TextStyle(
                  color: Colors.orange[600],
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Recipe description
          if (content['recipeDescription'] != null && content['recipeDescription'].toString().isNotEmpty) ...[
            _buildRecipeSection('Description', content['recipeDescription'], Icons.description),
            const SizedBox(height: 12),
          ],
          
          // Recipe info row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (content['servings'] != null)
                _buildRecipeInfoChip('Servings', '${content['servings']}', Icons.people),
              if (content['prepTime'] != null)
                _buildRecipeInfoChip('Prep', content['prepTime'], Icons.schedule),
              if (content['cookTime'] != null)
                _buildRecipeInfoChip('Cook', content['cookTime'], Icons.timer),
            ],
          ),
          const SizedBox(height: 16),
          
          // Ingredients
          if (content['ingredients'] != null && content['ingredients'].toString().isNotEmpty) ...[
            _buildRecipeSection('Ingredients', content['ingredients'], Icons.list_alt),
            const SizedBox(height: 12),
          ],
          
          // Instructions
          if (content['instructions'] != null && content['instructions'].toString().isNotEmpty) ...[
            _buildRecipeSection('Instructions', content['instructions'], Icons.format_list_numbered),
            const SizedBox(height: 12),
          ],
          
          // Nutrition info
          if (content['nutritionInfo'] != null && content['nutritionInfo'].toString().isNotEmpty) ...[
            _buildRecipeSection('Nutrition Info', content['nutritionInfo'], Icons.local_fire_department),
          ],
        ],
      ),
    );
  }

  Widget _buildRecipeSection(String title, String content, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.orange[600], size: 16),
            const SizedBox(width: 6),
            Text(
              title,
              style: TextStyle(
                color: Colors.orange[600],
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          content,
          style: TextStyle(
            color: Colors.grey[700],
            fontSize: 13,
            height: 1.4,
          ),
          softWrap: true,
          overflow: TextOverflow.visible,
        ),
      ],
    );
  }

  Widget _buildRecipeInfoChip(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.orange[600], size: 14),
          const SizedBox(width: 4),
          Text(
            '$label: $value',
            style: TextStyle(
              color: Colors.orange[700],
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openExternalUrl(BuildContext context, String? url) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No URL available')),
      );
      return;
    }

    try {
      // Try different launch modes
      bool launched = false;
      
      // First try: External application mode
      try {
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalApplication,
          );
          launched = true;
        }
      } catch (e) {
        print('External application launch failed: $e');
      }
      
      // Second try: Platform default mode
      if (!launched) {
        try {
          await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.platformDefault,
          );
          launched = true;
        } catch (e) {
          print('Platform default launch failed: $e');
        }
      }
      
      // Third try: External non-browser mode
      if (!launched) {
        try {
          await launchUrl(
            Uri.parse(url),
            mode: LaunchMode.externalNonBrowserApplication,
          );
          launched = true;
        } catch (e) {
          print('External non-browser launch failed: $e');
        }
      }
      
      // If all methods fail, show URL in dialog
      if (!launched) {
        _showUrlDialog(context, url);
      }
      
    } catch (e) {
      print('All launch methods failed: $e');
      _showUrlDialog(context, url);
    }
  }

  void _showUrlDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open Link'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Copy this URL and open it in your browser:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                url,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Or try opening the link manually in your browser.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class VideoPlayerWidget extends StatefulWidget {
  final String? youtubeUrl;
  final String? youtubeVideoId;
  final String? videoFileName;
  final int? videoFileSize;
  final bool? isWebFile;

  const VideoPlayerWidget({
    super.key,
    this.youtubeUrl,
    this.youtubeVideoId,
    this.videoFileName,
    this.videoFileSize,
    this.isWebFile,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // If we have YouTube video ID or URL, show embedded player
    if ((widget.youtubeVideoId != null && widget.youtubeVideoId!.isNotEmpty) || 
        (widget.youtubeUrl != null && widget.youtubeUrl!.isNotEmpty)) {
      return _buildYouTubeEmbeddedPlayer(context);
    }
    
    // Fallback to old video display
    return _buildFallbackPlayer(context);
  }

  Widget _buildYouTubeEmbeddedPlayer(BuildContext context) {
    // Check if we have a valid video ID
    String videoId = widget.youtubeVideoId ?? '';
    if (videoId.isEmpty && widget.youtubeUrl != null) {
      RegExp regExp = RegExp(
        r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
        caseSensitive: false,
      );
      Match? match = regExp.firstMatch(widget.youtubeUrl!);
      videoId = match?.group(1) ?? '';
    }

    // For now, let's use a simpler approach with YouTube thumbnail
    return _buildYouTubeThumbnailPlayer(context, videoId);
  }

  Widget _buildYouTubeThumbnailPlayer(BuildContext context, String videoId) {
    String thumbnailUrl = 'https://img.youtube.com/vi/$videoId/maxresdefault.jpg';
    
    return Container(
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Stack(
          children: [
            // YouTube thumbnail
            Image.network(
              thumbnailUrl,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: Colors.red[50],
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.play_circle_filled,
                          size: 64,
                          color: Colors.red[600],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'YouTube Video',
                          style: TextStyle(
                            color: Colors.red[600],
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            
            // Play button overlay
            Center(
              child: GestureDetector(
                onTap: () => _openYouTubeVideo(context),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
            
            // YouTube branding overlay
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.play_circle_filled,
                      color: Colors.red[400],
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'YouTube',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> _openYouTubeVideo(BuildContext context) async {
    String videoUrl = widget.youtubeUrl ?? '';
    if (videoUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No video URL available')),
      );
      return;
    }

    try {
      // Try different launch modes
      bool launched = false;
      
      // First try: External application mode
      try {
        if (await canLaunchUrl(Uri.parse(videoUrl))) {
          await launchUrl(
            Uri.parse(videoUrl),
            mode: LaunchMode.externalApplication,
          );
          launched = true;
        }
      } catch (e) {
        print('External application launch failed: $e');
      }
      
      // Second try: Platform default mode
      if (!launched) {
        try {
          await launchUrl(
            Uri.parse(videoUrl),
            mode: LaunchMode.platformDefault,
          );
          launched = true;
        } catch (e) {
          print('Platform default launch failed: $e');
        }
      }
      
      // Third try: External non-browser mode
      if (!launched) {
        try {
          await launchUrl(
            Uri.parse(videoUrl),
            mode: LaunchMode.externalNonBrowserApplication,
          );
          launched = true;
        } catch (e) {
          print('External non-browser launch failed: $e');
        }
      }
      
      // If all methods fail, show URL in dialog
      if (!launched) {
        _showVideoUrlDialog(context, videoUrl);
      }
      
    } catch (e) {
      print('All launch methods failed: $e');
      _showVideoUrlDialog(context, videoUrl);
    }
  }

  void _showVideoUrlDialog(BuildContext context, String videoUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open Video'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Copy this URL and open it in your browser:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: SelectableText(
                videoUrl,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Or try opening YouTube app manually and search for the video.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackPlayer(BuildContext context) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.purple[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.purple[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple[100],
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.play_circle_filled,
              size: 48,
              color: Colors.purple[600],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Watch Video',
            style: TextStyle(
              color: Colors.purple[600],
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            widget.videoFileName ?? 'Video Content',
            style: TextStyle(
              color: Colors.purple[500],
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _playVideo(context),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Play Video'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple[600],
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _playVideo(BuildContext context) async {
    // Get the video URL based on filename
    String videoUrl;
    
    switch (widget.videoFileName) {
      case 'nutrition_basics.mp4':
        videoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
        break;
      case 'exercise_tips.mov':
        videoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4';
        break;
      case 'meal_prep_tutorial.avi':
        videoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4';
        break;
      default:
        videoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
    }

    try {
      // Try to launch the video in the default video player
      if (await canLaunchUrl(Uri.parse(videoUrl))) {
        await launchUrl(
          Uri.parse(videoUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        // Fallback: show video info dialog
        _showVideoInfoDialog(context, videoUrl);
      }
    } catch (e) {
      // Fallback: show video info dialog
      _showVideoInfoDialog(context, videoUrl);
    }
  }

  void _showVideoInfoDialog(BuildContext context, String videoUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Video Information'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.videoFileName != null) Text('File: ${widget.videoFileName}'),
            if (widget.videoFileSize != null) Text('Size: ${widget.videoFileSize! ~/ (1024 * 1024)} MB'),
            const SizedBox(height: 16),
            const Text('Video URL:'),
            SelectableText(
              videoUrl,
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 16),
            const Text('You can copy this URL and open it in your browser to watch the video.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

