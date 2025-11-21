import 'package:flutter/material.dart';
import 'services/recipe_service.dart';
import 'services/dietary_filter_service.dart';
import 'services/meal_time_service.dart';
import 'recipe_detail_page.dart';

class RecipeSearchPage extends StatefulWidget {
  const RecipeSearchPage({super.key});

  @override
  State<RecipeSearchPage> createState() => _RecipeSearchPageState();
}

class _RecipeSearchPageState extends State<RecipeSearchPage> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _error;
  String? _userDietaryPreference;
  
  String? _selectedCuisine;
  String? _selectedMealType;
  int? _maxReadyTime;
  String _currentMealPeriod = MealTimeService.getCurrentMealPeriod();
  bool _filterByMealTime = false; // Default off for search (user controls it)

  @override
  void initState() {
    super.initState();
    _loadUserPreference();
    // Load default recipes on init
    _loadDefaultRecipes();
  }

  Future<void> _loadUserPreference() async {
    final pref = await DietaryFilterService.getUserDietaryPreference();
    setState(() {
      _userDietaryPreference = pref;
    });
    print('DEBUG: User dietary preference loaded: $_userDietaryPreference');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDefaultRecipes() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Fetch random popular recipes - empty query gets variety
      final results = await RecipeService.fetchRecipes('');
      
      setState(() {
        _searchResults = results.cast<Map<String, dynamic>>();
        _isLoading = false;
        _hasSearched = true;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading recipes: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    
    // Build search query based on filters
    final searchQuery = _buildSearchQuery(query);
    print('DEBUG: Built search query: "$searchQuery"');

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _error = null;
    });

    try {
      // Fetch recipes from all sources with dynamic query
      // Pass user's dietary preference to RecipeService
      final allResults = await RecipeService.fetchRecipes(
        searchQuery,
        dietaryPreferences: _userDietaryPreference != null ? [_userDietaryPreference!] : null,
      );
      
      // Apply dietary filtering
      List<Map<String, dynamic>> dietFiltered = DietaryFilterService.filterRecipesByDiet(
        allResults.cast<Map<String, dynamic>>(),
        _userDietaryPreference,
      );
      
      // Apply additional client-side filtering (for cooking time, etc.)
      List<Map<String, dynamic>> filteredResults = _applyFilters(dietFiltered);

      setState(() {
        _searchResults = filteredResults;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error searching recipes: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  String _buildSearchQuery(String userQuery) {
    // Start with user's search query if provided
    List<String> queryParts = [];
    
    if (userQuery.isNotEmpty) {
      queryParts.add(userQuery);
    }
    
    // Add cuisine to query
    if (_selectedCuisine != null) {
      queryParts.add(_selectedCuisine!);
    }
    
    // Add meal type to query
    if (_selectedMealType != null) {
      queryParts.add(_selectedMealType!);
    }
    
    // Note: Dietary preference is handled separately via filtering
    // Don't add it to search query to get broader results that we can filter
    
    // If we have query parts, join them
    if (queryParts.isNotEmpty) {
      return queryParts.join(' ');
    }
    
    // Default fallback - empty string will fetch popular/random recipes
    return '';
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> recipes) {
    // Apply cooking time filter
    print('DEBUG: Applying client-side filters to ${recipes.length} recipes');
    print('DEBUG: MaxTime filter: $_maxReadyTime');
    print('DEBUG: User dietary preference: $_userDietaryPreference');

    final filtered = recipes.where((recipe) {
      // Filter by max ready time
      if (_maxReadyTime != null) {
        final readyTime = recipe['readyInMinutes'] as int? ?? 
                         recipe['cookingTime'] as int? ?? 999;
        if (readyTime > _maxReadyTime!) {
          print('DEBUG: Recipe "${recipe['title']}" excluded - cooking time: ${readyTime}min > ${_maxReadyTime}min');
          return false;
        }
      }
      
      return true;
    }).toList();

    print('DEBUG: Recipes after client-side filtering: ${filtered.length}');
    
    // Apply meal time filtering if enabled
    if (_filterByMealTime && filtered.isNotEmpty) {
      print('DEBUG: Applying meal time filter for period: $_currentMealPeriod');
      final timeFiltered = MealTimeService.filterRecipesByMealPeriod(
        filtered,
        _currentMealPeriod,
        minSuitability: 0.3,
      );
      print('DEBUG: After meal time filtering: ${timeFiltered.length} recipes');
      return timeFiltered;
    }
    
    return filtered;
  }

  int _getActiveFiltersCount() {
    int count = 0;
    if (_selectedCuisine != null) count++;
    if (_selectedMealType != null) count++;
    if (_maxReadyTime != null) count++;
    return count;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: const Color(0xFFF8FFF4),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF2E7D32),
                Color(0xFF388E3C),
                Color(0xFF4CAF50),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text(
              'Search Recipes',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 22,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(0, 2),
                    blurRadius: 4,
                    color: Colors.black26,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Meal Period Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.green[50]!, Colors.green[100]!],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(
                    MealTimeService.getMealPeriodIcon(_currentMealPeriod),
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          MealTimeService.getMealPeriodDisplayName(_currentMealPeriod),
                          style: TextStyle(
                            color: Colors.green[800],
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          MealTimeService.getMealPeriodTimeRange(_currentMealPeriod),
                          style: TextStyle(
                            color: Colors.green[600],
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Filter by time',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: _filterByMealTime,
                    onChanged: (value) {
                      setState(() {
                        _filterByMealTime = value;
                      });
                      if (_hasSearched) {
                        _performSearch();
                      }
                    },
                    activeColor: Colors.green[700],
                  ),
                ],
              ),
            ),
            
            // Search Bar
            Container(
              padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search for recipes...',
                      prefixIcon: const Icon(Icons.search, color: Colors.green),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.green[600]!, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                const SizedBox(width: 8),
                Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: _showFilters,
                        icon: const Icon(Icons.filter_list),
                        color: Colors.green[700],
                        tooltip: 'Filters',
                      ),
                    ),
                    if (_getActiveFiltersCount() > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            _getActiveFiltersCount().toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 4),
                ElevatedButton(
                  onPressed: _isLoading ? null : _performSearch,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.search),
                ),
              ],
            ),
          ),

          // Results
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildBody() {
    final gradientBg = BoxDecoration(
      gradient: LinearGradient(
        colors: [const Color(0xFFF8FFF4), Colors.green[50]!],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
    );

    if (_isLoading) {
      return Container(
        decoration: gradientBg,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.green),
              SizedBox(height: 16),
              Text('Loading delicious recipes...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Container(
        decoration: gradientBg,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: Colors.red[700]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadDefaultRecipes,
                icon: const Icon(Icons.refresh),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green[600],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_searchResults.isEmpty) {
      return Container(
        decoration: gradientBg,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off, size: 80, color: Colors.grey[300]),
              const SizedBox(height: 16),
              Text(
                'No recipes found',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try adjusting your search or filters',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFF8FFF4), Colors.green[50]!],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.68,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: _searchResults.length,
        itemBuilder: (context, index) => _buildRecipeCard(_searchResults[index]),
      ),
    );
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipe) {
    // Extract nutrition data
    final nutrition = recipe['nutrition'] as Map<String, dynamic>? ?? {};
    final calories = nutrition['calories']?.toDouble() ?? 0.0;
    final protein = nutrition['protein']?.toDouble() ?? 0.0;
    final carbs = nutrition['carbs']?.toDouble() ?? nutrition['carbohydrates']?.toDouble() ?? 0.0;
    final fat = nutrition['fat']?.toDouble() ?? 0.0;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RecipeDetailPage(recipe: recipe),
            ),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recipe Image
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                  child: recipe['image'] != null
                      ? Image.network(
                          recipe['image'],
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            height: 140,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.green[100]!, Colors.green[200]!],
                              ),
                            ),
                            child: const Center(
                              child: Icon(Icons.restaurant_menu, size: 48, color: Colors.green),
                            ),
                          ),
                        )
                      : Container(
                          height: 140,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.green[100]!, Colors.green[200]!],
                            ),
                          ),
                          child: const Center(
                            child: Icon(Icons.restaurant_menu, size: 48, color: Colors.green),
                          ),
                        ),
                ),
                // Cooking time badge
                if (recipe['readyInMinutes'] != null || recipe['cookingTime'] != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time, size: 12, color: Colors.white),
                          const SizedBox(width: 4),
                          Text(
                            '${recipe['readyInMinutes'] ?? recipe['cookingTime']} min',
                            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            // Recipe Info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    recipe['title'] ?? 'Unknown Recipe',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // Nutrition Info
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNutritionItem('Cal', calories.toInt().toString(), Icons.local_fire_department, Colors.orange),
                        _buildNutritionItem('P', '${protein.toInt()}g', Icons.fitness_center, Colors.red),
                        _buildNutritionItem('C', '${carbs.toInt()}g', Icons.bakery_dining, Colors.amber),
                        _buildNutritionItem('F', '${fat.toInt()}g', Icons.water_drop, Colors.blue),
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

  Widget _buildNutritionItem(String label, String value, IconData icon, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedCuisine = null;
                        _selectedMealType = null;
                        _maxReadyTime = null;
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Clear All'),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildFilterDropdown(
                      'Cuisine',
                      _selectedCuisine,
                      ['Asian', 'Filipino', 'Mexican', 'Italian', 'American', 'Indian', 'Chinese', 'Japanese', 'Thai', 'Mediterranean', 'French'],
                      (value) => setState(() => _selectedCuisine = value),
                    ),
                    const SizedBox(height: 16),
                    // Dietary preference info (read-only, set in account settings)
                    if (_userDietaryPreference != null && _userDietaryPreference != 'None') ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.restaurant, color: Colors.green.shade700, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Dietary Preference: $_userDietaryPreference',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  Text(
                                    DietaryFilterService.getDietaryPreferenceDescription(_userDietaryPreference),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.green.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _buildFilterDropdown(
                      'Meal Type',
                      _selectedMealType,
                      ['breakfast', 'lunch', 'dinner', 'snack', 'dessert', 'appetizer'],
                      (value) => setState(() => _selectedMealType = value),
                    ),
                    const SizedBox(height: 16),
                    _buildReadyTimeFilter(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // Always perform search when filters are applied
                    _performSearch();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDropdown(String label, String? value, List<String> items, Function(String?) onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<String>(
            value: value,
            hint: Text('Select $label'),
            isExpanded: true,
            underline: const SizedBox(),
            items: items.map((item) {
              return DropdownMenuItem(
                value: item,
                child: Text(item),
              );
            }).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildReadyTimeFilter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Max Cooking Time',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: (_maxReadyTime ?? 120).toDouble(),
                min: 15,
                max: 120,
                divisions: 21,
                label: _maxReadyTime != null ? '$_maxReadyTime min' : 'Any',
                activeColor: Colors.green[600],
                onChanged: (value) {
                  setState(() {
                    _maxReadyTime = value.toInt();
                  });
                },
              ),
            ),
            Text(
              _maxReadyTime != null ? '$_maxReadyTime min' : 'Any',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
