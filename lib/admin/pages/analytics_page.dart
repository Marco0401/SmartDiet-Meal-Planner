import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:csv/csv.dart';
import 'dart:html' as html;
import 'dart:convert';

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  String _selectedTimeRange = '7 days';
  final List<String> _timeRanges = ['24 hours', '7 days', '30 days', '90 days'];
  
  // Cache for expensive queries
  Map<String, dynamic>? _cachedAnalyticsData;
  List<Map<String, dynamic>>? _cachedTopRecipes;
  List<Map<String, dynamic>>? _cachedRecentActivity;
  DateTime? _lastCacheTime;

  // Check if cache is still valid (5 minutes)
  bool _isCacheValid() {
    if (_lastCacheTime == null) return false;
    return DateTime.now().difference(_lastCacheTime!).inMinutes < 5;
  }
  
  // Clear cache when time range changes
  void _clearCache() {
    _cachedAnalyticsData = null;
    _cachedTopRecipes = null;
    _cachedRecentActivity = null;
    _lastCacheTime = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics & Reports'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          DropdownButton<String>(
            value: _selectedTimeRange,
            items: _timeRanges.map((range) {
              return DropdownMenuItem(value: range, child: Text(range));
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedTimeRange = value!;
                _clearCache(); // Clear cache when time range changes
              });
            },
          ),
          const SizedBox(width: 16),
          IconButton(
            onPressed: () {
              _clearCache();
              setState(() {}); // Refresh the UI
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Data',
          ),
          IconButton(
            onPressed: () => _exportReport(),
            icon: const Icon(Icons.download),
            tooltip: 'Export Report',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Key Metrics Cards - Real Data
            FutureBuilder<Map<String, dynamic>>(
              future: _getAnalyticsData(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Row(
                    children: [
                      Expanded(child: _buildLoadingCard()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildLoadingCard()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildLoadingCard()),
                      const SizedBox(width: 16),
                      Expanded(child: _buildLoadingCard()),
                    ],
                  );
                }
                
                if (snapshot.hasError) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error, size: 48, color: Colors.red),
                          const SizedBox(height: 16),
                          Text('Error loading analytics: ${snapshot.error}'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () {
                              _clearCache();
                              setState(() {});
                            },
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final data = snapshot.data ?? {};
                final userMetrics = data['users'] as Map<String, dynamic>? ?? {};
                final recipeMetrics = data['recipes'] as Map<String, dynamic>? ?? {};
                final mealPlanMetrics = data['mealPlans'] as Map<String, dynamic>? ?? {};
                final nutritionMetrics = data['nutrition'] as Map<String, dynamic>? ?? {};

                return Row(
                  children: [
                    Expanded(child: _buildMetricCard(
                      'Total Users', 
                      '${userMetrics['total'] ?? 0}', 
                      _calculateGrowth(userMetrics['growth']), 
                      Colors.blue, 
                      Icons.people
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: _buildMetricCard(
                      'Favorite Recipes', 
                      '${recipeMetrics['total'] ?? 0}', 
                      _calculateGrowth(recipeMetrics['growth']), 
                      Colors.orange, 
                      Icons.favorite
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: _buildMetricCard(
                      'Meal Plans', 
                      '${mealPlanMetrics['total'] ?? 0}', 
                      _calculateGrowth(mealPlanMetrics['growth']), 
                      Colors.green, 
                      Icons.calendar_today
                    )),
                    const SizedBox(width: 16),
                    Expanded(child: _buildMetricCard(
                      'Nutrition Entries', 
                      '${nutritionMetrics['total'] ?? 0}', 
                      _calculateGrowth(nutritionMetrics['growth']), 
                      Colors.purple, 
                      Icons.analytics
                    )),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
            
            // Charts and Reports
            Expanded(
              child: Row(
                children: [
                  // Left Column - Charts
                  Expanded(
                    flex: 2,
                    child: Column(
                      children: [
                        Expanded(child: _buildUserActivityChart()),
                        const SizedBox(height: 16),
                        Expanded(child: _buildPopularAllergensChart()),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Right Column - Lists
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(child: _buildTopRecipesList()),
                        const SizedBox(height: 16),
                        Expanded(child: _buildRecentActivityList()),
                      ],
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

  Widget _buildMetricCard(String title, String value, String change, Color color, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    change,
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserActivityChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'User Registration Trends',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _getUserRegistrationTrends(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final trends = snapshot.data ?? [];
                  if (trends.isEmpty) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text('No registration data available'),
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: trends.map((trend) {
                          final maxCount = trends.map((t) => t['count'] as int).reduce((a, b) => a > b ? a : b);
                          final scaledWidth = maxCount > 0 ? ((trend['count'] as int) / maxCount).clamp(0.0, 1.0) : 0.0;
                          
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    trend['date'],
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 20,
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: scaledWidth,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade600,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${trend['count']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPopularAllergensChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Most Common Allergens',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _getAllergenStats(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  final allergens = snapshot.data ?? [];
                  if (allergens.isEmpty) {
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Center(
                        child: Text('No allergen data available'),
                      ),
                    );
                  }

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: allergens.take(6).map((allergen) {
                          final maxCount = allergens.isNotEmpty ? allergens.first['count'] as int : 1;
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Text(
                                  allergen['icon'] ?? '⚠️',
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 80,
                                  child: Text(
                                    allergen['name'],
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                                Expanded(
                                  child: Container(
                                    height: 16,
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade100,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: FractionallySizedBox(
                                      alignment: Alignment.centerLeft,
                                      widthFactor: ((allergen['count'] as int) / maxCount).clamp(0.0, 1.0),
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade600,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${allergen['count']}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopRecipesList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Top Recipes',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _getTopRecipes(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error loading recipes: ${snapshot.error}'),
                    );
                  }
                  
                  final recipes = snapshot.data ?? [];
                  
                  if (recipes.isEmpty) {
                    return const Center(
                      child: Text(
                        'No recipe data available',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    itemCount: recipes.length,
                    itemBuilder: (context, index) {
                      final recipe = recipes[index];
                      final title = recipe['title'] as String;
                      final count = recipe['count'] as int;
                      final type = recipe['type'] as String;
                      
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getRecipeTypeColor(type),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: _getRecipeTypeColor(type).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                type,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: _getRecipeTypeColor(type),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('$count uses'),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '$count',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'times',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey.shade600,
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
    );
  }

  Color _getRecipeTypeColor(String type) {
    switch (type) {
      case 'Filipino': return Colors.red;
      case 'Italian': return Colors.green;
      case 'Asian': return Colors.blue;
      case 'API': return Colors.purple;
      case 'Admin': return Colors.indigo;
      case 'General': return Colors.orange;
      default: return Colors.grey;
    }
  }

  Widget _buildRecentActivityList() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent Activity',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _getRecentActivity(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error loading activity: ${snapshot.error}'),
                    );
                  }
                  
                  final activities = snapshot.data ?? [];
                  
                  if (activities.isEmpty) {
                    return const Center(
                      child: Text(
                        'No recent activity',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    itemCount: activities.length,
                    itemBuilder: (context, index) {
                      final activity = activities[index];
                      final title = activity['title'] as String;
                      final timestamp = activity['timestamp'] as Timestamp?;
                      final icon = activity['icon'] as IconData;
                      final color = activity['color'] as Color;
                      
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            icon,
                            color: color,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          _formatTimestamp(timestamp),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                        isThreeLine: false,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    
    final now = DateTime.now();
    final activityTime = timestamp.toDate();
    final difference = now.difference(activityTime);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(activityTime);
    }
  }


  void _exportReport() {
    showDialog(
      context: context,
      builder: (context) => _ExportOptionsDialog(
        onExport: (format, sections) {
          if (format == 'csv') {
            _exportAsCSV(sections);
          } else {
            _downloadWordDocument(sections);
          }
        },
      ),
    );
  }

  Future<void> _exportAsCSV(Set<String> sections) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating CSV report...'),
                ],
              ),
            ),
          ),
        ),
      );

      final analyticsData = await _getAnalyticsData();
      final topRecipes = await _getTopRecipes();
      final allergenStats = await _getAllergenStats();
      final registrationTrends = await _getUserRegistrationTrends();

      final List<List<dynamic>> rows = [];

      // Header
      rows.add(['SmartDiet Analytics Report']);
      rows.add(['Generated: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now())}']);
      rows.add(['Time Range: $_selectedTimeRange']);
      rows.add([]);

      // Key Metrics
      if (sections.contains('metrics')) {
        rows.add(['KEY METRICS']);
        rows.add(['Metric', 'Total', 'New', 'Growth']);
        
        final userMetrics = analyticsData['users'] as Map<String, dynamic>? ?? {};
        rows.add(['Users', userMetrics['total'] ?? 0, userMetrics['new'] ?? 0, _calculateGrowth(userMetrics['growth'])]);
        
        final recipeMetrics = analyticsData['recipes'] as Map<String, dynamic>? ?? {};
        rows.add(['Recipes', recipeMetrics['total'] ?? 0, recipeMetrics['new'] ?? 0, _calculateGrowth(recipeMetrics['growth'])]);
        
        final mealPlanMetrics = analyticsData['mealPlans'] as Map<String, dynamic>? ?? {};
        rows.add(['Meal Plans', mealPlanMetrics['total'] ?? 0, mealPlanMetrics['new'] ?? 0, _calculateGrowth(mealPlanMetrics['growth'])]);
        
        final nutritionMetrics = analyticsData['nutrition'] as Map<String, dynamic>? ?? {};
        rows.add(['Nutrition', nutritionMetrics['total'] ?? 0, nutritionMetrics['new'] ?? 0, _calculateGrowth(nutritionMetrics['growth'])]);
        
        rows.add([]);
      }

      // Top Recipes
      if (sections.contains('recipes')) {
        rows.add(['TOP RECIPES']);
        rows.add(['Rank', 'Recipe', 'Type', 'Count']);
        for (var i = 0; i < topRecipes.length; i++) {
          final recipe = topRecipes[i];
          rows.add([i + 1, recipe['title'], recipe['type'], recipe['count']]);
        }
        rows.add([]);
      }

      // Allergens
      if (sections.contains('allergens')) {
        rows.add(['ALLERGEN STATISTICS']);
        rows.add(['Allergen', 'Count']);
        for (final allergen in allergenStats) {
          rows.add([allergen['name'], allergen['count']]);
        }
        rows.add([]);
      }

      // Registration Trends
      if (sections.contains('trends')) {
        rows.add(['REGISTRATION TRENDS']);
        rows.add(['Date', 'New Users']);
        for (final trend in registrationTrends) {
          rows.add([trend['date'], trend['count']]);
        }
      }

      // Convert to CSV and download
      String csv = const ListToCsvConverter().convert(rows);
      final bytes = utf8.encode(csv);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'smartdiet_analytics_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv')
        ..click();
      html.Url.revokeObjectUrl(url);

      Navigator.pop(context); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Report exported successfully!'),
            ],
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _downloadWordDocument(Set<String> sections) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Generating Word document...'),
                ],
              ),
            ),
          ),
        ),
      );

      final analyticsData = await _getAnalyticsData();
      final topRecipes = await _getTopRecipes();
      final allergenStats = await _getAllergenStats();
      final registrationTrends = await _getUserRegistrationTrends();

      final userMetrics = analyticsData['users'] as Map<String, dynamic>? ?? {};
      final recipeMetrics = analyticsData['recipes'] as Map<String, dynamic>? ?? {};
      final mealPlanMetrics = analyticsData['mealPlans'] as Map<String, dynamic>? ?? {};
      final nutritionMetrics = analyticsData['nutrition'] as Map<String, dynamic>? ?? {};

      final htmlContent = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>SmartDiet Analytics Report</title>
  <style>
    @page { size: A4; margin: 1.5cm; }
    * { box-sizing: border-box; -webkit-print-color-adjust: exact !important; print-color-adjust: exact !important; }
    body { font-family: Arial, sans-serif; margin: 20px; color: #333; }
    .header { text-align: center; border-bottom: 3px solid #4CAF50; padding-bottom: 15px; margin-bottom: 20px; }
    .header h1 { margin: 0; color: #2E7D32; font-size: 28px; }
    .header h2 { margin: 5px 0 0 0; color: #666; font-size: 16px; font-weight: normal; }
    .metadata { background: #f5f5f5; padding: 10px; border-radius: 5px; margin-bottom: 20px; font-size: 13px; }
    .section { margin: 25px 0; }
    .section-title { background: #E8F5E9; padding: 10px; border-left: 4px solid #4CAF50; font-size: 18px; font-weight: bold; color: #1B5E20; margin-bottom: 15px; }
    .metrics { display: grid; grid-template-columns: repeat(2, 1fr); gap: 15px; margin-bottom: 20px; }
    .metric-card { background: linear-gradient(135deg, #e3f2fd, #bbdefb); border: 1px solid #90caf9; border-radius: 10px; padding: 15px; }
    .metric-label { font-size: 13px; color: #666; margin-bottom: 5px; }
    .metric-value { font-size: 28px; font-weight: bold; color: #1e293b; }
    .metric-change { display: inline-block; background: #dcfce7; color: #166534; padding: 4px 10px; border-radius: 12px; font-size: 12px; font-weight: bold; margin-top: 5px; }
    table { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
    thead { background: #4CAF50; color: white; }
    th { padding: 10px; text-align: left; font-size: 13px; }
    td { padding: 8px; font-size: 12px; border-bottom: 1px solid #e5e7eb; }
    tbody tr:nth-child(even) { background: #f9fafb; }
    .footer { margin-top: 30px; padding-top: 15px; border-top: 2px solid #e5e7eb; text-align: center; color: #9ca3af; font-size: 12px; }
  </style>
</head>
<body>
  <div class="header">
    <h1>🍽️ SmartDiet</h1>
    <h2>Analytics Report</h2>
  </div>
  
  <div class="metadata">
    📅 Generated: ${DateFormat('MMMM dd, yyyy - hh:mm a').format(DateTime.now())} | 
    ⏰ Time Range: $_selectedTimeRange
  </div>
  
  <div class="section">
    <div class="section-title">Key Performance Metrics</div>
    <div class="metrics">
      <div class="metric-card">
        <div class="metric-label">Total Users</div>
        <div class="metric-value">${userMetrics['total'] ?? 0}</div>
        <span class="metric-change">${_calculateGrowth(userMetrics['growth'])}</span>
      </div>
      <div class="metric-card">
        <div class="metric-label">Favorite Recipes</div>
        <div class="metric-value">${recipeMetrics['total'] ?? 0}</div>
        <span class="metric-change">${_calculateGrowth(recipeMetrics['growth'])}</span>
      </div>
      <div class="metric-card">
        <div class="metric-label">Meal Plans</div>
        <div class="metric-value">${mealPlanMetrics['total'] ?? 0}</div>
        <span class="metric-change">${_calculateGrowth(mealPlanMetrics['growth'])}</span>
      </div>
      <div class="metric-card">
        <div class="metric-label">Nutrition Entries</div>
        <div class="metric-value">${nutritionMetrics['total'] ?? 0}</div>
        <span class="metric-change">${_calculateGrowth(nutritionMetrics['growth'])}</span>
      </div>
    </div>
  </div>
  
  <div class="section">
    <div class="section-title">Top 10 Recipes</div>
    <table>
      <thead><tr><th>Rank</th><th>Recipe</th><th>Type</th><th>Count</th></tr></thead>
      <tbody>
        ${topRecipes.take(10).toList().asMap().entries.map((e) => '<tr><td>${e.key + 1}</td><td>${e.value['title']}</td><td>${e.value['type']}</td><td>${e.value['count']}</td></tr>').join()}
      </tbody>
    </table>
  </div>
  
  <div class="section">
    <div class="section-title">Allergen Statistics</div>
    <table>
      <thead><tr><th>Allergen</th><th>User Count</th></tr></thead>
      <tbody>
        ${allergenStats.take(10).map((a) => '<tr><td>${a['icon']} ${a['name']}</td><td>${a['count']}</td></tr>').join()}
      </tbody>
    </table>
  </div>
  
  <div class="section">
    <div class="section-title">Registration Trends</div>
    <table>
      <thead><tr><th>Date</th><th>New Users</th></tr></thead>
      <tbody>
        ${registrationTrends.map((t) => '<tr><td>${t['date']}</td><td>${t['count']}</td></tr>').join()}
      </tbody>
    </table>
  </div>
  
  <div class="footer">
    🍽️ SmartDiet Analytics - Confidential Report
  </div>
</body>
</html>
      ''';

      Navigator.pop(context); // Close loading dialog

      // Create Word-compatible HTML document
      final wordHtml = '''
<!DOCTYPE html>
<html xmlns:o='urn:schemas-microsoft-com:office:office' xmlns:w='urn:schemas-microsoft-com:office:word' xmlns='http://www.w3.org/TR/REC-html40'>
<head>
  <meta charset='utf-8'>
  <title>SmartDiet Analytics Report</title>
  <!--[if gte mso 9]>
  <xml>
    <w:WordDocument>
      <w:View>Print</w:View>
      <w:Zoom>90</w:Zoom>
      <w:DoNotOptimizeForBrowser/>
    </w:WordDocument>
  </xml>
  <![endif]-->
  <style>
    @page { size: A4; margin: 2cm; }
    body { font-family: Calibri, Arial, sans-serif; font-size: 11pt; line-height: 1.5; }
    h1 { color: #2E7D32; font-size: 24pt; text-align: center; margin-bottom: 10pt; }
    h2 { color: #4CAF50; font-size: 16pt; margin-top: 20pt; margin-bottom: 10pt; border-bottom: 2px solid #4CAF50; padding-bottom: 5pt; }
    table { width: 100%; border-collapse: collapse; margin: 15pt 0; }
    th { background-color: #4CAF50; color: white; padding: 8pt; text-align: left; font-weight: bold; }
    td { padding: 6pt; border-bottom: 1px solid #ddd; }
    tr:nth-child(even) { background-color: #f9f9f9; }
    .header { text-align: center; margin-bottom: 20pt; }
    .metadata { background-color: #f5f5f5; padding: 10pt; margin-bottom: 20pt; border-radius: 5pt; }
    .metric-grid { display: table; width: 100%; margin-bottom: 20pt; }
    .metric-row { display: table-row; }
    .metric-cell { display: table-cell; width: 50%; padding: 10pt; }
    .metric-box { background-color: #e3f2fd; border: 1px solid #90caf9; padding: 15pt; border-radius: 5pt; }
    .metric-label { font-size: 10pt; color: #666; margin-bottom: 5pt; }
    .metric-value { font-size: 24pt; font-weight: bold; color: #1e293b; }
    .metric-change { background-color: #dcfce7; color: #166534; padding: 3pt 8pt; border-radius: 10pt; font-size: 9pt; font-weight: bold; }
  </style>
</head>
<body>
  <div class="header">
    <h1>🍽️ SmartDiet Analytics Report</h1>
    <div class="metadata">
      <strong>Generated:</strong> ${DateFormat('MMMM dd, yyyy - hh:mm a').format(DateTime.now())}<br>
      <strong>Time Range:</strong> $_selectedTimeRange
    </div>
  </div>

  ${sections.contains('metrics') ? '''
  <h2>Key Performance Metrics</h2>
  <div class="metric-grid">
    <div class="metric-row">
      <div class="metric-cell">
        <div class="metric-box">
          <div class="metric-label">Total Users</div>
          <div class="metric-value">${userMetrics['total'] ?? 0}</div>
          <span class="metric-change">${_calculateGrowth(userMetrics['growth'])}</span>
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-box">
          <div class="metric-label">Favorite Recipes</div>
          <div class="metric-value">${recipeMetrics['total'] ?? 0}</div>
          <span class="metric-change">${_calculateGrowth(recipeMetrics['growth'])}</span>
        </div>
      </div>
    </div>
    <div class="metric-row">
      <div class="metric-cell">
        <div class="metric-box">
          <div class="metric-label">Meal Plans</div>
          <div class="metric-value">${mealPlanMetrics['total'] ?? 0}</div>
          <span class="metric-change">${_calculateGrowth(mealPlanMetrics['growth'])}</span>
        </div>
      </div>
      <div class="metric-cell">
        <div class="metric-box">
          <div class="metric-label">Nutrition Entries</div>
          <div class="metric-value">${nutritionMetrics['total'] ?? 0}</div>
          <span class="metric-change">${_calculateGrowth(nutritionMetrics['growth'])}</span>
        </div>
      </div>
    </div>
  </div>
  ''' : ''}

  ${sections.contains('recipes') ? '''
  <h2>Top 10 Recipes</h2>
  <table>
    <thead>
      <tr>
        <th style="width: 10%;">Rank</th>
        <th style="width: 50%;">Recipe Name</th>
        <th style="width: 20%;">Type</th>
        <th style="width: 20%;">Usage Count</th>
      </tr>
    </thead>
    <tbody>
      ${topRecipes.take(10).toList().asMap().entries.map((e) => 
        '<tr><td>${e.key + 1}</td><td>${e.value['title']}</td><td>${e.value['type']}</td><td>${e.value['count']}</td></tr>'
      ).join()}
    </tbody>
  </table>
  ''' : ''}

  ${sections.contains('allergens') ? '''
  <h2>Allergen Statistics</h2>
  <table>
    <thead>
      <tr>
        <th style="width: 70%;">Allergen</th>
        <th style="width: 30%;">User Count</th>
      </tr>
    </thead>
    <tbody>
      ${allergenStats.take(10).map((a) => 
        '<tr><td>${a['icon']} ${a['name']}</td><td>${a['count']}</td></tr>'
      ).join()}
    </tbody>
  </table>
  ''' : ''}

  ${sections.contains('trends') ? '''
  <h2>User Registration Trends</h2>
  <table>
    <thead>
      <tr>
        <th style="width: 50%;">Date</th>
        <th style="width: 50%;">New Users</th>
      </tr>
    </thead>
    <tbody>
      ${registrationTrends.map((t) => 
        '<tr><td>${t['date']}</td><td>${t['count']}</td></tr>'
      ).join()}
    </tbody>
  </table>
  ''' : ''}

  <div style="margin-top: 30pt; padding-top: 15pt; border-top: 2px solid #ddd; text-align: center; color: #999; font-size: 9pt;">
    🍽️ SmartDiet Analytics - Confidential Report
  </div>
</body>
</html>
      ''';

      // Download as .doc file (HTML format that Word can open)
      final bytes = utf8.encode(wordHtml);
      final blob = html.Blob([bytes], 'application/msword');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', 'SmartDiet_Analytics_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.doc')
        ..click();
      html.Url.revokeObjectUrl(url);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Word document downloaded! Open it and press Ctrl+P to print.'),
            ],
          ),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 4),
        ),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error printing: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Real Analytics Data Methods
  Future<List<Map<String, dynamic>>> _getTopRecipes() async {
    // Return cached data if available and valid
    if (_cachedTopRecipes != null && _isCacheValid()) {
      return _cachedTopRecipes!;
    }
    
    try {
      final Map<String, int> recipeCounts = {};
      
      // Get all users
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      for (final userDoc in usersSnapshot.docs) {
        // Check favorites collection
        final favoritesSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('favorites')
            .get();
        
        for (final favoriteDoc in favoritesSnapshot.docs) {
          final data = favoriteDoc.data();
          final recipeTitle = _getRecipeTitle(data);
          if (recipeTitle.isNotEmpty) {
            recipeCounts[recipeTitle] = (recipeCounts[recipeTitle] ?? 0) + 1;
          }
        }
        
        // Check meal plans for recipe usage
        final mealPlansSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('meal_plans')
            .get();
        
        for (final mealPlanDoc in mealPlansSnapshot.docs) {
          final data = mealPlanDoc.data();
          final meals = data['meals'] as List<dynamic>? ?? [];
          
          for (final meal in meals) {
            if (meal is Map<String, dynamic>) {
              final recipeTitle = _getRecipeTitle(meal);
              if (recipeTitle.isNotEmpty) {
                recipeCounts[recipeTitle] = (recipeCounts[recipeTitle] ?? 0) + 1;
              }
            }
          }
        }
        
        // Check individual meals
        final mealsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('meal_plans')
            .get();
        
        for (final mealDoc in mealsSnapshot.docs) {
          final data = mealDoc.data();
          final recipeTitle = _getRecipeTitle(data);
          if (recipeTitle.isNotEmpty) {
            recipeCounts[recipeTitle] = (recipeCounts[recipeTitle] ?? 0) + 1;
          }
        }
      }
      
      // Convert to list and sort by count
      final List<Map<String, dynamic>> topRecipes = recipeCounts.entries
          .map((entry) => {
                'title': entry.key,
                'count': entry.value,
                'type': _getRecipeType(entry.key),
              })
          .toList();
      
      topRecipes.sort((a, b) => b['count'].compareTo(a['count']));
      
      final result = topRecipes.take(10).toList();
      
      // Cache the result
      _cachedTopRecipes = result;
      _lastCacheTime = DateTime.now();
      
      return result;
    } catch (e) {
      print('Error getting top recipes: $e');
      return [];
    }
  }

  String _getRecipeTitle(Map<String, dynamic> data) {
    // Try different possible title fields
    String title = '';
    
    // Check if it's a favorite with nested recipe data
    if (data['recipe'] is Map<String, dynamic>) {
      final recipe = data['recipe'] as Map<String, dynamic>;
      title = recipe['title'] ?? 
              recipe['name'] ?? 
              recipe['recipeTitle'] ?? 
              recipe['recipeName'] ?? 
              recipe['dishName'] ?? 
              '';
    }
    
    // If still empty, try top-level fields
    if (title.isEmpty) {
      title = data['title'] ?? 
              data['name'] ?? 
              data['recipeTitle'] ?? 
              data['recipeName'] ?? 
              data['dishName'] ?? 
              data['mealName'] ?? 
              '';
    }
    
    // Clean up the title
    final cleanTitle = title.toString().trim();
    
    // If still empty, try to generate a meaningful name
    if (cleanTitle.isEmpty) {
      // Check if it's from API (Spoonacular/TheMealDB)
      if (data['source'] == 'spoonacular' || data['source'] == 'themealdb') {
        return 'API Recipe #${data['id'] ?? 'Unknown'}';
      }
      
      // Check if it's a Filipino recipe
      if (data['source'] == 'filipino') {
        return 'Filipino Recipe #${data['id'] ?? 'Unknown'}';
      }
      
      // Check if it's an admin recipe
      if (data['source'] == 'admin') {
        return 'Admin Recipe #${data['id'] ?? 'Unknown'}';
      }
      
      // Check if it's a favorite with recipe data
      if (data['recipeId'] != null) {
        return 'Favorite Recipe #${data['recipeId']}';
      }
      
      // If we have ingredients, try to create a name
      final ingredients = data['ingredients'] as List?;
      if (ingredients != null && ingredients.isNotEmpty) {
        final firstIngredient = ingredients.first.toString();
        return 'Recipe with $firstIngredient';
      }
      
      // Check if it's a meal with a specific type
      if (data['mealType'] != null) {
        return '${data['mealType']} Recipe';
      }
      
      // Check if it has a cuisine type
      if (data['cuisine'] != null) {
        return '${data['cuisine']} Recipe';
      }
      
      // Last resort - skip this entry entirely
      return '';
    }
    
    return cleanTitle;
  }

  String _getRecipeType(String title) {
    // Determine recipe type based on title or other criteria
    if (title.toLowerCase().contains('filipino') || 
        title.toLowerCase().contains('adobo') ||
        title.toLowerCase().contains('sinigang')) {
      return 'Filipino';
    } else if (title.toLowerCase().contains('pasta') ||
               title.toLowerCase().contains('pizza')) {
      return 'Italian';
    } else if (title.toLowerCase().contains('sushi') ||
               title.toLowerCase().contains('ramen')) {
      return 'Asian';
    } else if (title.toLowerCase().contains('api recipe')) {
      return 'API';
    } else if (title.toLowerCase().contains('admin recipe')) {
      return 'Admin';
    } else {
      return 'General';
    }
  }

  Future<List<Map<String, dynamic>>> _getRecentActivity() async {
    // Return cached data if available and valid
    if (_cachedRecentActivity != null && _isCacheValid()) {
      return _cachedRecentActivity!;
    }
    
    try {
      final List<Map<String, dynamic>> activities = [];
      
      // Get recent user registrations (this query is safe)
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();
      
      for (final userDoc in usersSnapshot.docs) {
        final data = userDoc.data();
        activities.add({
          'type': 'user_registration',
          'title': 'New user registered: ${data['name'] ?? data['email']}',
          'timestamp': data['createdAt'],
          'icon': Icons.person_add,
          'color': Colors.green,
        });
      }
      
      // Get recent announcements (this query is safe)
      final announcementsSnapshot = await FirebaseFirestore.instance
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();
      
      for (final announcementDoc in announcementsSnapshot.docs) {
        final data = announcementDoc.data();
        activities.add({
          'type': 'announcement_sent',
          'title': 'Announcement sent: ${data['title']}',
          'timestamp': data['createdAt'],
          'icon': Icons.campaign,
          'color': Colors.purple,
        });
      }
      
      // Get limited user data for meal plans and substitutions (avoid expensive queries)
      final allUsersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .limit(10) // Limit to recent users only
          .get();
      
      // Get meal plans from limited users only
      for (final userDoc in allUsersSnapshot.docs) {
        try {
          final mealPlansSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('meal_plans')
              .limit(2) // Limit per user
              .get();
          
          for (final mealPlanDoc in mealPlansSnapshot.docs) {
            final data = mealPlanDoc.data();
            if (data['createdAt'] != null) {
              activities.add({
                'type': 'meal_plan_created',
                'title': 'Meal plan created: ${data['name'] ?? 'Weekly Plan'}',
                'timestamp': data['createdAt'],
                'icon': Icons.restaurant_menu,
                'color': Colors.blue,
              });
            }
          }
        } catch (e) {
          // Skip this user if there's an error
          continue;
        }
      }
      
      // Get substitutions from limited users only
      for (final userDoc in allUsersSnapshot.docs) {
        try {
          final mealsSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('meal_plans')
              .where('substituted', isEqualTo: true)
              .limit(2) // Limit per user
              .get();
          
          for (final mealDoc in mealsSnapshot.docs) {
            final data = mealDoc.data();
            final substitutions = data['substitutions'] as Map<String, dynamic>? ?? {};
            if (substitutions.isNotEmpty && data['createdAt'] != null) {
              final substitution = substitutions.values.first;
              activities.add({
                'type': 'substitution_used',
                'title': 'Substitution used: $substitution',
                'timestamp': data['createdAt'],
                'icon': Icons.swap_horiz,
                'color': Colors.orange,
              });
            }
          }
        } catch (e) {
          // Skip this user if there's an error
          continue;
        }
      }
      
      // Sort by timestamp and take the most recent
      activities.sort((a, b) {
        final aTime = a['timestamp'] as Timestamp?;
        final bTime = b['timestamp'] as Timestamp?;
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return bTime.compareTo(aTime);
      });
      
      final result = activities.take(15).toList();
      
      // Cache the result
      _cachedRecentActivity = result;
      _lastCacheTime = DateTime.now();
      
      return result;
    } catch (e) {
      print('Error getting recent activity: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> _getAnalyticsData() async {
    // Return cached data if available and valid
    if (_cachedAnalyticsData != null && _isCacheValid()) {
      return _cachedAnalyticsData!;
    }
    
    try {
      final now = DateTime.now();
      final timeRangeDays = _getTimeRangeDays();
      final startDate = now.subtract(Duration(days: timeRangeDays));

      // Get user metrics
      final userMetrics = await _getUserMetrics(startDate);
      
      // Get recipe metrics
      final recipeMetrics = await _getRecipeMetrics(startDate);
      
      // Get meal plan metrics
      final mealPlanMetrics = await _getMealPlanMetrics(startDate);
      
      // Get nutrition metrics
      final nutritionMetrics = await _getNutritionMetrics(startDate);
      
      // Get recipe update metrics
      final recipeUpdateMetrics = await _getRecipeUpdateMetrics(startDate);

      final result = {
        'users': userMetrics,
        'recipes': recipeMetrics,
        'mealPlans': mealPlanMetrics,
        'nutrition': nutritionMetrics,
        'recipeUpdates': recipeUpdateMetrics,
      };
      
      // Cache the result
      _cachedAnalyticsData = result;
      _lastCacheTime = DateTime.now();
      
      return result;
    } catch (e) {
      print('Error getting analytics data: $e');
      return {};
    }
  }

  int _getTimeRangeDays() {
    switch (_selectedTimeRange) {
      case '24 hours':
        return 1;
      case '7 days':
        return 7;
      case '30 days':
        return 30;
      case '90 days':
        return 90;
      default:
        return 7;
    }
  }

  Future<Map<String, dynamic>> _getUserMetrics(DateTime startDate) async {
    try {
      // Get total users
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      final totalUsers = usersSnapshot.docs.length;
      
      // Get new users in time range
      final newUsersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(startDate))
          .get();
      
      final newUsers = newUsersSnapshot.docs.length;
      
      // Calculate growth (simplified)
      final growth = totalUsers > 0 ? (newUsers / totalUsers * 100) : 0.0;

      return {
        'total': totalUsers,
        'new': newUsers,
        'growth': growth,
      };
    } catch (e) {
      print('Error getting user metrics: $e');
      return {'total': 0, 'new': 0, 'growth': 0.0};
    }
  }

  Future<Map<String, dynamic>> _getRecipeMetrics(DateTime startDate) async {
    try {
      int totalFavorites = 0;
      int newFavorites = 0;

      // Query all users' favorites
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      for (final userDoc in usersSnapshot.docs) {
        try {
          final favoritesSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('favorites')
              .get();

          totalFavorites += favoritesSnapshot.docs.length;

          // Count new favorites in time range
          final newFavoritesSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('favorites')
              .where('addedAt', isGreaterThan: Timestamp.fromDate(startDate))
              .get();

          newFavorites += newFavoritesSnapshot.docs.length;
        } catch (e) {
          print('Error processing user ${userDoc.id} favorites: $e');
        }
      }

      final growth = totalFavorites > 0 ? (newFavorites / totalFavorites * 100) : 0.0;

      return {
        'total': totalFavorites,
        'new': newFavorites,
        'growth': growth,
      };
    } catch (e) {
      print('Error getting recipe metrics: $e');
      return {'total': 0, 'new': 0, 'growth': 0.0};
    }
  }

  Future<Map<String, dynamic>> _getMealPlanMetrics(DateTime startDate) async {
    try {
      int totalMealPlans = 0;
      int newMealPlans = 0;

      // Query all users' meal plans
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      for (final userDoc in usersSnapshot.docs) {
        try {
          final mealPlansSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('meal_plans')
              .get();

          totalMealPlans += mealPlansSnapshot.docs.length;

          // Count new meal plans in time range
          final newMealPlansSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('meal_plans')
              .where('createdAt', isGreaterThan: Timestamp.fromDate(startDate))
              .get();

          newMealPlans += newMealPlansSnapshot.docs.length;
        } catch (e) {
          print('Error processing user ${userDoc.id} meal plans: $e');
        }
      }

      final growth = totalMealPlans > 0 ? (newMealPlans / totalMealPlans * 100) : 0.0;

      return {
        'total': totalMealPlans,
        'new': newMealPlans,
        'growth': growth,
      };
    } catch (e) {
      print('Error getting meal plan metrics: $e');
      return {'total': 0, 'new': 0, 'growth': 0.0};
    }
  }

  Future<Map<String, dynamic>> _getNutritionMetrics(DateTime startDate) async {
    try {
      int totalNutritionEntries = 0;
      int newNutritionEntries = 0;

      // Query all users' nutrition data
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();

      for (final userDoc in usersSnapshot.docs) {
        try {
          // Check meals collection for nutrition entries
          final mealsSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('meal_plans')
              .get();

          totalNutritionEntries += mealsSnapshot.docs.length;

          // Count new nutrition entries in time range
          final newMealsSnapshot = await FirebaseFirestore.instance
              .collection('users')
              .doc(userDoc.id)
              .collection('meal_plans')
              .where('addedAt', isGreaterThan: Timestamp.fromDate(startDate))
              .get();

          newNutritionEntries += newMealsSnapshot.docs.length;
        } catch (e) {
          print('Error processing user ${userDoc.id} nutrition data: $e');
        }
      }

      final growth = totalNutritionEntries > 0 ? (newNutritionEntries / totalNutritionEntries * 100) : 0.0;

      return {
        'total': totalNutritionEntries,
        'new': newNutritionEntries,
        'growth': growth,
      };
    } catch (e) {
      print('Error getting nutrition metrics: $e');
      return {'total': 0, 'new': 0, 'growth': 0.0};
    }
  }

  String _calculateGrowth(dynamic growth) {
    if (growth == null) return '+0%';
    final growthValue = growth is double ? growth : (growth as num).toDouble();
    final sign = growthValue >= 0 ? '+' : '';
    return '$sign${growthValue.toStringAsFixed(1)}%';
  }

  Widget _buildLoadingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 60,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: 80,
              height: 16,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              width: 40,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _getUserRegistrationTrends() async {
    try {
      final trends = <Map<String, dynamic>>[];
      final now = DateTime.now();
      
      // Get registration data for the last 7 days
      for (int i = 6; i >= 0; i--) {
        final date = now.subtract(Duration(days: i));
        final startOfDay = DateTime(date.year, date.month, date.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));
        
        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .where('createdAt', isLessThan: Timestamp.fromDate(endOfDay))
            .get();
        
        trends.add({
          'date': DateFormat('MMM dd').format(date),
          'count': snapshot.docs.length,
        });
      }
      
      return trends;
    } catch (e) {
      print('Error getting registration trends: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _getAllergenStats() async {
    try {
      final allergenCounts = <String, int>{};
      
      // Query all users to get their allergens
      final usersSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .get();
      
      for (final userDoc in usersSnapshot.docs) {
        try {
          final userData = userDoc.data();
          final allergies = userData['allergies'] as List<dynamic>? ?? [];
          
          for (final allergy in allergies) {
            if (allergy.toString().toLowerCase() != 'none') {
              allergenCounts[allergy.toString()] = (allergenCounts[allergy.toString()] ?? 0) + 1;
            }
          }
        } catch (e) {
          print('Error processing user ${userDoc.id} allergens: $e');
        }
      }
      
      // Convert to list and sort by count
      final allergenList = allergenCounts.entries.map((entry) {
        return {
          'name': entry.key,
          'count': entry.value,
          'icon': _getAllergenIcon(entry.key),
        };
      }).toList();
      
      allergenList.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
      
      return allergenList;
    } catch (e) {
      print('Error getting allergen stats: $e');
      return [];
    }
  }

  String _getAllergenIcon(String allergen) {
    final lowerAllergen = allergen.toLowerCase();
    if (lowerAllergen.contains('dairy') || lowerAllergen.contains('milk')) {
      return '🥛';
    } else if (lowerAllergen.contains('egg')) {
      return '🥚';
    } else if (lowerAllergen.contains('fish')) {
      return '🐟';
    } else if (lowerAllergen.contains('shellfish')) {
      return '🦐';
    } else if (lowerAllergen.contains('nut')) {
      return '🥜';
    } else if (lowerAllergen.contains('wheat') || lowerAllergen.contains('gluten')) {
      return '🌾';
    } else if (lowerAllergen.contains('soy')) {
      return '🫘';
    } else if (lowerAllergen.contains('sesame')) {
      return '🌰';
    }
    return '⚠️';
  }

  Future<Map<String, dynamic>> _getRecipeUpdateMetrics(DateTime startDate) async {
    try {
      int totalRecipeUpdates = 0;
      int affectedMealPlans = 0;
      int affectedIndividualMeals = 0;
      int notificationsSent = 0;
      final updateTypes = <String, int>{};
      
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      
      for (final userDoc in usersSnapshot.docs) {
        // Check meal plans for recipe updates
        final mealPlansSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('meal_plans')
            .get();
        
        for (final mealPlanDoc in mealPlansSnapshot.docs) {
          final mealPlanData = mealPlanDoc.data();
          final meals = mealPlanData['meals'] as List<dynamic>? ?? [];
          
          for (final meal in meals) {
            if (meal['recipeUpdatedAt'] != null) {
              final updatedAt = DateTime.tryParse(meal['recipeUpdatedAt']);
              if (updatedAt != null && updatedAt.isAfter(startDate)) {
                totalRecipeUpdates++;
                affectedMealPlans++;
                
                // Track update types
                final source = meal['source'] ?? 'unknown';
                updateTypes[source] = (updateTypes[source] ?? 0) + 1;
              }
            }
          }
        }
        
        // Check individual meals for recipe updates
        final mealsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('meal_plans')
            .where('recipeUpdatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .get();
        
        for (final mealDoc in mealsSnapshot.docs) {
          final mealData = mealDoc.data();
          totalRecipeUpdates++;
          affectedIndividualMeals++;
          
          // Track update types
          final source = mealData['source'] ?? 'unknown';
          updateTypes[source] = (updateTypes[source] ?? 0) + 1;
        }
        
        // Count notifications
        final notificationsSnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('notifications')
            .where('type', isEqualTo: 'recipe_updated')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
            .get();
        
        notificationsSent += notificationsSnapshot.docs.length;
      }
      
      return {
        'totalUpdates': totalRecipeUpdates,
        'affectedMealPlans': affectedMealPlans,
        'affectedIndividualMeals': affectedIndividualMeals,
        'notificationsSent': notificationsSent,
        'updateTypes': updateTypes,
        'averageUpdatesPerUser': usersSnapshot.docs.isNotEmpty 
            ? (totalRecipeUpdates / usersSnapshot.docs.length).toStringAsFixed(1)
            : '0',
      };
    } catch (e) {
      print('Error getting recipe update metrics: $e');
      return {
        'totalUpdates': 0,
        'affectedMealPlans': 0,
        'affectedIndividualMeals': 0,
        'notificationsSent': 0,
        'updateTypes': <String, int>{},
        'averageUpdatesPerUser': '0',
      };
    }
  }
}

// Export Options Dialog Widget
class _ExportOptionsDialog extends StatefulWidget {
  final Function(String format, Set<String> sections) onExport;

  const _ExportOptionsDialog({required this.onExport});

  @override
  State<_ExportOptionsDialog> createState() => _ExportOptionsDialogState();
}

class _ExportOptionsDialogState extends State<_ExportOptionsDialog> {
  String _selectedFormat = 'word';
  final Set<String> _selectedSections = {'metrics', 'recipes', 'allergens', 'trends'};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export Analytics Report'),
      content: SizedBox(
        width: 450,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Format:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: RadioListTile<String>(
                    value: 'csv',
                    groupValue: _selectedFormat,
                    onChanged: (value) {
                      setState(() {
                        _selectedFormat = value!;
                      });
                    },
                    title: const Row(
                      children: [
                        Icon(Icons.table_chart, color: Colors.green, size: 20),
                        SizedBox(width: 8),
                        Text('CSV'),
                      ],
                    ),
                    subtitle: const Text('Spreadsheet'),
                    dense: true,
                  ),
                ),
                Expanded(
                  child: RadioListTile<String>(
                    value: 'word',
                    groupValue: _selectedFormat,
                    onChanged: (value) {
                      setState(() {
                        _selectedFormat = value!;
                      });
                    },
                    title: const Row(
                      children: [
                        Icon(Icons.description, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Text('Word'),
                      ],
                    ),
                    subtitle: const Text('Document'),
                    dense: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Select Sections to Include:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              value: _selectedSections.contains('metrics'),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedSections.add('metrics');
                  } else {
                    _selectedSections.remove('metrics');
                  }
                });
              },
              title: const Row(
                children: [
                  Icon(Icons.analytics, size: 20, color: Colors.purple),
                  SizedBox(width: 8),
                  Text('Key Performance Metrics'),
                ],
              ),
              subtitle: const Text('Users, Recipes, Meal Plans, Nutrition'),
              dense: true,
            ),
            CheckboxListTile(
              value: _selectedSections.contains('recipes'),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedSections.add('recipes');
                  } else {
                    _selectedSections.remove('recipes');
                  }
                });
              },
              title: const Row(
                children: [
                  Icon(Icons.restaurant_menu, size: 20, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Top Recipes'),
                ],
              ),
              subtitle: const Text('Most popular recipes'),
              dense: true,
            ),
            CheckboxListTile(
              value: _selectedSections.contains('allergens'),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedSections.add('allergens');
                  } else {
                    _selectedSections.remove('allergens');
                  }
                });
              },
              title: const Row(
                children: [
                  Icon(Icons.warning, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Allergen Statistics'),
                ],
              ),
              subtitle: const Text('Most common allergens'),
              dense: true,
            ),
            CheckboxListTile(
              value: _selectedSections.contains('trends'),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedSections.add('trends');
                  } else {
                    _selectedSections.remove('trends');
                  }
                });
              },
              title: const Row(
                children: [
                  Icon(Icons.trending_up, size: 20, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Registration Trends'),
                ],
              ),
              subtitle: const Text('User growth over time'),
              dense: true,
            ),
            if (_selectedSections.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Please select at least one section',
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _selectedSections.isEmpty
              ? null
              : () {
                  Navigator.pop(context);
                  widget.onExport(_selectedFormat, _selectedSections);
                },
          icon: const Icon(Icons.download),
          label: const Text('Export'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
