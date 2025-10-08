import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'login_page.dart';
import 'account_settings_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/recipe_service.dart';
import 'services/filipino_recipe_service.dart';
import 'recipe_detail_page.dart';
import 'meal_planner_page.dart';
import 'nutrition_analytics_page.dart';
import 'meal_suggestions_page.dart';
import 'meal_favorites_page.dart';
import 'dashboard_page.dart';
import 'progress_tracking_page.dart';
import 'ai_meal_planner_page.dart';
import 'unified_meal_planner_page.dart';
import 'notifications_page.dart';
import 'widgets/notification_badge.dart';
import 'services/notification_service.dart';
import 'personalized_guidelines_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load();
  await Firebase.initializeApp();
  
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
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  // Search state
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _ingredientFilterController =
      TextEditingController();
  String _searchQuery = '';
  String _ingredientFilter = '';
  List<dynamic> _recipes = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRecipes('adobo'); // Default query for Filipino dishes
  }

  void _fetchRecipes(String query) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Use comprehensive recipe service for all sources (Spoonacular + TheMealDB + Filipino)
      final recipes = await RecipeService.fetchRecipes(query);
      setState(() {
        _recipes = recipes;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
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

  void _performSearch() {
    String query = _searchQuery.trim();
    if (query.isEmpty) {
      query = 'adobo'; // Default query for Filipino dishes
    }

    // Add ingredient filter to query if provided
    if (_ingredientFilter.trim().isNotEmpty) {
      query += ' ${_ingredientFilter.trim()}';
    }

    _fetchRecipes(query);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _ingredientFilterController.dispose();
    super.dispose();
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
            _drawerOption(1, "App Settings", Icons.settings),
            _drawerOption(2, "Get Meal Suggestions", Icons.lightbulb),
            _drawerOption(3, "Nutritional Guidelines", Icons.article),
            _drawerOption(4, "Data & Privacy", Icons.privacy_tip),
            _drawerOption(5, "About SmartDiet", Icons.info),
            _drawerOption(6, "Design Showcase", Icons.palette),
            const Divider(),
          ],
        ),
      ),
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
              // Search Bar with Filters
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    // Main Search Bar
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.green[50]!,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: Colors.white,
                            blurRadius: 0,
                            offset: const Offset(0, -1),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.green[200]!,
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search recipes...',
                          prefixIcon: Icon(Icons.search),
                          border: InputBorder.none,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                          _performSearch();
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Ingredient Filter
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            Colors.blue[50]!,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(25),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.blue.withOpacity(0.15),
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: Colors.white,
                            blurRadius: 0,
                            offset: const Offset(0, -1),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.blue[200]!,
                          width: 1.5,
                        ),
                      ),
                      child: TextField(
                        controller: _ingredientFilterController,
                        decoration: InputDecoration(
                          hintText: 'Filter by ingredient (optional)... ',
                          prefixIcon: const Icon(
                            Icons.filter_list,
                            color: Colors.green,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 0,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _ingredientFilter = value;
                          });
                          _performSearch();
                        },
                      ),
                    ),
                  ],
                ),
              ),
              // Main Content - Show different content based on search state
              if (_searchQuery.isEmpty) ...[
                // Wrap main content in SingleChildScrollView for scrolling
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Profile Header
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                          child: Card(
                            elevation: 12,
                            shadowColor: Colors.green.withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.white,
                                    Colors.green[50]!,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(
                                  color: Colors.green[200]!,
                                  width: 1,
                                ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 20,
                                horizontal: 16,
                              ),
                              child: FutureBuilder<Map<String, dynamic>?>(
                                future: _fetchUserProfile(),
                                builder: (context, snapshot) {
                                  if (snapshot.connectionState ==
                                      ConnectionState.waiting) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  final data = snapshot.data;
                                  final name = data?['fullName'] ?? 'User';
                                  final photoUrl = data?['photoUrl'];
                                  String initials = '';
                                  if (name is String && name.isNotEmpty) {
                                    final parts = name.trim().split(' ');
                                    initials = parts.length > 1
                                        ? (parts[0][0] + parts[1][0])
                                              .toUpperCase()
                                        : name[0].toUpperCase();
                                  }
                                  return Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 32,
                                        backgroundColor: Colors.green[100],
                                        backgroundImage:
                                            photoUrl != null && photoUrl != ''
                                            ? NetworkImage(photoUrl)
                                            : null,
                                        child:
                                            (photoUrl == null || photoUrl == '')
                                            ? Text(
                                                initials,
                                                style: const TextStyle(
                                                  fontSize: 24,
                                                  color: Color(0xFF388E3C),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 18),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Hello, $name!',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleLarge
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green[900],
                                                    fontSize: 22,
                                                  ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Welcome back to SmartDiet',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color: Colors.green[700],
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                              ),
                            ),
                          ),
                        ),
                        // Featured Recipe Card (first recipe) - only show when not searching
                        if (_recipes.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                              elevation: 3,
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
                        const SizedBox(
                          height: 100,
                        ), // Bottom padding for keyboard
                      ],
                    ),
                  ),
                ),
              ] else ...[
                // Search Results - overlay the main body when searching
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Search Results Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.search,
                                color: Colors.green,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Search Results for "$_searchQuery" (${_recipes.length})',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _searchController.clear();
                                    _ingredientFilter = '';
                                    _ingredientFilterController.clear();
                                  });
                                  _fetchRecipes('adobo'); // Reset to default
                                },
                                tooltip: 'Clear search',
                              ),
                            ],
                          ),
                        ),
                        // Search Results Content
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
                                        color: Colors.red[300],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _error!,
                                        style: TextStyle(
                                          color: Colors.red[700],
                                          fontSize: 16,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              : _recipes.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No recipes found for "$_searchQuery"',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Try different keywords or ingredients',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.all(8),
                                  itemCount: _recipes.length,
                                  itemBuilder: (context, index) {
                                    final recipe = _recipes[index];
                                    return Card(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 4,
                                        horizontal: 8,
                                      ),
                                      child: InkWell(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  RecipeDetailPage(
                                                    recipe: recipe,
                                                  ),
                                            ),
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(8),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Row(
                                            children: [
                                              // Recipe image
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                child:
                                                    recipe['image'] != null &&
                                                        recipe['image']
                                                            .toString()
                                                            .isNotEmpty
                                                    ? recipe['image'].toString().startsWith('assets/')
                                                        ? Image.asset(
                                                            recipe['image'],
                                                            width: 60,
                                                            height: 60,
                                                            fit: BoxFit.cover,
                                                            errorBuilder: (context, error, stackTrace) {
                                                              return Container(
                                                                width: 60,
                                                                height: 60,
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
                                                                child: const Icon(
                                                                  Icons.restaurant_menu,
                                                                  color: Colors.green,
                                                                ),
                                                              );
                                                            },
                                                          )
                                                        : Image.network(
                                                        recipe['image'],
                                                        width: 60,
                                                        height: 60,
                                                        fit: BoxFit.cover,
                                                        errorBuilder:
                                                            (
                                                              context,
                                                              error,
                                                              stackTrace,
                                                            ) {
                                                              return Container(
                                                                width: 60,
                                                                height: 60,
                                                                decoration: BoxDecoration(
                                                                  gradient: LinearGradient(
                                                                    colors: [
                                                                      Colors
                                                                          .green[50]!,
                                                                      Colors
                                                                          .green[100]!,
                                                                    ],
                                                                    begin: Alignment
                                                                        .topLeft,
                                                                    end: Alignment
                                                                        .bottomRight,
                                                                  ),
                                                                ),
                                                                child: const Icon(
                                                                  Icons
                                                                      .restaurant_menu,
                                                                  color: Colors
                                                                      .green,
                                                                ),
                                                              );
                                                            },
                                                        loadingBuilder:
                                                            (
                                                              context,
                                                              child,
                                                              loadingProgress,
                                                            ) {
                                                              if (loadingProgress ==
                                                                  null) {
                                                                return child;
                                                              }
                                                              return Container(
                                                                width: 60,
                                                                height: 60,
                                                                decoration: BoxDecoration(
                                                                  gradient: LinearGradient(
                                                                    colors: [
                                                                      Colors
                                                                          .green[50]!,
                                                                      Colors
                                                                          .green[100]!,
                                                                    ],
                                                                    begin: Alignment
                                                                        .topLeft,
                                                                    end: Alignment
                                                                        .bottomRight,
                                                                  ),
                                                                ),
                                                                child: const Center(
                                                                  child: SizedBox(
                                                                    width: 16,
                                                                    height: 16,
                                                                    child: CircularProgressIndicator(
                                                                      color: Colors
                                                                          .green,
                                                                      strokeWidth:
                                                                          2,
                                                                    ),
                                                                  ),
                                                                ),
                                                              );
                                                            },
                                                      )
                                                    : Container(
                                                        width: 60,
                                                        height: 60,
                                                        decoration: BoxDecoration(
                                                          gradient: LinearGradient(
                                                            colors: [
                                                              Colors.green[50]!,
                                                              Colors
                                                                  .green[100]!,
                                                            ],
                                                            begin: Alignment
                                                                .topLeft,
                                                            end: Alignment
                                                                .bottomRight,
                                                          ),
                                                        ),
                                                        child: const Icon(
                                                          Icons.restaurant_menu,
                                                          color: Colors.green,
                                                        ),
                                                      ),
                                              ),
                                              const SizedBox(width: 12),
                                              // Recipe title
                                              Expanded(
                                                child: Text(
                                                  recipe['title'] ?? '',
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 16,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const Icon(
                                                Icons.arrow_forward_ios,
                                                size: 16,
                                                color: Colors.grey,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                        ),
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
                  // Already on search page, do nothing
                  break;
                case 1:
          Navigator.push(
            context,
                    MaterialPageRoute(builder: (context) => const MealPlannerPage()),
                  );
                  break;
                case 2:
                  _showMyRecipesOptionsDialog();
                  break;
                case 3:
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProgressTrackingPage()),
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
                icon: Icon(Icons.search, size: 24),
                label: 'Search',
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
                icon: Icon(Icons.trending_up, size: 24),
                label: 'Progress',
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
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.45; // 45% of screen width
    final cardHeight = screenWidth * 0.55; // Responsive height based on width
    
    return Container(
      width: cardWidth,
      height: cardHeight,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RecipeDetailPage(recipe: recipe),
          ),
        );
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
              Container(
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
    final theme = Theme.of(context);

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
                  return _buildImagePlaceholder(theme);
                },
              )
            : Image.network(
                recipe['image'],
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildImagePlaceholder(theme);
                },
              ),
      );
    }
    return _buildImagePlaceholder(theme);
  }

  Widget _buildImagePlaceholder(ThemeData theme) {
                            return Container(
      width: double.infinity,
      height: double.infinity,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
            theme.colorScheme.surfaceVariant,
            theme.colorScheme.surfaceVariant.withOpacity(0.7),
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
            _showAppSettingsDialog();
          } else if (number == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MealSuggestionsPage()),
            );
          } else if (number == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PersonalizedGuidelinesPage()),
            );
          } else if (number == 6) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const Scaffold(
                body: Center(child: Text('Design Showcase coming soon!')),
              )),
            );
          } else {
            _showComingSoonDialog(text);
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
}
