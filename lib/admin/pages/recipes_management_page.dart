import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/recipe_service.dart';
import '../../services/filipino_recipe_service.dart';
import '../widgets/enhanced_recipe_dialog.dart';
import 'bulk_recipe_operations_page.dart';
import 'recipe_rollback_page.dart';

class RecipesManagementPage extends StatefulWidget {
  const RecipesManagementPage({super.key});

  @override
  State<RecipesManagementPage> createState() => _RecipesManagementPageState();
}

class _RecipesManagementPageState extends State<RecipesManagementPage> with TickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) {
        setState(() {
          _searchQuery = ''; // Reset search when switching tabs
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<List<dynamic>> _fetchAdminRecipesWithIds(String query) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('admin_recipes')
          .get();
      
      final allRecipes = snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
        'source': 'Admin Created',
      }).toList();
      
      // Filter recipes based on search query
      final filteredRecipes = allRecipes.where((recipe) {
        final title = (recipe['title'] ?? '').toString().toLowerCase();
        final description = (recipe['description'] ?? '').toString().toLowerCase();
        final ingredients = (recipe['ingredients'] as List<dynamic>? ?? [])
            .map((ing) => ing.toString().toLowerCase())
            .join(' ');
        final cuisine = (recipe['cuisine'] ?? '').toString().toLowerCase();
        
        final searchTerms = query.toLowerCase().split(' ');
        
        return searchTerms.any((term) =>
            title.contains(term) ||
            description.contains(term) ||
            ingredients.contains(term) ||
            cuisine.contains(term));
      }).toList();
      
