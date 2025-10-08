import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../services/filipino_recipe_service.dart';

class NutritionistRecipePickerDialog extends StatefulWidget {
  final Function(Map<String, dynamic>) onRecipeSelected;

  const NutritionistRecipePickerDialog({
    super.key,
    required this.onRecipeSelected,
  });

  @override
  State<NutritionistRecipePickerDialog> createState() => _NutritionistRecipePickerDialogState();
}

class _NutritionistRecipePickerDialogState extends State<NutritionistRecipePickerDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _apiRecipes = [];
  List<Map<String, dynamic>> _generalRecipes = [];
  List<Map<String, dynamic>> _filipinoRecipes = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadFilipinoRecipes();
    _loadGeneralRecipes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchApiRecipes(String query) async {
    if (query.isEmpty) return;
    
    setState(() => _isLoading = true);
    
    try {
      final apiKey = dotenv.env['SPOONACULAR_API_KEY'];
      final response = await http.get(
        Uri.parse(
          'https://api.spoonacular.com/recipes/complexSearch?query=$query&number=20&addRecipeNutrition=true&apiKey=$apiKey',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _apiRecipes = List<Map<String, dynamic>>.from(data['results']);
        });
      }
    } catch (e) {
      print('Error searching API recipes: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadGeneralRecipes() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('admin_recipes')
          .get();
      
      setState(() {
        _generalRecipes = snapshot.docs.map((doc) => {
          'id': doc.id,
          ...doc.data(),
        }).toList();
      });
    } catch (e) {
      print('Error loading general recipes: $e');
    }
  }

  Future<void> _loadFilipinoRecipes() async {
    try {
      final recipes = await FilipinoRecipeService.fetchFilipinoRecipes('');
      setState(() {
        _filipinoRecipes = recipes.map((r) => Map<String, dynamic>.from(r)).toList();
      });
    } catch (e) {
      print('Error loading Filipino recipes: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[700],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.restaurant_menu, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Pick a Recipe',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search recipes...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                  if (_tabController.index == 0 && value.length > 2) {
                    _searchApiRecipes(value);
                  }
                },
              ),
            ),
            
            // Tabs
            TabBar(
              controller: _tabController,
              labelColor: Colors.green[700],
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.green[700],
              tabs: const [
                Tab(text: 'API Recipes', icon: Icon(Icons.cloud)),
                Tab(text: 'General', icon: Icon(Icons.restaurant)),
                Tab(text: 'Filipino', icon: Icon(Icons.flag)),
              ],
            ),
            
            // Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildApiRecipesTab(),
                  _buildGeneralRecipesTab(),
                  _buildFilipinoRecipesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApiRecipesTab() {
    if (_searchQuery.isEmpty || _searchQuery.length < 3) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Search for recipes from Spoonacular API',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_apiRecipes.isEmpty) {
      return const Center(child: Text('No results found'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _apiRecipes.length,
      itemBuilder: (context, index) {
        final recipe = _apiRecipes[index];
        return _buildRecipeCard(recipe, 'api');
      },
    );
  }

  Widget _buildGeneralRecipesTab() {
    final filteredRecipes = _generalRecipes.where((recipe) {
      final title = (recipe['title'] ?? '').toString().toLowerCase();
      return title.contains(_searchQuery.toLowerCase());
    }).toList();

    if (filteredRecipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No general recipes found',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredRecipes.length,
      itemBuilder: (context, index) {
        final recipe = filteredRecipes[index];
        return _buildRecipeCard(recipe, 'general');
      },
    );
  }

  Widget _buildFilipinoRecipesTab() {
    final filteredRecipes = _filipinoRecipes.where((recipe) {
      final title = (recipe['title'] ?? '').toString().toLowerCase();
      return title.contains(_searchQuery.toLowerCase());
    }).toList();

    if (filteredRecipes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.flag, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No Filipino recipes found',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredRecipes.length,
      itemBuilder: (context, index) {
        final recipe = filteredRecipes[index];
        return _buildRecipeCard(recipe, 'filipino');
      },
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe, String source) {
    final nutrition = recipe['nutrition'] ?? {};
    final calories = nutrition['calories'] ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showRecipeEditDialog(recipe, source),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  recipe['image'] ?? 'https://via.placeholder.com/80',
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 80,
                    height: 80,
                    color: Colors.grey[300],
                    child: const Icon(Icons.restaurant),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe['title'] ?? 'Untitled Recipe',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$calories cal',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: source == 'filipino' ? Colors.red[100] :
                               source == 'general' ? Colors.blue[100] :
                               Colors.green[100],
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        source == 'filipino' ? 'Filipino' :
                        source == 'general' ? 'General' : 'API',
                        style: TextStyle(
                          fontSize: 11,
                          color: source == 'filipino' ? Colors.red[900] :
                                 source == 'general' ? Colors.blue[900] :
                                 Colors.green[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Arrow
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecipeEditDialog(Map<String, dynamic> recipe, String source) async {
    Navigator.pop(context); // Close picker
    
    // Fetch full recipe details if needed
    Map<String, dynamic> fullRecipe = recipe;
    
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
    );
    
    try {
      // For Filipino recipes, fetch full details if ingredients are missing
      if (source == 'filipino' && (recipe['ingredients'] == null || (recipe['ingredients'] as List).isEmpty)) {
        final details = await FilipinoRecipeService.getRecipeDetails(recipe['id']);
        if (details != null) {
          fullRecipe = details;
        }
      }
      // For API recipes, they should already have ingredients from the search
      // For general recipes, they should already have full details from Firestore
    } catch (e) {
      print('Error fetching full recipe details: $e');
    }
    
    // Close loading
    if (mounted) Navigator.pop(context);
    
    // Show edit dialog
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => _RecipeEditDialog(
          recipe: fullRecipe,
          source: source,
          onSave: widget.onRecipeSelected,
        ),
      );
    }
  }
}

class _RecipeEditDialog extends StatefulWidget {
  final Map<String, dynamic> recipe;
  final String source;
  final Function(Map<String, dynamic>) onSave;

  const _RecipeEditDialog({
    required this.recipe,
    required this.source,
    required this.onSave,
  });

  @override
  State<_RecipeEditDialog> createState() => _RecipeEditDialogState();
}

class _RecipeEditDialogState extends State<_RecipeEditDialog> {
  late TextEditingController _titleController;
  late TextEditingController _caloriesController;
  late TextEditingController _proteinController;
  late TextEditingController _carbsController;
  late TextEditingController _fatController;
  late TextEditingController _fiberController;
  late TextEditingController _sugarController;

  @override
  void initState() {
    super.initState();
    final nutrition = widget.recipe['nutrition'] ?? {};
    
    _titleController = TextEditingController(text: widget.recipe['title'] ?? '');
    _caloriesController = TextEditingController(text: (nutrition['calories'] ?? 0).toString());
    _proteinController = TextEditingController(text: (nutrition['protein'] ?? 0).toString());
    _carbsController = TextEditingController(text: (nutrition['carbs'] ?? 0).toString());
    _fatController = TextEditingController(text: (nutrition['fat'] ?? 0).toString());
    _fiberController = TextEditingController(text: (nutrition['fiber'] ?? 0).toString());
    _sugarController = TextEditingController(text: (nutrition['sugar'] ?? 0).toString());
  }

  @override
  void dispose() {
    _titleController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _fiberController.dispose();
    _sugarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[700],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Edit Recipe Details',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        labelText: 'Recipe Title',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    const Text(
                      'Nutrition Information',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _caloriesController,
                            decoration: const InputDecoration(
                              labelText: 'Calories',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _proteinController,
                            decoration: const InputDecoration(
                              labelText: 'Protein (g)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _carbsController,
                            decoration: const InputDecoration(
                              labelText: 'Carbs (g)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _fatController,
                            decoration: const InputDecoration(
                              labelText: 'Fat (g)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _fiberController,
                            decoration: const InputDecoration(
                              labelText: 'Fiber (g)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _sugarController,
                            decoration: const InputDecoration(
                              labelText: 'Sugar (g)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Actions
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: _saveRecipe,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Add to Meal Plan'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _saveRecipe() {
    final editedRecipe = {
      ...widget.recipe,
      'title': _titleController.text,
      'nutrition': {
        'calories': double.tryParse(_caloriesController.text) ?? 0,
        'protein': double.tryParse(_proteinController.text) ?? 0,
        'carbs': double.tryParse(_carbsController.text) ?? 0,
        'fat': double.tryParse(_fatController.text) ?? 0,
        'fiber': double.tryParse(_fiberController.text) ?? 0,
        'sugar': double.tryParse(_sugarController.text) ?? 0,
      },
      'source': widget.source,
    };
    
    widget.onSave(editedRecipe);
    Navigator.pop(context);
  }
}

