import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/curated_data_migration_service.dart';
import '../../services/allergen_service.dart';
import '../../services/filipino_recipe_service.dart';

class CuratedContentManagementPage extends StatefulWidget {
  const CuratedContentManagementPage({super.key});

  @override
  State<CuratedContentManagementPage> createState() => _CuratedContentManagementPageState();
}

class _CuratedContentManagementPageState extends State<CuratedContentManagementPage> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;
  bool _needsMigration = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _checkMigrationStatus();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkMigrationStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final needsMigration = await CuratedDataMigrationService.needsMigration();
      setState(() {
        _needsMigration = needsMigration;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error checking migration status: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _runMigration() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await CuratedDataMigrationService.runAllMigrations();
      setState(() {
        _needsMigration = false;
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Migration completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Migration failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Curated Content Management'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.swap_horiz), text: 'System Substitutions'),
            Tab(icon: Icon(Icons.restaurant), text: 'Filipino Recipes'),
            Tab(icon: Icon(Icons.settings), text: 'Migration'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildSystemSubstitutionsTab(),
                _buildFilipinoRecipesTab(),
                _buildMigrationTab(),
              ],
            ),
    );
  }

  Widget _buildSystemSubstitutionsTab() {
    return FutureBuilder<Map<String, List<String>>>(
      future: AllergenService.getAllSubstitutions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading substitutions: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final substitutions = snapshot.data ?? {};

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'System Substitutions',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _editSystemSubstitutions(substitutions),
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit All'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: substitutions.length,
                  itemBuilder: (context, index) {
                    final allergenType = substitutions.keys.elementAt(index);
                    final substitutionList = substitutions[allergenType] ?? [];
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ExpansionTile(
                        title: Text(
                          allergenType.replaceAll('_', ' ').toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${substitutionList.length} substitutions'),
                        children: substitutionList.map((substitution) => ListTile(
                          title: Text(substitution),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () => _editSingleSubstitution(allergenType, substitution, substitutionList),
                          ),
                        )).toList(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilipinoRecipesTab() {
    return FutureBuilder<List<dynamic>>(
      future: _getCuratedFilipinoRecipes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading recipes: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final recipes = snapshot.data ?? [];

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Curated Filipino Recipes',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _addFilipinoRecipe(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Recipe'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: recipes.length,
                  itemBuilder: (context, index) {
                    final recipe = recipes[index];
                    final title = recipe['title'] as String? ?? 'Untitled';
                    final description = recipe['description'] as String? ?? '';
                    final mealType = recipe['mealType'] as String? ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getMealTypeColor(mealType),
                          child: Text(
                            mealType.isNotEmpty ? mealType[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(title),
                        subtitle: Text(description),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit),
                              onPressed: () => _editFilipinoRecipe(recipe, recipes),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteFilipinoRecipe(recipe['id'], recipes),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMigrationTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Data Migration',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Migration Status',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        _needsMigration ? Icons.warning : Icons.check_circle,
                        color: _needsMigration ? Colors.orange : Colors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _needsMigration ? 'Migration Required' : 'Up to Date',
                        style: TextStyle(
                          color: _needsMigration ? Colors.orange : Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_needsMigration) ...[
                    const Text(
                      'Curated content needs to be migrated to Firestore to enable editing. This will move hardcoded data to the database.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _runMigration,
                      icon: const Icon(Icons.upload),
                      label: const Text('Run Migration'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ] else ...[
                    const Text(
                      'All curated content has been migrated to Firestore and is ready for editing.',
                      style: TextStyle(fontSize: 14, color: Colors.green),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _checkMigrationStatus,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Check Status'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<List<dynamic>> _getCuratedFilipinoRecipes() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('system_data')
          .doc('filipino_recipes')
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        return data?['data'] as List<dynamic>? ?? [];
      }
      return [];
    } catch (e) {
      print('Error getting curated recipes: $e');
      return [];
    }
  }

  Color _getMealTypeColor(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast': return Colors.orange;
      case 'lunch': return Colors.green;
      case 'dinner': return Colors.blue;
      case 'snack': return Colors.purple;
      default: return Colors.grey;
    }
  }

  void _editSystemSubstitutions(Map<String, List<String>> substitutions) {
    print('DEBUG: Opening edit system substitutions dialog');
    showDialog(
      context: context,
      builder: (context) => _EditSystemSubstitutionsDialog(
        substitutions: substitutions,
        onSubstitutionsUpdated: () {
          setState(() {}); // Refresh the page
        },
      ),
    );
  }

  void _editSingleSubstitution(String allergenType, String substitution, List<String> allSubstitutions) {
    print('DEBUG: Opening edit single substitution dialog for $allergenType');
    showDialog(
      context: context,
      builder: (context) => _EditSingleSubstitutionDialog(
        allergenType: allergenType,
        substitution: substitution,
        allSubstitutions: allSubstitutions,
        onSubstitutionUpdated: () {
          setState(() {}); // Refresh the page
        },
      ),
    );
  }

  void _addFilipinoRecipe() {
    showDialog(
      context: context,
      builder: (context) => _EditFilipinoRecipeDialog(
        recipe: null, // null means add new
        onRecipeUpdated: () {
          setState(() {}); // Refresh the page
        },
      ),
    );
  }

  void _editFilipinoRecipe(Map<String, dynamic> recipe, List<dynamic> allRecipes) {
    showDialog(
      context: context,
      builder: (context) => _EditFilipinoRecipeDialog(
        recipe: recipe,
        onRecipeUpdated: () {
          setState(() {}); // Refresh the page
        },
      ),
    );
  }

  void _deleteFilipinoRecipe(String recipeId, List<dynamic> allRecipes) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Recipe'),
        content: const Text('Are you sure you want to delete this recipe? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await FilipinoRecipeService.deleteCuratedFilipinoRecipe(recipeId);
                setState(() {});
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Recipe deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error deleting recipe: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// Edit System Substitutions Dialog
class _EditSystemSubstitutionsDialog extends StatefulWidget {
  final Map<String, List<String>> substitutions;
  final VoidCallback onSubstitutionsUpdated;

  const _EditSystemSubstitutionsDialog({
    required this.substitutions,
    required this.onSubstitutionsUpdated,
  });

  @override
  State<_EditSystemSubstitutionsDialog> createState() => _EditSystemSubstitutionsDialogState();
}

class _EditSystemSubstitutionsDialogState extends State<_EditSystemSubstitutionsDialog> {
  late Map<String, List<String>> _editedSubstitutions;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _editedSubstitutions = Map.from(widget.substitutions);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit System Substitutions'),
      content: SizedBox(
        width: 400,
        height: 500,
        child: ListView.builder(
          itemCount: _editedSubstitutions.length,
          itemBuilder: (context, index) {
            final allergenType = _editedSubstitutions.keys.elementAt(index);
            final substitutions = _editedSubstitutions[allergenType] ?? [];
            
            return ExpansionTile(
              title: Text(allergenType.replaceAll('_', ' ').toUpperCase()),
              children: substitutions.asMap().entries.map((entry) {
                final subIndex = entry.key;
                final substitution = entry.value;
                
                return ListTile(
                  title: TextField(
                    controller: TextEditingController(text: substitution),
                    onChanged: (value) {
                      _editedSubstitutions[allergenType]![subIndex] = value;
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      setState(() {
                        _editedSubstitutions[allergenType]!.removeAt(subIndex);
                      });
                    },
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveSubstitutions,
          child: _isLoading 
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _saveSubstitutions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await AllergenService.updateSystemSubstitutions(_editedSubstitutions);
      widget.onSubstitutionsUpdated();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('System substitutions updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating substitutions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

// Edit Single Substitution Dialog
class _EditSingleSubstitutionDialog extends StatefulWidget {
  final String allergenType;
  final String substitution;
  final List<String> allSubstitutions;
  final VoidCallback onSubstitutionUpdated;

  const _EditSingleSubstitutionDialog({
    required this.allergenType,
    required this.substitution,
    required this.allSubstitutions,
    required this.onSubstitutionUpdated,
  });

  @override
  State<_EditSingleSubstitutionDialog> createState() => _EditSingleSubstitutionDialogState();
}

class _EditSingleSubstitutionDialogState extends State<_EditSingleSubstitutionDialog> {
  late TextEditingController _controller;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.substitution);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit ${widget.allergenType.replaceAll('_', ' ').toUpperCase()} Substitution'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          labelText: 'Substitution',
          border: OutlineInputBorder(),
        ),
        maxLines: 3,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveSubstitution,
          child: _isLoading 
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _saveSubstitution() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current substitutions
      final currentSubstitutions = await AllergenService.getAllSubstitutions();
      
      // Update the specific substitution
      final updatedSubstitutions = Map<String, List<String>>.from(currentSubstitutions);
      final index = updatedSubstitutions[widget.allergenType]?.indexOf(widget.substitution) ?? -1;
      
      if (index != -1) {
        updatedSubstitutions[widget.allergenType]![index] = _controller.text.trim();
        await AllergenService.updateSystemSubstitutions(updatedSubstitutions);
        
        widget.onSubstitutionUpdated();
        if (mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Substitution updated successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating substitution: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

// Edit Filipino Recipe Dialog
class _EditFilipinoRecipeDialog extends StatefulWidget {
  final Map<String, dynamic>? recipe; // null for add new
  final VoidCallback onRecipeUpdated;

  const _EditFilipinoRecipeDialog({
    required this.recipe,
    required this.onRecipeUpdated,
  });

  @override
  State<_EditFilipinoRecipeDialog> createState() => _EditFilipinoRecipeDialogState();
}

class _EditFilipinoRecipeDialogState extends State<_EditFilipinoRecipeDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _instructionsController;
  late List<TextEditingController> _ingredientControllers;
  late String _selectedMealType;
  bool _isLoading = false;

  final List<String> _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.recipe?['title'] ?? '');
    _descriptionController = TextEditingController(text: widget.recipe?['description'] ?? '');
    _instructionsController = TextEditingController(text: widget.recipe?['instructions'] ?? '');
    _selectedMealType = widget.recipe?['mealType'] ?? 'breakfast';
    
    final ingredients = widget.recipe?['ingredients'] as List<dynamic>? ?? [];
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
    for (final controller in _ingredientControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.recipe == null ? 'Add Filipino Recipe' : 'Edit Filipino Recipe'),
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
                const Text('Ingredients:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ..._ingredientControllers.asMap().entries.map((entry) {
                  final index = entry.key;
                  final controller = entry.value;
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: controller,
                            decoration: InputDecoration(
                              labelText: 'Ingredient ${index + 1}',
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle, color: Colors.red),
                          onPressed: () {
                            if (_ingredientControllers.length > 1) {
                              setState(() {
                                controller.dispose();
                                _ingredientControllers.removeAt(index);
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  );
                }),
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      _ingredientControllers.add(TextEditingController());
                    });
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Ingredient'),
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
          onPressed: _isLoading ? null : _saveRecipe,
          child: _isLoading 
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(widget.recipe == null ? 'Add' : 'Save'),
        ),
      ],
    );
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final ingredients = _ingredientControllers
          .map((controller) => controller.text.trim())
          .where((ingredient) => ingredient.isNotEmpty)
          .toList();

      final recipeData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'instructions': _instructionsController.text.trim(),
        'ingredients': ingredients,
        'mealType': _selectedMealType,
        'cuisine': 'Filipino',
        'source': 'curated',
        'isEditable': true,
      };

      if (widget.recipe == null) {
        // Add new recipe
        await FilipinoRecipeService.addCuratedFilipinoRecipe(recipeData);
      } else {
        // Update existing recipe
        final allRecipes = await _getCuratedFilipinoRecipes();
        final updatedRecipes = allRecipes.map((recipe) {
          if (recipe['id'] == widget.recipe!['id']) {
            return {
              ...recipe,
              ...recipeData,
              'updatedAt': DateTime.now().toIso8601String(),
            };
          }
          return recipe;
        }).toList();
        
        // Update each recipe individually to avoid replacing the entire list
        for (final recipe in updatedRecipes) {
          await FilipinoRecipeService.updateSingleCuratedFilipinoRecipe(
            recipe.cast<Map<String, dynamic>>()
          );
        }
      }

      widget.onRecipeUpdated();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.recipe == null ? 'Recipe added successfully!' : 'Recipe updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving recipe: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<List<dynamic>> _getCuratedFilipinoRecipes() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('system_data')
          .doc('filipino_recipes')
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        return data?['data'] as List<dynamic>? ?? [];
      }
      return [];
    } catch (e) {
      print('Error getting curated recipes: $e');
      return [];
    }
  }
}
