import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class IngredientsManagementPage extends StatefulWidget {
  const IngredientsManagementPage({super.key});

  @override
  State<IngredientsManagementPage> createState() => _IngredientsManagementPageState();
}

class _IngredientsManagementPageState extends State<IngredientsManagementPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _caloriesController = TextEditingController();
  final TextEditingController _proteinController = TextEditingController();
  final TextEditingController _carbsController = TextEditingController();
  final TextEditingController _fatController = TextEditingController();
  final TextEditingController _fiberController = TextEditingController();

  Map<String, dynamic> _ingredients = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadIngredients();
  }

  Future<void> _loadIngredients() async {
    try {
      setState(() => _isLoading = true);
      final doc = await FirebaseFirestore.instance
          .collection('system_data')
          .doc('ingredient_nutrition')
          .get();

      if (doc.exists && doc.data()?['ingredients'] != null) {
        setState(() {
          _ingredients = Map<String, dynamic>.from(doc.data()?['ingredients'] ?? {});
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading ingredients: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addIngredient() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter ingredient name')),
      );
      return;
    }

    final ingredientName = _nameController.text.trim();
    
    // Check if ingredient already exists
    if (_ingredients.containsKey(ingredientName)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('"$ingredientName" already exists!'),
          action: SnackBarAction(
            label: 'Update',
            onPressed: () async {
              // Update existing ingredient
              final nutrition = {
                'calories': double.tryParse(_caloriesController.text) ?? 0.0,
                'protein': double.tryParse(_proteinController.text) ?? 0.0,
                'carbs': double.tryParse(_carbsController.text) ?? 0.0,
                'fat': double.tryParse(_fatController.text) ?? 0.0,
                'fiber': double.tryParse(_fiberController.text) ?? 0.0,
              };

              _ingredients[ingredientName] = nutrition;

              try {
                await FirebaseFirestore.instance
                    .collection('system_data')
                    .doc('ingredient_nutrition')
                    .set({
                  'ingredients': _ingredients,
                  'lastUpdated': FieldValue.serverTimestamp(),
                  'count': _ingredients.length,
                }, SetOptions(merge: true));

                setState(() {});
                _clearFields();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingredient updated successfully!')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
          ),
        ),
      );
      return;
    }

    try {
      final nutrition = {
        'calories': double.tryParse(_caloriesController.text) ?? 0.0,
        'protein': double.tryParse(_proteinController.text) ?? 0.0,
        'carbs': double.tryParse(_carbsController.text) ?? 0.0,
        'fat': double.tryParse(_fatController.text) ?? 0.0,
        'fiber': double.tryParse(_fiberController.text) ?? 0.0,
      };

      _ingredients[ingredientName] = nutrition;

      await FirebaseFirestore.instance
          .collection('system_data')
          .doc('ingredient_nutrition')
          .set({
        'ingredients': _ingredients,
        'lastUpdated': FieldValue.serverTimestamp(),
        'count': _ingredients.length,
      }, SetOptions(merge: true));

      setState(() {});
      _clearFields();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingredient added successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _addBatchIngredients() async {
    // Comprehensive ingredient database with nutrition data
    final batchIngredients = {
      // Vegetables
      'Carrots': {'calories': 25, 'protein': 0.5, 'carbs': 6, 'fat': 0.2, 'fiber': 1.5},
    'Broccoli': {'calories': 35, 'protein': 3.0, 'carbs': 6.5, 'fat': 0.4, 'fiber': 2.5},
    'Spinach': {'calories': 7, 'protein': 0.9, 'carbs': 1.1, 'fat': 0.1, 'fiber': 0.7},
    'Tomatoes': {'calories': 18, 'protein': 0.9, 'carbs': 3.9, 'fat': 0.2, 'fiber': 1.2},
    'Onion': {'calories': 40, 'protein': 1.1, 'carbs': 9.3, 'fat': 0.1, 'fiber': 1.7},
    'Garlic': {'calories': 149, 'protein': 6.4, 'carbs': 33, 'fat': 0.5, 'fiber': 2.1},
    'Bell peppers': {'calories': 20, 'protein': 1.0, 'carbs': 4.8, 'fat': 0.2, 'fiber': 1.5},
    'Cucumber': {'calories': 15, 'protein': 0.6, 'carbs': 3.6, 'fat': 0.1, 'fiber': 0.5},
    'Cabbage': {'calories': 25, 'protein': 1.3, 'carbs': 5.8, 'fat': 0.1, 'fiber': 2.5},
    'Cauliflower': {'calories': 25, 'protein': 1.9, 'carbs': 5.0, 'fat': 0.3, 'fiber': 2.0},
    'Zucchini': {'calories': 17, 'protein': 1.2, 'carbs': 3.4, 'fat': 0.3, 'fiber': 1.0},
    'Eggplant': {'calories': 25, 'protein': 1.0, 'carbs': 6.0, 'fat': 0.2, 'fiber': 3.0},
    'Potatoes': {'calories': 87, 'protein': 2.0, 'carbs': 20, 'fat': 0.1, 'fiber': 2.2},
    'Sweet potatoes': {'calories': 86, 'protein': 1.6, 'carbs': 20, 'fat': 0.1, 'fiber': 3.0},
    'Lettuce': {'calories': 5, 'protein': 0.5, 'carbs': 1.0, 'fat': 0.1, 'fiber': 0.5},

    // Fruits
    'Bananas': {'calories': 89, 'protein': 1.1, 'carbs': 23, 'fat': 0.3, 'fiber': 2.6},
    'Apples': {'calories': 52, 'protein': 0.3, 'carbs': 14, 'fat': 0.2, 'fiber': 2.4},
    'Oranges': {'calories': 47, 'protein': 0.9, 'carbs': 12, 'fat': 0.1, 'fiber': 2.4},
    'Strawberries': {'calories': 32, 'protein': 0.7, 'carbs': 7.7, 'fat': 0.3, 'fiber': 2.0},
    'Avocado': {'calories': 160, 'protein': 2.0, 'carbs': 8.5, 'fat': 14.7, 'fiber': 6.7},
    'Mango': {'calories': 60, 'protein': 0.8, 'carbs': 15, 'fat': 0.4, 'fiber': 1.6},
    'Pineapple': {'calories': 50, 'protein': 0.5, 'carbs': 13, 'fat': 0.1, 'fiber': 1.4},
    'Grapes': {'calories': 69, 'protein': 0.7, 'carbs': 18, 'fat': 0.2, 'fiber': 0.9},
    'Watermelon': {'calories': 30, 'protein': 0.6, 'carbs': 7.6, 'fat': 0.2, 'fiber': 0.4},

    // Meats & Proteins
    'Chicken breast': {'calories': 165, 'protein': 31, 'carbs': 0, 'fat': 3.6, 'fiber': 0},
    'Ground pork': {'calories': 297, 'protein': 14, 'carbs': 0, 'fat': 26, 'fiber': 0},
    'Pork': {'calories': 242, 'protein': 27, 'carbs': 0, 'fat': 13.9, 'fiber': 0},
    'Beef': {'calories': 250, 'protein': 26, 'carbs': 0, 'fat': 17, 'fiber': 0},
    'Fish (salmon)': {'calories': 208, 'protein': 20, 'carbs': 0, 'fat': 12, 'fiber': 0},
    'Tuna': {'calories': 132, 'protein': 30, 'carbs': 0, 'fat': 0.6, 'fiber': 0},
    'Shrimp': {'calories': 85, 'protein': 18, 'carbs': 0.9, 'fat': 0.5, 'fiber': 0},
    'Eggs': {'calories': 70, 'protein': 6, 'carbs': 0.6, 'fat': 5, 'fiber': 0},
    'Egg': {'calories': 70, 'protein': 6, 'carbs': 0.6, 'fat': 5, 'fiber': 0},
    'Tofu': {'calories': 76, 'protein': 8, 'carbs': 1.9, 'fat': 4.8, 'fiber': 0.3},
    'Chickpeas': {'calories': 164, 'protein': 8.9, 'carbs': 27, 'fat': 2.6, 'fiber': 7.6},
    'Black beans': {'calories': 132, 'protein': 8.9, 'carbs': 24, 'fat': 0.5, 'fiber': 7.5},
    'Lentils': {'calories': 116, 'protein': 9, 'carbs': 20, 'fat': 0.4, 'fiber': 7.9},

    // Dairy
    'Milk': {'calories': 42, 'protein': 3.4, 'carbs': 5, 'fat': 1, 'fiber': 0},
    'Cheese': {'calories': 113, 'protein': 7, 'carbs': 0.9, 'fat': 9, 'fiber': 0},
    'Yogurt': {'calories': 59, 'protein': 10, 'carbs': 3.6, 'fat': 0.4, 'fiber': 0},
    'Butter': {'calories': 717, 'protein': 0.9, 'carbs': 0.1, 'fat': 81, 'fiber': 0},
    'Sour cream': {'calories': 193, 'protein': 2.9, 'carbs': 4.6, 'fat': 19, 'fiber': 0},

    // Grains & Starches
    'Rice': {'calories': 130, 'protein': 2.7, 'carbs': 28, 'fat': 0.3, 'fiber': 0.4},
    'Bread': {'calories': 265, 'protein': 9, 'carbs': 49, 'fat': 3.2, 'fiber': 2.7},
    'Pasta': {'calories': 131, 'protein': 5, 'carbs': 25, 'fat': 1.1, 'fiber': 1.8},
    'Oats': {'calories': 389, 'protein': 16.9, 'carbs': 66, 'fat': 6.9, 'fiber': 10.6},
    'Quinoa': {'calories': 222, 'protein': 8, 'carbs': 39, 'fat': 3.6, 'fiber': 5.2},
    'Corn': {'calories': 96, 'protein': 3.4, 'carbs': 21, 'fat': 1.2, 'fiber': 2.7},
    'Flour': {'calories': 364, 'protein': 10, 'carbs': 76, 'fat': 1, 'fiber': 2.7},

    // Condiments & Oils
    'Olive oil': {'calories': 884, 'protein': 0, 'carbs': 0, 'fat': 100, 'fiber': 0},
    'Vegetable oil': {'calories': 884, 'protein': 0, 'carbs': 0, 'fat': 100, 'fiber': 0},
    'Cooking oil': {'calories': 884, 'protein': 0, 'carbs': 0, 'fat': 100, 'fiber': 0},
    'Salt': {'calories': 0, 'protein': 0, 'carbs': 0, 'fat': 0, 'fiber': 0},
    'Black pepper': {'calories': 251, 'protein': 10.4, 'carbs': 64, 'fat': 3.3, 'fiber': 25.3},
    'Garlic powder': {'calories': 332, 'protein': 16.6, 'carbs': 73, 'fat': 0.8, 'fiber': 8.9},
    'Paprika': {'calories': 282, 'protein': 14.1, 'carbs': 54, 'fat': 12.9, 'fiber': 34.9},
    'Cumin': {'calories': 375, 'protein': 17.8, 'carbs': 44, 'fat': 22.3, 'fiber': 10.5},
    'Coriander': {'calories': 23, 'protein': 2.1, 'carbs': 3.7, 'fat': 0.5, 'fiber': 2.8},
    'Parsley': {'calories': 36, 'protein': 3.0, 'carbs': 6.3, 'fat': 0.8, 'fiber': 3.3},

    // Nuts & Seeds
    'Almonds': {'calories': 579, 'protein': 21, 'carbs': 22, 'fat': 50, 'fiber': 12.5},
    'Peanuts': {'calories': 567, 'protein': 26, 'carbs': 16, 'fat': 49, 'fiber': 8.5},
    'Walnuts': {'calories': 654, 'protein': 15, 'carbs': 14, 'fat': 65, 'fiber': 6.7},
    'Cashews': {'calories': 553, 'protein': 18, 'carbs': 30, 'fat': 44, 'fiber': 3.3},
    'Chia seeds': {'calories': 486, 'protein': 17, 'carbs': 42, 'fat': 31, 'fiber': 34.4},
    'Sesame seeds': {'calories': 573, 'protein': 18, 'carbs': 24, 'fat': 50, 'fiber': 14},

    // Filipino Specific Ingredients
    'Soy sauce': {'calories': 8, 'protein': 1.3, 'carbs': 0.8, 'fat': 0.1, 'fiber': 0},
    'Fish sauce': {'calories': 35, 'protein': 5.5, 'carbs': 3.5, 'fat': 0, 'fiber': 0},
    'Vinegar': {'calories': 18, 'protein': 0, 'carbs': 1, 'fat': 0, 'fiber': 0},
    'Coconut milk': {'calories': 230, 'protein': 2.3, 'carbs': 6, 'fat': 24, 'fiber': 0},
    'Coconut oil': {'calories': 862, 'protein': 0, 'carbs': 0, 'fat': 99.5, 'fiber': 0},
    'Lumpia wrapper': {'calories': 50, 'protein': 1.5, 'carbs': 10, 'fat': 1, 'fiber': 0.5},
    'Bagoong': {'calories': 70, 'protein': 10, 'carbs': 3, 'fat': 1, 'fiber': 0},
    'Atsuete': {'calories': 180, 'protein': 0.5, 'carbs': 40, 'fat': 0, 'fiber': 0},
    'Bagoong alamang': {'calories': 70, 'protein': 10, 'carbs': 3, 'fat': 1, 'fiber': 0},
    'Tamarind': {'calories': 239, 'protein': 2.8, 'carbs': 63, 'fat': 0.6, 'fiber': 5.1},
    'Sampalok': {'calories': 239, 'protein': 2.8, 'carbs': 63, 'fat': 0.6, 'fiber': 5.1},
    'Labanos': {'calories': 16, 'protein': 0.7, 'carbs': 3.4, 'fat': 0.1, 'fiber': 1.6},
    'Kamote': {'calories': 86, 'protein': 1.6, 'carbs': 20, 'fat': 0.1, 'fiber': 3.0},
    'Singkamas': {'calories': 35, 'protein': 0.7, 'carbs': 7.9, 'fat': 0.1, 'fiber': 1.5},
    'Kalabasa': {'calories': 45, 'protein': 1.0, 'carbs': 12, 'fat': 0.1, 'fiber': 2.8},

    // Additional common ingredients
    'Tomato sauce': {'calories': 24, 'protein': 1.2, 'carbs': 5.3, 'fat': 0.2, 'fiber': 1.5},
    'Tomato paste': {'calories': 82, 'protein': 4.3, 'carbs': 18, 'fat': 0.5, 'fiber': 3.1},
    'Chicken broth': {'calories': 21, 'protein': 2.5, 'carbs': 0.4, 'fat': 0.8, 'fiber': 0},
    'Beef broth': {'calories': 17, 'protein': 2.5, 'carbs': 0.2, 'fat': 0.5, 'fiber': 0},
    'Lemongrass': {'calories': 99, 'protein': 1.8, 'carbs': 25, 'fat': 0.5, 'fiber': 0},
    'Ginger': {'calories': 80, 'protein': 1.8, 'carbs': 18, 'fat': 0.8, 'fiber': 2},
    'Coconut cream': {'calories': 230, 'protein': 2.3, 'carbs': 6, 'fat': 24, 'fiber': 0},
    'Lime juice': {'calories': 29, 'protein': 0.7, 'carbs': 9.3, 'fat': 0.1, 'fiber': 0.4},
    'Lemon juice': {'calories': 22, 'protein': 0.4, 'carbs': 6.9, 'fat': 0.2, 'fiber': 0.3},
    'Honey': {'calories': 304, 'protein': 0.3, 'carbs': 82, 'fat': 0, 'fiber': 0.2},
    'Sugar': {'calories': 387, 'protein': 0, 'carbs': 100, 'fat': 0, 'fiber': 0},
    'Brown sugar': {'calories': 380, 'protein': 0.1, 'carbs': 98, 'fat': 0, 'fiber': 0},
    'Maple syrup': {'calories': 260, 'protein': 0, 'carbs': 67, 'fat': 0, 'fiber': 0},
    'Worcestershire sauce': {'calories': 22, 'protein': 0.4, 'carbs': 4.5, 'fat': 0, 'fiber': 0},
    'Ketchup': {'calories': 112, 'protein': 1.7, 'carbs': 26, 'fat': 0.3, 'fiber': 0.8},
    'Mustard': {'calories': 66, 'protein': 3.7, 'carbs': 5.8, 'fat': 3.9, 'fiber': 3.1},
    'Mayonnaise': {'calories': 680, 'protein': 1, 'carbs': 0.6, 'fat': 75, 'fiber': 0},
    'Hot sauce': {'calories': 0, 'protein': 0, 'carbs': 1, 'fat': 0, 'fiber': 0},
    'Chili peppers': {'calories': 40, 'protein': 2, 'carbs': 9, 'fat': 0.2, 'fiber': 1.5},
    'Jalapeños': {'calories': 29, 'protein': 1.4, 'carbs': 7, 'fat': 0.4, 'fiber': 2.5},
    'Cilantro': {'calories': 23, 'protein': 2.1, 'carbs': 3.7, 'fat': 0.5, 'fiber': 2.8},
    'Basil': {'calories': 22, 'protein': 3.2, 'carbs': 2.6, 'fat': 0.6, 'fiber': 1.6},
    'Oregano': {'calories': 306, 'protein': 10.9, 'carbs': 69, 'fat': 10.2, 'fiber': 43},
    'Thyme': {'calories': 276, 'protein': 9.1, 'carbs': 63, 'fat': 7.4, 'fiber': 37},
    'Rosemary': {'calories': 331, 'protein': 4.9, 'carbs': 65, 'fat': 15.2, 'fiber': 42.6},
    'Bay leaves': {'calories': 313, 'protein': 7.6, 'carbs': 75, 'fat': 8.4, 'fiber': 26.8},

    // Additional proteins
    'Ground beef': {'calories': 250, 'protein': 17, 'carbs': 0, 'fat': 20, 'fiber': 0},
    'Beef liver': {'calories': 191, 'protein': 29, 'carbs': 5.1, 'fat': 4.7, 'fiber': 0},
    'Pork liver': {'calories': 134, 'protein': 21, 'carbs': 2.5, 'fat': 3.7, 'fiber': 0},
    'Bacon': {'calories': 541, 'protein': 37, 'carbs': 1.4, 'fat': 42, 'fiber': 0},
    'Ham': {'calories': 145, 'protein': 21, 'carbs': 1.5, 'fat': 5.5, 'fiber': 0},
    'Sausage': {'calories': 301, 'protein': 13, 'carbs': 2, 'fat': 26, 'fiber': 0},
    'Turkey': {'calories': 104, 'protein': 30, 'carbs': 0, 'fat': 1.7, 'fiber': 0},

    // More vegetables
    'Mushrooms': {'calories': 22, 'protein': 3.1, 'carbs': 3.3, 'fat': 0.3, 'fiber': 1},
    'Asparagus': {'calories': 20, 'protein': 2.2, 'carbs': 3.9, 'fat': 0.1, 'fiber': 2.1},
    'Green beans': {'calories': 31, 'protein': 1.8, 'carbs': 7, 'fat': 0.1, 'fiber': 3.4},
    'Peas': {'calories': 81, 'protein': 5.4, 'carbs': 14, 'fat': 0.4, 'fiber': 5.1},
    'Corn': {'calories': 96, 'protein': 3.4, 'carbs': 21, 'fat': 1.2, 'fiber': 2.7},
    'Celery': {'calories': 16, 'protein': 0.7, 'carbs': 3, 'fat': 0.2, 'fiber': 1.6},
    'Radish': {'calories': 16, 'protein': 0.7, 'carbs': 3.4, 'fat': 0.1, 'fiber': 1.6},
    'Beets': {'calories': 43, 'protein': 1.6, 'carbs': 10, 'fat': 0.2, 'fiber': 2.8},

    // Dried fruits & Nuts
    'Raisins': {'calories': 299, 'protein': 3.1, 'carbs': 79, 'fat': 0.5, 'fiber': 3.7},
    'Dates': {'calories': 282, 'protein': 2.5, 'carbs': 75, 'fat': 0.4, 'fiber': 6.7},
    'Dried apricots': {'calories': 241, 'protein': 3.4, 'carbs': 63, 'fat': 0.5, 'fiber': 7.3},

    // Spices & Seasonings
    'Cinnamon': {'calories': 247, 'protein': 4, 'carbs': 80.6, 'fat': 1.2, 'fiber': 53.1},
    'Turmeric': {'calories': 354, 'protein': 7.8, 'carbs': 65, 'fat': 9.9, 'fiber': 21.1},
    'Bay leaves': {'calories': 313, 'protein': 7.6, 'carbs': 75, 'fat': 8.4, 'fiber': 26.8},
    'Cardamom': {'calories': 311, 'protein': 11, 'carbs': 68, 'fat': 6.7, 'fiber': 28},
    'Ginger': {'calories': 80, 'protein': 1.8, 'carbs': 18, 'fat': 0.8, 'fiber': 2},
    'Lemongrass': {'calories': 99, 'protein': 1.8, 'carbs': 25, 'fat': 0.5, 'fiber': 0},
    };

    // Merge with existing ingredients
    _ingredients.addAll(batchIngredients);

    try {
      await FirebaseFirestore.instance
          .collection('system_data')
          .doc('ingredient_nutrition')
          .set({
        'ingredients': _ingredients,
        'lastUpdated': FieldValue.serverTimestamp(),
        'count': _ingredients.length,
      }, SetOptions(merge: true));

      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully added ${batchIngredients.length} ingredients!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _clearFields() {
    _nameController.clear();
    _caloriesController.clear();
    _proteinController.clear();
    _carbsController.clear();
    _fatController.clear();
    _fiberController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingredients Management'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadIngredients,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Add Ingredient Form
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey[100],
                  child: Column(
                    children: [
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Ingredient Name',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lunch_dining),
                        ),
                      ),
                      const SizedBox(height: 8),
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
                                labelText: 'Protein',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _carbsController,
                              decoration: const InputDecoration(
                                labelText: 'Carbs',
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
                                labelText: 'Fat',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _fiberController,
                        decoration: const InputDecoration(
                          labelText: 'Fiber',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _addIngredient,
                              icon: const Icon(Icons.add),
                              label: const Text('Add Ingredient'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _addBatchIngredients,
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Add Batch'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Ingredients List
                Expanded(
                  child: _ingredients.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.lunch_dining, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'No ingredients yet',
                                style: TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Add ingredients using the form above',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _ingredients.length,
                          itemBuilder: (context, index) {
                            final name = _ingredients.keys.toList()[index];
                            final nutrition = _ingredients[name];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.green[100],
                                  child: Text('${index + 1}'),
                                ),
                                title: Text(name),
                                subtitle: Text(
                                  'Cal: ${nutrition['calories']} | P: ${nutrition['protein']} | C: ${nutrition['carbs']} | F: ${nutrition['fat']} | Fi: ${nutrition['fiber']}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete),
                                  onPressed: () async {
                                    _ingredients.remove(name);
                                    await FirebaseFirestore.instance
                                        .collection('system_data')
                                        .doc('ingredient_nutrition')
                                        .set({
                                      'ingredients': _ingredients,
                                      'lastUpdated': FieldValue.serverTimestamp(),
                                      'count': _ingredients.length,
                                    }, SetOptions(merge: true));
                                    setState(() {});
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _fiberController.dispose();
    super.dispose();
  }
}

