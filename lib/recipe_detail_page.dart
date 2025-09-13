import 'package:flutter/material.dart';
import 'services/recipe_service.dart';
import 'services/filipino_recipe_service.dart';
import 'services/allergen_service.dart';
import 'services/allergen_ml_service.dart';
import 'meal_favorites_page.dart';

class RecipeDetailPage extends StatefulWidget {
  final Map<String, dynamic> recipe;

  const RecipeDetailPage({super.key, required this.recipe});

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  Map<String, dynamic>? _recipeDetails;
  bool _isLoading = true;
  String? _error;
  Map<String, int>? _mlAllergens;
  String? _mlStatus; // debug/status of ML call
  String _mlSourceText = '';
  bool _isFavorited = false;
  bool _isCheckingFavorite = true;

  // Lightweight keyword hints to explain ML detections
  static const Map<String, List<String>> _mlKeywordMap = {
    'peanuts': ['peanut','peanuts','peanut butter'],
    'tree_nuts': ['almond','walnut','cashew','pecan','hazelnut','pistachio'],
    'milk': ['milk','cheese','yogurt','cream','butter','ghee','dairy'],
    'eggs': ['egg','eggs','mayonnaise','mayo'],
    'fish': ['fish','salmon','tuna','cod','tilapia','mackerel','anchovy'],
    'shellfish': ['shrimp','prawn','crab','lobster','clam','mussel','oyster','scallop'],
    'wheat_gluten': ['flour','wheat','bread','pasta','noodles','semolina'],
    'soy': ['soy','soya','tofu','edamame','soy sauce','miso','tempeh'],
    'sesame': ['sesame','tahini','sesame seed','sesame oil'],
  };

  List<String> _findMlMatches(String allergen, String text) {
    final terms = _mlKeywordMap[allergen] ?? const [];
    final lower = text.toLowerCase();
    final hits = <String>[];
    for (final t in terms) {
      if (lower.contains(t)) hits.add(t);
    }
    return hits;
  }

  @override
  void initState() {
    super.initState();
    _loadRecipeDetails();
    _checkIfFavorited();
  }

