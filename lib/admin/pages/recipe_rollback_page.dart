import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RecipeRollbackPage extends StatefulWidget {
  const RecipeRollbackPage({super.key});

  @override
  State<RecipeRollbackPage> createState() => _RecipeRollbackPageState();
}

class _RecipeRollbackPageState extends State<RecipeRollbackPage> {
  String _selectedRecipeType = 'filipino';
  String? _selectedRecipeId;
  Map<String, dynamic>? _selectedRecipe;
  List<Map<String, dynamic>> _updateHistory = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe Rollback'),
        backgroundColor: Colors.red[600],
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildRecipeSelector(),
          if (_selectedRecipe != null) _buildUpdateHistory(),
          if (_updateHistory.isNotEmpty) _buildRollbackActions(),
        ],
      ),
    );
  }

  Widget _buildRecipeSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(
          bottom: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Recipe to Rollback',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedRecipeType,
                  decoration: const InputDecoration(
                    labelText: 'Recipe Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'filipino', child: Text('Filipino Recipes')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin Recipes')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedRecipeType = value!;
                      _selectedRecipeId = null;
                      _selectedRecipe = null;
                      _updateHistory = [];
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getRecipes(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Text('Error: ${snapshot.error}');
                    }

                    final recipes = snapshot.data ?? [];
                    
                    return DropdownButtonFormField<String>(
                      value: _selectedRecipeId,
                      decoration: const InputDecoration(
                        labelText: 'Select Recipe',
                        border: OutlineInputBorder(),
                      ),
                      items: recipes.map((recipe) => DropdownMenuItem<String>(
                        value: recipe['id'],
                        child: Text(recipe['title'] ?? 'Untitled'),
                      )).toList(),
                      onChanged: (value) async {
                        if (value != null) {
                          await _loadRecipeDetails(value);
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateHistory() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history, color: Colors.blue[600]),
              const SizedBox(width: 8),
              Text(
                'Update History for "${_selectedRecipe?['title']}"',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_updateHistory.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No update history found for this recipe.'),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _updateHistory.length,
              itemBuilder: (context, index) {
                final update = _updateHistory[index];
                final updatedAt = DateTime.tryParse(update['updatedAt'] ?? '');
                final changes = update['changes'] as List<dynamic>? ?? [];
                final updatedBy = update['updatedBy'] ?? 'Unknown';

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.update,
                              size: 16,
                              color: Colors.orange[600],
                            ),
                            const SizedBox(width: 8),
                            Text(
                              updatedAt != null
                                  ? '${_formatDate(updatedAt)} at ${_formatTime(updatedAt)}'
                                  : 'Unknown date',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const Spacer(),
                            if (index > 0) // Don't show rollback for the latest version
                              IconButton(
                                onPressed: () => _showRollbackConfirmation(update, index),
                                icon: const Icon(Icons.undo, color: Colors.red),
                                tooltip: 'Rollback to this version',
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Updated by: $updatedBy',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        if (changes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          const Text(
                            'Changes:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ...changes.map((change) => Padding(
                            padding: const EdgeInsets.only(left: 8, bottom: 2),
                            child: Text(
                              '• $change',
                              style: const TextStyle(fontSize: 12),
                            ),
                          )),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRollbackActions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        border: Border(
          top: BorderSide(color: Colors.red[200]!),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.red[600]),
              const SizedBox(width: 8),
              const Text(
                'Rollback Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Rolling back a recipe will restore it to a previous version and update all meal plans and individual meals that use this recipe.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _isLoading ? null : _rollbackToLatest,
                icon: _isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.undo),
                label: const Text('Rollback to Previous Version'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[600],
                  foregroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _resetSelection,
                icon: const Icon(Icons.refresh),
                label: const Text('Reset'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getRecipes() async {
    if (_selectedRecipeType == 'filipino') {
      final doc = await FirebaseFirestore.instance
          .collection('system_data')
          .doc('filipino_recipes')
          .get();
      
      if (doc.exists) {
        final data = doc.data();
        final recipes = data?['data'] as List<dynamic>? ?? [];
        return recipes.cast<Map<String, dynamic>>();
      }
    } else {
      final snapshot = await FirebaseFirestore.instance
          .collection('admin_recipes')
          .get();
      
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList();
    }
    
    return [];
  }

  Future<void> _loadRecipeDetails(String recipeId) async {
    setState(() {
      _isLoading = true;
      _selectedRecipeId = recipeId;
    });

    try {
      Map<String, dynamic>? recipe;
      
      if (_selectedRecipeType == 'filipino') {
        final doc = await FirebaseFirestore.instance
            .collection('system_data')
            .doc('filipino_recipes')
            .get();
        
        if (doc.exists) {
          final data = doc.data();
          final recipes = data?['data'] as List<dynamic>? ?? [];
          recipe = recipes.firstWhere(
            (r) => r['id'] == recipeId,
            orElse: () => null,
          );
        }
      } else {
        final doc = await FirebaseFirestore.instance
            .collection('admin_recipes')
            .doc(recipeId)
            .get();
        
        if (doc.exists) {
          recipe = {
            'id': doc.id,
            ...doc.data()!,
          };
        }
      }

      if (recipe != null) {
        setState(() {
          _selectedRecipe = recipe;
          _updateHistory = _extractUpdateHistory(recipe!);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading recipe details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _extractUpdateHistory(Map<String, dynamic> recipe) {
    // This would need to be implemented based on how you store update history
    // For now, we'll create a mock history
    final history = <Map<String, dynamic>>[];
    
    // Add current version
    history.add({
      'updatedAt': recipe['updatedAt'] ?? DateTime.now().toIso8601String(),
      'changes': ['Current version'],
      'updatedBy': 'admin',
      'version': 'current',
    });
    
    // Add some mock historical versions
    final createdAt = DateTime.tryParse(recipe['createdAt'] ?? '');
    if (createdAt != null) {
      history.add({
        'updatedAt': createdAt.toIso8601String(),
        'changes': ['Initial version'],
        'updatedBy': 'admin',
        'version': 'initial',
      });
    }
    
    return history.reversed.toList(); // Show newest first
  }

  void _showRollbackConfirmation(Map<String, dynamic> update, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Rollback'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to rollback this recipe to the selected version?'),
            const SizedBox(height: 16),
            Text(
              'This will:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[600]),
            ),
            const SizedBox(height: 8),
            const Text('• Restore the recipe to a previous state'),
            const Text('• Update all meal plans containing this recipe'),
            const Text('• Update all individual meals with this recipe'),
            const Text('• This action cannot be undone'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _performRollback(update, index);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Rollback'),
          ),
        ],
      ),
    );
  }

  Future<void> _performRollback(Map<String, dynamic> update, int index) async {
    setState(() {
      _isLoading = true;
    });

    try {
      // This is a simplified rollback - in a real implementation,
      // you would need to store the actual previous recipe data
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rollback feature coming soon! This would restore the recipe to the selected version.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error performing rollback: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _rollbackToLatest() async {
    if (_updateHistory.length < 2) return;

    final previousVersion = _updateHistory[1]; // Second item (previous version)
    await _performRollback(previousVersion, 1);
  }

  void _resetSelection() {
    setState(() {
      _selectedRecipeId = null;
      _selectedRecipe = null;
      _updateHistory = [];
    });
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '${difference} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
