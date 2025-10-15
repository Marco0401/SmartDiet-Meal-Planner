import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

class ContentCreationPage extends StatefulWidget {
  const ContentCreationPage({super.key});

  @override
  State<ContentCreationPage> createState() => _ContentCreationPageState();
}

class _ContentCreationPageState extends State<ContentCreationPage> with TickerProviderStateMixin {
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
        title: const Text('Educational Content Creation'),
        backgroundColor: const Color(0xFF4CAF50),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Tips', icon: Icon(Icons.lightbulb)),
            Tab(text: 'Articles', icon: Icon(Icons.article)),
            Tab(text: 'Videos', icon: Icon(Icons.video_library)),
            Tab(text: 'Recipes', icon: Icon(Icons.restaurant)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _showAddContentDialog(contentType: _getCurrentTabContentType()),
            icon: const Icon(Icons.add),
            tooltip: 'Add New Content',
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
                hintText: 'Search content...',
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
                _buildContentList('tips'),
                _buildContentList('articles'),
                _buildContentList('videos'),
                _buildContentList('recipes'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentList(String contentType) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('educational_content')
          .where('type', isEqualTo: contentType)
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

        final content = snapshot.data?.docs ?? [];
        final filteredContent = content.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final title = data['title']?.toString().toLowerCase() ?? '';
          final description = data['description']?.toString().toLowerCase() ?? '';
          return title.contains(_searchQuery) || description.contains(_searchQuery);
        }).toList();