      print('Admin Recipes: Successfully fetched ${filteredRecipes.length} recipes');
      return filteredRecipes;
    } catch (e) {
      print('Error fetching admin recipes: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Recipes'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'API Recipes', icon: Icon(Icons.public)),
            Tab(text: 'Filipino Recipes', icon: Icon(Icons.restaurant)),
            Tab(text: 'General Recipes', icon: Icon(Icons.folder)),
            Tab(text: 'Bulk Operations', icon: Icon(Icons.group_work)),
            Tab(text: 'Recipe Rollback', icon: Icon(Icons.undo)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildApiRecipesTab(),
          _buildFilipinoRecipesTab(),
          _buildGeneralRecipesTab(),
          const BulkRecipeOperationsPage(),
          const RecipeRollbackPage(),
        ],
      ),
    );
  }

  Widget _buildRecipeImage(dynamic imageUrl) {
    // Handle null or empty image URLs
    if (imageUrl == null || imageUrl.toString().trim().isEmpty) {
      print('DEBUG: Recipe image is null or empty');
      return Container(
        width: double.infinity,
        height: 200,
        color: Colors.grey.shade200,
        child: const Icon(Icons.restaurant, size: 50, color: Colors.grey),
      );
    }

    final String imageUrlString = imageUrl.toString().trim();
    print('DEBUG: Loading recipe image: $imageUrlString');
    
    // Check if it's a local asset path
    if (imageUrlString.startsWith('assets/')) {
      return Image.asset(
        imageUrlString,
        width: double.infinity,
        height: 200,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('DEBUG: Asset image loading error for path: $imageUrlString');
          print('DEBUG: Error: $error');
          return Container(
            width: double.infinity,
            height: 200,
            color: Colors.grey.shade200,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                const SizedBox(height: 8),
                Text(
                  'Asset not found',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          );
        },
      );
    }

    // Check if it's a valid network URL
    if (!imageUrlString.startsWith('http://') && !imageUrlString.startsWith('https://')) {
      print('DEBUG: Invalid image URL format: $imageUrlString');
      return Container(
        width: double.infinity,
        height: 200,
        color: Colors.grey.shade200,
        child: const Icon(Icons.restaurant, size: 50, color: Colors.grey),
      );
    }

    return Image.network(
      imageUrlString,
      width: double.infinity,
      height: 200,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: double.infinity,
          height: 200,
          color: Colors.grey.shade100,
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('DEBUG: Image loading error for URL: $imageUrlString');
        print('DEBUG: Error: $error');
        return Container(
          width: double.infinity,
          height: 200,
          color: Colors.grey.shade200,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.broken_image, size: 50, color: Colors.grey),
              const SizedBox(height: 8),
              Text(
                'Image failed to load',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildApiRecipesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search and Stats Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.purple.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.public, color: Colors.blue.shade600, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'API Recipes',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Powered by Spoonacular & TheMealDB',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Search API Recipes',
                    hintText: 'Try "chicken", "pasta", "dessert"...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchQuery = '';
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Recipe Grid
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: _fetchAdminRecipesWithIds(_searchQuery),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Fetching delicious recipes...'),
                      ],
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading recipes',
                          style: TextStyle(fontSize: 18, color: Colors.red.shade600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: TextStyle(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => setState(() {}),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                final recipes = snapshot.data ?? [];
                
                if (recipes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'No recipes found' : 'No recipes match "$_searchQuery"',
                          style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                        ),
                        if (_searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Try a different search term',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.8,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: recipes.length,
                  itemBuilder: (context, index) {
                    final recipe = recipes[index];
                    return _buildRecipeCard(recipe, 'api');
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilipinoRecipesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header with Stats
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade50, Colors.red.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.restaurant, color: Colors.orange.shade600, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Filipino Recipe Database',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    FutureBuilder<List<dynamic>>(
                      future: FilipinoRecipeService.fetchFilipinoRecipes(''),
                      builder: (context, snapshot) {
                        final count = snapshot.data?.length ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$count Recipes',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Search Filipino Recipes',
                          hintText: 'Try "adobo", "sinigang", "kare-kare"...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showAddRecipeDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Recipe'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Recipe Grid
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: FilipinoRecipeService.fetchFilipinoRecipes(_searchQuery),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading Filipino recipes...'),
                      ],
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading recipes',
                          style: TextStyle(fontSize: 18, color: Colors.red.shade600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: TextStyle(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => setState(() {}),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                final recipes = snapshot.data ?? [];
                print('DEBUG: Filipino recipes count: ${recipes.length}');
                print('DEBUG: Search query: "$_searchQuery"');
                
                if (recipes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.restaurant_menu, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'No Filipino recipes found' : 'No recipes match "$_searchQuery"',
                          style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                        ),
                        if (_searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Try a different search term',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: recipes.length,
                  itemBuilder: (context, index) {
                    final recipe = recipes[index];
                    return _buildRecipeCard(recipe, 'filipino');
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGeneralRecipesTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header with Stats
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade50, Colors.teal.shade50],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.folder, color: Colors.green.shade600, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'General Recipes',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    FutureBuilder<QuerySnapshot>(
                      future: FirebaseFirestore.instance.collection('admin_recipes').get(),
                      builder: (context, snapshot) {
                        final count = snapshot.data?.docs.length ?? 0;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$count Recipes',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: 'Search General Recipes',
                          hintText: 'Search by title, description...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _showAddRecipeDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Add Recipe'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Recipe Grid
          Expanded(
            child: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance.collection('admin_recipes').get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Loading general recipes...'),
                      ],
                    ),
                  );
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading recipes',
                          style: TextStyle(fontSize: 18, color: Colors.red.shade600),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${snapshot.error}',
                          style: TextStyle(color: Colors.grey.shade600),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => setState(() {}),
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }
                final recipes = snapshot.data?.docs ?? [];
                final filteredRecipes = recipes.where((doc) {
                  final recipe = doc.data() as Map<String, dynamic>;
                  final title = (recipe['title'] ?? '').toString().toLowerCase();
                  final description = (recipe['description'] ?? '').toString().toLowerCase();
                  final query = _searchQuery.toLowerCase();
                  return title.contains(query) || description.contains(query);
                }).toList();
                
                if (filteredRecipes.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'No general recipes found' : 'No recipes match "$_searchQuery"',
                          style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                        ),
                        if (_searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Try a different search term',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: filteredRecipes.length,
                  itemBuilder: (context, index) {
                    final recipe = filteredRecipes[index].data() as Map<String, dynamic>;
                    return _buildRecipeCard(recipe, 'general');
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _viewApiRecipe(dynamic recipe) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(recipe['title'] ?? 'Recipe Details'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (recipe['image'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _buildRecipeImage(recipe['image']),
                  ),
                const SizedBox(height: 16),
                Text(
                  'Source: ${recipe['id'].toString().startsWith('themealdb_') ? 'TheMealDB' : 'Spoonacular'}',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                if (recipe['summary'] != null)
                  Text(
                    recipe['summary'],
                    style: const TextStyle(fontSize: 14),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _addApiRecipeToDatabase(recipe);
            },
            child: const Text('Add to Database'),
          ),
        ],
      ),
    );
  }

  void _addApiRecipeToDatabase(dynamic recipe) {
    // Implementation for adding API recipe to database
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Recipe added to database!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _editRecipe(dynamic recipe) {
    showDialog(
      context: context,
      builder: (context) => EnhancedRecipeDialog(
        recipe: recipe,
        title: 'Edit Recipe',
        onSave: (updatedRecipe) async {
          try {
            // Check if it's a Filipino recipe by ID pattern or source
            final isFilipinoRecipe = recipe['id'].toString().startsWith('admin_filipino_') || 
                                   recipe['id'].toString().startsWith('firestore_filipino_') ||
                                   recipe['id'].toString().startsWith('local_filipino_') ||
                                   recipe['source'] == 'curated' || 
                                   recipe['source'] == 'Filipino';
            
            if (isFilipinoRecipe) {
              await FilipinoRecipeService.updateSingleCuratedFilipinoRecipe(updatedRecipe);
            } else {
              await RecipeService.updateSingleAdminRecipe(recipe['id'], updatedRecipe);
            }
            setState(() {});
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error updating recipe: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  void _deleteRecipe(dynamic recipe) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recipe'),
        content: Text('Are you sure you want to delete "${recipe['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement delete functionality
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Recipe deleted!'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }


  void _showAddRecipeDialog() {
    showDialog(
      context: context,
      builder: (context) => EnhancedRecipeDialog(
        recipe: null,
        title: 'Add New Recipe',
        onSave: (newRecipe) async {
          try {
            // Check if it's a Filipino recipe
            final cuisine = newRecipe['cuisine']?.toString().toLowerCase() ?? '';
            final isFilipinoRecipe = cuisine == 'filipino';
            
            if (isFilipinoRecipe) {
              // Add to Filipino recipes system
              await FilipinoRecipeService.addSingleCuratedFilipinoRecipe(newRecipe);
            } else {
              // Add to admin recipes collection
              await FirebaseFirestore.instance
                  .collection('admin_recipes')
                  .add({
                ...newRecipe,
                'createdAt': DateTime.now().toIso8601String(),
                'source': 'Admin Created',
              });
            }
            setState(() {});
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error adding recipe: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
      ),
    );
  }

  Widget _buildRecipeCard(dynamic recipe, String type) {
    final title = recipe['title'] ?? 'Unknown Recipe';
    final description = recipe['description'] ?? recipe['summary'] ?? '';
    final image = recipe['image'];
    final mealType = recipe['mealType'] ?? '';
    
    // Get colors based on type
    Color primaryColor;
    Color accentColor;
    IconData typeIcon;
    
    switch (type) {
      case 'api':
        primaryColor = Colors.blue.shade600;
        accentColor = Colors.blue.shade100;
        typeIcon = Icons.public;
        break;
      case 'filipino':
        primaryColor = Colors.orange.shade600;
        accentColor = Colors.orange.shade100;
        typeIcon = Icons.restaurant;
        break;
      case 'general':
        primaryColor = Colors.green.shade600;
        accentColor = Colors.green.shade100;
        typeIcon = Icons.folder;
        break;
      default:
        primaryColor = Colors.grey.shade600;
        accentColor = Colors.grey.shade100;
        typeIcon = Icons.restaurant_menu;
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          if (type == 'api') {
            _viewApiRecipe(recipe);
          } else {
            _editRecipe(recipe);
          }
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  gradient: LinearGradient(
                    colors: [accentColor, primaryColor.withValues(alpha: 0.1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Recipe Image
                    if (image != null && image.toString().isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: _buildDialogImage(image.toString(), typeIcon, primaryColor),
                      )
                    else
                      _buildPlaceholderImage(typeIcon, primaryColor),
                    
                    // Type Badge
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(typeIcon, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              type.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Meal Type Badge
                    if (mealType.isNotEmpty)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            mealType.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Content Section
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // Description
                    Expanded(
                      child: Text(
                        description,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Action Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // View/Edit Button
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (type == 'api') {
                                _viewApiRecipe(recipe);
                              } else {
                                _editRecipe(recipe);
                              }
                            },
                            icon: Icon(
                              type == 'api' ? Icons.visibility : Icons.edit,
                              size: 14,
                            ),
                            label: Text(
                              type == 'api' ? 'View' : 'Edit',
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: const Size(0, 28),
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 8),
                        
                        // Delete Button (for non-API recipes)
                        if (type != 'api')
                          IconButton(
                            onPressed: () => _deleteRecipe(recipe),
                            icon: const Icon(Icons.delete, size: 18),
                            color: Colors.red.shade600,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
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
    );
  }

  Widget _buildDialogImage(String imageUrl, IconData icon, Color color) {
    // Handle empty or invalid image URLs
    if (imageUrl.trim().isEmpty) {
      print('DEBUG: Dialog image is empty');
      return _buildPlaceholderImage(icon, color);
    }

    // Check if it's a local asset path
    if (imageUrl.startsWith('assets/')) {
      print('DEBUG: Loading dialog asset image: $imageUrl');
      return Image.asset(
        imageUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          print('DEBUG: Dialog asset image loading error for path: $imageUrl');
          print('DEBUG: Error: $error');
          return _buildPlaceholderImage(icon, color);
        },
      );
    }

    // Check if it's a valid network URL
    if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
      print('DEBUG: Dialog image URL is invalid: $imageUrl');
      return _buildPlaceholderImage(icon, color);
    }

    print('DEBUG: Loading dialog network image: $imageUrl');

    return Image.network(
      imageUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: double.infinity,
          height: 200,
          color: Colors.grey.shade100,
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        print('DEBUG: Dialog image loading error for URL: $imageUrl');
        print('DEBUG: Error: $error');
        return _buildPlaceholderImage(icon, color);
      },
    );
  }

  Widget _buildPlaceholderImage(IconData icon, Color color) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.1), color.withValues(alpha: 0.3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: color.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 8),
          Text(
            'No Image',
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class EditFilipinoRecipeDialog extends StatefulWidget {
  final Map<String, dynamic> recipe;
  final VoidCallback onRecipeUpdated;

  const EditFilipinoRecipeDialog({
    super.key,
    required this.recipe,
    required this.onRecipeUpdated,
  });

  @override
  State<EditFilipinoRecipeDialog> createState() => _EditFilipinoRecipeDialogState();
}

class _EditFilipinoRecipeDialogState extends State<EditFilipinoRecipeDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _instructionsController;
  late TextEditingController _imageUrlController;
  late TextEditingController _cookingTimeController;
  late TextEditingController _servingsController;
  late List<TextEditingController> _ingredientControllers;
  late String _selectedMealType;
  bool _isUpdating = false;
  

  final List<String> _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack', 'salad', 'soup', 'appetizer', 'dessert', 'beverage'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.recipe['title'] ?? '');
    _descriptionController = TextEditingController(text: widget.recipe['description'] ?? '');
    _instructionsController = TextEditingController(text: widget.recipe['instructions'] ?? '');
    _imageUrlController = TextEditingController(text: widget.recipe['image'] ?? '');
    _cookingTimeController = TextEditingController(text: widget.recipe['cookingTime']?.toString() ?? '');
    _servingsController = TextEditingController(text: widget.recipe['servings']?.toString() ?? '');
    final recipeMealType = widget.recipe['mealType'] ?? 'breakfast';
    _selectedMealType = _mealTypes.contains(recipeMealType) ? recipeMealType : 'breakfast';
    
    final ingredients = widget.recipe['ingredients'] as List<dynamic>? ?? [];
    _ingredientControllers = ingredients.map((ingredient) => 
      TextEditingController(text: ingredient.toString())
    ).toList();
    
    if (_ingredientControllers.isEmpty) {
      _ingredientControllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _imageUrlController.dispose();
    _cookingTimeController.dispose();
    _servingsController.dispose();
    for (final controller in _ingredientControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Filipino Recipe'),
      content: SizedBox(
        width: 500,
        height: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Recipe Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty == true ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedMealType,
                  decoration: const InputDecoration(
                    labelText: 'Meal Type',
                    border: OutlineInputBorder(),
                  ),
                  items: _mealTypes.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.toUpperCase()),
                  )).toList(),
                  onChanged: (value) => setState(() => _selectedMealType = value!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _instructionsController,
                  decoration: const InputDecoration(
                    labelText: 'Instructions',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isUpdating ? null : _updateRecipe,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: _isUpdating 
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _updateRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final updatedRecipe = {
        ...widget.recipe,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'instructions': _instructionsController.text.trim(),
        'cookingTime': int.tryParse(_cookingTimeController.text.trim()) ?? 0,
        'servings': int.tryParse(_servingsController.text.trim()) ?? 1,
        'image': _imageUrlController.text.trim().isNotEmpty ? _imageUrlController.text.trim() : null,
        'ingredients': _ingredientControllers
            .map((controller) => controller.text.trim())
            .where((ingredient) => ingredient.isNotEmpty)
            .toList(),
        'updatedAt': DateTime.now().toIso8601String(),
      };

      await FilipinoRecipeService.updateSingleCuratedFilipinoRecipe(updatedRecipe);
      widget.onRecipeUpdated();

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipe updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating recipe: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }
}

class AddRecipeDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onRecipeAdded;

  const AddRecipeDialog({
    super.key,
    required this.onRecipeAdded,
  });

  @override
  State<AddRecipeDialog> createState() => _AddRecipeDialogState();
}

class _AddRecipeDialogState extends State<AddRecipeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _cookingTimeController = TextEditingController();
  final _servingsController = TextEditingController();
  late String _selectedMealType;
  bool _isAdding = false;

  final List<String> _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack', 'salad', 'soup', 'appetizer', 'dessert', 'beverage'];

  @override
  void initState() {
    super.initState();
    _selectedMealType = 'breakfast';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    _imageUrlController.dispose();
    _cookingTimeController.dispose();
    _servingsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Filipino Recipe'),
      content: SizedBox(
        width: 500,
        height: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Recipe Title',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => value?.isEmpty == true ? 'Title is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: _selectedMealType,
                  decoration: const InputDecoration(
                    labelText: 'Meal Type',
                    border: OutlineInputBorder(),
                  ),
                  items: _mealTypes.map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type.toUpperCase()),
                  )).toList(),
                  onChanged: (value) => setState(() => _selectedMealType = value!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _instructionsController,
                  decoration: const InputDecoration(
                    labelText: 'Instructions',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isAdding ? null : _addRecipe,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          child: _isAdding 
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Text('Add'),
        ),
      ],
    );
  }

  Future<void> _addRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isAdding = true;
    });

    try {
      final recipeData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'instructions': _instructionsController.text.trim(),
        'cookingTime': int.tryParse(_cookingTimeController.text.trim()) ?? 0,
        'servings': int.tryParse(_servingsController.text.trim()) ?? 1,
        'image': _imageUrlController.text.trim().isNotEmpty ? _imageUrlController.text.trim() : null,
        'ingredients': [],
        'mealType': _selectedMealType,
        'cuisine': 'Filipino',
        'source': 'curated',
        'isEditable': true,
        'createdAt': DateTime.now().toIso8601String(),
      };

      await FilipinoRecipeService.addCuratedFilipinoRecipe(recipeData);
      widget.onRecipeAdded(recipeData);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recipe added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding recipe: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
      }
    }
  }
}
