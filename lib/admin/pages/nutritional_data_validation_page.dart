import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../services/nutrition_service.dart';
import '../../services/meal_validation_service.dart';

class _TableHeaderCell extends StatelessWidget {
  final String label;
  const _TableHeaderCell(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      color: Colors.blueGrey.withOpacity(0.08),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.blueGrey),
      ),
    );
  }
}

class _TableDataCell extends StatelessWidget {
  final String value;
  final bool isBold;
  final Color? color;
  const _TableDataCell(this.value, {this.isBold = false, this.color, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        value,
        style: TextStyle(
          fontSize: 12,
          fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
          color: color ?? Colors.black87,
        ),
      ),
    );
  }
}

class NutritionalDataValidationPage extends StatefulWidget {
  const NutritionalDataValidationPage({super.key});

  @override
  State<NutritionalDataValidationPage> createState() => _NutritionalDataValidationPageState();
}

class _NutritionalDataValidationPageState extends State<NutritionalDataValidationPage> with TickerProviderStateMixin {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  Future<void> _promptRecipeRevision(Map<String, dynamic> recipe, String source) async {
    final controller = TextEditingController(text: recipe['revisionNote'] ?? '');

    final shouldSend = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Request Recipe Revision'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Explain why this recipe needs updates:'),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Please provide specific revision notes...',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Add revision notes before sending'), backgroundColor: Colors.orange),
                    );
                    return;
                  }
                  Navigator.pop(context, true);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                child: const Text('Send Revision Request'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldSend) return;

    final note = controller.text.trim();

    try {
      if (source == 'filipino') {
        final docRef = FirebaseFirestore.instance.collection('system_data').doc('filipino_recipes');
        final doc = await docRef.get();
        final data = doc.data();
        final recipes = List<Map<String, dynamic>>.from(data?['data'] ?? []);
        final index = recipes.indexWhere((r) => r['id'] == recipe['id']);
        if (index != -1) {
          recipes[index]['needsRevision'] = true;
          recipes[index]['revisionNote'] = note;
          recipes[index]['nutritionValidated'] = false;
          recipes[index]['validatedBy'] = null;
          await docRef.update({'data': recipes});
        }
      } else {
        await FirebaseFirestore.instance.collection('admin_recipes').doc(recipe['id']).update({
          'needsRevision': true,
          'revisionNote': note,
          'nutritionValidated': false,
          'validatedBy': null,
          'validatedAt': null,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Revision request sent to recipe owner'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error requesting revision: $e'), backgroundColor: Colors.red),
        );
      }
    }
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
            Tab(text: 'Meal Validation', icon: Icon(Icons.restaurant_menu)),
            Tab(text: 'Ingredient Database', icon: Icon(Icons.inventory_2)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMealValidationTab(),
          Column(
            children: [
              // Search bar for ingredients
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search ingredients...',
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
                child: _buildIngredientDatabaseTab(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // MEAL VALIDATION TAB
  Widget _buildMealValidationTab() {
    return _MealValidationTabContent();
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
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _promptRecipeRevision(recipe, source),
                          icon: const Icon(Icons.warning, size: 16),
                          label: const Text('Request Revision', style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
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

  TableRow? _buildMacroComparisonRow(String label, dynamic actual, dynamic target, {String suffix = ''}) {
    final actualValue = _parseDouble(actual);
    final targetValue = _parseDouble(target);
    if (actualValue == 0 && targetValue == 0) return null;

    final variance = actualValue - targetValue;
    String varianceLabel;
    Color varianceColor;

    if (targetValue == 0 && actualValue == 0) {
      varianceLabel = 'On target';
      varianceColor = Colors.green[700]!;
    } else if (targetValue == 0) {
      varianceLabel = '+${_formatValue(actualValue, suffix)}';
      varianceColor = Colors.orange[700]!;
    } else if (variance.abs() <= targetValue * 0.1) {
      varianceLabel = 'On target';
      varianceColor = Colors.green[700]!;
    } else if (variance > 0) {
      varianceLabel = '+${_formatValue(variance, suffix)}';
      varianceColor = Colors.red[700]!;
    } else {
      varianceLabel = '-${_formatValue(variance.abs(), suffix)}';
      varianceColor = Colors.orange[700]!;
    }

    return TableRow(children: [
      _TableDataCell(label, isBold: true),
      _TableDataCell(_formatValue(actualValue, suffix)),
      _TableDataCell(_formatValue(targetValue, suffix)),
      _TableDataCell(varianceLabel, color: varianceColor),
    ]);
  }

  String _formatValue(double value, String suffix) {
    final formatted = value.abs() >= 10 ? value.round().toString() : value.toStringAsFixed(1);
    return suffix.isEmpty ? formatted : '$formatted $suffix';
  }

  Widget _buildMacroInsights(
    Map<String, dynamic> actual,
    Map<String, dynamic> targets,
    Map<String, dynamic> profile,
  ) {
    final conditions = List<String>.from(profile['healthConditions'] ?? const [])
        .map((c) => c.toString().toLowerCase())
        .where((c) => c != 'none')
        .toList();

    final insights = <String>[];
    final actualCarbs = _parseDouble(actual['carbs']);
    final targetCarbs = _parseDouble(targets['carbs']);
    final actualFat = _parseDouble(actual['fat']);
    final targetFat = _parseDouble(targets['fat']);

    if (conditions.any((c) => c.contains('diabetes')) && actualCarbs > targetCarbs) {
      insights.add('Consider reducing carbohydrate portions to support diabetes management goals.');
    }

    if (conditions.any((c) => c.contains('cholesterol')) && actualFat > targetFat) {
      insights.add('High fat content detected; adjust saturated fat sources for cholesterol management.');
    }

    if (insights.isEmpty) {
      insights.add('Macros are generally aligned with personalized targets.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: insights
          .map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 16, color: Colors.teal),
                  const SizedBox(width: 6),
                  Expanded(child: Text(text, style: TextStyle(color: Colors.grey[700], fontSize: 12))),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildIngredientTable(List<String> ingredients, {bool compact = false}) {
    final maxItems = compact ? 6 : ingredients.length;
    final display = ingredients.take(maxItems).toList();
    final remaining = ingredients.length - display.length;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
        color: Colors.green.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.list_alt, size: 18, color: Colors.green),
                const SizedBox(width: 8),
                Text('Ingredients (${ingredients.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
                if (remaining > 0) ...[
                  const SizedBox(width: 8),
                  Text('+${remaining} more', style: TextStyle(color: Colors.green[800], fontSize: 12)),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          ...display.map(
            (ingredient) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.circle, size: 6, color: Colors.green),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(ingredient, style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showReviewDialog(
    String validationId,
    Map<String, dynamic> rawData,
    Map<String, dynamic> mealData,
    Map<String, dynamic> userProfile,
    Map<String, dynamic> macroTargets,
    List<String> ingredients,
    List<String> issues,
  ) async {
    final nutrition = mealData['nutrition'] as Map<String, dynamic>? ?? {};
    final instructionsText = (mealData['instructions'] as String?)?.trim() ?? '';

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 720),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF4CAF50),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                  child: Text(
                    'Review Meal: ${mealData['name'] ?? 'Manual Entry'}',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            _buildInfoChip(Icons.person_outline, rawData['userName'] ?? 'Unknown'),
                            _buildInfoChip(Icons.email_outlined, rawData['userEmail'] ?? '--'),
                            if (mealData['mealType'] != null)
                              _buildInfoChip(Icons.restaurant_menu, 'Type: ${(mealData['mealType'] as String).toUpperCase()}'),
                            if (rawData['submittedAt'] is Timestamp)
                              _buildInfoChip(
                                Icons.schedule,
                                'Submitted: ${DateFormat('MMM dd, HH:mm').format((rawData['submittedAt'] as Timestamp).toDate())}',
                              ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        if (macroTargets.isNotEmpty)
                          _buildMacroComparisonTable(nutrition, macroTargets, userProfile)
                        else
                          _buildNutritionInfo(nutrition),
                        const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _buildIngredientTable(ingredients)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildUserProfileSummary(userProfile)),
                          ],
                        ),
                        if (issues.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildIssuesPanel(issues),
                        ],
                        if (instructionsText.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildInstructionsPreview(instructionsText),
                        ],
                      ],
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.of(dialogContext).pop(),
                          icon: const Icon(Icons.close),
                          label: const Text('Close'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(dialogContext).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please use the Meal Validation tab for meal reviews')),
                          );
                        },
                        icon: const Icon(Icons.info_outline),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        label: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIssuesPanel(List<String> issues) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
              SizedBox(width: 6),
              Text('AI Analysis Warnings', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          ...issues.map(
            (issue) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(issue, style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsPreview(String instructions) {
    final lines = instructions
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final previewLines = lines.take(6).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.blueGrey.withOpacity(0.05),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.menu_book_outlined, size: 18, color: Colors.blueGrey),
              SizedBox(width: 6),
              Text('Instructions Overview', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 8),
          ...previewLines.asMap().entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('${entry.key + 1}. ${entry.value}', style: const TextStyle(fontSize: 12)),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[800]),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
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

  double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  Widget _buildMacroComparisonTable(
    Map<String, dynamic> actual,
    Map<String, dynamic> targets,
    Map<String, dynamic> userProfile, {
    bool compact = false,
  }) {
    final rows = <TableRow>[];

    void addRow(String label, dynamic a, dynamic t, String suffix) {
      final row = _buildMacroComparisonRow(label, a, t, suffix: suffix);
      if (row != null) rows.add(row);
    }

    addRow('Calories', actual['calories'], targets['calories'], 'kcal');
    addRow('Protein', actual['protein'], targets['protein'], 'g');
    addRow('Carbs', actual['carbs'], targets['carbs'], 'g');
    addRow('Fat', actual['fat'], targets['fat'], 'g');

    if (rows.isEmpty) {
      return _buildNutritionInfo(actual);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withOpacity(0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: const [
                Icon(Icons.analytics_outlined, size: 18, color: Colors.teal),
                SizedBox(width: 8),
                Text('Macro Comparison', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Divider(height: 1),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.6),
              1: FlexColumnWidth(1.1),
              2: FlexColumnWidth(1.1),
              3: FlexColumnWidth(1.2),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              const TableRow(children: [
                _TableHeaderCell('Macro'),
                _TableHeaderCell('Submitted'),
                _TableHeaderCell('Target'),
                _TableHeaderCell('Variance'),
              ]),
              ...rows,
            ],
          ),
          if (!compact)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: _buildMacroInsights(actual, targets, userProfile),
            ),
        ],
      ),
    );
  }

  Widget _buildNutritionInfo(Map<String, dynamic> nutrition) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNutritionItem('Calories', '${nutrition['calories'] ?? 0}', 'kcal'),
          _buildNutritionItem('Protein', '${nutrition['protein'] ?? 0}', 'g'),
          _buildNutritionItem('Carbs', '${nutrition['carbs'] ?? 0}', 'g'),
          _buildNutritionItem('Fat', '${nutrition['fat'] ?? 0}', 'g'),
        ],
      ),
    );
  }

  Widget _buildNutritionItem(String label, String value, String unit) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            text: value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            children: [TextSpan(text: unit, style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.grey[600]))],
          ),
        ),
      ],
    );
  }

  Widget _buildUserProfileSummary(Map<String, dynamic> profile) {
    final age = profile['age'] ?? 0;
    final bmi = profile['bmi'] ?? 0.0;
    final healthConditions = profile['healthConditions'] as List? ?? [];
    final allergies = profile['allergies'] as List? ?? [];
    final goal = profile['goal'] ?? 'N/A';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('User Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildProfileChip('Age: $age', Icons.cake),
              _buildProfileChip('BMI: ${bmi.toStringAsFixed(1)}', Icons.monitor_weight),
              _buildProfileChip('Goal: $goal', Icons.flag),
            ],
          ),
          if (healthConditions.isNotEmpty && healthConditions.first != 'None') ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: healthConditions.map((condition) {
                return Chip(
                  label: Text(condition.toString(), style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.orange[100],
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ],
          if (allergies.isNotEmpty && allergies.first != 'None') ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: allergies.map((allergen) {
                return Chip(
                  label: Text(allergen.toString(), style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.red[100],
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileChip(String label, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[700]),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
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

// MEAL VALIDATION TAB WIDGET
class _MealValidationTabContent extends StatefulWidget {
  const _MealValidationTabContent();

  @override
  State<_MealValidationTabContent> createState() => _MealValidationTabContentState();
}

class _MealValidationTabContentState extends State<_MealValidationTabContent> {
  String _filterStatus = 'pending';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Expanded(child: _buildFilterTab('Pending', 'pending')),
              Expanded(child: _buildFilterTab('Approved', 'approved')),
              Expanded(child: _buildFilterTab('Rejected', 'rejected')),
            ],
          ),
        ),
        const Divider(height: 0),
        Expanded(child: _buildValidationQueue()),
      ],
    );
  }

  List<String> _extractIngredients(Map<String, dynamic> mealData) {
    final raw = mealData['ingredients'];
    if (raw is List) {
      return raw.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    }
    if (raw is String) {
      return raw
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  Widget _buildMacroComparisonTable(
    Map<String, dynamic> actual,
    Map<String, dynamic> targets,
    Map<String, dynamic> userProfile, {
    bool compact = false,
  }) {
    final rows = <TableRow>[];

    void addRow(String label, dynamic a, dynamic t, String suffix) {
      final row = _buildMacroComparisonRow(label, a, t, suffix: suffix);
      if (row != null) rows.add(row);
    }

    addRow('Calories', actual['calories'], targets['calories'], 'kcal');
    addRow('Protein', actual['protein'], targets['protein'], 'g');
    addRow('Carbs', actual['carbs'], targets['carbs'], 'g');
    addRow('Fat', actual['fat'], targets['fat'], 'g');

    if (rows.isEmpty) {
      return _buildNutritionInfo(actual);
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withOpacity(0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: const [
                Icon(Icons.analytics_outlined, size: 18, color: Colors.teal),
                SizedBox(width: 8),
                Text('Macro Comparison', style: TextStyle(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const Divider(height: 1),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.6),
              1: FlexColumnWidth(1.1),
              2: FlexColumnWidth(1.1),
              3: FlexColumnWidth(1.2),
            },
            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
            children: [
              const TableRow(children: [
                _TableHeaderCell('Macro'),
                _TableHeaderCell('Submitted'),
                _TableHeaderCell('Target'),
                _TableHeaderCell('Variance'),
              ]),
              ...rows,
            ],
          ),
          if (!compact)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: _buildMacroInsights(actual, targets, userProfile),
            ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String label, String status) {
    final isSelected = _filterStatus == status;
    return InkWell(
      onTap: () => setState(() => _filterStatus = status),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? const Color(0xFF4CAF50) : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFF4CAF50) : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildValidationQueue() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('meal_validation_queue')
          .where('status', isEqualTo: _filterStatus)
          .orderBy('submittedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        // Enhanced error handling
        if (snapshot.hasError) {
          final error = snapshot.error.toString();
          
          // Check if it's an index error
          if (error.contains('index') || error.contains('FAILED_PRECONDITION')) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 64, color: Colors.orange[700]),
                    const SizedBox(height: 16),
                    const Text(
                      'Database Index Required',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'A Firestore index is needed for meal validation queries.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Extract and show the index creation URL
                        final urlMatch = RegExp(r'https://[^\s]+').firstMatch(error);
                        if (urlMatch != null) {
                          final url = urlMatch.group(0);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: SelectableText('Open this URL in your browser:\n$url'),
                              duration: const Duration(seconds: 15),
                              action: SnackBarAction(
                                label: 'OK',
                                onPressed: () {},
                              ),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.link),
                      label: const Text('Show Index URL'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Click the button above to get the index creation link,\nthen open it in your browser to create the index.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),
                    ExpansionTile(
                      title: const Text('Manual Setup Instructions'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '1. Go to Firebase Console',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Text('2. Navigate to Firestore Database → Indexes'),
                              const SizedBox(height: 8),
                              const Text('3. Create a composite index with:'),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Collection: meal_validation_queue'),
                                    Text('Field 1: status (Ascending)'),
                                    Text('Field 2: submittedAt (Descending)'),
                                  ],
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
          
          // Generic error
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  const Text(
                    'Error Loading Validations',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {}); // Retry
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final validations = snapshot.data?.docs ?? [];

        if (validations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _filterStatus == 'pending' ? Icons.check_circle_outline : Icons.inbox_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  _filterStatus == 'pending' ? 'No pending validations' : 'No $_filterStatus validations',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  _filterStatus == 'pending' ? 'All meals have been reviewed!' : 'No meals in this category yet',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        // Build table view
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DataTable(
                headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                border: TableBorder.all(color: Colors.grey[300]!, width: 1),
                columnSpacing: 24,
                columns: const [
                  DataColumn(label: Text('User', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Meal Name', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Calories', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Submitted', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: validations.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final mealData = data['mealData'] as Map<String, dynamic>? ?? {};
                  final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();
                  final nutrition = mealData['nutrition'] as Map<String, dynamic>? ?? {};
                  final feedback = data['feedback'] as Map<String, dynamic>?;
                  final isRevisionRequested = feedback?['decision'] == 'revision_requested';
                  
                  return DataRow(
                    cells: [
                      // User
                      DataCell(
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: const Color(0xFF4CAF50),
                              child: Text(
                                (data['userName'] as String? ?? 'U')[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 12),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  data['userName'] as String? ?? 'Unknown',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  data['userEmail'] as String? ?? '',
                                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Meal Name
                      DataCell(
                        Text(
                          mealData['name'] as String? ?? 'Unnamed Meal',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      // Type
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            (mealData['mealType'] as String? ?? 'N/A').toUpperCase(),
                            style: TextStyle(fontSize: 11, color: Colors.blue[800], fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      // Calories
                      DataCell(
                        Text(
                          '${nutrition['calories'] ?? 0} kcal',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      // Submitted
                      DataCell(
                        Text(
                          submittedAt != null ? DateFormat('MMM dd, HH:mm').format(submittedAt) : 'N/A',
                          style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                        ),
                      ),
                      // Status
                      DataCell(
                        isRevisionRequested
                            ? Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange[50],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange[300]!),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.edit_note, size: 12, color: Colors.orange[800]),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Revision',
                                      style: TextStyle(fontSize: 11, color: Colors.orange[800], fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _filterStatus == 'pending' ? Colors.amber[50] : _filterStatus == 'approved' ? Colors.green[50] : Colors.red[50],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _filterStatus.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: _filterStatus == 'pending' ? Colors.amber[900] : _filterStatus == 'approved' ? Colors.green[900] : Colors.red[900],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                      ),
                      // Actions
                      DataCell(
                        IconButton(
                          icon: const Icon(Icons.visibility, size: 20),
                          color: const Color(0xFF4CAF50),
                          tooltip: 'Review Details',
                          onPressed: () => _showDetailedReviewDialog(doc.id, data),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDetailedReviewDialog(String validationId, Map<String, dynamic> data) async {
    final mealData = data['mealData'] as Map<String, dynamic>? ?? {};
    final userProfile = data['userProfile'] as Map<String, dynamic>? ?? {};
    final macroTargets = (userProfile['macroTargets'] as Map<String, dynamic>? ?? {});
    final ingredients = _extractIngredients(mealData);
    final issues = MealValidationService.analyzeMeal(mealData, userProfile);
    final nutrition = mealData['nutrition'] as Map<String, dynamic>? ?? {};
    final submittedAt = (data['submittedAt'] as Timestamp?)?.toDate();

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 900,
          height: 700,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: const Color(0xFF4CAF50),
                    child: Text(
                      (data['userName'] as String? ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          mealData['name'] as String? ?? 'Unnamed Meal',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${data['userName']} • ${data['userEmail']}',
                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 32),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Meal Info
                      Row(
                        children: [
                          _buildInfoChip(Icons.restaurant_menu, 'Type: ${(mealData['mealType'] as String? ?? 'N/A').toUpperCase()}'),
                          const SizedBox(width: 8),
                          if (submittedAt != null)
                            _buildInfoChip(Icons.schedule, 'Submitted: ${DateFormat('MMM dd, HH:mm').format(submittedAt)}'),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Macro Comparison
                      if (macroTargets.isNotEmpty)
                        _buildMacroComparisonTable(nutrition, macroTargets, userProfile)
                      else
                        _buildNutritionInfo(nutrition),
                      
                      const SizedBox(height: 16),
                      
                      // Ingredients & User Profile
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (ingredients.isNotEmpty) ...[
                            Expanded(child: _buildIngredientTable(ingredients)),
                            const SizedBox(width: 16),
                          ],
                          Expanded(child: _buildUserProfileSummary(userProfile)),
                        ],
                      ),
                      
                      // AI Warnings
                      if (issues.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.warning, color: Colors.red[700], size: 20),
                                  const SizedBox(width: 8),
                                  Text('AI Analysis Warnings', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[700])),
                                ],
                              ),
                              const SizedBox(height: 8),
                              ...issues.map((issue) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('• $issue', style: TextStyle(fontSize: 13, color: Colors.red[700])),
                              )),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              
              // Action Buttons
              if (_filterStatus == 'pending') ...[
                const Divider(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showRejectDialog(validationId, data);
                      },
                      icon: const Icon(Icons.cancel),
                      label: const Text('Reject'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _showRevisionDialog(validationId, data);
                      },
                      icon: const Icon(Icons.edit_note),
                      label: const Text('Request Revision'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _quickApprove(validationId, data);
                      },
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Quick Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[800]),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildNutritionInfo(Map<String, dynamic> nutrition) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNutritionItem('Calories', '${nutrition['calories'] ?? 0}', 'kcal'),
          _buildNutritionItem('Protein', '${nutrition['protein'] ?? 0}', 'g'),
          _buildNutritionItem('Carbs', '${nutrition['carbs'] ?? 0}', 'g'),
          _buildNutritionItem('Fat', '${nutrition['fat'] ?? 0}', 'g'),
        ],
      ),
    );
  }

  Widget _buildNutritionItem(String label, String value, String unit) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            text: value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            children: [TextSpan(text: unit, style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: Colors.grey[600]))],
          ),
        ),
      ],
    );
  }

  Widget _buildUserProfileSummary(Map<String, dynamic> profile) {
    final age = profile['age'] ?? 0;
    final bmi = profile['bmi'] ?? 0.0;
    final healthConditions = profile['healthConditions'] as List? ?? [];
    final allergies = profile['allergies'] as List? ?? [];
    final goal = profile['goal'] ?? 'N/A';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('User Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildProfileChip('Age: $age', Icons.cake),
              _buildProfileChip('BMI: ${bmi.toStringAsFixed(1)}', Icons.monitor_weight),
              _buildProfileChip('Goal: $goal', Icons.flag),
            ],
          ),
          if (healthConditions.isNotEmpty && healthConditions.first != 'None') ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: healthConditions.map((condition) {
                return Chip(
                  label: Text(condition.toString(), style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.orange[100],
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ],
          if (allergies.isNotEmpty && allergies.first != 'None') ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: allergies.map((allergen) {
                return Chip(
                  label: Text(allergen.toString(), style: const TextStyle(fontSize: 11)),
                  backgroundColor: Colors.red[100],
                  padding: EdgeInsets.zero,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProfileChip(String label, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey[700]),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildFeedback(Map<String, dynamic> feedback, DateTime? reviewedAt) {
    final decision = feedback['decision'] as String? ?? '';
    final comments = feedback['comments'] as String? ?? '';
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: decision == 'approved' ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: decision == 'approved' ? Colors.green[200]! : Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                decision == 'approved' ? Icons.check_circle : Icons.cancel,
                color: decision == 'approved' ? Colors.green[700] : Colors.red[700],
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                decision == 'approved' ? 'Approved' : 'Rejected',
                style: TextStyle(fontWeight: FontWeight.bold, color: decision == 'approved' ? Colors.green[700] : Colors.red[700]),
              ),
              if (reviewedAt != null) ...[
                const Spacer(),
                Text(DateFormat('MMM dd, HH:mm').format(reviewedAt), style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ],
          ),
          if (comments.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(comments, style: TextStyle(fontSize: 13, color: Colors.grey[800])),
          ],
        ],
      ),
    );
  }

  Future<void> _quickApprove(String validationId, Map<String, dynamic> data) async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
      final nutritionistName = userDoc.data()?['fullName'] ?? 'Nutritionist';

      await MealValidationService.approveMeal(
        validationId: validationId,
        nutritionistName: nutritionistName,
        comments: 'Meal approved by nutritionist',
      );

      // Add meal to user's meal plan
      final mealData = data['mealData'] as Map<String, dynamic>;
      final userId = data['userId'] as String;
      
      await FirebaseFirestore.instance.collection('users').doc(userId).collection('meal_plans').add({
        'title': mealData['name'],
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'mealType': mealData['mealType'],
        'ingredients': mealData['ingredients'] ?? [],
        'instructions': mealData['instructions'] ?? '',
        'nutrition': mealData['nutrition'] ?? {},
        'servingSize': mealData['servingSize'] ?? '1 serving',
        'image': mealData['image'],
        'validated': true,
        'validatedBy': nutritionistName,
        'validatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Send in-app notification to user
      await _sendValidationNotification(userId, mealData['name'], true, 'Your meal has been approved by a nutritionist!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Meal approved successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving meal: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _showRejectDialog(String validationId, Map<String, dynamic> data) async {
    final reasonController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Meal'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Enter rejection reason...', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please provide a reason'), backgroundColor: Colors.orange),
                );
                return;
              }

              try {
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser == null) return;

                final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
                final nutritionistName = userDoc.data()?['fullName'] ?? 'Nutritionist';

                await MealValidationService.rejectMeal(
                  validationId: validationId,
                  nutritionistName: nutritionistName,
                  reason: reasonController.text.trim(),
                );

                // Send in-app notification to user
                final mealData = data['mealData'] as Map<String, dynamic>;
                final userId = data['userId'] as String;
                await _sendValidationNotification(userId, mealData['name'], false, reasonController.text.trim());

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Meal rejected with feedback'), backgroundColor: Colors.orange),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error rejecting meal: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Submit Rejection'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRevisionDialog(String validationId, Map<String, dynamic> data) async {
    final commentsController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Revision'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Explain what needs to be updated:'),
            const SizedBox(height: 12),
            TextField(
              controller: commentsController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Provide detailed revision instructions...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final comments = commentsController.text.trim();
              if (comments.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please add instructions for revision'), backgroundColor: Colors.orange),
                );
                return;
              }

              try {
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser == null) return;

                final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
                final nutritionistName = userDoc.data()?['fullName'] ?? 'Nutritionist';

                await MealValidationService.requestRevision(
                  validationId: validationId,
                  nutritionistName: nutritionistName,
                  comments: comments,
                );

                final mealData = data['mealData'] as Map<String, dynamic>;
                final userId = data['userId'] as String;
                await _sendValidationNotification(
                  userId,
                  mealData['name'],
                  false,
                  'Nutritionist requested revisions: $comments',
                );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Revision requested from user'), backgroundColor: Colors.orange),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error requesting revision: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendValidationNotification(String userId, String mealName, bool approved, String message) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).collection('notifications').add({
        'title': approved ? '✅ Meal Approved!' : '❌ Meal Needs Revision',
        'message': '$mealName: $message',
        'type': 'meal_validation',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'actionData': 'meal:$mealName',
      });
    } catch (e) {
      print('Error sending notification: $e');
    }
  }

  // Helper methods for meal validation tab
  TableRow? _buildMacroComparisonRow(String label, dynamic actual, dynamic target, {String suffix = ''}) {
    final actualValue = _parseDouble(actual);
    final targetValue = _parseDouble(target);
    if (actualValue == 0 && targetValue == 0) return null;

    final variance = actualValue - targetValue;
    String varianceLabel;
    Color varianceColor;

    if (targetValue == 0 && actualValue == 0) {
      varianceLabel = 'On target';
      varianceColor = Colors.green[700]!;
    } else if (targetValue == 0) {
      varianceLabel = '+${_formatValue(actualValue, suffix)}';
      varianceColor = Colors.orange[700]!;
    } else if (variance.abs() <= targetValue * 0.1) {
      varianceLabel = 'On target';
      varianceColor = Colors.green[700]!;
    } else if (variance > 0) {
      varianceLabel = '+${_formatValue(variance, suffix)}';
      varianceColor = Colors.red[700]!;
    } else {
      varianceLabel = '-${_formatValue(variance.abs(), suffix)}';
      varianceColor = Colors.orange[700]!;
    }

    return TableRow(children: [
      _TableDataCell(label, isBold: true),
      _TableDataCell(_formatValue(actualValue, suffix)),
      _TableDataCell(_formatValue(targetValue, suffix)),
      _TableDataCell(varianceLabel, color: varianceColor),
    ]);
  }

  String _formatValue(double value, String suffix) {
    final formatted = value.abs() >= 10 ? value.round().toString() : value.toStringAsFixed(1);
    return suffix.isEmpty ? formatted : '$formatted $suffix';
  }

  Widget _buildMacroInsights(
    Map<String, dynamic> actual,
    Map<String, dynamic> targets,
    Map<String, dynamic> profile,
  ) {
    final conditions = List<String>.from(profile['healthConditions'] ?? const [])
        .map((c) => c.toString().toLowerCase())
        .where((c) => c != 'none')
        .toList();

    final insights = <String>[];
    final actualCarbs = _parseDouble(actual['carbs']);
    final targetCarbs = _parseDouble(targets['carbs']);
    final actualFat = _parseDouble(actual['fat']);
    final targetFat = _parseDouble(targets['fat']);

    if (conditions.any((c) => c.contains('diabetes')) && actualCarbs > targetCarbs) {
      insights.add('Consider reducing carbohydrate portions to support diabetes management goals.');
    }

    if (conditions.any((c) => c.contains('cholesterol')) && actualFat > targetFat) {
      insights.add('High fat content detected; adjust saturated fat sources for cholesterol management.');
    }

    if (insights.isEmpty) {
      insights.add('Macros are generally aligned with personalized targets.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: insights
          .map(
            (text) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lightbulb_outline, size: 16, color: Colors.teal),
                  const SizedBox(width: 6),
                  Expanded(child: Text(text, style: TextStyle(color: Colors.grey[700], fontSize: 12))),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildIngredientTable(List<String> ingredients, {bool compact = false}) {
    final maxItems = compact ? 6 : ingredients.length;
    final display = ingredients.take(maxItems).toList();
    final remaining = ingredients.length - display.length;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.2)),
        color: Colors.green.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.12),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                const Icon(Icons.list_alt, size: 18, color: Colors.green),
                const SizedBox(width: 8),
                Text('Ingredients (${ingredients.length})', style: const TextStyle(fontWeight: FontWeight.w600)),
                if (remaining > 0) ...[
                  const SizedBox(width: 8),
                  Text('+${remaining} more', style: TextStyle(color: Colors.green[800], fontSize: 12)),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          ...display.map(
            (ingredient) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.circle, size: 6, color: Colors.green),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(ingredient, style: const TextStyle(fontSize: 13))),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showReviewDialog(
    String validationId,
    Map<String, dynamic> rawData,
    Map<String, dynamic> mealData,
    Map<String, dynamic> userProfile,
    Map<String, dynamic> macroTargets,
    List<String> ingredients,
    List<String> issues,
  ) async {
    final nutrition = mealData['nutrition'] as Map<String, dynamic>? ?? {};
    
    final caloriesController = TextEditingController(text: '${nutrition['calories'] ?? 0}');
    final proteinController = TextEditingController(text: '${nutrition['protein'] ?? 0}');
    final carbsController = TextEditingController(text: '${nutrition['carbs'] ?? 0}');
    final fatController = TextEditingController(text: '${nutrition['fat'] ?? 0}');
    final commentsController = TextEditingController();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Review: ${mealData['name'] ?? 'Meal'}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User info
              Text('User: ${rawData['userName']}', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('Email: ${rawData['userEmail']}', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 16),
              
              // Macro comparison
              if (macroTargets.isNotEmpty) ...[
                const Text('Nutrition vs Targets', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _buildMacroComparison('Calories', nutrition['calories'], macroTargets['calories']),
                _buildMacroComparison('Protein', nutrition['protein'], macroTargets['protein']),
                _buildMacroComparison('Carbs', nutrition['carbs'], macroTargets['carbs']),
                _buildMacroComparison('Fat', nutrition['fat'], macroTargets['fat']),
                const SizedBox(height: 16),
              ],
              
              // Warnings
              if (issues.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, color: Colors.red[700], size: 16),
                          const SizedBox(width: 8),
                          const Text('Warnings', style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...issues.map((issue) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('• $issue', style: TextStyle(fontSize: 12, color: Colors.red[700])),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Correct nutrition values
              const Text('Correct Nutrition Values (if needed)', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextField(
                controller: caloriesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Calories', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: proteinController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Protein (g)', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: carbsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Carbs (g)', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: fatController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Fat (g)', border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: commentsController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Comments/Feedback',
                  border: OutlineInputBorder(),
                  hintText: 'Add any notes or corrections...',
                ),
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
              try {
                final currentUser = FirebaseAuth.instance.currentUser;
                if (currentUser == null) return;

                final userDoc = await FirebaseFirestore.instance.collection('users').doc(currentUser.uid).get();
                final nutritionistName = userDoc.data()?['fullName'] ?? 'Nutritionist';

                final correctedNutrition = <String, double>{
                  'calories': double.tryParse(caloriesController.text) ?? _parseDouble(nutrition['calories']),
                  'protein': double.tryParse(proteinController.text) ?? _parseDouble(nutrition['protein']),
                  'carbs': double.tryParse(carbsController.text) ?? _parseDouble(nutrition['carbs']),
                  'fat': double.tryParse(fatController.text) ?? _parseDouble(nutrition['fat']),
                };

                await MealValidationService.approveMeal(
                  validationId: validationId,
                  nutritionistName: nutritionistName,
                  comments: commentsController.text.trim().isEmpty 
                      ? 'Meal approved with corrections' 
                      : commentsController.text.trim(),
                  correctedNutrition: correctedNutrition,
                );

                // Add meal to user's meal plan with corrected nutrition
                final userId = rawData['userId'] as String;
                await FirebaseFirestore.instance.collection('users').doc(userId).collection('meal_plans').add({
                  'title': mealData['name'],
                  'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
                  'mealType': mealData['mealType'],
                  'ingredients': ingredients,
                  'instructions': mealData['instructions'] ?? '',
                  'nutrition': correctedNutrition,
                  'servingSize': mealData['servingSize'] ?? '1 serving',
                  'image': mealData['image'],
                  'validated': true,
                  'validatedBy': nutritionistName,
                  'validatedAt': FieldValue.serverTimestamp(),
                  'nutritionCorrected': true,
                  'createdAt': FieldValue.serverTimestamp(),
                });

                // Send notification
                await _sendValidationNotification(
                  userId,
                  mealData['name'],
                  true,
                  commentsController.text.trim().isEmpty 
                      ? 'Your meal has been approved with nutrition corrections!' 
                      : commentsController.text.trim(),
                );

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Meal approved with corrections!'), backgroundColor: Colors.green),
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Approve with Corrections'),
          ),
        ],
      ),
    );
  }

  Widget _buildMacroComparison(String label, dynamic actual, dynamic target) {
    final actualValue = _parseDouble(actual);
    final targetValue = _parseDouble(target);
    final percentage = targetValue > 0 ? (actualValue / targetValue * 100) : 0;
    
    Color color = Colors.green;
    if (percentage > 150) {
      color = Colors.red;
    } else if (percentage > 120) {
      color = Colors.orange;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 13))),
          Expanded(
            child: Row(
              children: [
                Text(
                  '${actualValue.toStringAsFixed(0)} / ${targetValue.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Text('(${percentage.toStringAsFixed(0)}%)', style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
