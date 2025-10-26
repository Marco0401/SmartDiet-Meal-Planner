import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/allergen_service.dart';
import '../../services/substitution_nutrition_service.dart';
import '../widgets/edit_nutrition_dialog.dart';

class SubstitutionsManagementPage extends StatefulWidget {
  const SubstitutionsManagementPage({super.key});

  @override
  State<SubstitutionsManagementPage> createState() => _SubstitutionsManagementPageState();
}

class _SubstitutionsManagementPageState extends State<SubstitutionsManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Substitutions'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {}); // Refresh
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Substitution Data',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Search and Add Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search substitutions...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    _showAddSubstitutionDialog();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Add Substitution'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Statistics Cards
            FutureBuilder<Map<String, dynamic>>(
              future: _getSubstitutionData(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final data = snapshot.data!;
                  final availableSubstitutions = data['available'] as List<Map<String, dynamic>>? ?? [];
                  final usageStats = data['usage'] as Map<String, int>? ?? {};
                  
                  final totalSubstitutions = availableSubstitutions.length;
                  final totalUsage = usageStats.values.fold(0, (sum, count) => sum + count);
                  final mostUsedAllergen = _getMostUsedAllergen(usageStats);
                  final activeSubstitutions = usageStats.keys.length;
                  
                  return Column(
                    children: [
                      Row(
                        children: [
                          Expanded(child: _buildStatCard('Total Available', totalSubstitutions.toString(), Colors.purple, Icons.swap_horiz)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildStatCard('Times Used', totalUsage.toString(), Colors.green, Icons.trending_up)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildStatCard('Active Substitutions', activeSubstitutions.toString(), Colors.blue, Icons.check_circle)),
                          const SizedBox(width: 16),
                          Expanded(child: _buildStatCard('Most Used', mostUsedAllergen, Colors.orange, Icons.star)),
                        ],
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            const SizedBox(height: 24),
            
            // Substitutions List
            Expanded(
              child: Card(
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 44, child: Text('Rank', style: TextStyle(fontWeight: FontWeight.bold))),
                          const Expanded(flex: 1, child: Text('Allergen', style: TextStyle(fontWeight: FontWeight.bold))),
                          const Expanded(flex: 3, child: Text('Substitution', style: TextStyle(fontWeight: FontWeight.bold))),
                          const Expanded(flex: 1, child: Text('Usage', style: TextStyle(fontWeight: FontWeight.bold))),
                          const SizedBox(width: 100, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                    
                    // Real Substitutions from Mobile App
                    Expanded(
                      child: FutureBuilder<Map<String, dynamic>>(
                        future: _getSubstitutionData(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Text('Error loading substitutions: ${snapshot.error}'),
                            );
                          }

                          final data = snapshot.data ?? {};
                          final availableSubstitutions = data['available'] as List<Map<String, dynamic>>? ?? [];
                          final usageStats = data['usage'] as Map<String, int>? ?? {};

                          final filteredSubstitutions = availableSubstitutions.where((sub) {
                            final allergen = sub['allergen'].toString().toLowerCase();
                            final substitution = sub['substitution'].toString().toLowerCase();
                            return allergen.contains(_searchQuery) || substitution.contains(_searchQuery);
                          }).toList();
                          
                          // Sort by usage count (highest first)
                          filteredSubstitutions.sort((a, b) {
                            final keyA = a['key'] as String;
                            final keyB = b['key'] as String;
                            final usageA = usageStats[keyA] ?? 0;
                            final usageB = usageStats[keyB] ?? 0;
                            return usageB.compareTo(usageA); // Descending order
                          });
                          

                          if (filteredSubstitutions.isEmpty) {
                            return const Center(
                              child: Text('No substitutions found'),
                            );
                          }

                          return ListView.builder(
                            itemCount: filteredSubstitutions.length,
                            itemBuilder: (context, index) {
                              final substitution = filteredSubstitutions[index];
                              final usageCount = usageStats[substitution['key']] ?? 0;
                              
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: Colors.grey.shade200),
                                  ),
                                  color: index < 3 ? Colors.green.shade50 : null, // Highlight top 3
                                ),
                                child: Row(
                                  children: [
                                    // Ranking indicator
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: index < 3 ? Colors.green.shade600 : Colors.grey.shade400,
                                        shape: BoxShape.circle,
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
                                    // Allergen
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            _getIconWidget(substitution['icon']),
                                            const SizedBox(width: 4),
                                            Flexible(
                                              child: Text(
                                                substitution['allergen'] ?? 'Unknown',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.red.shade700,
                                                ),
                                                textAlign: TextAlign.center,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    
                                    // Substitution
                                    Expanded(
                                      flex: 3,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              substitution['substitution'] ?? 'No substitution available',
                                              style: const TextStyle(fontSize: 14),
                                            ),
                                            if (substitution['source'] == 'admin') ...[
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.purple.shade100,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  'Admin Created',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.purple.shade700,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ],
                                            if (substitution['source'] == 'firestore') ...[
                                              const SizedBox(height: 4),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.shade100,
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  'Firestore Data',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: Colors.blue.shade700,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                              if (substitution['nutrition'] != null && substitution['nutrition'].isNotEmpty) ...[
                                                const SizedBox(height: 4),
                                                Row(
                                                  children: [
                                                    _buildNutritionChip('Cal', substitution['nutrition']['calories']?.toString() ?? '0'),
                                                    const SizedBox(width: 4),
                                                    _buildNutritionChip('P', substitution['nutrition']['protein']?.toString() ?? '0'),
                                                    const SizedBox(width: 4),
                                                    _buildNutritionChip('C', substitution['nutrition']['carbs']?.toString() ?? '0'),
                                                    const SizedBox(width: 4),
                                                    _buildNutritionChip('F', substitution['nutrition']['fat']?.toString() ?? '0'),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                    
                                    // Usage
                                    Expanded(
                                      flex: 1,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: usageCount > 0 ? Colors.green.shade100 : Colors.blue.shade100,
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '$usageCount times',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: usageCount > 0 ? Colors.green.shade700 : Colors.blue.shade700,
                                            fontWeight: usageCount > 0 ? FontWeight.bold : FontWeight.normal,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                    
                                    // Actions
                                    SizedBox(
                                      width: 140,
                                      child: Row(
                                        children: [
                                          IconButton(
                                            onPressed: () => _editSubstitution(index),
                                            icon: const Icon(Icons.edit, size: 18),
                                            tooltip: 'Edit Substitution',
                                          ),
                                          IconButton(
                                            onPressed: () => _editNutrition(substitution),
                                            icon: const Icon(Icons.science, size: 18, color: Colors.blue),
                                            tooltip: 'Edit Nutrition',
                                          ),
                                          IconButton(
                                            onPressed: () => _deleteSubstitution(index),
                                            icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                            tooltip: 'Delete Substitution',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _getSubstitutionData() async {
    try {
      // Initialize default substitution nutrition data first
      await SubstitutionNutritionService.initializeDefaultSubstitutionData();
      
      // Get available substitutions from Firestore (system_data/ingredient_substitutions)
      final availableSubstitutions = <Map<String, dynamic>>[];
      
      try {
        print('DEBUG: Attempting to load substitutions from system_data/substitutions');
        
        // Try to get the document
        final substitutionDoc = await FirebaseFirestore.instance
            .collection('system_data')
            .doc('substitutions')
            .get();
        
        print('DEBUG: Document exists: ${substitutionDoc.exists}');
        
        // Also load nutrition data
        final nutritionDoc = await FirebaseFirestore.instance
            .collection('system_data')
            .doc('substitution_nutrition')
            .get();
        
        Map<String, dynamic> nutritionData = {};
        if (nutritionDoc.exists) {
          nutritionData = Map<String, dynamic>.from(nutritionDoc.data() ?? {});
          print('DEBUG: Loaded nutrition data with ${nutritionData.length} entries');
        } else {
          print('DEBUG: No nutrition document found');
        }
        
        if (substitutionDoc.exists) {
          final data = substitutionDoc.data() as Map<String, dynamic>;
          print('DEBUG: Loaded substitution data from Firestore: ${data.keys.toList()}');
          
          // Get substitutions from the 'data' field
          final substitutionsData = data['data'] as Map<String, dynamic>? ?? {};
          print('DEBUG: Substitutions data keys: ${substitutionsData.keys.toList()}');
          
          // Process each allergen category
          final allergenCategories = ['dairy', 'eggs', 'fish', 'peanuts', 'shellfish', 'soy', 'tree_nuts', 'wheat'];
          
          for (final category in allergenCategories) {
            final substitutions = substitutionsData[category];
            if (substitutions == null) continue;
            
            // Handle both old format (List<String>) and new format (List<Map>)
            if (substitutions is List) {
              for (final substitution in substitutions) {
                if (substitution is String) {
                  // Old format - just substitution string
                  final substitutionKey = '${category}_$substitution';
                  final nutritionInfo = nutritionData[substitutionKey];
                  
                  availableSubstitutions.add({
                    'allergen': _getAllergenDisplayName(category),
                    'allergenType': category,
                    'substitution': substitution,
                    'icon': _getAllergenIconName(category),
                    'key': substitutionKey,
                    'source': 'firestore',
                    'nutrition': nutritionInfo?['nutrition'] ?? {},
                    'id': substitutionKey,
                  });
                } else if (substitution is Map<String, dynamic>) {
                  // New format - substitution with embedded nutrition
                  final substitutionText = substitution['substitution'] as String? ?? '';
                  final substitutionKey = '${category}_$substitutionText';
                  
                  availableSubstitutions.add({
                    'allergen': _getAllergenDisplayName(category),
                    'allergenType': category,
                    'substitution': substitutionText,
                    'icon': _getAllergenIconName(category),
                    'key': substitutionKey,
                    'source': 'firestore',
                    'nutrition': substitution['nutrition'] as Map<String, dynamic>? ?? {},
                    'id': substitutionKey,
                  });
                }
              }
            }
          }
          print('DEBUG: Total Firestore substitutions loaded: ${availableSubstitutions.length}');
        } else {
          print('DEBUG: No substitution document found in Firestore');
        }
      } catch (e) {
        print('Error loading Firestore substitutions: $e');
      }
      
      // Also get admin-created substitutions from the old collection for backward compatibility
      try {
        final adminSubstitutionsSnapshot = await FirebaseFirestore.instance
            .collection('admin_substitutions')
            .get();
        
        print('DEBUG: Found ${adminSubstitutionsSnapshot.docs.length} admin substitutions');
        
        for (final doc in adminSubstitutionsSnapshot.docs) {
          final data = doc.data();
          availableSubstitutions.add({
            'allergen': data['allergen'],
            'allergenType': data['allergenType'],
            'substitution': data['substitution'],
            'icon': data['icon'],
            'key': data['key'],
            'source': 'admin',
            'createdAt': data['createdAt'],
            'createdBy': data['createdBy'],
            'id': doc.id,
          });
        }
      } catch (e) {
        print('Error fetching admin substitutions: $e');
      }
      
      print('DEBUG: Total substitutions loaded: ${availableSubstitutions.length}');
      print('DEBUG: Substitution sources: ${availableSubstitutions.map((s) => s['source']).toList()}');
      
      // Get usage statistics from Firestore meal plans
      final usageStats = await _getSubstitutionUsageStats();
      
      print('DEBUG: Available substitutions keys: ${availableSubstitutions.map((s) => s['key']).toList()}');
      print('DEBUG: Usage stats keys: ${usageStats.keys.toList()}');
      
      return {
        'available': availableSubstitutions,
        'usage': usageStats,
      };
    } catch (e) {
      print('Error getting substitution data: $e');
      return {
        'available': <Map<String, dynamic>>[],
        'usage': <String, int>{},
      };
    }
  }

  Future<int> _updateExistingMealsWithSubstitution(String oldSubstitution, String newSubstitution) async {
    try {
      int updatedCount = 0;
      
      // Get all users
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      for (final userDoc in usersSnapshot.docs) {
        // Check meal_plans collection
        final mealPlansSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('meal_plans')
            .get();
        
        for (final mealPlanDoc in mealPlansSnapshot.docs) {
          final data = mealPlanDoc.data();
          final meals = data['meals'] as List<dynamic>? ?? [];
          bool needsUpdate = false;
          
          for (final meal in meals) {
            if (meal is Map<String, dynamic> && 
                meal['substituted'] == true && 
                meal['substitutions'] != null) {
              
              final substitutions = meal['substitutions'] as Map<String, dynamic>;
              for (final entry in substitutions.entries) {
                if (entry.value == oldSubstitution) {
                  substitutions[entry.key] = newSubstitution;
                  needsUpdate = true;
                }
              }
            }
          }
          
          if (needsUpdate) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(userDoc.id)
                .collection('meal_plans')
                .doc(mealPlanDoc.id)
                .update({'meals': meals});
            updatedCount++;
          }
        }
        
        // Check individual meals collection
        final mealsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('meals')
            .get();
        
        for (final mealDoc in mealsSnapshot.docs) {
          final data = mealDoc.data();
          bool needsUpdate = false;
          
          if (data['substituted'] == true && data['substitutions'] != null) {
            final substitutions = data['substitutions'] as Map<String, dynamic>;
            for (final entry in substitutions.entries) {
              if (entry.value == oldSubstitution) {
                substitutions[entry.key] = newSubstitution;
                needsUpdate = true;
              }
            }
            
            if (needsUpdate) {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(userDoc.id)
                  .collection('meals')
                  .doc(mealDoc.id)
                  .update({'substitutions': substitutions});
              updatedCount++;
            }
          }
        }
      }
      
      return updatedCount;
    } catch (e) {
      print('Error updating existing meals: $e');
      return 0;
    }
  }

  Future<Map<String, int>> _getSubstitutionUsageStats() async {
    try {
      final usageStats = <String, int>{};
      
      print('DEBUG: Starting to collect substitution usage stats');
      
      // Query all users' meals for substituted meals
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      print('DEBUG: Found ${usersSnapshot.docs.length} users');
      
      
      for (final userDoc in usersSnapshot.docs) {
        try {
          // Check both meal_plans and meals collections
          final mealPlansSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('meal_plans')
              .get();
          
          final mealsSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('meals')
              .get();
          
          print('DEBUG: User ${userDoc.id} has ${mealPlansSnapshot.docs.length} meal plans and ${mealsSnapshot.docs.length} meals');
          
          // Process meal plans
          for (final mealPlanDoc in mealPlansSnapshot.docs) {
            final data = mealPlanDoc.data();
            final meals = data['meals'] as List<dynamic>? ?? [];
            
            for (final meal in meals) {
              if (meal is Map<String, dynamic> && 
                  meal['substituted'] == true && 
                  meal['substitutions'] != null) {
                
                final substitutions = meal['substitutions'] as Map<String, dynamic>;
                print('DEBUG: Found substitutions in meal plan: $substitutions');
                
                for (final entry in substitutions.entries) {
                  final ingredient = entry.key;
                  final substitution = entry.value;
                  
                  // Try to find the allergen type for this substitution
                  final allergenType = await _getAllergenTypeForSubstitution(ingredient, substitution);
                  
                  // Try to find matching admin substitution
                  final matchingAdminSubstitution = await _findMatchingAdminSubstitution(ingredient, substitution, allergenType);
                  if (matchingAdminSubstitution != null) {
                    final key = '${allergenType}_$matchingAdminSubstitution';
                    usageStats[key] = (usageStats[key] ?? 0) + 1;
                    print('DEBUG: Recorded usage for: $key');
                  } else {
                    // If no exact match, create a generic key
                    final key = '${allergenType}_$substitution';
                    usageStats[key] = (usageStats[key] ?? 0) + 1;
                    print('DEBUG: Recorded usage for generic: $key');
                  }
                }
              }
            }
          }
          
          // Process individual meals
          for (final mealDoc in mealsSnapshot.docs) {
            final meal = mealDoc.data();
            
            if (meal['substituted'] == true && meal['substitutions'] != null) {
              final substitutions = meal['substitutions'] as Map<String, dynamic>;
              print('DEBUG: Found substitutions in individual meal: $substitutions');
              
              for (final entry in substitutions.entries) {
                final ingredient = entry.key;
                final substitution = entry.value;
                
                // Try to find the allergen type for this substitution
                final allergenType = await _getAllergenTypeForSubstitution(ingredient, substitution);
                
                // Try to find matching admin substitution
                final matchingAdminSubstitution = await _findMatchingAdminSubstitution(ingredient, substitution, allergenType);
                if (matchingAdminSubstitution != null) {
                  final key = '${allergenType}_$matchingAdminSubstitution';
                  usageStats[key] = (usageStats[key] ?? 0) + 1;
                  print('DEBUG: Recorded usage for: $key');
                } else {
                  // If no exact match, create a generic key
                  final key = '${allergenType}_$substitution';
                  usageStats[key] = (usageStats[key] ?? 0) + 1;
                  print('DEBUG: Recorded usage for generic: $key');
                }
              }
            }
          }
        } catch (e) {
          print('Error processing user ${userDoc.id}: $e');
        }
      }
      
      print('DEBUG: Final usage stats: $usageStats');
      return usageStats;
    } catch (e) {
      print('Error getting usage stats: $e');
      return {};
    }
  }

  Future<String> _getAllergenTypeForSubstitution(String ingredient, String substitution) async {
    // First try to determine allergen type from the ingredient
    String allergenType = _getAllergenTypeForIngredient(ingredient);
    
    // If we couldn't determine from ingredient, try to find in admin substitutions
    if (allergenType == 'unknown') {
      try {
        // Query admin substitutions to find the exact match
        final adminSubstitutionsSnapshot = await FirebaseFirestore.instance
            .collection('admin_substitutions')
            .where('substitution', isEqualTo: substitution)
            .get();
        
        if (adminSubstitutionsSnapshot.docs.isNotEmpty) {
          final data = adminSubstitutionsSnapshot.docs.first.data();
          allergenType = data['allergenType'] as String? ?? 'unknown';
          print('DEBUG: Found admin substitution match: $substitution -> $allergenType');
        }
      } catch (e) {
        print('DEBUG: Error querying admin substitutions: $e');
      }
    }
    
    return allergenType;
  }

  Future<String?> _findMatchingAdminSubstitution(String ingredient, String substitution, String allergenType) async {
    try {
      // Query admin substitutions for this allergen type
      final adminSubstitutionsSnapshot = await FirebaseFirestore.instance
          .collection('admin_substitutions')
          .where('allergenType', isEqualTo: allergenType)
          .get();
      
      for (final doc in adminSubstitutionsSnapshot.docs) {
        final data = doc.data();
        final adminSubstitution = data['substitution'] as String? ?? '';
        
        // Check if the admin substitution contains the user's substitution
        if (adminSubstitution.toLowerCase().contains(substitution.toLowerCase()) ||
            substitution.toLowerCase().contains(adminSubstitution.toLowerCase())) {
          print('DEBUG: Found matching admin substitution: $adminSubstitution for user substitution: $substitution');
          return adminSubstitution;
        }
      }
      
      // If no exact match, try to find by ingredient matching
      for (final doc in adminSubstitutionsSnapshot.docs) {
        final data = doc.data();
        final adminSubstitution = data['substitution'] as String? ?? '';
        
        // Check if the admin substitution is for the same type of ingredient
        if (adminSubstitution.toLowerCase().contains(ingredient.toLowerCase()) ||
            ingredient.toLowerCase().contains(adminSubstitution.toLowerCase())) {
          print('DEBUG: Found ingredient-based admin substitution: $adminSubstitution for ingredient: $ingredient');
          return adminSubstitution;
        }
      }
      
      print('DEBUG: No matching admin substitution found for: $ingredient -> $substitution');
      return null;
    } catch (e) {
      print('DEBUG: Error finding matching admin substitution: $e');
      return null;
    }
  }


  String _getAllergenTypeForIngredient(String ingredient) {
    // Enhanced mapping to determine allergen type from ingredient
    final lowerIngredient = ingredient.toLowerCase();
    
    print('DEBUG: Mapping ingredient "$ingredient" to allergen type');
    
    // Fish (check before dairy since milkfish contains "milk")
    if (lowerIngredient.contains('fish') || lowerIngredient.contains('salmon') || 
        lowerIngredient.contains('tuna') || lowerIngredient.contains('cod') ||
        lowerIngredient.contains('halibut') || lowerIngredient.contains('sardine') ||
        lowerIngredient.contains('anchovy') || lowerIngredient.contains('bangus') ||
        lowerIngredient.contains('milkfish') || lowerIngredient.contains('tilapia') ||
        lowerIngredient.contains('lapu-lapu') || lowerIngredient.contains('galunggong') ||
        lowerIngredient.contains('tamban') || lowerIngredient.contains('tulingan')) {
      print('DEBUG: Mapped to Fish');
      return 'fish';
    }
    
    // Peanuts (check before dairy since peanut butter contains "butter")
    if (lowerIngredient.contains('peanut') || lowerIngredient.contains('groundnut') ||
        lowerIngredient.contains('arachis')) {
      print('DEBUG: Mapped to Peanuts');
      return 'peanuts';
    }
    
    // Dairy products (check after fish to avoid milkfish being misclassified)
    if (lowerIngredient.contains('milk') || lowerIngredient.contains('cheese') || 
        lowerIngredient.contains('butter') || lowerIngredient.contains('cream') ||
        lowerIngredient.contains('yogurt') || lowerIngredient.contains('whey') ||
        lowerIngredient.contains('lactose') || lowerIngredient.contains('casein')) {
      print('DEBUG: Mapped to Dairy');
      return 'dairy';
    } 
    // Eggs
    else if (lowerIngredient.contains('egg') || lowerIngredient.contains('mayonnaise') ||
             lowerIngredient.contains('albumen') || lowerIngredient.contains('lecithin') ||
             lowerIngredient.contains('egg beaters')) {
      print('DEBUG: Mapped to Eggs');
      return 'eggs';
    } 
    // Wheat/Gluten
    else if (lowerIngredient.contains('wheat') || lowerIngredient.contains('flour') ||
             lowerIngredient.contains('bread') || lowerIngredient.contains('pasta') ||
             lowerIngredient.contains('gluten') || lowerIngredient.contains('barley') ||
             lowerIngredient.contains('rye') || lowerIngredient.contains('oats')) {
      print('DEBUG: Mapped to Wheat');
      return 'wheat';
    } 
    // Soy
    else if (lowerIngredient.contains('soy') || lowerIngredient.contains('tofu') ||
             lowerIngredient.contains('miso') || lowerIngredient.contains('tempeh') ||
             lowerIngredient.contains('soybean') || lowerIngredient.contains('soy sauce')) {
      print('DEBUG: Mapped to Soy');
      return 'soy';
    } 
    // Tree Nuts
    else if (lowerIngredient.contains('almond') || lowerIngredient.contains('walnut') ||
             lowerIngredient.contains('cashew') || lowerIngredient.contains('pistachio') ||
             lowerIngredient.contains('hazelnut') || lowerIngredient.contains('pecan') ||
             lowerIngredient.contains('macadamia') || lowerIngredient.contains('brazil') ||
             lowerIngredient.contains('nut') || lowerIngredient.contains('pine nut')) {
      print('DEBUG: Mapped to Tree Nuts');
      return 'tree_nuts';
    } 
    // Peanuts
    else if (lowerIngredient.contains('peanut') || lowerIngredient.contains('groundnut')) {
      print('DEBUG: Mapped to Peanuts');
      return 'peanuts';
    } 
    // Fish
    else if (lowerIngredient.contains('fish') || lowerIngredient.contains('salmon') || 
             lowerIngredient.contains('tuna') || lowerIngredient.contains('cod') ||
             lowerIngredient.contains('halibut') || lowerIngredient.contains('mackerel') ||
             lowerIngredient.contains('sardine') || lowerIngredient.contains('anchovy') ||
             lowerIngredient.contains('trout') || lowerIngredient.contains('bass') ||
             lowerIngredient.contains('tilapia') || lowerIngredient.contains('snapper')) {
      print('DEBUG: Mapped to Fish');
      return 'fish';
    } 
    // Shellfish
    else if (lowerIngredient.contains('shellfish') || lowerIngredient.contains('shrimp') || 
             lowerIngredient.contains('crab') || lowerIngredient.contains('lobster') ||
             lowerIngredient.contains('scallop') || lowerIngredient.contains('mussel') ||
             lowerIngredient.contains('clam') || lowerIngredient.contains('oyster') ||
             lowerIngredient.contains('squid') || lowerIngredient.contains('octopus') ||
             lowerIngredient.contains('prawn') || lowerIngredient.contains('crayfish')) {
      print('DEBUG: Mapped to Shellfish');
      return 'shellfish';
    }
    
    print('DEBUG: Mapped to Other');
    return 'other';
  }

  Widget _buildStatCard(String title, String value, Color color, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getMostUsedAllergen(Map<String, int> usageStats) {
    if (usageStats.isEmpty) return 'None';
    
    String mostUsed = '';
    int maxCount = 0;
    
    for (final entry in usageStats.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        // Extract allergen type from key (format: allergenType_substitution)
        final parts = entry.key.split('_');
        if (parts.isNotEmpty) {
          mostUsed = AllergenService.getDisplayName(parts[0]);
        }
      }
    }
    
    return mostUsed.isEmpty ? 'None' : mostUsed;
  }

  void _showAddSubstitutionDialog() {
    showDialog(
      context: context,
      builder: (context) => AddSubstitutionDialog(
        onSubstitutionAdded: () {
          setState(() {}); // Refresh the list
        },
      ),
    );
  }

  void _editSubstitution(int index) async {
    try {
      // Get the substitution data
      final data = await _getSubstitutionData();
      final availableSubstitutions = data['available'] as List<Map<String, dynamic>>? ?? [];
      final usageStats = data['usage'] as Map<String, int>? ?? {};
      
      // Apply the same filtering and sorting as the UI
      final filteredSubstitutions = availableSubstitutions.where((sub) {
        final allergen = sub['allergen'].toString().toLowerCase();
        final substitution = sub['substitution'].toString().toLowerCase();
        return allergen.contains(_searchQuery) || substitution.contains(_searchQuery);
      }).toList();
      
      // Sort by usage count (highest first) - same as UI
      filteredSubstitutions.sort((a, b) {
        final keyA = a['key'] as String;
        final keyB = b['key'] as String;
        final usageA = usageStats[keyA] ?? 0;
        final usageB = usageStats[keyB] ?? 0;
        return usageB.compareTo(usageA); // Descending order
      });
      
      if (index >= filteredSubstitutions.length) return;
      
      final substitution = filteredSubstitutions[index];
      
      
      // Allow editing for both admin-created and Firestore substitutions
      if (substitution['source'] == 'admin' || substitution['source'] == 'firestore') {
        // Show edit dialog for substitution
        showDialog(
          context: context,
          builder: (context) => EditSubstitutionDialog(
            substitution: substitution,
            onSubstitutionUpdated: () {
              setState(() {});
            },
            updateExistingMeals: _updateExistingMealsWithSubstitution,
          ),
        );
      } else {
        // Unknown source - cannot be edited
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Substitution "${substitution['substitution']}" cannot be edited. Unknown source type.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      print('Error editing substitution: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error editing substitution: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _deleteSubstitution(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Substitution'),
        content: const Text('Are you sure you want to delete this substitution? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _performDeleteSubstitution(index);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateFirestoreSubstitution(Map<String, dynamic> oldSubstitution, Map<String, dynamic> newSubstitutionData) async {
    try {
      // Get current substitutions from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('system_data')
          .doc('substitutions')
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final substitutionsData = data['data'] as Map<String, dynamic>? ?? {};
        
        // Get the allergen type and old substitution text
        final allergenType = oldSubstitution['allergenType'] as String;
        final oldSubstitutionText = oldSubstitution['substitution'] as String;
        final newSubstitutionText = newSubstitutionData['substitution'] as String;
        
        // Update the substitution in the list
        if (substitutionsData.containsKey(allergenType)) {
          final substitutions = List<String>.from(substitutionsData[allergenType] ?? []);
          final index = substitutions.indexOf(oldSubstitutionText);
          if (index != -1) {
            substitutions[index] = newSubstitutionText;
            substitutionsData[allergenType] = substitutions;
            
            // Update Firestore
            await FirebaseFirestore.instance
                .collection('system_data')
                .doc('substitutions')
                .update({
                  'data': substitutionsData,
                  'updatedAt': DateTime.now().toIso8601String(),
                });
          }
        }
      }
    } catch (e) {
      print('Error updating Firestore substitution: $e');
      rethrow;
    }
  }

  Future<void> _removeFirestoreSubstitution(Map<String, dynamic> substitution) async {
    try {
      // Get current substitutions from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('system_data')
          .doc('substitutions')
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final substitutionsData = data['data'] as Map<String, dynamic>? ?? {};
        
        // Get the allergen type and substitution text
        final allergenType = substitution['allergenType'] as String;
        final substitutionText = substitution['substitution'] as String;
        
        // Remove the substitution from the list
        if (substitutionsData.containsKey(allergenType)) {
          final substitutions = List<dynamic>.from(substitutionsData[allergenType] ?? []);
          
          // Remove the substitution (handle both old and new formats)
          substitutions.removeWhere((sub) {
            if (sub is String) {
              return sub == substitutionText;
            } else if (sub is Map<String, dynamic>) {
              return sub['substitution'] == substitutionText;
            }
            return false;
          });
          
          substitutionsData[allergenType] = substitutions;
          
          // Update Firestore
          await FirebaseFirestore.instance
              .collection('system_data')
              .doc('substitutions')
              .update({
                'data': substitutionsData,
                'updatedAt': DateTime.now().toIso8601String(),
              });
        }
      }
    } catch (e) {
      print('Error removing Firestore substitution: $e');
      rethrow;
    }
  }

  Future<void> _performDeleteSubstitution(int index) async {
    try {
      // Get the substitution data
      final data = await _getSubstitutionData();
      final availableSubstitutions = data['available'] as List<Map<String, dynamic>>? ?? [];
      
      if (index >= availableSubstitutions.length) return;
      
      final substitution = availableSubstitutions[index];
      
      // Handle deletion based on source
      if (substitution['source'] == 'admin' && substitution['id'] != null) {
        // Delete admin-created substitution from Firestore
        await FirebaseFirestore.instance
            .collection('admin_substitutions')
            .doc(substitution['id'])
            .delete();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Admin substitution "${substitution['substitution']}" deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (substitution['source'] == 'firestore') {
        // Remove Firestore substitution from system data
        await _removeFirestoreSubstitution(substitution);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Firestore substitution "${substitution['substitution']}" deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Unknown source - cannot be deleted
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Unknown substitution type cannot be deleted'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
      
      // Refresh the list
      setState(() {});
    } catch (e) {
      print('Error deleting substitution: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting substitution: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _editNutrition(Map<String, dynamic> substitution) {
    showDialog(
      context: context,
      builder: (context) => EditNutritionDialog(
        substitution: substitution,
        onSave: (updatedSubstitution) async {
          await _saveSubstitutionNutrition(updatedSubstitution);
          setState(() {}); // Refresh the page
        },
      ),
    );
  }

  Future<void> _saveSubstitutionNutrition(Map<String, dynamic> substitution) async {
    try {
      // Get current substitutions from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('system_data')
          .doc('substitutions')
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final substitutionsData = data['data'] as Map<String, dynamic>? ?? {};
        
        // Get the allergen type and substitution text
        final allergenType = substitution['allergenType'] as String;
        final substitutionText = substitution['substitution'] as String;
        
        // Update the substitution with nutrition data
        if (substitutionsData.containsKey(allergenType)) {
          final substitutions = List<dynamic>.from(substitutionsData[allergenType] ?? []);
          
          // Find and update the substitution with nutrition data
          for (int i = 0; i < substitutions.length; i++) {
            final sub = substitutions[i];
            if (sub is String && sub == substitutionText) {
              // Old format - convert to new format with nutrition
              substitutions[i] = {
                'substitution': substitutionText,
                'nutrition': substitution['nutrition'] ?? {},
              };
              break;
            } else if (sub is Map<String, dynamic> && 
                       sub['substitution'] == substitutionText) {
              // New format - update nutrition
              substitutions[i] = {
                'substitution': substitutionText,
                'nutrition': substitution['nutrition'] ?? sub['nutrition'] ?? {},
              };
              break;
            }
          }
          
          substitutionsData[allergenType] = substitutions;
          
          // Update Firestore
          await FirebaseFirestore.instance
              .collection('system_data')
              .doc('substitutions')
              .update({
                'data': substitutionsData,
                'updatedAt': DateTime.now().toIso8601String(),
              });
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Substitution nutrition updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error saving substitution nutrition: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildNutritionChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.green.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 10,
          color: Colors.green.shade700,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _getIconWidget(dynamic iconData) {
    if (iconData is IconData) {
      return Icon(iconData, size: 14);
    } else if (iconData is String) {
      switch (iconData) {
        case 'science':
          return const Icon(Icons.science, size: 14);
        case 'warning':
          return const Icon(Icons.warning, size: 14);
        case 'food':
          return const Icon(Icons.fastfood, size: 14);
        case 'milk':
          return const Icon(Icons.local_drink, size: 14);
        case 'egg':
          return const Icon(Icons.egg, size: 14);
        case 'nuts':
          return const Icon(Icons.cookie, size: 14);
        case 'wheat':
          return const Icon(Icons.grain, size: 14);
        case 'soy':
          return const Icon(Icons.eco, size: 14);
        case 'dairy':
          return const Icon(Icons.local_drink, size: 14);
        case 'eggs':
          return const Icon(Icons.egg, size: 14);
        case 'fish':
          return const Icon(Icons.set_meal, size: 14);
        case 'peanuts':
          return const Icon(Icons.cookie, size: 14);
        case 'shellfish':
          return const Icon(Icons.set_meal, size: 14);
        case 'tree_nuts':
          return const Icon(Icons.cookie, size: 14);
        default:
          return const Icon(Icons.warning, size: 14);
      }
    } else {
      return const Icon(Icons.warning, size: 14);
    }
  }

  String _getAllergenDisplayName(String category) {
    switch (category) {
      case 'dairy':
        return 'Dairy';
      case 'eggs':
        return 'Eggs';
      case 'fish':
        return 'Fish';
      case 'peanuts':
        return 'Peanuts';
      case 'shellfish':
        return 'Shellfish';
      case 'soy':
        return 'Soy';
      case 'tree_nuts':
        return 'Tree Nuts';
      case 'wheat':
        return 'Wheat';
      default:
        return 'Unknown';
    }
  }

  String _getAllergenIconName(String category) {
    switch (category) {
      case 'dairy':
        return 'dairy';
      case 'eggs':
        return 'eggs';
      case 'fish':
        return 'fish';
      case 'peanuts':
        return 'nuts';
      case 'shellfish':
        return 'fish';
      case 'soy':
        return 'soy';
      case 'tree_nuts':
        return 'nuts';
      case 'wheat':
        return 'wheat';
      default:
        return 'warning';
    }
  }
}

class EditSubstitutionDialog extends StatefulWidget {
  final Map<String, dynamic> substitution;
  final VoidCallback onSubstitutionUpdated;
  final Future<int> Function(String oldSubstitution, String newSubstitution) updateExistingMeals;

  const EditSubstitutionDialog({
    super.key,
    required this.substitution,
    required this.onSubstitutionUpdated,
    required this.updateExistingMeals,
  });

  @override
  State<EditSubstitutionDialog> createState() => _EditSubstitutionDialogState();
}

class _EditSubstitutionDialogState extends State<EditSubstitutionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _substitutionController = TextEditingController();
  String? _selectedAllergenType;
  bool _isUpdating = false;

  final List<Map<String, dynamic>> _allergenTypes = [
    {'type': 'dairy', 'displayName': 'Dairy', 'icon': '🥛'},
    {'type': 'eggs', 'displayName': 'Eggs', 'icon': '🥚'},
    {'type': 'fish', 'displayName': 'Fish', 'icon': '🐟'},
    {'type': 'shellfish', 'displayName': 'Shellfish', 'icon': '🦐'},
    {'type': 'tree_nuts', 'displayName': 'Tree Nuts', 'icon': '🌰'},
    {'type': 'peanuts', 'displayName': 'Peanuts', 'icon': '🥜'},
    {'type': 'wheat', 'displayName': 'Wheat/Gluten', 'icon': '🌾'},
    {'type': 'soy', 'displayName': 'Soy', 'icon': '🫘'},
  ];

  @override
  void initState() {
    super.initState();
    _substitutionController.text = widget.substitution['substitution'] ?? '';
    _selectedAllergenType = widget.substitution['allergenType'] ?? '';
  }

  @override
  void dispose() {
    _substitutionController.dispose();
    super.dispose();
  }

  Future<bool> _showUpdateConfirmationDialog(String oldSubstitution, String newSubstitution) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Update Existing Meals?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'This substitution is used in existing meals. Updating it will change the substitution text in all meals that currently use:',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'From:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(
                    '"$oldSubstitution"',
                    style: const TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'To:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  Text(
                    '"$newSubstitution"',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'This action cannot be undone. Do you want to proceed?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Update All Meals'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _updateSubstitution() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAllergenType == null) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final allergenData = _allergenTypes.firstWhere(
        (allergen) => allergen['type'] == _selectedAllergenType,
      );

      final substitutionData = {
        'allergen': allergenData['displayName'],
        'allergenType': _selectedAllergenType,
        'substitution': _substitutionController.text.trim(),
        'icon': allergenData['icon'],
        'key': '${_selectedAllergenType}_${_substitutionController.text.trim()}',
        'updatedAt': DateTime.now().toIso8601String(),
        'updatedBy': 'admin',
      };

      final oldSubstitution = widget.substitution['substitution'];
      final newSubstitution = _substitutionController.text.trim();
      
      // Update the substitution based on source
      if (widget.substitution['source'] == 'admin') {
        // Update admin-created substitution
        await FirebaseFirestore.instance
            .collection('admin_substitutions')
            .doc(widget.substitution['id'])
            .update(substitutionData);
      } else if (widget.substitution['source'] == 'firestore') {
        // Update Firestore substitution
        await _updateFirestoreSubstitutionInDialog(widget.substitution, substitutionData);
      }

      // Update existing meals that use this substitution
      if (oldSubstitution != newSubstitution) {
        // Show confirmation dialog
        final shouldUpdate = await _showUpdateConfirmationDialog(oldSubstitution, newSubstitution);
        if (!shouldUpdate) {
          setState(() {
            _isUpdating = false;
          });
          return;
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Updating existing meals with new substitution...'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        
        final updatedMealsCount = await widget.updateExistingMeals(oldSubstitution, newSubstitution);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Substitution updated successfully!\n'
                'Updated $updatedMealsCount existing meals.\n'
                '${allergenData['displayName']} → $newSubstitution',
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Substitution updated successfully: ${allergenData['displayName']} → $newSubstitution',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      widget.onSubstitutionUpdated();

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error updating substitution: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating substitution: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  Future<void> _updateFirestoreSubstitutionInDialog(Map<String, dynamic> oldSubstitution, Map<String, dynamic> newSubstitutionData) async {
    try {
      // Get current substitutions from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('system_data')
          .doc('substitutions')
          .get();
      
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final substitutionsData = data['data'] as Map<String, dynamic>? ?? {};
        
        // Get the allergen type and old substitution text
        final allergenType = oldSubstitution['allergenType'] as String;
        final oldSubstitutionText = oldSubstitution['substitution'] as String;
        final newSubstitutionText = newSubstitutionData['substitution'] as String;
        
        // Update the substitution in the list
        if (substitutionsData.containsKey(allergenType)) {
          final substitutions = List<dynamic>.from(substitutionsData[allergenType] ?? []);
          
          // Find and update the substitution
          for (int i = 0; i < substitutions.length; i++) {
            final substitution = substitutions[i];
            if (substitution is String && substitution == oldSubstitutionText) {
              // Old format - replace with new format
              substitutions[i] = {
                'substitution': newSubstitutionText,
                'nutrition': newSubstitutionData['nutrition'] ?? {},
              };
              break;
            } else if (substitution is Map<String, dynamic> && 
                       substitution['substitution'] == oldSubstitutionText) {
              // New format - update existing
              substitutions[i] = {
                'substitution': newSubstitutionText,
                'nutrition': newSubstitutionData['nutrition'] ?? substitution['nutrition'] ?? {},
              };
              break;
            }
          }
          
          substitutionsData[allergenType] = substitutions;
          
          // Update Firestore
          await FirebaseFirestore.instance
              .collection('system_data')
              .doc('substitutions')
              .update({
                'data': substitutionsData,
                'updatedAt': DateTime.now().toIso8601String(),
              });
        }
      }
    } catch (e) {
      print('Error updating Firestore substitution: $e');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 20,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F5E8),
              Color(0xFFC8E6C9),
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.edit, color: Colors.blue, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Edit Substitution',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const Text(
                              'Update the substitution details',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Allergen Type:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedAllergenType,
                      hint: const Text('Choose an allergen type'),
                      isExpanded: true,
                      items: _allergenTypes.map((allergen) {
                        return DropdownMenuItem<String>(
                          value: allergen['type'],
                          child: Row(
                            children: [
                              Text(
                                allergen['icon'],
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 12),
                              Text(allergen['displayName']),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedAllergenType = value;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Substitution:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _substitutionController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Tofu for fish protein',
                    prefixIcon: const Icon(Icons.swap_horiz),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a substitution';
                    }
                    if (value.trim().length < 3) {
                      return 'Substitution must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                if (_selectedAllergenType != null && _substitutionController.text.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Preview:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _allergenTypes.firstWhere((a) => a['type'] == _selectedAllergenType)['icon'],
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _allergenTypes.firstWhere((a) => a['type'] == _selectedAllergenType)['displayName'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Icon(Icons.arrow_forward, color: Colors.blue),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _substitutionController.text.trim(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isUpdating ? null : () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (_selectedAllergenType != null &&
                                  _substitutionController.text.trim().isNotEmpty &&
                                  !_isUpdating)
                            ? _updateSubstitution
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isUpdating
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Update Substitution'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AddSubstitutionDialog extends StatefulWidget {
  final VoidCallback onSubstitutionAdded;

  const AddSubstitutionDialog({
    super.key,
    required this.onSubstitutionAdded,
  });

  @override
  State<AddSubstitutionDialog> createState() => _AddSubstitutionDialogState();
}

class _AddSubstitutionDialogState extends State<AddSubstitutionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _substitutionController = TextEditingController();
  String? _selectedAllergenType;
  bool _isAdding = false;

  // Nutrition input controllers
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _fiberController = TextEditingController();
  final _sugarController = TextEditingController();
  final _sodiumController = TextEditingController();
  final _cholesterolController = TextEditingController();

  final List<Map<String, dynamic>> _allergenTypes = [
    {'type': 'dairy', 'displayName': 'Dairy', 'icon': '🥛'},
    {'type': 'eggs', 'displayName': 'Eggs', 'icon': '🥚'},
    {'type': 'fish', 'displayName': 'Fish', 'icon': '🐟'},
    {'type': 'shellfish', 'displayName': 'Shellfish', 'icon': '🦐'},
    {'type': 'tree_nuts', 'displayName': 'Tree Nuts', 'icon': '🌰'},
    {'type': 'peanuts', 'displayName': 'Peanuts', 'icon': '🥜'},
    {'type': 'wheat', 'displayName': 'Wheat/Gluten', 'icon': '🌾'},
    {'type': 'soy', 'displayName': 'Soy', 'icon': '🫘'},
  ];

  @override
  void dispose() {
    _substitutionController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _fiberController.dispose();
    _sugarController.dispose();
    _sodiumController.dispose();
    _cholesterolController.dispose();
    super.dispose();
  }

  Future<void> _addSubstitution() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAllergenType == null) return;

    final allergenType = _selectedAllergenType!; // Non-null assertion after null check

    setState(() {
      _isAdding = true;
    });

    try {
      // Get the allergen type details
      final allergenData = _allergenTypes.firstWhere(
        (allergen) => allergen['type'] == allergenType,
      );

      // Parse nutrition values
      final nutrition = {
        'calories': double.tryParse(_caloriesController.text) ?? 0.0,
        'protein': double.tryParse(_proteinController.text) ?? 0.0,
        'carbs': double.tryParse(_carbsController.text) ?? 0.0,
        'fat': double.tryParse(_fatController.text) ?? 0.0,
        'fiber': double.tryParse(_fiberController.text) ?? 0.0,
        'sugar': double.tryParse(_sugarController.text) ?? 0.0,
        'sodium': double.tryParse(_sodiumController.text) ?? 0.0,
        'cholesterol': double.tryParse(_cholesterolController.text) ?? 0.0,
      };

      // Create the substitution data with nutrition
      final substitutionData = {
        'substitution': _substitutionController.text.trim(),
        'nutrition': nutrition,
      };

      // Get current substitutions from system_data/substitutions
      final doc = await FirebaseFirestore.instance
          .collection('system_data')
          .doc('substitutions')
          .get();

      Map<String, dynamic> substitutionsData = {};
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        substitutionsData = data['data'] as Map<String, dynamic>? ?? {};
      }

      // Add the new substitution to the appropriate allergen category
      if (!substitutionsData.containsKey(allergenType)) {
        substitutionsData[allergenType] = [];
      }
      
      final substitutions = List<dynamic>.from(substitutionsData[allergenType] ?? []);
      substitutions.add(substitutionData);
      substitutionsData[allergenType] = substitutions;

      // Update the system_data/substitutions document
      await FirebaseFirestore.instance
          .collection('system_data')
          .doc('substitutions')
          .set({
        'data': substitutionsData,
        'type': 'system_substitutions',
        'version': '2.0',
        'updatedAt': DateTime.now().toIso8601String(),
        'migratedAt': doc.exists ? (doc.data() as Map<String, dynamic>)['migratedAt'] : DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Substitution added successfully to system_data/substitutions: ${allergenData['displayName']} → ${_substitutionController.text.trim()}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      // Call the callback to refresh the parent
      widget.onSubstitutionAdded();

      // Close the dialog
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error adding substitution: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding substitution: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAdding = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 20,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F5E8),
              Color(0xFFC8E6C9),
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.add_circle, color: Colors.purple, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Add New Substitution',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                            const Text(
                              'Create a new ingredient substitution option',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.purple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Allergen Type Selection
                const Text(
                  'Select Allergen Type:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedAllergenType,
                      hint: const Text('Choose an allergen type'),
                      isExpanded: true,
                      items: _allergenTypes.map((allergen) {
                        return DropdownMenuItem<String>(
                          value: allergen['type'],
                          child: Row(
                            children: [
                              Text(
                                allergen['icon'],
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(width: 12),
                              Text(allergen['displayName']),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedAllergenType = value;
                        });
                      },
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Substitution Input
                const Text(
                  'Enter Substitution:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _substitutionController,
                  decoration: InputDecoration(
                    hintText: 'e.g., Tofu for fish protein',
                    prefixIcon: const Icon(Icons.swap_horiz),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a substitution';
                    }
                    if (value.trim().length < 3) {
                      return 'Substitution must be at least 3 characters';
                    }
                    return null;
                  },
                ),
                
                const SizedBox(height: 20),
                
                // Preview
                if (_selectedAllergenType != null && _substitutionController.text.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Preview:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _allergenTypes.firstWhere((a) => a['type'] == _selectedAllergenType)['icon'],
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _allergenTypes.firstWhere((a) => a['type'] == _selectedAllergenType)['displayName'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Icon(Icons.arrow_forward, color: Colors.blue),
                            const SizedBox(width: 16),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _substitutionController.text.trim(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                
                // Nutrition Information Section
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.science, color: Colors.orange, size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Nutrition Information (per 100g)',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNutritionInput(
                              controller: _caloriesController,
                              label: 'Calories',
                              icon: Icons.local_fire_department,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildNutritionInput(
                              controller: _proteinController,
                              label: 'Protein (g)',
                              icon: Icons.fitness_center,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNutritionInput(
                              controller: _carbsController,
                              label: 'Carbs (g)',
                              icon: Icons.grain,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildNutritionInput(
                              controller: _fatController,
                              label: 'Fat (g)',
                              icon: Icons.opacity,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNutritionInput(
                              controller: _fiberController,
                              label: 'Fiber (g)',
                              icon: Icons.eco,
                              color: Colors.brown,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildNutritionInput(
                              controller: _sugarController,
                              label: 'Sugar (g)',
                              icon: Icons.cake,
                              color: Colors.pink,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildNutritionInput(
                              controller: _sodiumController,
                              label: 'Sodium (mg)',
                              icon: Icons.water_drop,
                              color: Colors.cyan,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildNutritionInput(
                              controller: _cholesterolController,
                              label: 'Cholesterol (mg)',
                              icon: Icons.heart_broken,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: _isAdding ? null : () {
                          Navigator.of(context).pop();
                        },
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: (_selectedAllergenType != null && 
                                   _substitutionController.text.trim().isNotEmpty && 
                                   !_isAdding) 
                            ? _addSubstitution 
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _isAdding
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text('Add Substitution'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNutritionInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color, size: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      validator: (value) {
        if (value != null && value.isNotEmpty) {
          final parsed = double.tryParse(value);
          if (parsed == null) {
            return 'Invalid number';
          }
          if (parsed < 0) {
            return 'Must be positive';
          }
        }
        return null;
      },
    );
  }
}