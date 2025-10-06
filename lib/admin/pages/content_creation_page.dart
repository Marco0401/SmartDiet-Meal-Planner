import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
            onPressed: () => _showAddContentDialog(contentType: 'tips'),
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
          .orderBy('createdAt', descending: true)
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
  String _selectedType = 'tips';
  bool _isPublished = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.contentType;
    
    if (widget.initialData != null) {
      _titleController.text = widget.initialData!['title'] ?? '';
      _descriptionController.text = widget.initialData!['description'] ?? '';
      _contentController.text = widget.initialData!['content'] ?? '';
      _selectedType = widget.initialData!['type'] ?? 'tips';
      _isPublished = widget.initialData!['isPublished'] ?? false;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
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
              widget.contentId != null ? 'Edit Content' : 'Add New Content',
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
                      
                      // Type
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Content Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'tips', child: Text('Tips')),
                          DropdownMenuItem(value: 'articles', child: Text('Articles')),
                          DropdownMenuItem(value: 'videos', child: Text('Videos')),
                          DropdownMenuItem(value: 'recipes', child: Text('Recipes')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
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
                      
                      // Published Status
                      SwitchListTile(
                        title: const Text('Published'),
                        subtitle: const Text('Content is visible to users'),
                        value: _isPublished,
                        onChanged: (value) {
                          setState(() {
                            _isPublished = value;
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
                  onPressed: _saveContent,
                  child: Text(widget.contentId != null ? 'Update' : 'Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveContent() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final data = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'content': _contentController.text.trim(),
        'type': _selectedType,
        'isPublished': _isPublished,
        'lastUpdated': FieldValue.serverTimestamp(),
        'createdBy': 'nutritionist',
        'views': 0,
        'likes': 0,
      };

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
            content: Text(widget.contentId != null ? 'Content updated!' : 'Content created!'),
            backgroundColor: Colors.green,
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
}
