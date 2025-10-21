import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/allergen_service.dart';

class AllergenValidationPage extends StatefulWidget {
  const AllergenValidationPage({super.key});

  @override
  State<AllergenValidationPage> createState() => _AllergenValidationPageState();
}

class _AllergenValidationPageState extends State<AllergenValidationPage> with TickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  Map<String, dynamic> _validationStatus = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadValidationData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadValidationData() async {
    setState(() => _isLoading = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('system_data')
          .doc('validation_status')
          .get();
      
      if (doc.exists) {
        setState(() {
          _validationStatus = doc.data() ?? {};
          _isLoading = false;
        });
      } else {
        // Initialize validation status document
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading validation data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Allergen and Substitution Validation'),
        backgroundColor: const Color(0xFFFF9800),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Allergen Detection', icon: Icon(Icons.warning_amber)),
            Tab(text: 'Substitutions', icon: Icon(Icons.swap_horiz)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadValidationData,
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
                hintText: 'Search allergens and substitutions...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
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
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),
          
          // Tab Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAllergenDetectionTab(),
                      _buildSubstitutionsTab(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAllergenDetectionTab() {
    return FutureBuilder<Map<String, List<String>>>(
      future: _getAllAllergenKeywords(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final allergenKeywords = snapshot.data ?? {};
        final filteredAllergens = allergenKeywords.entries
            .where((entry) {
              if (_searchQuery.isEmpty) return true;
              return entry.key.toLowerCase().contains(_searchQuery) ||
                  entry.value.any((keyword) => keyword.toLowerCase().contains(_searchQuery));
            })
            .toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info Banner
            _buildInfoBanner(
              'Allergen Detection Keywords',
              'Review and validate the keywords used by the system to detect allergens in recipes. '
              'Validated allergens will be marked as "Nutritionist Verified" in the app.',
              Colors.orange,
            ),
            const SizedBox(height: 16),

            // Allergen Categories
            ...filteredAllergens.map((entry) => _buildAllergenCard(
              entry.key,
              entry.value,
            )).toList(),
          ],
        );
      },
    );
  }

  Widget _buildSubstitutionsTab() {
    return FutureBuilder<Map<String, Map<String, List<String>>>>(
      future: _getAllSubstitutions(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final substitutions = snapshot.data ?? {};
        final filteredSubstitutions = substitutions.entries
            .where((entry) {
              if (_searchQuery.isEmpty) return true;
              return entry.key.toLowerCase().contains(_searchQuery) ||
                  entry.value.keys.any((ing) => ing.toLowerCase().contains(_searchQuery));
            })
            .toList();

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Info Banner
            _buildInfoBanner(
              'Substitution Database',
              'Review and validate ingredient substitutions for each allergen type. '
              'Validated substitutions will be marked as "Nutritionist Approved" when suggested to users.',
              Colors.green,
            ),
            const SizedBox(height: 16),

            // Substitution Categories
            ...filteredSubstitutions.map((entry) => _buildSubstitutionCard(
              entry.key,
              entry.value,
            )).toList(),
          ],
        );
      },
    );
  }

  Widget _buildInfoBanner(String title, String description, MaterialColor color) {
    return Card(
      color: color[50],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: color[700]),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: color[900],
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: color[800],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllergenCard(String allergenType, List<String> keywords) {
    final color = _getAllergenTypeColor(allergenType);
    final icon = _getAllergenTypeIcon(allergenType);
    final isValidated = _validationStatus['allergens']?[allergenType]?['validated'] == true;
    final validatedBy = _validationStatus['allergens']?[allergenType]?['validatedBy'];
    final validatedAt = _validationStatus['allergens']?[allergenType]?['validatedAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        allergenType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${keywords.length} detection keywords',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isValidated)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.verified, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'VALIDATED',
                          style: TextStyle(
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
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Detection Keywords:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: keywords.map((keyword) {
                    return Chip(
                      label: Text(keyword),
                      backgroundColor: color.withOpacity(0.1),
                      side: BorderSide(color: color.withOpacity(0.3)),
                      labelStyle: TextStyle(
                        color: color.withOpacity(0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  }).toList(),
                ),

                if (isValidated && validatedAt != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Validated by ${validatedBy ?? "Nutritionist"} on ${_formatDate(validatedAt.toDate())}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isValidated
                            ? () => _revokeValidation('allergens', allergenType)
                            : () => _validateItem('allergens', allergenType),
                        icon: Icon(isValidated ? Icons.cancel : Icons.check, size: 18),
                        label: Text(isValidated ? 'Revoke Validation' : 'Validate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isValidated ? Colors.orange : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
    );
  }

  Widget _buildSubstitutionCard(String allergenType, Map<String, List<String>> substitutionMap) {
    final color = _getAllergenTypeColor(allergenType);
    final icon = _getAllergenTypeIcon(allergenType);
    final isValidated = _validationStatus['substitutions']?[allergenType]?['validated'] == true;
    final validatedBy = _validationStatus['substitutions']?[allergenType]?['validatedBy'];
    final validatedAt = _validationStatus['substitutions']?[allergenType]?['validatedAt'] as Timestamp?;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        allergenType.toUpperCase(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${substitutionMap.length} ingredients with substitutions',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isValidated)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.verified, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'VALIDATED',
                          style: TextStyle(
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
          ),

          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sample Substitutions:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                ...substitutionMap.entries.take(5).map((entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red.shade900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward, size: 14, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            entry.value.join(', '),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
                if (substitutionMap.length > 5)
                  Text(
                    '... and ${substitutionMap.length - 5} more',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                if (isValidated && validatedAt != null) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.check_circle, size: 16, color: Colors.green.shade700),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Validated by ${validatedBy ?? "Nutritionist"} on ${_formatDate(validatedAt.toDate())}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: isValidated
                            ? () => _revokeValidation('substitutions', allergenType)
                            : () => _validateItem('substitutions', allergenType),
                        icon: Icon(isValidated ? Icons.cancel : Icons.check, size: 18),
                        label: Text(isValidated ? 'Revoke Validation' : 'Validate'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isValidated ? Colors.orange : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
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
    );
  }

  Future<void> _validateItem(String category, String type) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Get nutritionist email
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      final nutritionistName = userDoc.data()?['fullName'] ?? user.email ?? 'Nutritionist';

      await FirebaseFirestore.instance
          .collection('system_data')
          .doc('validation_status')
          .set({
        category: {
          type: {
            'validated': true,
            'validatedBy': nutritionistName,
            'validatedAt': FieldValue.serverTimestamp(),
          }
        }
      }, SetOptions(merge: true));

      await _loadValidationData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$type validated successfully!'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error validating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _revokeValidation(String category, String type) async {
    try {
      await FirebaseFirestore.instance
          .collection('system_data')
          .doc('validation_status')
          .set({
        category: {
          type: {
            'validated': false,
            'validatedBy': null,
            'validatedAt': null,
          }
        }
      }, SetOptions(merge: true));

      await _loadValidationData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$type validation revoked'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error revoking validation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<Map<String, List<String>>> _getAllAllergenKeywords() async {
    // Get all allergen types and their keywords
    final allergenTypes = ['dairy', 'eggs', 'fish', 'shellfish', 'tree_nuts', 'peanuts', 'wheat', 'soy'];
    final Map<String, List<String>> result = {};

    for (final type in allergenTypes) {
      try {
        final keywords = await AllergenService.getSubstitutions(type);
        // Get the keys (ingredients that need substitution) as detection keywords
        result[type] = keywords.isNotEmpty ? ['Various ingredients'] : [];
      } catch (e) {
        result[type] = [];
      }
    }

    // Get hardcoded allergen keywords from AllergenService
    result['dairy'] = ['milk', 'cheese', 'butter', 'cream', 'yogurt', 'whey', 'casein', 'lactose', 'gatas', 'keso', 'mantikilya'];
    result['eggs'] = ['egg', 'eggs', 'itlog', 'mayonnaise'];
    result['fish'] = ['fish', 'salmon', 'tuna', 'tilapia', 'bangus', 'milkfish', 'isda', 'anchovies', 'sardines'];
    result['shellfish'] = ['shrimp', 'crab', 'lobster', 'prawn', 'hipon', 'alimango'];
    result['tree nuts'] = ['almond', 'cashew', 'walnut', 'pecan', 'pistachio', 'hazelnut'];
    result['peanuts'] = ['peanut', 'peanuts', 'mani'];
    result['wheat'] = ['wheat', 'flour', 'bread', 'pasta', 'trigo', 'harina'];
    result['soy'] = ['soy', 'tofu', 'soya', 'tokwa'];
    result['gluten'] = ['gluten', 'wheat', 'barley', 'rye'];

    return result;
  }

  Future<Map<String, Map<String, List<String>>>> _getAllSubstitutions() async {
    final allergenTypes = ['dairy', 'eggs', 'fish', 'shellfish', 'tree_nuts', 'peanuts', 'wheat', 'soy'];
    final Map<String, Map<String, List<String>>> result = {};

    for (final type in allergenTypes) {
      try {
        final subs = await AllergenService.getSubstitutions(type);
        if (subs.isNotEmpty) {
          // Convert List<String> to Map format for display
          result[type] = {
            'Sample': subs.take(5).toList(),
          };
        }
      } catch (e) {
        result[type] = {};
      }
    }

    return result;
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  Color _getAllergenTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'dairy':
        return Colors.blue;
      case 'eggs':
        return Colors.orange;
      case 'fish':
        return Colors.cyan;
      case 'shellfish':
        return Colors.teal;
      case 'tree nuts':
        return Colors.brown;
      case 'peanuts':
        return Colors.amber;
      case 'wheat':
        return Colors.yellow.shade700;
      case 'soy':
        return Colors.green;
      case 'gluten':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  IconData _getAllergenTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'dairy':
        return Icons.water_drop;
      case 'eggs':
        return Icons.egg;
      case 'fish':
      case 'shellfish':
        return Icons.set_meal;
      case 'tree nuts':
      case 'peanuts':
        return Icons.nature;
      case 'wheat':
      case 'gluten':
        return Icons.grain;
      case 'soy':
        return Icons.eco;
      default:
        return Icons.warning;
    }
  }
}
