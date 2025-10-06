import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class GuidelinesEditorPage extends StatefulWidget {
  const GuidelinesEditorPage({super.key});

  @override
  State<GuidelinesEditorPage> createState() => _GuidelinesEditorPageState();
}

class _GuidelinesEditorPageState extends State<GuidelinesEditorPage> with TickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
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
        title: const Text('Nutritional Guidelines Editor'),
        backgroundColor: const Color(0xFF9C27B0),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: const [
            Tab(text: 'General Guidelines', icon: Icon(Icons.article)),
            Tab(text: 'Allergen Rules', icon: Icon(Icons.warning)),
            Tab(text: 'Dietary Standards', icon: Icon(Icons.restaurant)),
            Tab(text: 'Health Conditions', icon: Icon(Icons.health_and_safety)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _showAddGuidelineDialog(category: 'general'),
            icon: const Icon(Icons.add),
            tooltip: 'Add New Guideline',
          ),
          IconButton(
            onPressed: () {
              setState(() {});
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search guidelines...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGuidelinesList('general'),
                _buildGuidelinesList('allergen'),
                _buildGuidelinesList('dietary'),
                _buildGuidelinesList('health'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidelinesList(String category) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('nutritional_guidelines')
          .where('category', isEqualTo: category)
          .orderBy('lastUpdated', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final guidelines = snapshot.data?.docs ?? [];
        final filteredGuidelines = guidelines.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final title = data['title']?.toString().toLowerCase() ?? '';
          final content = data['content']?.toString().toLowerCase() ?? '';
          return title.contains(_searchQuery) || content.contains(_searchQuery);
        }).toList();

        if (filteredGuidelines.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No guidelines found for ${_getCategoryDisplayName(category)}',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showAddGuidelineDialog(category: category),
                  icon: const Icon(Icons.add),
                  label: const Text('Add First Guideline'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredGuidelines.length,
          itemBuilder: (context, index) {
            final doc = filteredGuidelines[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildGuidelineCard(doc.id, data, category);
          },
        );
      },
    );
  }

  Widget _buildGuidelineCard(String guidelineId, Map<String, dynamic> data, String category) {
    final title = data['title'] ?? 'Untitled Guideline';
    final content = data['content'] ?? '';
    final priority = data['priority'] ?? 'medium';
    final isActive = data['isActive'] ?? true;
    final lastUpdated = data['lastUpdated'] as Timestamp?;
    final createdBy = data['createdBy'] ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getCategoryColor(category).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getCategoryIcon(category),
                    color: _getCategoryColor(category),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getCategoryDisplayName(category),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getPriorityColor(priority).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    priority.toUpperCase(),
                    style: TextStyle(
                      color: _getPriorityColor(priority),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Content Preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Content:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    content.length > 200 ? '${content.substring(0, 200)}...' : content,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Status and Metadata
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isActive ? 'ACTIVE' : 'INACTIVE',
                    style: TextStyle(
                      color: isActive ? Colors.green : Colors.red,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'By: $createdBy',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                Text(
                  'Updated: ${lastUpdated != null ? DateFormat('MMM dd, yyyy').format(lastUpdated.toDate()) : 'Unknown'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Actions
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _toggleGuidelineStatus(guidelineId, !isActive),
                  icon: Icon(isActive ? Icons.pause : Icons.play_arrow, size: 16),
                  label: Text(isActive ? 'Deactivate' : 'Activate'),
                  style: TextButton.styleFrom(
                    foregroundColor: isActive ? Colors.orange : Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _editGuideline(guidelineId, data),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _deleteGuideline(guidelineId, title),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'general':
        return 'General Guidelines';
      case 'allergen':
        return 'Allergen Rules';
      case 'dietary':
        return 'Dietary Standards';
      case 'health':
        return 'Health Conditions';
      default:
        return 'Unknown Category';
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'general':
        return Colors.blue;
      case 'allergen':
        return Colors.orange;
      case 'dietary':
        return Colors.green;
      case 'health':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'general':
        return Icons.article;
      case 'allergen':
        return Icons.warning;
      case 'dietary':
        return Icons.restaurant;
      case 'health':
        return Icons.health_and_safety;
      default:
        return Icons.help;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  void _showAddGuidelineDialog({String? category}) {
    showDialog(
      context: context,
      builder: (context) => _AddGuidelineDialog(
        category: category ?? 'general',
        onGuidelineAdded: () {
          setState(() {});
        },
      ),
    );
  }

  void _editGuideline(String guidelineId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => _AddGuidelineDialog(
        category: data['category'] ?? 'general',
        guidelineId: guidelineId,
        initialData: data,
        onGuidelineAdded: () {
          setState(() {});
        },
      ),
    );
  }

  Future<void> _toggleGuidelineStatus(String guidelineId, bool newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('nutritional_guidelines')
          .doc(guidelineId)
          .update({
        'isActive': newStatus,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Guideline ${newStatus ? 'activated' : 'deactivated'} successfully!'),
            backgroundColor: newStatus ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating guideline: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteGuideline(String guidelineId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Guideline'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('nutritional_guidelines')
            .doc(guidelineId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Guideline deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting guideline: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class _AddGuidelineDialog extends StatefulWidget {
  final String category;
  final String? guidelineId;
  final Map<String, dynamic>? initialData;
  final VoidCallback onGuidelineAdded;

  const _AddGuidelineDialog({
    required this.category,
    this.guidelineId,
    this.initialData,
    required this.onGuidelineAdded,
  });

  @override
  State<_AddGuidelineDialog> createState() => _AddGuidelineDialogState();
}

class _AddGuidelineDialogState extends State<_AddGuidelineDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  String _selectedCategory = 'general';
  String _selectedPriority = 'medium';
  bool _isActive = true;

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.category;
    
    if (widget.initialData != null) {
      _titleController.text = widget.initialData!['title'] ?? '';
      _contentController.text = widget.initialData!['content'] ?? '';
      _selectedCategory = widget.initialData!['category'] ?? 'general';
      _selectedPriority = widget.initialData!['priority'] ?? 'medium';
      _isActive = widget.initialData!['isActive'] ?? true;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              widget.guidelineId != null ? 'Edit Guideline' : 'Add New Guideline',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Title
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Category
                      DropdownButtonFormField<String>(
                        value: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'general', child: Text('General Guidelines')),
                          DropdownMenuItem(value: 'allergen', child: Text('Allergen Rules')),
                          DropdownMenuItem(value: 'dietary', child: Text('Dietary Standards')),
                          DropdownMenuItem(value: 'health', child: Text('Health Conditions')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Priority
                      DropdownButtonFormField<String>(
                        value: _selectedPriority,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'low', child: Text('Low')),
                          DropdownMenuItem(value: 'medium', child: Text('Medium')),
                          DropdownMenuItem(value: 'high', child: Text('High')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedPriority = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Content
                      TextFormField(
                        controller: _contentController,
                        decoration: const InputDecoration(
                          labelText: 'Content',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 8,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter content';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Active Status
                      SwitchListTile(
                        title: const Text('Active'),
                        subtitle: const Text('Guideline is currently active'),
                        value: _isActive,
                        onChanged: (value) {
                          setState(() {
                            _isActive = value;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _saveGuideline,
                  child: Text(widget.guidelineId != null ? 'Update' : 'Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveGuideline() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final data = {
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'category': _selectedCategory,
        'priority': _selectedPriority,
        'isActive': _isActive,
        'lastUpdated': FieldValue.serverTimestamp(),
        'createdBy': 'nutritionist',
      };

      if (widget.guidelineId != null) {
        // Update existing guideline
        await FirebaseFirestore.instance
            .collection('nutritional_guidelines')
            .doc(widget.guidelineId)
            .update(data);
      } else {
        // Create new guideline
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('nutritional_guidelines')
            .add(data);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onGuidelineAdded();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.guidelineId != null ? 'Guideline updated!' : 'Guideline created!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving guideline: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
