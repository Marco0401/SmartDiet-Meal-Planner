import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/recipe_service.dart';
import 'services/filipino_recipe_service.dart';
import 'shopping_list_management_page.dart';

class ShoppingListGeneratorPage extends StatefulWidget {
  const ShoppingListGeneratorPage({super.key});

  @override
  State<ShoppingListGeneratorPage> createState() => _ShoppingListGeneratorPageState();
}

class _ShoppingListGeneratorPageState extends State<ShoppingListGeneratorPage> {
  DateTime _selectedStartDate = DateTime.now();
  DateTime _selectedEndDate = DateTime.now().add(const Duration(days: 6));
  List<Map<String, dynamic>> _selectedRecipes = [];
  List<Map<String, dynamic>> _generatedShoppingList = [];
  bool _isGenerating = false;
  bool _isLoadingRecipes = false;
  int _servingsPerRecipe = 4;


  @override
  void initState() {
    super.initState();
    // Auto-load planned meals when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecipes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Shopping List Generator',
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
              icon: const Icon(Icons.shopping_cart),
              onPressed: _generatedShoppingList.isNotEmpty ? _shareShoppingList : null,
              tooltip: 'Share Shopping List',
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
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
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(
                    Icons.shopping_cart_outlined,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Smart Shopping List',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Generate shopping lists from your meal plans',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withOpacity(0.9),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            // Content Section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildDateRangeSelector(),
                  const SizedBox(height: 24),
                  _buildServingsSelector(),
                  const SizedBox(height: 24),
                  _buildRecipeSelector(),
                  const SizedBox(height: 32),
                  _buildGenerateButton(),
                  const SizedBox(height: 16),
                  _buildDirectAccessButton(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeSelector() {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.date_range,
                    color: Colors.green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Meal Planning Period',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    label: 'Start Date',
                    date: _selectedStartDate,
                    onTap: _selectStartDate,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDateField(
                    label: 'End Date',
                    date: _selectedEndDate,
                    onTap: _selectEndDate,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 20,
                  color: Colors.green.shade600,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateFormat('MMM dd, yyyy').format(date),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: Colors.grey.shade600,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildServingsSelector() {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.people,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Servings per Recipe',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Number of servings:',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _servingsPerRecipe > 1 ? () {
                          setState(() {
                            _servingsPerRecipe--;
                          });
                        } : null,
                        icon: Icon(
                          Icons.remove,
                          color: _servingsPerRecipe > 1 ? Colors.orange : Colors.grey.shade400,
                        ),
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          _servingsPerRecipe.toString(),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _servingsPerRecipe++;
                          });
                        },
                        icon: const Icon(
                          Icons.add,
                          color: Colors.orange,
                        ),
                        style: IconButton.styleFrom(
                          padding: const EdgeInsets.all(8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecipeSelector() {
    return Container(
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.restaurant,
                    color: Colors.purple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Selected Recipes',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: _loadRecipes,
                        icon: _isLoadingRecipes 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.refresh, size: 18),
                        tooltip: 'Load Planned Meals',
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.purple,
                        ),
                      ),
                      IconButton(
                        onPressed: _loadManualRecipes,
                        icon: const Icon(Icons.add, size: 18),
                        tooltip: 'Add More Recipes',
                        style: IconButton.styleFrom(
                          foregroundColor: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_selectedRecipes.isEmpty)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.restaurant_menu, size: 48, color: Colors.grey),
                      const SizedBox(height: 8),
                      const Text('No recipes selected'),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: _loadRecipes,
                        child: const Text('Load Planned Meals'),
                      ),
                    ],
                  ),
                ),
              )
            else
              Container(
                height: 200,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _selectedRecipes.length,
                  itemBuilder: (context, index) {
                    final recipe = _selectedRecipes[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.green,
                          child: Text(
                            recipe['title']?.toString().substring(0, 1).toUpperCase() ?? 'R',
                            style: const TextStyle(
                              color: Colors.white, 
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(
                          recipe['title'] ?? 'Unknown Recipe',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${recipe['cuisine'] ?? 'Unknown'} • ${recipe['mealType'] ?? 'Unknown'}',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (recipe['source'] == 'planned_meal' && recipe['plannedDate'] != null)
                              Text(
                                'Planned for ${recipe['plannedDate']}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.green[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red, size: 20),
                          onPressed: () {
                            setState(() {
                              _selectedRecipes.removeAt(index);
                            });
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade400],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _selectedRecipes.isNotEmpty && !_isGenerating ? _generateShoppingList : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isGenerating) ...[
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Generating...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ] else ...[
                  const Icon(
                    Icons.shopping_cart,
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Generate Shopping List',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDirectAccessButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _goToShoppingListManager,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.list_alt,
                  color: Colors.green.shade600,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Go to Shopping List Manager',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _goToShoppingListManager() async {
    // Navigate directly to shopping list management page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShoppingListManagementPage(
          shoppingList: [], // Empty list - user can load saved lists
          startDate: _selectedStartDate,
          endDate: _selectedEndDate,
        ),
      ),
    );
  }

  Future<void> _selectStartDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedStartDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _selectedStartDate = date;
        if (_selectedEndDate.isBefore(_selectedStartDate)) {
          _selectedEndDate = _selectedStartDate.add(const Duration(days: 6));
        }
      });
      // Reload planned meals for new date range
      _loadRecipes();
    }
  }

  Future<void> _selectEndDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedEndDate,
      firstDate: _selectedStartDate,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date != null) {
      setState(() {
        _selectedEndDate = date;
      });
      // Reload planned meals for new date range
      _loadRecipes();
    }
  }

  Future<void> _loadRecipes() async {
    setState(() {
      _isLoadingRecipes = true;
    });

    try {
      // First, try to load planned meals for the selected date range
      final plannedMeals = await _loadPlannedMealsForDateRange();
      
      if (plannedMeals.isNotEmpty) {
        // If we have planned meals, show them as pre-selected
        setState(() {
          _selectedRecipes = plannedMeals;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${plannedMeals.length} planned meals for selected dates!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // If no planned meals, load all available recipes for manual selection
        final generalRecipes = await RecipeService.fetchRecipes('');
        final filipinoRecipes = await FilipinoRecipeService.fetchFilipinoRecipes('');
        
        // Combine and filter recipes
        List<Map<String, dynamic>> allRecipes = [
          ...generalRecipes,
          ...filipinoRecipes,
        ];

        // Show recipe selection dialog
        final selectedRecipes = await _showRecipeSelectionDialog(allRecipes);
        
        if (selectedRecipes != null) {
          setState(() {
            _selectedRecipes = selectedRecipes;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading recipes: $e')),
      );
    } finally {
      setState(() {
        _isLoadingRecipes = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _loadPlannedMealsForDateRange() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return [];

    try {
      // Convert dates to strings for Firestore query
      final startDateStr = DateFormat('yyyy-MM-dd').format(_selectedStartDate);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_selectedEndDate);

      // Query meals within the date range from meal_plans collection
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meal_plans')
          .where('date', isGreaterThanOrEqualTo: startDateStr)
          .where('date', isLessThanOrEqualTo: endDateStr)
          .get();

      // Convert to recipe format for consistency
      final plannedMeals = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? 'Planned Meal',
          'cuisine': data['cuisine'] ?? 'Planned',
          'mealType': data['meal_type'] ?? data['mealType'] ?? 'lunch',
          'ingredients': data['ingredients'] ?? [],
          'instructions': data['instructions'] ?? '',
          'image': data['image'] ?? '',
          'nutrition': data['nutrition'] ?? {},
          'source': 'planned_meal',
          'plannedDate': data['date'],
        };
      }).toList();

      return plannedMeals;
    } catch (e) {
      print('Error loading planned meals: $e');
      return [];
    }
  }

  Future<void> _loadManualRecipes() async {
    setState(() {
      _isLoadingRecipes = true;
    });

    try {
      // Load all available recipes for manual selection
      final generalRecipes = await RecipeService.fetchRecipes('');
      final filipinoRecipes = await FilipinoRecipeService.fetchFilipinoRecipes('');
      
      // Combine and filter recipes
      List<Map<String, dynamic>> allRecipes = [
        ...generalRecipes,
        ...filipinoRecipes,
      ];

      // Show recipe selection dialog
      final selectedRecipes = await _showRecipeSelectionDialog(allRecipes);
      
      if (selectedRecipes != null && selectedRecipes.isNotEmpty) {
        setState(() {
          _selectedRecipes.addAll(selectedRecipes);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading recipes: $e')),
      );
    } finally {
      setState(() {
        _isLoadingRecipes = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>?> _showRecipeSelectionDialog(List<Map<String, dynamic>> recipes) async {
    List<Map<String, dynamic>> selectedRecipes = [];
    List<Map<String, dynamic>> filteredRecipes = List.from(recipes);
    TextEditingController searchController = TextEditingController();
    
    return showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.green.shade600, Colors.green.shade400],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.restaurant_menu,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Select Recipes',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${selectedRecipes.length} selected',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Search Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search recipes...',
                        hintStyle: TextStyle(color: Colors.grey.shade600),
                        prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, color: Colors.grey.shade600),
                                onPressed: () {
                                  searchController.clear();
                                  setDialogState(() {
                                    filteredRecipes = List.from(recipes);
                                  });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (value) {
                        setDialogState(() {
                          filteredRecipes = recipes.where((recipe) {
                            final title = recipe['title']?.toString().toLowerCase() ?? '';
                            final cuisine = recipe['cuisine']?.toString().toLowerCase() ?? '';
                            final searchTerm = value.toLowerCase();
                            return title.contains(searchTerm) || cuisine.contains(searchTerm);
                          }).toList();
                        });
                      },
                    ),
                  ),
                ),
                
                // Recipe List
                Expanded(
                  child: filteredRecipes.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.search_off,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No recipes found',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Try a different search term',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredRecipes.length,
                          itemBuilder: (context, index) {
                            final recipe = filteredRecipes[index];
                            final isSelected = selectedRecipes.contains(recipe);
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.green.shade50 : Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? Colors.green.shade300 : Colors.grey.shade200,
                                  width: isSelected ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.grey.withOpacity(0.1),
                                    spreadRadius: 1,
                                    blurRadius: 3,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: CheckboxListTile(
                                value: isSelected,
                                onChanged: (value) {
                                  setDialogState(() {
                                    if (value == true) {
                                      selectedRecipes.add(recipe);
                                    } else {
                                      selectedRecipes.remove(recipe);
                                    }
                                  });
                                },
                                title: Text(
                                  recipe['title'] ?? 'Unknown Recipe',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: isSelected ? Colors.green.shade700 : Colors.black87,
                                  ),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            recipe['cuisine'] ?? 'General',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.blue.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade100,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            recipe['mealType'] ?? 'Any',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.orange.shade700,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                secondary: CircleAvatar(
                                  backgroundColor: isSelected ? Colors.green.shade100 : Colors.grey.shade100,
                                  child: Icon(
                                    Icons.restaurant,
                                    color: isSelected ? Colors.green.shade600 : Colors.grey.shade600,
                                    size: 20,
                                  ),
                                ),
                                activeColor: Colors.green,
                                checkColor: Colors.white,
                              ),
                            );
                          },
                        ),
                ),
                
                // Bottom Actions
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            side: BorderSide(color: Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: selectedRecipes.isNotEmpty
                              ? () => Navigator.of(context).pop(selectedRecipes)
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text('Select ${selectedRecipes.length} Recipe${selectedRecipes.length != 1 ? 's' : ''}'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _generateShoppingList() async {
    setState(() {
      _isGenerating = true;
    });

    try {
      print('DEBUG: Starting shopping list generation with ${_selectedRecipes.length} recipes');
      print('DEBUG: Servings per recipe: $_servingsPerRecipe');
      
      // Extract ingredients from selected recipes
      // Use Map with normalized names as keys to combine plurals (e.g., "egg" and "eggs")
      Map<String, double> ingredientQuantities = {};
      Map<String, String> ingredientUnits = {};
      Map<String, String> ingredientCategories = {};
      Map<String, String> displayNames = {}; // Store original display name for each normalized key

      for (final recipe in _selectedRecipes) {
        print('DEBUG: Processing recipe: ${recipe['title']}');
        final ingredients = recipe['ingredients'] as List<dynamic>? ?? [];
        print('DEBUG: Found ${ingredients.length} ingredients');
        
        for (final ingredient in ingredients) {
          if (ingredient is String) {
            try {
              print('DEBUG: Processing ingredient: $ingredient');
              // Parse ingredient string (e.g., "2 cups rice", "1 lb chicken")
              final parsed = _parseIngredient(ingredient);
              final name = parsed['name'];
              final quantity = (parsed['quantity'] as double) * _servingsPerRecipe;
              final unit = parsed['unit'];
              final category = _categorizeIngredient(name);

              print('DEBUG: Parsed as: $quantity $unit $name ($category)');

              // Normalize the ingredient name to combine plurals
              final normalizedName = _normalizeIngredientName(name);
              print('DEBUG: Normalized name: $normalizedName for display: $name');

              if (ingredientQuantities.containsKey(normalizedName)) {
                ingredientQuantities[normalizedName] = ingredientQuantities[normalizedName]! + quantity;
              } else {
                ingredientQuantities[normalizedName] = quantity;
                ingredientUnits[normalizedName] = unit;
                ingredientCategories[normalizedName] = category;
                displayNames[normalizedName] = name; // Store original display name
              }
            } catch (e) {
              print('DEBUG: Error processing string ingredient: $e');
              print('DEBUG: Ingredient string: $ingredient');
              // Skip this ingredient if there's an error
            }
          } else if (ingredient is Map<String, dynamic>) {
            // Handle structured ingredient objects
            try {
              final name = ingredient['name'] ?? ingredient['originalName'] ?? 'Unknown';
              final amount = ingredient['amount'] ?? 1.0;
              final quantity = (amount is int ? amount.toDouble() : amount as double) * _servingsPerRecipe;
              final unit = ingredient['unit'] ?? ingredient['unitShort'] ?? 'piece';
              final category = _categorizeIngredient(name);
              
              print('DEBUG: Processing structured ingredient: $name ($quantity $unit)');

              // Normalize the ingredient name to combine plurals
              final normalizedName = _normalizeIngredientName(name);
              print('DEBUG: Normalized name: $normalizedName for display: $name');

              if (ingredientQuantities.containsKey(normalizedName)) {
                ingredientQuantities[normalizedName] = ingredientQuantities[normalizedName]! + quantity;
              } else {
                ingredientQuantities[normalizedName] = quantity;
                ingredientUnits[normalizedName] = unit;
                ingredientCategories[normalizedName] = category;
                displayNames[normalizedName] = name; // Store original display name
              }
            } catch (e) {
              print('DEBUG: Error processing structured ingredient: $e');
              print('DEBUG: Ingredient data: $ingredient');
              // Skip this ingredient if there's an error
            }
          }
        }
      }

      // Convert to shopping list format with display names
      _generatedShoppingList = ingredientQuantities.entries.map((entry) {
        final normalizedKey = entry.key;
        final displayName = displayNames[normalizedKey] ?? entry.key; // Use original display name if available
        return {
          'name': displayName, // Use the original display name (not normalized)
          'quantity': entry.value.toStringAsFixed(1),
          'unit': ingredientUnits[normalizedKey] ?? 'piece',
          'category': ingredientCategories[normalizedKey] ?? 'Other',
          'price': 0.0, // Initialize price to 0
          'checked': false,
        };
      }).toList();

      // Sort by category
      _generatedShoppingList.sort((a, b) => a['category'].compareTo(b['category']));

      print('DEBUG: Generated ${_generatedShoppingList.length} shopping list items');
      for (final item in _generatedShoppingList) {
        print('DEBUG: ${item['quantity']} ${item['unit']} ${item['name']} (${item['category']})');
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Shopping list generated successfully! ${_generatedShoppingList.length} items'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate to shopping list management page
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ShoppingListManagementPage(
            shoppingList: _generatedShoppingList,
            startDate: _selectedStartDate,
            endDate: _selectedEndDate,
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating shopping list: $e')),
      );
    } finally {
      setState(() {
        _isGenerating = false;
      });
    }
  }

  Map<String, dynamic> _parseIngredient(String ingredient) {
    // Enhanced ingredient parsing to handle various formats
    final trimmed = ingredient.trim();
    
    // Handle different ingredient formats
    if (trimmed.isEmpty) {
      return {
        'quantity': 1.0,
        'unit': 'piece',
        'name': 'Unknown ingredient',
      };
    }
    
    // Clean up common parsing issues
    String cleanedIngredient = trimmed;
    
    // Remove leading commas and spaces
    cleanedIngredient = cleanedIngredient.replaceFirst(RegExp(r'^,\s*'), '');
    
    // Fix common parsing issues
    cleanedIngredient = cleanedIngredient.replaceAll(RegExp(r'\s+'), ' '); // Multiple spaces to single
    cleanedIngredient = cleanedIngredient.replaceAll(RegExp(r',\s*$'), ''); // Remove trailing commas
    
    // Try to parse quantity and unit from the beginning
    final quantityMatch = RegExp(r'^(\d+(?:\.\d+)?)\s*([a-zA-Z]+)?').firstMatch(cleanedIngredient);
    
    if (quantityMatch != null) {
      final quantityStr = quantityMatch.group(1)!;
      final unitStr = quantityMatch.group(2) ?? '';
      final quantity = double.tryParse(quantityStr) ?? 1.0;
      
      // Extract the ingredient name (everything after quantity and unit)
      final nameStart = quantityMatch.end;
      String name = cleanedIngredient.substring(nameStart).trim();
      
      // Clean up the name further
      name = _cleanIngredientName(name);
      
      // Determine appropriate unit if not provided
      String unit = unitStr.isNotEmpty ? unitStr : _determineUnit(name);
      
      return {
        'quantity': quantity,
        'unit': unit,
        'name': name.isNotEmpty ? name : cleanedIngredient,
      };
    }
    
    // If no quantity found, treat as single ingredient
    return {
      'quantity': 1.0,
      'unit': 'piece',
      'name': _cleanIngredientName(cleanedIngredient),
    };
  }

  String _cleanIngredientName(String name) {
    // Clean up ingredient names
    String cleaned = name.trim();
    
    // Remove common prefixes and suffixes
    cleaned = cleaned.replaceFirst(RegExp(r'^,\s*'), ''); // Remove leading comma
    cleaned = cleaned.replaceFirst(RegExp(r',\s*$'), ''); // Remove trailing comma
    
    // Fix common issues
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' '); // Multiple spaces to single
    cleaned = cleaned.replaceAll(RegExp(r',\s*,+'), ','); // Multiple commas to single
    
    // Capitalize first letter
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }
    
    return cleaned;
  }

  /// Normalize ingredient name by removing plurals and converting to lowercase
  /// This allows "egg" and "eggs" to be combined, "carrot" and "carrots" to be combined, etc.
  String _normalizeIngredientName(String name) {
    if (name.isEmpty) return name;
    
    String normalized = name.toLowerCase().trim();
    
    // Remove trailing 's' for plurals (e.g., "eggs" -> "egg", "carrots" -> "carrot")
    // Only remove 's' if it's at the end and not part of another word
    if (normalized.endsWith('s') && normalized.length > 1) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    
    // Remove leading "a ", "an ", "the " articles
    normalized = normalized.replaceFirst(RegExp(r'^(a|an|the)\s+'), '');
    
    // Remove common measurement prefixes
    normalized = normalized.replaceAll(RegExp(r'^\d+(\.\d+)?\s*(cup|cups|tbsp|tsp|lb|kg|g|ml|l|oz|piece|pieces|slice|slices)\s+'), '');
    
    return normalized.trim();
  }

  String _determineUnit(String ingredientName) {
    final lowerName = ingredientName.toLowerCase();
    
    if (lowerName.contains('cup') || lowerName.contains('cups')) return 'cup';
    if (lowerName.contains('tbsp') || lowerName.contains('tablespoon')) return 'tbsp';
    if (lowerName.contains('tsp') || lowerName.contains('teaspoon')) return 'tsp';
    if (lowerName.contains('lb') || lowerName.contains('pound')) return 'lb';
    if (lowerName.contains('kg') || lowerName.contains('kilogram')) return 'kg';
    if (lowerName.contains('g') || lowerName.contains('gram')) return 'g';
    if (lowerName.contains('ml') || lowerName.contains('milliliter')) return 'ml';
    if (lowerName.contains('l') || lowerName.contains('liter')) return 'L';
    if (lowerName.contains('oz') || lowerName.contains('ounce')) return 'oz';
    if (lowerName.contains('can') || lowerName.contains('cans')) return 'can';
    if (lowerName.contains('jar') || lowerName.contains('jars')) return 'jar';
    if (lowerName.contains('bottle') || lowerName.contains('bottles')) return 'bottle';
    if (lowerName.contains('package') || lowerName.contains('packages')) return 'package';
    if (lowerName.contains('bag') || lowerName.contains('bags')) return 'bag';
    if (lowerName.contains('box') || lowerName.contains('boxes')) return 'box';
    if (lowerName.contains('head') || lowerName.contains('heads')) return 'head';
    if (lowerName.contains('clove') || lowerName.contains('cloves')) return 'clove';
    if (lowerName.contains('serving') || lowerName.contains('servings')) return 'serving';
    if (lowerName.contains('slice') || lowerName.contains('slices')) return 'slice';
    if (lowerName.contains('piece') || lowerName.contains('pieces')) return 'piece';
    
    return 'piece'; // Default unit
  }

  String _categorizeIngredient(String ingredient) {
    final lowerIngredient = ingredient.toLowerCase();
    
    // Grains and Starches
    if (lowerIngredient.contains('rice') || lowerIngredient.contains('pasta') || 
        lowerIngredient.contains('bread') || lowerIngredient.contains('wrapper') ||
        lowerIngredient.contains('flour') || lowerIngredient.contains('noodles')) {
      return 'Grains';
    } 
    // Meat and Protein
    else if (lowerIngredient.contains('chicken') || lowerIngredient.contains('beef') || 
             lowerIngredient.contains('pork') || lowerIngredient.contains('fish') ||
             lowerIngredient.contains('meat') || lowerIngredient.contains('ground') ||
             lowerIngredient.contains('shrimp') || lowerIngredient.contains('egg') ||
             lowerIngredient.contains('egg beaters')) {
      return 'Meat';
    } 
    // Vegetables
    else if (lowerIngredient.contains('onion') || lowerIngredient.contains('garlic') || 
             lowerIngredient.contains('tomato') || lowerIngredient.contains('vegetable') ||
             lowerIngredient.contains('carrot') || lowerIngredient.contains('cabbage') ||
             lowerIngredient.contains('lettuce') || lowerIngredient.contains('spinach') ||
             lowerIngredient.contains('pepper') || lowerIngredient.contains('cucumber')) {
      return 'Vegetables';
    } 
    // Dairy
    else if (lowerIngredient.contains('milk') || lowerIngredient.contains('cheese') || 
             lowerIngredient.contains('yogurt') || lowerIngredient.contains('butter') ||
             lowerIngredient.contains('cream')) {
      return 'Dairy';
    } 
    // Condiments and Sauces
    else if (lowerIngredient.contains('oil') || lowerIngredient.contains('vinegar') || 
             lowerIngredient.contains('soy') || lowerIngredient.contains('sauce') ||
             lowerIngredient.contains('salt') || lowerIngredient.contains('pepper') ||
             lowerIngredient.contains('spice') || lowerIngredient.contains('seasoning') ||
             lowerIngredient.contains('fish sauce') || lowerIngredient.contains('patis')) {
      return 'Condiments';
    } 
    // Fruits
    else if (lowerIngredient.contains('banana') || lowerIngredient.contains('apple') || 
             lowerIngredient.contains('orange') || lowerIngredient.contains('mango') ||
             lowerIngredient.contains('pineapple') || lowerIngredient.contains('lemon') ||
             lowerIngredient.contains('lime') || lowerIngredient.contains('calamansi')) {
      return 'Fruits';
    }
    // Filipino specific ingredients
    else if (lowerIngredient.contains('coconut') || lowerIngredient.contains('palm') ||
             lowerIngredient.contains('bagoong') || lowerIngredient.contains('achuete') ||
             lowerIngredient.contains('tamarind') || lowerIngredient.contains('bay leaves') ||
             lowerIngredient.contains('lemongrass') || lowerIngredient.contains('ginger') ||
             lowerIngredient.contains('turmeric')) {
      return 'Filipino';
    }
    else {
      return 'Other';
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'Grains':
        return Icons.grain;
      case 'Meat':
        return Icons.restaurant;
      case 'Vegetables':
        return Icons.eco;
      case 'Dairy':
        return Icons.local_drink;
      case 'Condiments':
        return Icons.local_bar;
      case 'Fruits':
        return Icons.apple;
      case 'Filipino':
        return Icons.flag;
      default:
        return Icons.shopping_basket;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Grains':
        return Colors.amber;
      case 'Meat':
        return Colors.red;
      case 'Vegetables':
        return Colors.green;
      case 'Dairy':
        return Colors.blue;
      case 'Condiments':
        return Colors.orange;
      case 'Fruits':
        return Colors.pink;
      case 'Filipino':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _toggleAllItems() {
    final allChecked = _generatedShoppingList.every((item) => item['checked'] == true);
    setState(() {
      for (final item in _generatedShoppingList) {
        item['checked'] = !allChecked;
      }
    });
  }

  void _shareShoppingList() {
    final uncheckedItems = _generatedShoppingList.where((item) => item['checked'] != true).toList();
    final checkedItems = _generatedShoppingList.where((item) => item['checked'] == true).toList();
    
    // Group items by category
    final Map<String, List<Map<String, dynamic>>> groupedItems = {};
    for (final item in uncheckedItems) {
      final category = item['category'] ?? 'Other';
      if (!groupedItems.containsKey(category)) {
        groupedItems[category] = [];
      }
      groupedItems[category]!.add(item);
    }
    
    String listText = '🛒 Shopping List\n';
    listText += '📅 ${DateFormat('MMM dd').format(_selectedStartDate)} - ${DateFormat('MMM dd, yyyy').format(_selectedEndDate)}\n\n';
    
    if (uncheckedItems.isNotEmpty) {
      listText += '📝 To Buy:\n';
      
      // Sort categories for consistent ordering
      final sortedCategories = groupedItems.keys.toList()..sort();
      
      for (final category in sortedCategories) {
        final items = groupedItems[category]!;
        listText += '\n${_getCategoryIcon(category)} $category:\n';
        for (final item in items) {
          listText += '• ${item['quantity']} ${item['unit']} ${item['name']}\n';
        }
      }
      
      if (checkedItems.isNotEmpty) {
        listText += '\n✅ Already Bought:\n';
        for (final item in checkedItems) {
          listText += '• ${item['quantity']} ${item['unit']} ${item['name']}\n';
        }
      }
    } else if (checkedItems.isNotEmpty) {
      listText += '✅ All items bought!\n';
      for (final item in checkedItems) {
        listText += '• ${item['quantity']} ${item['unit']} ${item['name']}\n';
      }
    } else {
      listText += 'No items in shopping list.';
    }
    
    // Show share dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Shopping List'),
        content: SingleChildScrollView(
          child: SelectableText(
            listText,
            style: const TextStyle(fontSize: 14),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              // Here you could implement actual sharing functionality
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Shopping list copied to clipboard!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }
}
