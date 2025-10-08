import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../services/personalized_nutrition_service.dart';

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
    _tabController = TabController(length: 5, vsync: this);
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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.psychology, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('Nutritional Guidelines Editor'),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF9C27B0), Color(0xFFBA68C8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white.withOpacity(0.1),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              isScrollable: true,
              tabs: const [
                Tab(text: 'General Guidelines', icon: Icon(Icons.article, size: 18)),
                Tab(text: 'Allergen Rules', icon: Icon(Icons.warning, size: 18)),
                Tab(text: 'Dietary Standards', icon: Icon(Icons.restaurant, size: 18)),
                Tab(text: 'Health Conditions', icon: Icon(Icons.health_and_safety, size: 18)),
                Tab(text: 'Personalized Rules', icon: Icon(Icons.person_pin, size: 18)),
              ],
            ),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () => _showAddGuidelineDialog(category: 'general'),
              icon: const Icon(Icons.add),
              tooltip: 'Add New Guideline',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              onPressed: () {
                setState(() {});
              },
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
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
                _buildPersonalizedRulesList(),
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
      elevation: 3,
      shadowColor: _getCategoryColor(category).withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: _getCategoryColor(category).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              _getCategoryColor(category).withOpacity(0.02),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getCategoryColor(category),
                          _getCategoryColor(category).withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _getCategoryColor(category).withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      _getCategoryIcon(category),
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.label,
                              size: 14,
                              color: _getCategoryColor(category),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _getCategoryDisplayName(category),
                              style: TextStyle(
                                fontSize: 13,
                                color: _getCategoryColor(category),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getPriorityColor(priority),
                          _getPriorityColor(priority).withOpacity(0.7),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _getPriorityColor(priority).withOpacity(0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          priority == 'high' ? Icons.arrow_upward :
                          priority == 'medium' ? Icons.remove : Icons.arrow_downward,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          priority.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            
              const SizedBox(height: 20),
              
              // Content Preview
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _getCategoryColor(category).withOpacity(0.05),
                      Colors.grey.shade50,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getCategoryColor(category).withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.description,
                          size: 16,
                          color: _getCategoryColor(category),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Content Preview',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _getCategoryColor(category),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      content.length > 200 ? '${content.substring(0, 200)}...' : content,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Status and Metadata
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isActive 
                          ? [Colors.green, Colors.green.shade600]
                          : [Colors.grey, Colors.grey.shade600],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (isActive ? Colors.green : Colors.grey).withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive ? Icons.check_circle : Icons.pause_circle,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isActive ? 'ACTIVE' : 'INACTIVE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.person, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    createdBy,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.schedule, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    lastUpdated != null ? DateFormat('MMM dd, yyyy').format(lastUpdated.toDate()) : 'Unknown',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),
              
              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _toggleGuidelineStatus(guidelineId, !isActive),
                      icon: Icon(isActive ? Icons.pause : Icons.play_arrow, size: 18),
                      label: Text(isActive ? 'Deactivate' : 'Activate'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isActive ? Colors.orange : Colors.green,
                        side: BorderSide(
                          color: isActive ? Colors.orange : Colors.green,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _editGuideline(guidelineId, data),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _getCategoryColor(category),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => _deleteGuideline(guidelineId, title),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.all(12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.red.shade200),
                      ),
                    ),
                    child: const Icon(Icons.delete, size: 20),
                  ),
                ],
              ),
            ],
          ),
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

  String _formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
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

  Widget _buildPersonalizedRulesList() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _getPersonalizedRulesStream(),
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

        final rules = snapshot.data ?? [];

        if (rules.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_pin,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No personalized nutrition rules found',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Create rules to provide personalized nutrition advice based on user profiles',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => _showAddPersonalizedRuleDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Create First Rule'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rules.length,
          itemBuilder: (context, index) {
            final rule = rules[index];
            return _buildPersonalizedRuleCard(rule);
          },
        );
      },
    );
  }

  Stream<List<Map<String, dynamic>>> _getPersonalizedRulesStream() async* {
    try {
      final rules = await PersonalizedNutritionService.getAllNutritionRules();
      yield rules;
    } catch (e) {
      yield [];
    }
  }

  Widget _buildPersonalizedRuleCard(Map<String, dynamic> rule) {
    final id = rule['id'] as String;
    final name = rule['name'] ?? 'Unnamed Rule';
    final description = rule['description'] ?? '';
    final priority = rule['priority'] ?? 'medium';
    final isActive = rule['isActive'] ?? true;
    final conditions = rule['conditions'] as Map<String, dynamic>? ?? {};
    final adjustments = rule['adjustments'] as Map<String, dynamic>? ?? {};
    final createdAt = rule['createdAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shadowColor: Colors.purple.withOpacity(0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.purple.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Color(0xFFF3E5F5),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF9C27B0), Color(0xFFBA68C8)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purple.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.person_pin,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              priority == 'high' ? Icons.arrow_upward :
                              priority == 'medium' ? Icons.remove : Icons.arrow_downward,
                              size: 14,
                              color: _getPriorityColor(priority),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Priority: ${priority.toUpperCase()}',
                              style: TextStyle(
                                fontSize: 12,
                                color: _getPriorityColor(priority),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isActive 
                          ? [Colors.green, Colors.green.shade600]
                          : [Colors.grey, Colors.grey.shade600],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: (isActive ? Colors.green : Colors.grey).withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isActive ? Icons.check_circle : Icons.pause_circle,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isActive ? 'ACTIVE' : 'INACTIVE',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Description
              if (description.isNotEmpty) ...[
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
                const SizedBox(height: 12),
              ],
              
              // Conditions
              if (conditions.isNotEmpty) ...[
                const Text(
                  'Applies to:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _buildConditionChips(conditions),
                ),
                const SizedBox(height: 12),
              ],
              
              // Adjustments
              if (adjustments.isNotEmpty) ...[
                const Text(
                  'Nutrition Adjustments:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: _buildAdjustmentChips(adjustments),
                ),
                const SizedBox(height: 12),
              ],
              
              // Timestamp
              if (createdAt != null) ...[
                Text(
                  'Created: ${_formatDate(createdAt.toDate())}',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
              ],
              
              const Divider(height: 1),
              const SizedBox(height: 12),
              
              // Actions
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _toggleRuleStatus(id, !isActive),
                      icon: Icon(isActive ? Icons.pause : Icons.play_arrow, size: 18),
                      label: Text(isActive ? 'Deactivate' : 'Activate'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isActive ? Colors.orange : Colors.green,
                        side: BorderSide(
                          color: isActive ? Colors.orange : Colors.green,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _editPersonalizedRule(id, rule),
                      icon: const Icon(Icons.edit, size: 18),
                      label: const Text('Edit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () => _deletePersonalizedRule(id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade50,
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.all(12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: Colors.red.shade200),
                      ),
                    ),
                    child: const Icon(Icons.delete, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildConditionChips(Map<String, dynamic> conditions) {
    final chips = <Widget>[];
    
    if (conditions['minAge'] != null) {
      chips.add(_buildChip('Age ${conditions['minAge']}+', Colors.blue));
    }
    if (conditions['maxAge'] != null) {
      chips.add(_buildChip('Age ${conditions['maxAge']}-', Colors.blue));
    }
    if (conditions['gender'] != null) {
      chips.add(_buildChip(conditions['gender'], Colors.pink));
    }
    if (conditions['healthConditions'] != null) {
      final healthConditions = List<String>.from(conditions['healthConditions']);
      for (final condition in healthConditions) {
        chips.add(_buildChip(condition, Colors.red));
      }
    }
    if (conditions['dietaryPreferences'] != null) {
      final preferences = List<String>.from(conditions['dietaryPreferences']);
      for (final preference in preferences) {
        chips.add(_buildChip(preference, Colors.green));
      }
    }
    if (conditions['bodyGoals'] != null) {
      final goals = List<String>.from(conditions['bodyGoals']);
      for (final goal in goals) {
        chips.add(_buildChip(goal, Colors.orange));
      }
    }
    
    return chips;
  }

  List<Widget> _buildAdjustmentChips(Map<String, dynamic> adjustments) {
    final chips = <Widget>[];
    
    if (adjustments['calorieMultiplier'] != null) {
      chips.add(_buildChip('Calories ×${adjustments['calorieMultiplier']}', Colors.red));
    }
    if (adjustments['proteinRatio'] != null) {
      chips.add(_buildChip('Protein ${(adjustments['proteinRatio'] * 100).toStringAsFixed(0)}%', Colors.blue));
    }
    if (adjustments['carbRatio'] != null) {
      chips.add(_buildChip('Carbs ${(adjustments['carbRatio'] * 100).toStringAsFixed(0)}%', Colors.orange));
    }
    if (adjustments['fatRatio'] != null) {
      chips.add(_buildChip('Fat ${(adjustments['fatRatio'] * 100).toStringAsFixed(0)}%', Colors.green));
    }
    if (adjustments['mealFrequency'] != null) {
      chips.add(_buildChip('${adjustments['mealFrequency']} meals/day', Colors.purple));
    }
    
    return chips;
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showAddPersonalizedRuleDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddPersonalizedRuleDialog(
        onRuleAdded: () {
          setState(() {});
        },
      ),
    );
  }

  void _editPersonalizedRule(String ruleId, Map<String, dynamic> rule) {
    showDialog(
      context: context,
      builder: (context) => _AddPersonalizedRuleDialog(
        ruleId: ruleId,
        initialData: rule,
        onRuleAdded: () {
          setState(() {});
        },
      ),
    );
  }

  Future<void> _toggleRuleStatus(String ruleId, bool isActive) async {
    try {
      await PersonalizedNutritionService.updateNutritionRule(ruleId, {
        'isActive': isActive,
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rule ${isActive ? 'activated' : 'deactivated'} successfully'),
            backgroundColor: isActive ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating rule: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deletePersonalizedRule(String ruleId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Rule'),
        content: const Text('Are you sure you want to delete this personalized nutrition rule?'),
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
        await PersonalizedNutritionService.deleteNutritionRule(ruleId);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Rule deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting rule: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
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

class _AddPersonalizedRuleDialog extends StatefulWidget {
  final String? ruleId;
  final Map<String, dynamic>? initialData;
  final VoidCallback onRuleAdded;

  const _AddPersonalizedRuleDialog({
    this.ruleId,
    this.initialData,
    required this.onRuleAdded,
  });

  @override
  State<_AddPersonalizedRuleDialog> createState() => _AddPersonalizedRuleDialogState();
}

class _AddPersonalizedRuleDialogState extends State<_AddPersonalizedRuleDialog> with TickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  
  // Basic info
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedPriority = 'medium';
  bool _isActive = true;
  
  // Conditions
  int? _minAge;
  int? _maxAge;
  String? _gender;
  List<String> _healthConditions = [];
  List<String> _dietaryPreferences = [];
  List<String> _bodyGoals = [];
  String? _pregnancyStatus;
  bool _lactationStatus = false;
  
  // Adjustments
  double? _calorieMultiplier;
  double? _proteinRatio;
  double? _carbRatio;
  double? _fatRatio;
  int? _mealFrequency;
  List<String> _foodsToInclude = [];
  List<String> _foodsToAvoid = [];
  List<String> _supplements = [];
  List<String> _specialInstructions = [];

  final List<String> _priorities = ['low', 'medium', 'high'];
  final List<String> _genders = ['male', 'female', 'other'];
  final List<String> _pregnancyStatuses = ['none', 'pregnant', 'postpartum'];
  
  final List<String> _availableHealthConditions = [
    'Diabetes', 'Hypertension', 'Heart Disease', 'Obesity', 'Underweight',
    'High Cholesterol', 'Kidney Disease', 'Liver Disease', 'Celiac Disease',
    'IBS', 'Crohn\'s Disease', 'Ulcerative Colitis', 'PCOS', 'Thyroid Issues'
  ];
  
  final List<String> _availableDietaryPreferences = [
    'Vegetarian', 'Vegan', 'Keto', 'Paleo', 'Mediterranean', 'Low-Carb',
    'High-Protein', 'Gluten-Free', 'Dairy-Free', 'Low-Sodium', 'Low-Fat'
  ];
  
  final List<String> _availableBodyGoals = [
    'Weight Loss', 'Weight Gain', 'Muscle Building', 'Maintenance',
    'Athletic Performance', 'General Health', 'Fat Loss', 'Lean Mass Gain'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    if (widget.initialData != null) {
      _loadInitialData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _loadInitialData() {
    final data = widget.initialData!;
    _nameController.text = data['name'] ?? '';
    _descriptionController.text = data['description'] ?? '';
    _selectedPriority = data['priority'] ?? 'medium';
    _isActive = data['isActive'] ?? true;
    
    final conditions = data['conditions'] as Map<String, dynamic>? ?? {};
    _minAge = conditions['minAge'];
    _maxAge = conditions['maxAge'];
    _gender = conditions['gender'];
    _healthConditions = List<String>.from(conditions['healthConditions'] ?? []);
    _dietaryPreferences = List<String>.from(conditions['dietaryPreferences'] ?? []);
    _bodyGoals = List<String>.from(conditions['bodyGoals'] ?? []);
    _pregnancyStatus = conditions['pregnancyStatus'];
    _lactationStatus = conditions['lactationStatus'] ?? false;
    
    final adjustments = data['adjustments'] as Map<String, dynamic>? ?? {};
    _calorieMultiplier = adjustments['calorieMultiplier'];
    _proteinRatio = adjustments['proteinRatio'];
    _carbRatio = adjustments['carbRatio'];
    _fatRatio = adjustments['fatRatio'];
    _mealFrequency = adjustments['mealFrequency'];
    _foodsToInclude = List<String>.from(adjustments['foodsToInclude'] ?? []);
    _foodsToAvoid = List<String>.from(adjustments['foodsToAvoid'] ?? []);
    _supplements = List<String>.from(adjustments['supplements'] ?? []);
    _specialInstructions = List<String>.from(adjustments['specialInstructions'] ?? []);
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
            Text(
              widget.ruleId != null ? 'Edit Personalized Rule' : 'Add New Personalized Rule',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TabBar(
              controller: _tabController,
              labelColor: Colors.blue,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(text: 'Basic Info', icon: Icon(Icons.info)),
                Tab(text: 'Conditions', icon: Icon(Icons.person)),
                Tab(text: 'Adjustments', icon: Icon(Icons.tune)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildBasicInfoTab(),
                  _buildConditionsTab(),
                  _buildAdjustmentsTab(),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _saveRule,
                  child: Text(widget.ruleId != null ? 'Update' : 'Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBasicInfoTab() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Rule Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value?.isEmpty == true ? 'Name is required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedPriority,
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                      border: OutlineInputBorder(),
                    ),
                    items: _priorities.map((priority) => DropdownMenuItem(
                      value: priority,
                      child: Text(priority.toUpperCase()),
                    )).toList(),
                    onChanged: (value) => setState(() => _selectedPriority = value!),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SwitchListTile(
                    title: const Text('Active'),
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionsTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Age Range
          const Text('Age Range', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Min Age',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => _minAge = int.tryParse(value),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Max Age',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => _maxAge = int.tryParse(value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Gender
          DropdownButtonFormField<String>(
            value: _gender,
            decoration: const InputDecoration(
              labelText: 'Gender',
              border: OutlineInputBorder(),
            ),
            items: _genders.map((gender) => DropdownMenuItem(
              value: gender,
              child: Text(gender.toUpperCase()),
            )).toList(),
            onChanged: (value) => setState(() => _gender = value),
          ),
          const SizedBox(height: 16),
          
          // Health Conditions
          const Text('Health Conditions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _availableHealthConditions.map((condition) {
              final isSelected = _healthConditions.contains(condition);
              return FilterChip(
                label: Text(condition),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _healthConditions.add(condition);
                    } else {
                      _healthConditions.remove(condition);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          
          // Dietary Preferences
          const Text('Dietary Preferences', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _availableDietaryPreferences.map((preference) {
              final isSelected = _dietaryPreferences.contains(preference);
              return FilterChip(
                label: Text(preference),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _dietaryPreferences.add(preference);
                    } else {
                      _dietaryPreferences.remove(preference);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          
          // Body Goals
          const Text('Body Goals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _availableBodyGoals.map((goal) {
              final isSelected = _bodyGoals.contains(goal);
              return FilterChip(
                label: Text(goal),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _bodyGoals.add(goal);
                    } else {
                      _bodyGoals.remove(goal);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          
          // Pregnancy Status
          DropdownButtonFormField<String>(
            value: _pregnancyStatus,
            decoration: const InputDecoration(
              labelText: 'Pregnancy Status',
              border: OutlineInputBorder(),
            ),
            items: _pregnancyStatuses.map((status) => DropdownMenuItem(
              value: status,
              child: Text(status.toUpperCase()),
            )).toList(),
            onChanged: (value) => setState(() => _pregnancyStatus = value),
          ),
          const SizedBox(height: 16),
          
          // Lactation Status
          SwitchListTile(
            title: const Text('Lactation Status'),
            value: _lactationStatus,
            onChanged: (value) => setState(() => _lactationStatus = value),
          ),
        ],
      ),
    );
  }

  Widget _buildAdjustmentsTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Calorie Multiplier
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Calorie Multiplier (e.g., 1.2 for 20% increase)',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.number,
            onChanged: (value) => _calorieMultiplier = double.tryParse(value),
          ),
          const SizedBox(height: 16),
          
          // Macro Ratios
          const Text('Macronutrient Ratios', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Protein Ratio (0.0-1.0)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => _proteinRatio = double.tryParse(value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Carb Ratio (0.0-1.0)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => _carbRatio = double.tryParse(value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Fat Ratio (0.0-1.0)',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => _fatRatio = double.tryParse(value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  decoration: const InputDecoration(
                    labelText: 'Meal Frequency',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) => _mealFrequency = int.tryParse(value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Foods to Include
          const Text('Foods to Include', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Comma-separated list',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              _foodsToInclude = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
            },
          ),
          const SizedBox(height: 16),
          
          // Foods to Avoid
          const Text('Foods to Avoid', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Comma-separated list',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              _foodsToAvoid = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
            },
          ),
          const SizedBox(height: 16),
          
          // Supplements
          const Text('Recommended Supplements', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Comma-separated list',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              _supplements = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
            },
          ),
          const SizedBox(height: 16),
          
          // Special Instructions
          const Text('Special Instructions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Comma-separated list',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            onChanged: (value) {
              _specialInstructions = value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveRule() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final ruleData = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'priority': _selectedPriority,
        'isActive': _isActive,
        'conditions': {
          if (_minAge != null) 'minAge': _minAge,
          if (_maxAge != null) 'maxAge': _maxAge,
          if (_gender != null) 'gender': _gender,
          if (_healthConditions.isNotEmpty) 'healthConditions': _healthConditions,
          if (_dietaryPreferences.isNotEmpty) 'dietaryPreferences': _dietaryPreferences,
          if (_bodyGoals.isNotEmpty) 'bodyGoals': _bodyGoals,
          if (_pregnancyStatus != null) 'pregnancyStatus': _pregnancyStatus,
          'lactationStatus': _lactationStatus,
        },
        'adjustments': {
          if (_calorieMultiplier != null) 'calorieMultiplier': _calorieMultiplier,
          if (_proteinRatio != null) 'proteinRatio': _proteinRatio,
          if (_carbRatio != null) 'carbRatio': _carbRatio,
          if (_fatRatio != null) 'fatRatio': _fatRatio,
          if (_mealFrequency != null) 'mealFrequency': _mealFrequency,
          if (_foodsToInclude.isNotEmpty) 'foodsToInclude': _foodsToInclude,
          if (_foodsToAvoid.isNotEmpty) 'foodsToAvoid': _foodsToAvoid,
          if (_supplements.isNotEmpty) 'supplements': _supplements,
          if (_specialInstructions.isNotEmpty) 'specialInstructions': _specialInstructions,
        },
      };

      if (widget.ruleId != null) {
        await PersonalizedNutritionService.updateNutritionRule(widget.ruleId!, ruleData);
      } else {
        await PersonalizedNutritionService.createNutritionRule(ruleData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Rule ${widget.ruleId != null ? 'updated' : 'created'} successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
        widget.onRuleAdded();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving rule: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
