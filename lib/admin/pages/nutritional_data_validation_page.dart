import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/nutrition_service.dart';

class NutritionalDataValidationPage extends StatefulWidget {
  const NutritionalDataValidationPage({super.key});

  @override
  State<NutritionalDataValidationPage> createState() => _NutritionalDataValidationPageState();
}

class _NutritionalDataValidationPageState extends State<NutritionalDataValidationPage> with TickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nutritional Data Validation'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Filipino Recipes', icon: Icon(Icons.flag)),
            Tab(text: 'General Recipes', icon: Icon(Icons.restaurant)),
            Tab(text: 'Ingredient Database', icon: Icon(Icons.inventory_2)),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search recipes or ingredients...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFilipinoRecipesTab(),
                _buildGeneralRecipesTab(),
                _buildIngredientDatabaseTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilipinoRecipesTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('system_data')
          .doc('filipino_recipes')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Center(child: Text('No Filipino recipes found'));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final recipes = List<Map<String, dynamic>>.from(data?['data'] ?? []);
        
        final filteredRecipes = _searchQuery.isEmpty
            ? recipes
            : recipes.where((r) => 
                (r['title'] ?? '').toString().toLowerCase().contains(_searchQuery)
              ).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredRecipes.length,
          itemBuilder: (context, index) {
            return _buildRecipeCard(filteredRecipes[index], 'filipino');
          },
        );
      },
    );
  }

  Widget _buildGeneralRecipesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('admin_recipes')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('No general recipes found'));
        }

        final recipes = snapshot.data!.docs.map((doc) {
          return {'id': doc.id, ...doc.data() as Map<String, dynamic>};
        }).toList();
        
        final filteredRecipes = _searchQuery.isEmpty
            ? recipes
            : recipes.where((r) => 
                (r['title'] ?? '').toString().toLowerCase().contains(_searchQuery)
              ).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredRecipes.length,
          itemBuilder: (context, index) {
            return _buildRecipeCard(filteredRecipes[index], 'general');
          },
        );
      },
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe, String source) {
    final nutrition = recipe['nutrition'] ?? {};
    final calories = nutrition['calories']?.toDouble() ?? 0;
    final protein = nutrition['protein']?.toDouble() ?? 0;
    final carbs = nutrition['carbs']?.toDouble() ?? 0;
    final fat = nutrition['fat']?.toDouble() ?? 0;
    final isValidated = recipe['nutritionValidated'] == true;
    final validatedBy = recipe['validatedBy'];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[200],
              ),
              child: recipe['image'] != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        recipe['image'],
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => 
                            Icon(Icons.restaurant, size: 32, color: Colors.grey[400]),
                      ),
                    )
                  : Icon(Icons.restaurant, size: 32, color: Colors.grey[400]),
            ),
            const SizedBox(width: 16),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          recipe['title'] ?? 'Untitled Recipe',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isValidated)
                        Tooltip(
                          message: 'Validated by ${validatedBy ?? "Nutritionist"}',
                          child: Icon(Icons.verified, color: Colors.green[600], size: 20),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: source == 'filipino' ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      source.toUpperCase(),
                      style: TextStyle(
                        color: source == 'filipino' ? Colors.red : Colors.blue,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildNutritionChip(Icons.local_fire_department, '${calories.toInt()}', Colors.orange),
                      _buildNutritionChip(Icons.fitness_center, 'P: ${protein.toStringAsFixed(1)}g', Colors.red),
                      _buildNutritionChip(Icons.grain, 'C: ${carbs.toStringAsFixed(1)}g', Colors.blue),
                      _buildNutritionChip(Icons.water_drop, 'F: ${fat.toStringAsFixed(1)}g', Colors.purple),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _editRecipe(recipe, source),
                          icon: const Icon(Icons.edit, size: 16),
                          label: const Text('Edit', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: const Size(0, 32),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _validateRecipe(recipe, source),
                          icon: Icon(
                            isValidated ? Icons.check_circle : Icons.check,
                            size: 16,
                          ),
                          label: Text(
                            isValidated ? 'Validated' : 'Validate',
                            style: const TextStyle(fontSize: 12),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isValidated ? Colors.green : Colors.grey,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: const Size(0, 32),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNutritionChip(IconData icon, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _editRecipe(Map<String, dynamic> recipe, String source) {
    final caloriesController = TextEditingController(
        text: (recipe['nutrition']?['calories'] ?? 0).toString());
    final proteinController = TextEditingController(
        text: (recipe['nutrition']?['protein'] ?? 0).toString());
    final carbsController = TextEditingController(
        text: (recipe['nutrition']?['carbs'] ?? 0).toString());
    final fatController = TextEditingController(
        text: (recipe['nutrition']?['fat'] ?? 0).toString());

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit: ${recipe['title']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: caloriesController,
                decoration: const InputDecoration(
                    labelText: 'Calories', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: proteinController,
                decoration: const InputDecoration(
                    labelText: 'Protein (g)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: carbsController,
                decoration: const InputDecoration(
                    labelText: 'Carbs (g)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: fatController,
                decoration: const InputDecoration(
                    labelText: 'Fat (g)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedNutrition = {
                'calories': double.tryParse(caloriesController.text) ?? 0,
                'protein': double.tryParse(proteinController.text) ?? 0,
                'carbs': double.tryParse(carbsController.text) ?? 0,
                'fat': double.tryParse(fatController.text) ?? 0,
                'fiber': recipe['nutrition']?['fiber'] ?? 0,
              };

              try {
                if (source == 'filipino') {
                  final doc = await FirebaseFirestore.instance
                      .collection('system_data')
                      .doc('filipino_recipes')
                      .get();
                  
                  final data = doc.data();
                  final recipes = List<Map<String, dynamic>>.from(data?['data'] ?? []);
                  final index = recipes.indexWhere((r) => r['id'] == recipe['id']);
                  
                  if (index != -1) {
                    recipes[index]['nutrition'] = updatedNutrition;
                    await FirebaseFirestore.instance
                        .collection('system_data')
                        .doc('filipino_recipes')
                        .update({'data': recipes});
                  }
                } else {
                  await FirebaseFirestore.instance
                      .collection('admin_recipes')
                      .doc(recipe['id'])
                      .update({'nutrition': updatedNutrition});
                }

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Updated!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: source == 'filipino' ? Colors.red : Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _validateRecipe(Map<String, dynamic> recipe, String source) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .get();
      
      final nutritionistName = userDoc.data()?['full_name'] ?? user?.email ?? 'Nutritionist';
      final isCurrentlyValidated = recipe['nutritionValidated'] == true;

      if (source == 'filipino') {
        final doc = await FirebaseFirestore.instance
            .collection('system_data')
            .doc('filipino_recipes')
            .get();
        
        final data = doc.data();
        final recipes = List<Map<String, dynamic>>.from(data?['data'] ?? []);
        final index = recipes.indexWhere((r) => r['id'] == recipe['id']);
        
        if (index != -1) {
          recipes[index]['nutritionValidated'] = !isCurrentlyValidated;
          recipes[index]['validatedBy'] = !isCurrentlyValidated ? nutritionistName : null;
          recipes[index]['validatedAt'] = !isCurrentlyValidated ? DateTime.now().toIso8601String() : null;
          
          await FirebaseFirestore.instance
              .collection('system_data')
              .doc('filipino_recipes')
              .update({'data': recipes});
        }
      } else {
        await FirebaseFirestore.instance
            .collection('admin_recipes')
            .doc(recipe['id'])
            .update({
          'nutritionValidated': !isCurrentlyValidated,
          'validatedBy': !isCurrentlyValidated ? nutritionistName : null,
          'validatedAt': !isCurrentlyValidated ? FieldValue.serverTimestamp() : null,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isCurrentlyValidated ? 'Validation removed' : 'Recipe validated!'),
            backgroundColor: isCurrentlyValidated ? Colors.orange : Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildIngredientDatabaseTab() {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('system_data')
          .doc('ingredient_nutrition')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.orange));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'Ingredient Database Not Found',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Click below to migrate ingredients from code to Firestore',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _migrateIngredientDatabase,
                    icon: const Icon(Icons.upload),
                    label: const Text('Migrate Ingredients to Firestore'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _cleanDuplicates,
                    icon: const Icon(Icons.cleaning_services),
                    label: const Text('Clean Duplicate Ingredients'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        final ingredients = Map<String, dynamic>.from(data?['ingredients'] ?? {});
        
        if (ingredients.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.inbox, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No ingredients found'),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _migrateIngredientDatabase,
                  icon: const Icon(Icons.upload),
                  label: const Text('Migrate Ingredients'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        // Filter ingredients based on search
        final filteredIngredients = _searchQuery.isEmpty
            ? ingredients
            : Map.fromEntries(
                ingredients.entries.where((entry) =>
                  entry.key.toLowerCase().contains(_searchQuery)
                ),
              );

        // Categorize ingredients
        final categorized = _categorizeIngredients(filteredIngredients);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _migrateIngredientDatabase,
                    icon: const Icon(Icons.upload),
                    label: const Text('Migrate Ingredients'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _cleanDuplicates,
                    icon: const Icon(Icons.cleaning_services),
                    label: const Text('Clean Duplicates'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              '${filteredIngredients.length} ingredients in database',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...categorized.entries.map((category) {
              return _buildIngredientCategory(category.key, category.value);
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildIngredientCard(String name, Map<String, dynamic> nutrition) {
    final calories = nutrition['calories']?.toDouble() ?? 0;
    final protein = nutrition['protein']?.toDouble() ?? 0;
    final carbs = nutrition['carbs']?.toDouble() ?? 0;
    final fat = nutrition['fat']?.toDouble() ?? 0;
    final isValidated = nutrition['validatedBy'] != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.orange.withOpacity(0.2),
          child: Text(
            name[0].toUpperCase(),
            style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          '${calories.toInt()} cal | P: ${protein.toStringAsFixed(1)}g | C: ${carbs.toStringAsFixed(1)}g | F: ${fat.toStringAsFixed(1)}g',
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isValidated)
              const Icon(Icons.verified, color: Colors.green, size: 20),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _editIngredient(name, nutrition),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _cleanDuplicates() async {
    // Show confirmation dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Clean Duplicates'),
        content: const Text(
          'This will remove duplicate ingredients (case-insensitive) from your database.\n\n'
          'For duplicates, the first occurrence will be kept.\n\n'
          'This action cannot be undone. Continue?',
        ),
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
            child: const Text('Clean Duplicates'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Cleaning duplicates...'),
          ],
        ),
      ),
    );

    try {
      // Read existing ingredients from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('system_data')
          .doc('ingredient_nutrition')
          .get();

      if (!doc.exists) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No ingredients found in database'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final data = doc.data();
      final existingIngredients = Map<String, dynamic>.from(data?['ingredients'] ?? {});
      print('DEBUG: Found ${existingIngredients.length} total ingredients');

      // Find and remove duplicates (case-insensitive)
      final cleanedIngredients = <String, dynamic>{};
      final lowerCaseMap = <String, String>{}; // lowercase -> original key
      final duplicatesFound = <String>[];
      int duplicateCount = 0;

      for (final entry in existingIngredients.entries) {
        final ingredientName = entry.key;
        final ingredientLower = ingredientName.toLowerCase();

        // Check if we already have this ingredient (case-insensitive)
        if (lowerCaseMap.containsKey(ingredientLower)) {
          // Found a duplicate
          final existingKey = lowerCaseMap[ingredientLower]!;
          duplicatesFound.add('Duplicate: "$ingredientName" (keeping "$existingKey")');
          duplicateCount++;
          print('DEBUG: Found duplicate: "$ingredientName" (already have "$existingKey")');
        } else {
          // First occurrence, keep it
          cleanedIngredients[ingredientName] = entry.value;
          lowerCaseMap[ingredientLower] = ingredientName;
        }
      }

      if (duplicateCount == 0) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ No duplicates found! Database is clean.'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return;
      }

      print('DEBUG: Removed $duplicateCount duplicates');
      print('DEBUG: Clean ingredients count: ${cleanedIngredients.length}');

      // Update Firestore with cleaned ingredients
      await FirebaseFirestore.instance
          .collection('system_data')
          .doc('ingredient_nutrition')
          .set({
        'ingredients': cleanedIngredients,
        'cleanedAt': FieldValue.serverTimestamp(),
        'version': 2,
        'totalIngredients': cleanedIngredients.length,
      });

      if (mounted) {
        Navigator.pop(context);
        
        // Show detailed results
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('✅ Cleanup Complete!'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Removed $duplicateCount duplicate ingredients'),
                  Text('Kept ${cleanedIngredients.length} unique ingredients'),
                  const SizedBox(height: 16),
                  if (duplicatesFound.isNotEmpty) ...[
                    const Text('Duplicates removed:', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...duplicatesFound.take(20).map((dup) => Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 4),
                      child: Text('• $dup', style: const TextStyle(fontSize: 12)),
                    )),
                    if (duplicatesFound.length > 20)
                      Text('... and ${duplicatesFound.length - 20} more'),
                  ],
                ],
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cleaning duplicates: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _migrateIngredientDatabase() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Migrating ingredients...'),
          ],
        ),
      ),
    );

    try {
      // Get the full hardcoded ingredient database from NutritionService
      final hardcodedDb = NutritionService.getIngredientDatabase();
      print('DEBUG: Loaded ${hardcodedDb.length} ingredients from NutritionService');
      
      // Read existing ingredients from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('system_data')
          .doc('ingredient_nutrition')
          .get();
      
      Map<String, dynamic> existingIngredients = {};
      if (doc.exists) {
        final data = doc.data();
        existingIngredients = Map<String, dynamic>.from(data?['ingredients'] ?? {});
        print('DEBUG: Found ${existingIngredients.length} existing ingredients in Firestore');
      }
      
      // Create a case-insensitive lookup map for existing ingredients
      final existingLowerCaseMap = <String, String>{};
      for (final key in existingIngredients.keys) {
        existingLowerCaseMap[key.toLowerCase()] = key;
      }
      
      // Merge hardcoded ingredients with existing, avoiding duplicates
      final mergedIngredients = Map<String, dynamic>.from(existingIngredients);
      int newCount = 0;
      int skippedCount = 0;
      
      for (final entry in hardcodedDb.entries) {
        final ingredientName = entry.key;
        final ingredientLower = ingredientName.toLowerCase();
        
        // Check if this ingredient already exists (case-insensitive)
        if (existingLowerCaseMap.containsKey(ingredientLower)) {
          print('DEBUG: Skipping duplicate: $ingredientName (exists as: ${existingLowerCaseMap[ingredientLower]})');
          skippedCount++;
          continue;
        }
        
        // Add new ingredient
        mergedIngredients[ingredientName] = entry.value;
        newCount++;
      }
      
      print('DEBUG: Added $newCount new ingredients, skipped $skippedCount duplicates');
      print('DEBUG: Total ingredients after merge: ${mergedIngredients.length}');

      // Update Firestore with merged ingredients
      await FirebaseFirestore.instance
          .collection('system_data')
          .doc('ingredient_nutrition')
          .set({
        'ingredients': mergedIngredients,
        'migratedAt': FieldValue.serverTimestamp(),
        'version': 2,
        'totalIngredients': mergedIngredients.length,
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Migration complete!\n'
                'Added: $newCount new ingredients\n'
                'Skipped: $skippedCount duplicates\n'
                'Total: ${mergedIngredients.length} ingredients'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editIngredient(String name, Map<String, dynamic> nutrition) {
    final caloriesController = TextEditingController(text: nutrition['calories']?.toString() ?? '0');
    final proteinController = TextEditingController(text: nutrition['protein']?.toString() ?? '0');
    final carbsController = TextEditingController(text: nutrition['carbs']?.toString() ?? '0');
    final fatController = TextEditingController(text: nutrition['fat']?.toString() ?? '0');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit: $name'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: caloriesController,
                decoration: const InputDecoration(labelText: 'Calories', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: proteinController,
                decoration: const InputDecoration(labelText: 'Protein (g)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: carbsController,
                decoration: const InputDecoration(labelText: 'Carbs (g)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: fatController,
                decoration: const InputDecoration(labelText: 'Fat (g)', border: OutlineInputBorder()),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedNutrition = {
                'calories': double.tryParse(caloriesController.text) ?? 0,
                'protein': double.tryParse(proteinController.text) ?? 0,
                'carbs': double.tryParse(carbsController.text) ?? 0,
                'fat': double.tryParse(fatController.text) ?? 0,
                'fiber': nutrition['fiber'] ?? 0,
                'validatedBy': FirebaseAuth.instance.currentUser?.email ?? 'Nutritionist',
                'validatedAt': FieldValue.serverTimestamp(),
              };

              try {
                await FirebaseFirestore.instance
                    .collection('system_data')
                    .doc('ingredient_nutrition')
                    .update({'ingredients.$name': updatedNutrition});

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Updated!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Map<String, Map<String, dynamic>> _categorizeIngredients(Map<String, dynamic> ingredients) {
    final categories = {
      'Proteins': <String, dynamic>{},
      'Grains & Carbs': <String, dynamic>{},
      'Vegetables': <String, dynamic>{},
      'Fruits': <String, dynamic>{},
      'Filipino Ingredients': <String, dynamic>{},
      'Others': <String, dynamic>{},
    };

    final proteinKeywords = ['chicken', 'beef', 'pork', 'fish', 'salmon', 'tuna', 'egg', 'bangus', 'tilapia'];
    final grainKeywords = ['rice', 'bread', 'pasta', 'oats', 'bigas'];
    final vegetableKeywords = ['broccoli', 'spinach', 'carrot', 'tomato', 'kamatis', 'kangkong', 'sitaw'];
    final fruitKeywords = ['apple', 'banana', 'mango', 'saging', 'mangga'];
    final filipinoKeywords = ['patis', 'toyo', 'bagoong', 'suka', 'luya', 'talong'];

    for (final entry in ingredients.entries) {
      final name = entry.key.toLowerCase();
      
      if (proteinKeywords.any((k) => name.contains(k))) {
        categories['Proteins']![entry.key] = entry.value;
      } else if (grainKeywords.any((k) => name.contains(k))) {
        categories['Grains & Carbs']![entry.key] = entry.value;
      } else if (vegetableKeywords.any((k) => name.contains(k))) {
        categories['Vegetables']![entry.key] = entry.value;
      } else if (fruitKeywords.any((k) => name.contains(k))) {
        categories['Fruits']![entry.key] = entry.value;
      } else if (filipinoKeywords.any((k) => name.contains(k))) {
        categories['Filipino Ingredients']![entry.key] = entry.value;
      } else {
        categories['Others']![entry.key] = entry.value;
      }
    }

    // Remove empty categories
    categories.removeWhere((key, value) => value.isEmpty);
    return categories;
  }

  Widget _buildIngredientCategory(String categoryName, Map<String, dynamic> ingredients) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        leading: Icon(_getCategoryIcon(categoryName), color: _getCategoryColor(categoryName)),
        title: Text(
          categoryName,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text('${ingredients.length} ingredients'),
        children: ingredients.entries.map((entry) {
          return _buildIngredientCard(entry.key, Map<String, dynamic>.from(entry.value));
        }).toList(),
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Proteins': return Icons.set_meal;
      case 'Grains & Carbs': return Icons.rice_bowl;
      case 'Vegetables': return Icons.eco;
      case 'Fruits': return Icons.apple;
      case 'Filipino Ingredients': return Icons.flag;
      default: return Icons.category;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Proteins': return Colors.red;
      case 'Grains & Carbs': return Colors.amber;
      case 'Vegetables': return Colors.green;
      case 'Fruits': return Colors.orange;
      case 'Filipino Ingredients': return Colors.purple;
      default: return Colors.grey;
    }
  }
}