        if (filteredContent.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getContentTypeIcon(contentType),
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No ${_getContentTypeDisplayName(contentType)} found',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showAddContentDialog(contentType: contentType),
                  icon: const Icon(Icons.add),
                  label: Text('Add First ${_getContentTypeDisplayName(contentType).substring(0, _getContentTypeDisplayName(contentType).length - 1)}'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredContent.length,
          itemBuilder: (context, index) {
            final doc = filteredContent[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildContentCard(doc.id, data, contentType);
          },
        );
      },
    );
  }

  Widget _buildContentCard(String contentId, Map<String, dynamic> data, String contentType) {
    final title = data['title'] ?? 'Untitled Content';
    final description = data['description'] ?? '';
    final isPublished = data['isPublished'] ?? false;
    final createdAt = data['createdAt'] as Timestamp?;
    final publishedAt = data['publishedAt'] as Timestamp?;
    final views = data['views'] ?? 0;
    final likes = data['likes'] ?? 0;

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
                    color: _getContentTypeColor(contentType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getContentTypeIcon(contentType),
                    color: _getContentTypeColor(contentType),
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
                        _getContentTypeDisplayName(contentType),
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
                    color: isPublished ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isPublished ? 'PUBLISHED' : 'DRAFT',
                    style: TextStyle(
                      color: isPublished ? Colors.green : Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Description Preview
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
                    'Description:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description.length > 200 ? '${description.substring(0, 200)}...' : description,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Stats
            Row(
              children: [
                _buildStatItem(Icons.visibility, views.toString(), 'Views'),
                const SizedBox(width: 16),
                _buildStatItem(Icons.favorite, likes.toString(), 'Likes'),
                const Spacer(),
                if (isPublished && publishedAt != null)
                  Text(
                    'Published: ${DateFormat('MMM dd, yyyy').format(publishedAt.toDate())}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  )
                else
                  Text(
                    'Created: ${createdAt != null ? DateFormat('MMM dd, yyyy').format(createdAt.toDate()) : 'Unknown'}',
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
                  onPressed: () => _togglePublishStatus(contentId, !isPublished),
                  icon: Icon(isPublished ? Icons.unpublished : Icons.publish, size: 16),
                  label: Text(isPublished ? 'Unpublish' : 'Publish'),
                  style: TextButton.styleFrom(
                    foregroundColor: isPublished ? Colors.orange : Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _editContent(contentId, data),
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _viewContent(contentId, data),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('View'),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _deleteContent(contentId, title),
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

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  String _getContentTypeDisplayName(String type) {
    switch (type) {
      case 'tips':
        return 'Tips';
      case 'articles':
        return 'Articles';
      case 'videos':
        return 'Videos';
      case 'recipes':
        return 'Recipes';
      default:
        return 'Unknown Type';
    }
  }

  String _getCurrentTabContentType() {
    switch (_tabController.index) {
      case 0:
        return 'tips';
      case 1:
        return 'articles';
      case 2:
        return 'videos';
      case 3:
        return 'recipes';
      default:
        return 'tips';
    }
  }

  Color _getContentTypeColor(String type) {
    switch (type) {
      case 'tips':
        return Colors.amber;
      case 'articles':
        return Colors.blue;
      case 'videos':
        return Colors.red;
      case 'recipes':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getContentTypeIcon(String type) {
    switch (type) {
      case 'tips':
        return Icons.lightbulb;
      case 'articles':
        return Icons.article;
      case 'videos':
        return Icons.video_library;
      case 'recipes':
        return Icons.restaurant;
      default:
        return Icons.help;
    }
  }

  void _showAddContentDialog({String? contentType}) {
    showDialog(
      context: context,
      builder: (context) => _AddContentDialog(
        contentType: contentType ?? 'tips',
        onContentAdded: () {
          setState(() {});
        },
      ),
    );
  }

  void _editContent(String contentId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => _AddContentDialog(
        contentType: data['type'] ?? 'tips',
        contentId: contentId,
        initialData: data,
        onContentAdded: () {
          setState(() {});
        },
      ),
    );
  }

  void _viewContent(String contentId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['title'] ?? 'Content Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Type: ${_getContentTypeDisplayName(data['type'] ?? '')}'),
              Text('Description: ${data['description'] ?? 'No description'}'),
              Text('Status: ${data['isPublished'] == true ? 'Published' : 'Draft'}'),
              Text('Views: ${data['views'] ?? 0}'),
              Text('Likes: ${data['likes'] ?? 0}'),
              if (data['content'] != null) ...[
                const SizedBox(height: 8),
                const Text('Content:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(data['content']),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePublishStatus(String contentId, bool newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('educational_content')
          .doc(contentId)
          .update({
        'isPublished': newStatus,
        if (newStatus) 'publishedAt': FieldValue.serverTimestamp(),
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Content ${newStatus ? 'published' : 'unpublished'} successfully!'),
            backgroundColor: newStatus ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating content: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteContent(String contentId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Content'),
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
            .collection('educational_content')
            .doc(contentId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Content deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting content: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class _AddContentDialog extends StatefulWidget {
  final String contentType;
  final String? contentId;
  final Map<String, dynamic>? initialData;
  final VoidCallback onContentAdded;

  const _AddContentDialog({
    required this.contentType,
    this.contentId,
    this.initialData,
    required this.onContentAdded,
  });

  @override
  State<_AddContentDialog> createState() => _AddContentDialogState();
}

class _AddContentDialogState extends State<_AddContentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contentController = TextEditingController();
  final _urlController = TextEditingController();
  final _authorController = TextEditingController();
  final _durationController = TextEditingController();
  final _servingsController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _cookTimeController = TextEditingController();
  final _recipeDescriptionController = TextEditingController();
  final _ingredientsController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _nutritionInfoController = TextEditingController();
  
  String _selectedType = 'tips';
  bool _isPublished = false;
  String _contentSource = 'text'; // 'text', 'url', 'video'
  String? _selectedCategory;
  List<String> _selectedTags = [];
  String? _difficultyLevel;
  String? _targetAudience;

  // Content type specific options
  final List<String> _tipCategories = ['Nutrition', 'Exercise', 'Lifestyle', 'Health', 'Cooking'];
  final List<String> _articleCategories = ['Research', 'News', 'Guide', 'Review', 'Opinion'];
  final List<String> _videoCategories = ['Tutorial', 'Educational', 'Demonstration', 'Interview', 'Documentary'];
  final List<String> _recipeCategories = ['Breakfast', 'Lunch', 'Dinner', 'Snack', 'Dessert', 'Beverage'];
  
  final List<String> _difficultyLevels = ['Beginner', 'Intermediate', 'Advanced'];
  final List<String> _targetAudiences = ['General', 'Athletes', 'Seniors', 'Children', 'Pregnant Women', 'Diabetics'];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.contentType;
    
    if (widget.initialData != null) {
      _titleController.text = widget.initialData!['title'] ?? '';
      _descriptionController.text = widget.initialData!['description'] ?? '';
      _contentController.text = widget.initialData!['content'] ?? '';
      _urlController.text = widget.initialData!['url'] ?? '';
      _authorController.text = widget.initialData!['author'] ?? '';
      _durationController.text = widget.initialData!['duration'] ?? '';
      _servingsController.text = widget.initialData!['servings']?.toString() ?? '';
      _prepTimeController.text = widget.initialData!['prepTime'] ?? '';
      _cookTimeController.text = widget.initialData!['cookTime'] ?? '';
      _selectedType = widget.initialData!['type'] ?? 'tips';
      _isPublished = widget.initialData!['isPublished'] ?? false;
      _contentSource = widget.initialData!['contentSource'] ?? 'text';
      _selectedCategory = widget.initialData!['category'];
      _selectedTags = List<String>.from(widget.initialData!['tags'] ?? []);
      _difficultyLevel = widget.initialData!['difficultyLevel'];
      _targetAudience = widget.initialData!['targetAudience'];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    _urlController.dispose();
    _authorController.dispose();
    _durationController.dispose();
    _servingsController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                Icon(_getContentTypeIcon(_selectedType), size: 28, color: _getContentTypeColor(_selectedType)),
                const SizedBox(width: 12),
                Text(
                  widget.contentId != null ? 'Edit ${_getContentTypeName(_selectedType)}' : 'Create New ${_getContentTypeName(_selectedType)}',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Content Type Specific Form
                      _buildContentTypeForm(),
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
                ElevatedButton.icon(
                  onPressed: _saveContent,
                  icon: Icon(_getContentTypeIcon(_selectedType)),
                  label: Text(widget.contentId != null ? 'Update' : 'Create'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _getContentTypeColor(_selectedType),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContentTypeForm() {
    switch (_selectedType) {
      case 'tips':
        return _buildTipsForm();
      case 'articles':
        return _buildArticlesForm();
      case 'videos':
        return _buildVideosForm();
      case 'recipes':
        return _buildRecipesForm();
      default:
        return _buildTipsForm();
    }
  }

  Widget _buildTipsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBasicFields(),
        const SizedBox(height: 20),
        _buildCategoryDropdown(_tipCategories),
        const SizedBox(height: 20),
        _buildTagsField(),
        const SizedBox(height: 20),
        _buildTargetAudienceDropdown(),
        const SizedBox(height: 20),
        _buildPublishedSwitch(),
      ],
    );
  }

  Widget _buildArticlesForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBasicFields(),
        const SizedBox(height: 20),
        _buildAuthorField(),
        const SizedBox(height: 20),
        _buildContentField(),
        const SizedBox(height: 20),
        _buildOptionalUrlField(),
        const SizedBox(height: 20),
        _buildCategoryDropdown(_articleCategories),
        const SizedBox(height: 20),
        _buildTagsField(),
        const SizedBox(height: 20),
        _buildTargetAudienceDropdown(),
        const SizedBox(height: 20),
        _buildPublishedSwitch(),
      ],
    );
  }

  Widget _buildVideosForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBasicFields(),
        const SizedBox(height: 20),
        _buildAuthorField(),
        const SizedBox(height: 20),
        _buildVideoSourceSelector(),
        const SizedBox(height: 20),
        if (_contentSource == 'url') _buildVideoUrlField(),
        if (_contentSource == 'text') _buildContentField(),
        const SizedBox(height: 20),
        _buildDurationField(),
        const SizedBox(height: 20),
        _buildCategoryDropdown(_videoCategories),
        const SizedBox(height: 20),
        _buildDifficultyDropdown(),
        const SizedBox(height: 20),
        _buildTagsField(),
        const SizedBox(height: 20),
        _buildTargetAudienceDropdown(),
        const SizedBox(height: 20),
        _buildPublishedSwitch(),
      ],
    );
  }

  Widget _buildRecipesForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBasicFields(),
        const SizedBox(height: 20),
        _buildAuthorField(),
        const SizedBox(height: 20),
        _buildRecipeDescriptionField(),
        const SizedBox(height: 20),
        _buildIngredientsField(),
        const SizedBox(height: 20),
        _buildInstructionsField(),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(child: _buildServingsField()),
            const SizedBox(width: 16),
            Expanded(child: _buildPrepTimeField()),
            const SizedBox(width: 16),
            Expanded(child: _buildCookTimeField()),
          ],
        ),
        const SizedBox(height: 20),
        _buildNutritionInfoField(),
        const SizedBox(height: 20),
        _buildRecipeImageField(),
        const SizedBox(height: 20),
        _buildCategoryDropdown(_recipeCategories),
        const SizedBox(height: 20),
        _buildDifficultyDropdown(),
        const SizedBox(height: 20),
        _buildTagsField(),
        const SizedBox(height: 20),
        _buildTargetAudienceDropdown(),
        const SizedBox(height: 20),
        _buildPublishedSwitch(),
      ],
    );
  }

  Widget _buildBasicFields() {
    return Column(
      children: [
        TextFormField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'Title',
            border: const OutlineInputBorder(),
            prefixIcon: Icon(Icons.title, color: _getContentTypeColor(_selectedType)),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a title';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: 'Description',
            border: const OutlineInputBorder(),
            prefixIcon: Icon(Icons.description, color: _getContentTypeColor(_selectedType)),
          ),
          maxLines: 3,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter a description';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildAuthorField() {
    return TextFormField(
      controller: _authorController,
      decoration: InputDecoration(
        labelText: 'Author/Creator',
        border: const OutlineInputBorder(),
        prefixIcon: Icon(Icons.person, color: _getContentTypeColor(_selectedType)),
      ),
    );
  }


  Widget _buildContentField() {
    return TextFormField(
      controller: _contentController,
      decoration: InputDecoration(
        labelText: 'Content',
        border: const OutlineInputBorder(),
        alignLabelWithHint: true,
        prefixIcon: Icon(Icons.article, color: _getContentTypeColor(_selectedType)),
      ),
      maxLines: 8,
      validator: (value) {
        if (_contentSource == 'text' && (value == null || value.isEmpty)) {
          return 'Please enter content';
        }
        return null;
      },
    );
  }


  Widget _buildOptionalUrlField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.link, color: _getContentTypeColor(_selectedType), size: 20),
            const SizedBox(width: 8),
            Text(
              'Optional External Link',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _getContentTypeColor(_selectedType),
                fontSize: 16,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[600], size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Add a URL if this article references external content or if users should read more elsewhere',
                  style: TextStyle(
                    color: Colors.blue[700],
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _urlController,
          decoration: InputDecoration(
            labelText: 'External URL (Optional)',
            border: const OutlineInputBorder(),
            prefixIcon: Icon(Icons.open_in_new, color: _getContentTypeColor(_selectedType)),
            hintText: 'https://example.com/article',
            helperText: 'Leave empty if this is your own article content',
          ),
          validator: (value) {
            if (value != null && value.isNotEmpty) {
              // Basic URL validation
              if (!value.startsWith('http://') && !value.startsWith('https://')) {
                return 'Please enter a valid URL starting with http:// or https://';
              }
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildVideoSourceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Video Source', style: TextStyle(fontWeight: FontWeight.bold, color: _getContentTypeColor(_selectedType))),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: RadioListTile<String>(
                title: const Text('YouTube Video'),
                subtitle: const Text('Embed YouTube video'),
                value: 'url',
                groupValue: _contentSource,
                onChanged: (value) => setState(() => _contentSource = value!),
                activeColor: _getContentTypeColor(_selectedType),
              ),
            ),
            Expanded(
              child: RadioListTile<String>(
                title: const Text('Text Description'),
                subtitle: const Text('Describe video content'),
                value: 'text',
                groupValue: _contentSource,
                onChanged: (value) => setState(() => _contentSource = value!),
                activeColor: _getContentTypeColor(_selectedType),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVideoUrlField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _urlController,
          decoration: InputDecoration(
            labelText: 'YouTube Video URL',
            border: const OutlineInputBorder(),
            prefixIcon: Icon(Icons.play_circle_filled, color: _getContentTypeColor(_selectedType)),
            hintText: 'https://www.youtube.com/watch?v=VIDEO_ID',
            helperText: 'Paste the YouTube video URL here',
          ),
          validator: (value) {
            if (_contentSource == 'url' && (value == null || value.isEmpty)) {
              return 'Please enter a YouTube video URL';
            }
            if (value != null && value.isNotEmpty) {
              if (!value.contains('youtube.com') && !value.contains('youtu.be')) {
                return 'Please enter a valid YouTube URL';
              }
            }
            return null;
          },
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red[200]!),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.red[600], size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Paste the YouTube video URL. The video will be embedded and playable in the app.',
                  style: TextStyle(
                    color: Colors.red[700],
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDurationField() {
    return TextFormField(
      controller: _durationController,
      decoration: InputDecoration(
        labelText: 'Duration (minutes)',
        border: const OutlineInputBorder(),
        prefixIcon: Icon(Icons.timer, color: _getContentTypeColor(_selectedType)),
        hintText: 'e.g., 15',
      ),
      keyboardType: TextInputType.number,
    );
  }

  Widget _buildServingsField() {
    return TextFormField(
      controller: _servingsController,
      decoration: InputDecoration(
        labelText: 'Servings',
        border: const OutlineInputBorder(),
        prefixIcon: Icon(Icons.people, color: _getContentTypeColor(_selectedType)),
        hintText: '4',
      ),
      keyboardType: TextInputType.number,
    );
  }

  Widget _buildPrepTimeField() {
    return TextFormField(
      controller: _prepTimeController,
      decoration: InputDecoration(
        labelText: 'Prep Time',
        border: const OutlineInputBorder(),
        prefixIcon: Icon(Icons.schedule, color: _getContentTypeColor(_selectedType)),
        hintText: '15 mins',
      ),
    );
  }

  Widget _buildCookTimeField() {
    return TextFormField(
      controller: _cookTimeController,
      decoration: InputDecoration(
        labelText: 'Cook Time',
        border: const OutlineInputBorder(),
        prefixIcon: Icon(Icons.schedule, color: _getContentTypeColor(_selectedType)),
        hintText: '30 mins',
      ),
    );
  }

  Widget _buildCategoryDropdown(List<String> categories) {
    return DropdownButtonFormField<String>(
      value: _selectedCategory,
      decoration: InputDecoration(
        labelText: 'Category',
        border: const OutlineInputBorder(),
        prefixIcon: Icon(Icons.category, color: _getContentTypeColor(_selectedType)),
      ),
      items: categories.map((category) => DropdownMenuItem(
        value: category,
        child: Text(category),
      )).toList(),
      onChanged: (value) => setState(() => _selectedCategory = value),
    );
  }

  Widget _buildDifficultyDropdown() {
    return DropdownButtonFormField<String>(
      value: _difficultyLevel,
      decoration: InputDecoration(
        labelText: 'Difficulty Level',
        border: const OutlineInputBorder(),
        prefixIcon: Icon(Icons.trending_up, color: _getContentTypeColor(_selectedType)),
      ),
      items: _difficultyLevels.map((level) => DropdownMenuItem(
        value: level,
        child: Text(level),
      )).toList(),
      onChanged: (value) => setState(() => _difficultyLevel = value),
    );
  }

  Widget _buildTargetAudienceDropdown() {
    return DropdownButtonFormField<String>(
      value: _targetAudience,
      decoration: InputDecoration(
        labelText: 'Target Audience',
        border: const OutlineInputBorder(),
        prefixIcon: Icon(Icons.group, color: _getContentTypeColor(_selectedType)),
      ),
      items: _targetAudiences.map((audience) => DropdownMenuItem(
        value: audience,
        child: Text(audience),
      )).toList(),
      onChanged: (value) => setState(() => _targetAudience = value),
    );
  }

  Widget _buildTagsField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tags', style: TextStyle(fontWeight: FontWeight.bold, color: _getContentTypeColor(_selectedType))),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ..._selectedTags.map((tag) => Chip(
              label: Text(tag),
              onDeleted: () => setState(() => _selectedTags.remove(tag)),
              deleteIconColor: _getContentTypeColor(_selectedType),
            )),
            ActionChip(
              label: const Text('+ Add Tag'),
              onPressed: _addTag,
              backgroundColor: _getContentTypeColor(_selectedType).withOpacity(0.1),
              labelStyle: TextStyle(color: _getContentTypeColor(_selectedType)),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPublishedSwitch() {
    return SwitchListTile(
      title: const Text('Published'),
      subtitle: const Text('Content is visible to users'),
      value: _isPublished,
      onChanged: (value) => setState(() => _isPublished = value),
      activeColor: _getContentTypeColor(_selectedType),
    );
  }

  void _addTag() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Tag'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Tag name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() => _selectedTags.add(controller.text.trim()));
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  IconData _getContentTypeIcon(String type) {
    switch (type) {
      case 'tips': return Icons.lightbulb;
      case 'articles': return Icons.article;
      case 'videos': return Icons.video_library;
      case 'recipes': return Icons.restaurant;
      default: return Icons.lightbulb;
    }
  }

  Color _getContentTypeColor(String type) {
    switch (type) {
      case 'tips': return Colors.orange;
      case 'articles': return Colors.blue;
      case 'videos': return Colors.purple;
      case 'recipes': return Colors.green;
      default: return Colors.orange;
    }
  }

  String _getContentTypeName(String type) {
    switch (type) {
      case 'tips': return 'Tip';
      case 'articles': return 'Article';
      case 'videos': return 'Video';
      case 'recipes': return 'Recipe';
      default: return 'Content';
    }
  }

  String _extractYouTubeVideoId(String url) {
    // Extract video ID from various YouTube URL formats
    RegExp regExp = RegExp(
      r'(?:youtube\.com\/(?:[^\/]+\/.+\/|(?:v|e(?:mbed)?)\/|.*[?&]v=)|youtu\.be\/)([^"&?\/\s]{11})',
      caseSensitive: false,
    );
    Match? match = regExp.firstMatch(url);
    return match?.group(1) ?? '';
  }

  Future<void> _saveContent() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final data = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'type': _selectedType,
        'isPublished': _isPublished,
        'lastUpdated': FieldValue.serverTimestamp(),
        'createdBy': 'nutritionist',
        'views': 0,
        'likes': 0,
        'contentSource': _contentSource,
        'category': _selectedCategory,
        'tags': _selectedTags,
        'difficultyLevel': _difficultyLevel,
        'targetAudience': _targetAudience,
      };

      // Add content-specific fields
      if (_selectedType == 'articles') {
        // Articles always have content
        data['content'] = _contentController.text.trim();
        data['contentSource'] = 'text'; // Articles are always text-based
        
        // Add optional URL if provided
        if (_urlController.text.isNotEmpty) {
          data['url'] = _urlController.text.trim();
        }
      } else if (_contentSource == 'text') {
        data['content'] = _contentController.text.trim();
      } else if (_contentSource == 'url') {
        data['url'] = _urlController.text.trim();
      }

      // Add author if provided
      if (_authorController.text.isNotEmpty) {
        data['author'] = _authorController.text.trim();
      }

      // Add video-specific fields
      if (_selectedType == 'videos') {
        if (_durationController.text.isNotEmpty) {
          data['duration'] = _durationController.text.trim();
        }
        // Set contentSource based on video type
        data['contentSource'] = _contentSource;
        
        // Add YouTube URL if provided
        if (_contentSource == 'url' && _urlController.text.isNotEmpty) {
          data['youtubeUrl'] = _urlController.text.trim();
          // Extract video ID for embedding
          String videoId = _extractYouTubeVideoId(_urlController.text.trim());
          if (videoId.isNotEmpty) {
            data['youtubeVideoId'] = videoId;
          }
        }
      }

      // Add recipe-specific fields
      if (_selectedType == 'recipes') {
        // Basic recipe info
        if (_servingsController.text.isNotEmpty) {
          data['servings'] = int.tryParse(_servingsController.text.trim()) ?? 1;
        }
        if (_prepTimeController.text.isNotEmpty) {
          data['prepTime'] = _prepTimeController.text.trim();
        }
        if (_cookTimeController.text.isNotEmpty) {
          data['cookTime'] = _cookTimeController.text.trim();
        }
        
        // Enhanced recipe fields
        if (_recipeDescriptionController.text.isNotEmpty) {
          data['recipeDescription'] = _recipeDescriptionController.text.trim();
        }
        if (_ingredientsController.text.isNotEmpty) {
          data['ingredients'] = _ingredientsController.text.trim();
        }
        if (_instructionsController.text.isNotEmpty) {
          data['instructions'] = _instructionsController.text.trim();
        }
        if (_nutritionInfoController.text.isNotEmpty) {
          data['nutritionInfo'] = _nutritionInfoController.text.trim();
        }
        
        // Set content type for recipes
        data['contentSource'] = 'recipe';
      }

      if (widget.contentId != null) {
        // Update existing content
        await FirebaseFirestore.instance
            .collection('educational_content')
            .doc(widget.contentId)
            .update(data);
      } else {
        // Create new content
        data['createdAt'] = FieldValue.serverTimestamp();
        if (_isPublished) {
          data['publishedAt'] = FieldValue.serverTimestamp();
        }
        await FirebaseFirestore.instance
            .collection('educational_content')
            .add(data);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onContentAdded();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.contentId != null 
                ? '${_getContentTypeName(_selectedType)} updated!' 
                : '${_getContentTypeName(_selectedType)} created!'),
            backgroundColor: _getContentTypeColor(_selectedType),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving content: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildRecipeDescriptionField() {
    return TextFormField(
      controller: _recipeDescriptionController,
      decoration: InputDecoration(
        labelText: 'Recipe Description',
        border: const OutlineInputBorder(),
        prefixIcon: Icon(Icons.description, color: _getContentTypeColor(_selectedType)),
        hintText: 'Brief description of the recipe...',
        helperText: 'Describe what makes this recipe special',
      ),
      maxLines: 3,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter a recipe description';
        }
        return null;
      },
    );
  }

  Widget _buildIngredientsField() {
    return TextFormField(
      controller: _ingredientsController,
      decoration: InputDecoration(
        labelText: 'Ingredients',
        border: const OutlineInputBorder(),
        prefixIcon: Icon(Icons.list_alt, color: _getContentTypeColor(_selectedType)),
        hintText: 'List all ingredients with measurements...',
        helperText: 'Example: 2 cups flour, 1 tsp salt, 3 eggs',
      ),
      maxLines: 5,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter the ingredients';
        }
        return null;
      },
    );
  }

  Widget _buildInstructionsField() {
    return TextFormField(
      controller: _instructionsController,
      decoration: InputDecoration(
        labelText: 'Cooking Instructions',
        border: const OutlineInputBorder(),
        prefixIcon: Icon(Icons.format_list_numbered, color: _getContentTypeColor(_selectedType)),
        hintText: 'Step-by-step cooking instructions...',
        helperText: 'Provide clear, numbered steps',
      ),
      maxLines: 8,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter cooking instructions';
        }
        return null;
      },
    );
  }

  Widget _buildNutritionInfoField() {
    return TextFormField(
      controller: _nutritionInfoController,
      decoration: InputDecoration(
        labelText: 'Nutrition Information (Optional)',
        border: const OutlineInputBorder(),
        prefixIcon: Icon(Icons.local_fire_department, color: _getContentTypeColor(_selectedType)),
        hintText: 'Calories per serving, protein, carbs, etc.',
        helperText: 'Example: 350 calories, 25g protein, 30g carbs per serving',
      ),
      maxLines: 3,
    );
  }

  Widget _buildRecipeImageField() {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        border: Border.all(
          color: _getContentTypeColor(_selectedType)
        ),
        borderRadius: BorderRadius.circular(12),
        color: _getContentTypeColor(_selectedType).withOpacity(0.05),
      ),
      child: InkWell(
        onTap: () {
          // TODO: Implement image picker for recipe photos
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recipe image upload coming soon!'),
              backgroundColor: Colors.orange,
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getContentTypeColor(_selectedType).withOpacity(0.1),
                borderRadius: BorderRadius.circular(50),
              ),
              child: Icon(
                Icons.add_a_photo, 
                size: 32, 
                color: _getContentTypeColor(_selectedType)
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add Recipe Photo', 
              style: TextStyle(
                color: _getContentTypeColor(_selectedType),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              )
            ),
            const SizedBox(height: 4),
            Text(
              'Tap to upload recipe image',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
