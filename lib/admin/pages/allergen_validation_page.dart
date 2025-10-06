import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AllergenValidationPage extends StatefulWidget {
  const AllergenValidationPage({super.key});

  @override
  State<AllergenValidationPage> createState() => _AllergenValidationPageState();
}

class _AllergenValidationPageState extends State<AllergenValidationPage> with TickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
        title: const Text('Allergen Validation'),
        backgroundColor: const Color(0xFFFF9800),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Pending', icon: Icon(Icons.pending)),
            Tab(text: 'Validated', icon: Icon(Icons.check_circle)),
            Tab(text: 'Flagged', icon: Icon(Icons.warning)),
          ],
        ),
        actions: [
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
                hintText: 'Search allergens...',
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
                _buildAllergenList('pending'),
                _buildAllergenList('validated'),
                _buildAllergenList('flagged'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergenList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('allergen_validations')
          .where('status', isEqualTo: status)
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

        final allergens = snapshot.data?.docs ?? [];
        final filteredAllergens = allergens.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final ingredient = data['ingredient']?.toString().toLowerCase() ?? '';
          final allergenType = data['allergenType']?.toString().toLowerCase() ?? '';
          return ingredient.contains(_searchQuery) || allergenType.contains(_searchQuery);
        }).toList();

        if (filteredAllergens.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  status == 'pending' ? Icons.pending : 
                  status == 'validated' ? Icons.check_circle : Icons.warning,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  status == 'pending' ? 'No allergens pending validation' :
                  status == 'validated' ? 'No validated allergens' : 'No flagged allergens',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredAllergens.length,
          itemBuilder: (context, index) {
            final doc = filteredAllergens[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildAllergenCard(doc.id, data, status);
          },
        );
      },
    );
  }

  Widget _buildAllergenCard(String validationId, Map<String, dynamic> data, String status) {
    final ingredient = data['ingredient'] ?? 'Unknown Ingredient';
    final allergenType = data['allergenType'] ?? 'Unknown';
    final confidence = data['confidence'] ?? 0.0;
    final recipeName = data['recipeName'] ?? 'Unknown Recipe';
    final userName = data['userName'] ?? 'Unknown User';
    final createdAt = data['createdAt'] as Timestamp?;
    final notes = data['notes'] ?? '';

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
                    color: _getAllergenTypeColor(allergenType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getAllergenTypeIcon(allergenType),
                    color: _getAllergenTypeColor(allergenType),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ingredient,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'in $recipeName',
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
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Allergen Type and Confidence
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Allergen Type',
                    allergenType,
                    _getAllergenTypeColor(allergenType),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInfoItem(
                    'Confidence',
                    '${(confidence * 100).toStringAsFixed(1)}%',
                    confidence > 0.7 ? Colors.green : confidence > 0.4 ? Colors.orange : Colors.red,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // User and Date
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'User',
                    userName,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildInfoItem(
                    'Date',
                    createdAt != null ? DateFormat('MMM dd, yyyy').format(createdAt.toDate()) : 'Unknown',
                    Colors.grey,
                  ),
                ),
              ],
            ),
            
            if (notes.isNotEmpty) ...[
              const SizedBox(height: 12),
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
                      'Notes:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notes,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 16),
            
            // Actions
            Row(
              children: [
                Text(
                  'Created: ${createdAt != null ? DateFormat('MMM dd, yyyy HH:mm').format(createdAt.toDate()) : 'Unknown'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const Spacer(),
                if (status == 'pending') ...[
                  TextButton.icon(
                    onPressed: () => _flagAllergen(validationId),
                    icon: const Icon(Icons.flag, size: 16),
                    label: const Text('Flag'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _validateAllergen(validationId),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Validate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ] else ...[
                  TextButton.icon(
                    onPressed: () => _viewAllergenDetails(validationId, data),
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('View Details'),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Color _getAllergenTypeColor(String allergenType) {
    switch (allergenType.toLowerCase()) {
      case 'dairy':
        return Colors.blue;
      case 'nuts':
        return Colors.brown;
      case 'gluten':
        return Colors.amber;
      case 'fish':
        return Colors.cyan;
      case 'shellfish':
        return Colors.teal;
      case 'eggs':
        return Colors.orange;
      case 'soy':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getAllergenTypeIcon(String allergenType) {
    switch (allergenType.toLowerCase()) {
      case 'dairy':
        return Icons.local_drink;
      case 'nuts':
        return Icons.eco;
      case 'gluten':
        return Icons.grain;
      case 'fish':
        return Icons.set_meal;
      case 'shellfish':
        return Icons.waves;
      case 'eggs':
        return Icons.egg;
      case 'soy':
        return Icons.agriculture;
      default:
        return Icons.warning;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'validated':
        return Colors.green;
      case 'flagged':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _validateAllergen(String validationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('allergen_validations')
          .doc(validationId)
          .update({
        'status': 'validated',
        'validatedAt': FieldValue.serverTimestamp(),
        'validatedBy': 'nutritionist',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Allergen validation approved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error validating allergen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _flagAllergen(String validationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('allergen_validations')
          .doc(validationId)
          .update({
        'status': 'flagged',
        'flaggedAt': FieldValue.serverTimestamp(),
        'flaggedBy': 'nutritionist',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Allergen flagged for review'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error flagging allergen: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewAllergenDetails(String validationId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Allergen Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Ingredient: ${data['ingredient'] ?? 'Unknown'}'),
              Text('Allergen Type: ${data['allergenType'] ?? 'Unknown'}'),
              Text('Recipe: ${data['recipeName'] ?? 'Unknown'}'),
              Text('User: ${data['userName'] ?? 'Unknown'}'),
              Text('Confidence: ${((data['confidence'] ?? 0.0) * 100).toStringAsFixed(1)}%'),
              if (data['notes']?.isNotEmpty == true) ...[
                const SizedBox(height: 8),
                Text('Notes: ${data['notes']}'),
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
}