  Future<void> _loadRecipeDetails() async {
    try {
      // Check if this is a local recipe or API recipe
      final recipeId = widget.recipe['id'];
      
      if (recipeId == null) {
        // No ID, use the recipe data directly
        setState(() {
          _recipeDetails = widget.recipe;
          _isLoading = false;
        });
        return;
      }
      
      if (recipeId.toString().startsWith('local_')) {
        // This is a local recipe, use the data directly
        setState(() {
          _recipeDetails = widget.recipe;
          _isLoading = false;
        });
        return;
      }
      
      // Try Filipino Recipe Service first for Filipino recipes
      Map<String, dynamic>? details;
      if (widget.recipe['cuisine'] == 'Filipino' || 
          recipeId.toString().startsWith('curated_') ||
          recipeId.toString().startsWith('themealdb_') ||
          recipeId.toString().startsWith('local_filipino_')) {
        details = await FilipinoRecipeService.getRecipeDetails(recipeId.toString());
      }
      
      // Fallback to regular Recipe Service
      if (details == null) {
        details = await RecipeService.fetchRecipeDetails(recipeId);
      }
      
      setState(() {
        _recipeDetails = details;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _runAllergenML() async {
    try {
      setState(() => _mlStatus = 'ML: detecting...');
      final r = _recipeDetails ?? widget.recipe;
      final title = (r['title'] ?? '').toString();
      final ingredients = (r['extendedIngredients'] as List?)?.map((e) => (e['name'] ?? '').toString()).join(' ') ??
          (r['ingredients'] as List?)?.map((e) => e.toString()).join(' ') ?? '';
      final text = (title + ' ' + ingredients).trim();
      if (text.isEmpty) return;
      final result = await AllergenMLService.predictWithScores(text);
      final labels = result.labels;
      // Debug: print ML labels
      // ignore: avoid_print
      print('ML allergens for "$title": ' + labels.toString());
      if (mounted) {
        setState(() {
          _mlAllergens = labels;
          _mlSourceText = text;
          final positives = result.scores.entries
              .where((e) => e.value == 1)
              .where((e) => _findMlMatches(e.key, text).isNotEmpty)
              .map((e) => '${e.key} ${(result.scores[e.key] ?? 0).toStringAsFixed(2)}')
              .toList();
          _mlStatus = positives.isEmpty ? 'ML: no positives' : 'ML: ' + positives.join(', ');
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('ML error: ' + e.toString());
      if (mounted) setState(() => _mlStatus = 'ML error');
    }
  }

  Future<void> _checkIfFavorited() async {
    if (widget.recipe['id'] != null) {
      final isFavorited = await FavoriteService.isFavorited(widget.recipe['id'].toString());
      setState(() {
        _isFavorited = isFavorited;
        _isCheckingFavorite = false;
      });
    } else {
      setState(() {
        _isCheckingFavorite = false;
      });
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorited) {
      await FavoriteService.removeFromFavorites(widget.recipe['id'].toString());
      setState(() {
        _isFavorited = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Removed from favorites'),
          backgroundColor: Colors.orange,
        ),
      );
    } else {
      await FavoriteService.addToFavorites(context, widget.recipe);
      setState(() {
        _isFavorited = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.recipe['title'] ?? 'Recipe Details'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          if (!_isCheckingFavorite && widget.recipe['id'] != null)
            IconButton(
              onPressed: _toggleFavorite,
              icon: Icon(
                _isFavorited ? Icons.favorite : Icons.favorite_border,
                color: _isFavorited ? Colors.red : Colors.white,
              ),
              tooltip: _isFavorited ? 'Remove from favorites' : 'Add to favorites',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text('Error: $_error'))
          : _buildRecipeDetails(),
    );
  }

  Widget _buildRecipeDetails() {
    if (_recipeDetails == null) {
      return const Center(child: Text('No details available'));
    }

    final details = _recipeDetails!;

    // Kick off ML allergen detection once details are present
    if (_mlAllergens == null) {
      _runAllergenML();
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recipe Image
          if (details['image'] != null &&
              details['image'].toString().isNotEmpty)
            SizedBox(
              width: double.infinity,
              height: 250,
              child: Image.network(
                details['image'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 250,
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
                            size: 64,
                            color: Colors.green,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Recipe Image',
                            style: TextStyle(
                              color: Colors.green,
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 250,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green[50]!, Colors.green[100]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.green),
                    ),
                  );
                },
              ),
            ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recipe Title
                Text(
                  details['title'] ?? 'No Title',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                const SizedBox(height: 8),

                // Recipe Summary
                if (details['summary'] != null)
                  Text(
                    _stripHtmlTags(details['summary']),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),

                const SizedBox(height: 24),

                // Allergen Information
                _buildAllergenSection(details),

                const SizedBox(height: 24),

                // Nutrition Information
                if (details['nutrition'] != null)
                  _buildNutritionSection(details['nutrition']),

                const SizedBox(height: 24),

                // Ingredients Section
                _buildIngredientsSection(details),

                const SizedBox(height: 24),

                // Instructions Section
                _buildInstructionsSection(details),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionSection(Map<String, dynamic> nutrition) {
    // Handle both API recipes (nutrients array) and local recipes (direct nutrition values)
    List<dynamic>? nutrients;
    
    if (nutrition['nutrients'] != null) {
      // API recipe format
      nutrients = nutrition['nutrients'] as List<dynamic>?;
    } else {
      // Local recipe format - convert to API-like format
      nutrients = [
        {'name': 'Calories', 'amount': nutrition['calories'], 'unit': 'cal'},
        {'name': 'Protein', 'amount': nutrition['protein'], 'unit': 'g'},
        {'name': 'Carbohydrates', 'amount': nutrition['carbs'], 'unit': 'g'},
        {'name': 'Fat', 'amount': nutrition['fat'], 'unit': 'g'},
        {'name': 'Fiber', 'amount': nutrition['fiber'], 'unit': 'g'},
      ].where((nutrient) => nutrient['amount'] != null && nutrient['amount'] > 0).toList();
    }
    
    if (nutrients == null || nutrients.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nutrition Information',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: nutrients.take(6).map((nutrient) {
                final amount = nutrient['amount'];
                String amountText = '';

                if (amount != null) {
                  if (amount is num) {
                    amountText = amount.toStringAsFixed(1);
                  } else {
                    amountText = amount.toString();
                  }
                }

                return Chip(
                  backgroundColor: Colors.green[50],
                  label: Text(
                    '${nutrient['name']}: $amountText${nutrient['unit'] ?? ''}',
                    style: TextStyle(color: Colors.green[800]),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIngredientsSection(Map<String, dynamic> details) {
    // Handle both API recipes (extendedIngredients) and local recipes (ingredients)
    List<dynamic>? ingredients;
    
    if (details['extendedIngredients'] != null) {
      // API recipe format
      ingredients = details['extendedIngredients'] as List<dynamic>?;
    } else if (details['ingredients'] != null) {
      // Local recipe format - convert to API-like format
      final localIngredients = details['ingredients'] as List<dynamic>?;
      if (localIngredients != null) {
        ingredients = localIngredients.map((ingredient) => {
          'amount': 1,
          'unit': '',
          'name': ingredient.toString(),
        }).toList();
      }
    }
    
    if (ingredients == null || ingredients.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ingredients',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 12),
            ...ingredients.map((ingredient) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.circle, size: 8, color: Colors.green[600]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${_formatAmount(ingredient['amount'])} ${ingredient['unit'] ?? ''} ${ingredient['name'] ?? ''}',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionsSection(Map<String, dynamic> details) {
    // Handle both API recipes (instructions) and local recipes (instructions)
    String? instructions;
    
    if (details['instructions'] != null) {
      instructions = details['instructions'] as String?;
    }
    
    if (instructions == null || instructions.isEmpty) {
      return const SizedBox.shrink();
    }

    // Split instructions into steps
    final cleanInstructions = _stripHtmlTags(instructions);
    final steps = _splitIntoSteps(cleanInstructions);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Instructions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 12),
            ...steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.green[600],
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        step.trim(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  List<String> _splitIntoSteps(String instructions) {
    // Split by common step indicators
    final stepPatterns = [
      RegExp(r'\d+\.\s*', caseSensitive: false), // "1. ", "2. ", etc.
      RegExp(
        r'step\s*\d+[:\s]*',
        caseSensitive: false,
      ), // "Step 1:", "step 1:", etc.
      RegExp(r'^\s*[•·]\s*', caseSensitive: false), // Bullet points
    ];

    String processedInstructions = instructions;

    // Try to split by numbered steps first
    for (final pattern in stepPatterns) {
      if (pattern.hasMatch(processedInstructions)) {
        final parts = processedInstructions.split(pattern);
        if (parts.length > 1) {
          return parts.where((part) => part.trim().isNotEmpty).toList();
        }
      }
    }

    // If no clear step indicators, split by sentences
    final sentences = processedInstructions.split(RegExp(r'[.!?]\s+'));
    return sentences.where((sentence) => sentence.trim().isNotEmpty).toList();
  }

  String _formatAmount(dynamic amount) {
    if (amount == null) return '';

    if (amount is num) {
      return amount.toStringAsFixed(1);
    } else {
      return amount.toString();
    }
  }

  Widget _buildAllergenSection(Map<String, dynamic> details) {
    // Handle both API recipes (extendedIngredients) and local recipes (ingredients)
    List<dynamic>? ingredients;
    
    if (details['extendedIngredients'] != null) {
      // API recipe format
      ingredients = details['extendedIngredients'] as List<dynamic>?;
    } else if (details['ingredients'] != null) {
      // Local recipe format - convert to API-like format
      final localIngredients = details['ingredients'] as List<dynamic>?;
      if (localIngredients != null) {
        ingredients = localIngredients.map((ingredient) => {
          'amount': 1,
          'unit': '',
          'name': ingredient.toString(),
        }).toList();
      }
    }
    
    if (ingredients == null || ingredients.isEmpty) {
      return const SizedBox.shrink();
    }

    final allergens = AllergenService.checkAllergens(ingredients);
    final allergenCount = allergens.values.fold(
      0,
      (sum, list) => sum + list.length,
    );
    final riskLevel = AllergenService.getRiskLevel(allergenCount);
    final riskColor = Color(AllergenService.getRiskColor(riskLevel));

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Allergen Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: riskColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    riskLevel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (allergens.isEmpty && (_mlAllergens == null || _mlAllergens!.values.every((v) => v == 0)))
              const Text(
                'No common allergens detected in this recipe.',
                style: TextStyle(
                  color: Colors.green,
                  fontStyle: FontStyle.italic,
                ),
              )
            else ...[
              Text(
                'This recipe contains the following allergens:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              if (_mlStatus != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      const Icon(Icons.memory, size: 14, color: Color(0xFF888888)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _mlStatus!,
                          style: TextStyle(color: Colors.grey[700], fontStyle: FontStyle.italic, fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                ),
              if (_mlAllergens != null && _mlAllergens!.entries.any((e) => e.value == 1 && _findMlMatches(e.key, _mlSourceText).isNotEmpty))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _mlAllergens!.entries
                        .where((e) => e.value == 1 && _findMlMatches(e.key, _mlSourceText).isNotEmpty)
                        .map((e) => Chip(
                              backgroundColor: Colors.red[50],
                              label: Text('${e.key} (ML)', style: const TextStyle(color: Colors.red)),
                            ))
                        .toList(),
                  ),
                ),
              if (_mlAllergens != null && _mlAllergens!.entries.any((e) => e.value == 1 && _findMlMatches(e.key, _mlSourceText).isNotEmpty))
                ..._mlAllergens!.entries.where((e) => e.value == 1 && _findMlMatches(e.key, _mlSourceText).isNotEmpty).map((e) {
                  final matches = _findMlMatches(e.key, _mlSourceText);
                  return Padding(
                    padding: const EdgeInsets.only(left: 2, bottom: 6),
                    child: Text(
                      'Reason (ML): found ${matches.join(', ')}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      softWrap: true,
                    ),
                  );
                }).toList(),
              ...allergens.entries.map((entry) {
                final allergenType = entry.key;
                final ingredients = entry.value;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            AllergenService.getAllergenIcon(allergenType),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            AllergenService.getDisplayName(allergenType),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 24),
                        child: Text(
                          'Found in: ${ingredients.join(', ')}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.only(left: 24),
                        child: Text(
                          'Substitutions: ${AllergenService.getSubstitutions(allergenType).take(2).join(', ')}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Colors.green[600],
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
  String _stripHtmlTags(String htmlText) {
    // Simple HTML tag removal - you might want to use a proper HTML parser
    return htmlText
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .trim();
  }
}
