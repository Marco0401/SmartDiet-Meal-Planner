# Dietary Filtering Quick Reference

## For Developers

### Getting User's Dietary Preference
```dart
import 'services/dietary_filter_service.dart';

// Get user's dietary preference
final preference = await DietaryFilterService.getUserDietaryPreference();
// Returns: String? ('Vegetarian', 'Vegan', etc. or null)
```

### Filtering Recipes
```dart
import 'services/dietary_filter_service.dart';

// Filter a list of recipes
List<Map<String, dynamic>> recipes = [...];
final filtered = DietaryFilterService.filterRecipesByDiet(
  recipes,
  userDietaryPreference,
);
```

### Fetching Recipes with Filtering
```dart
import 'services/recipe_service.dart';

// Fetch recipes with dietary preference
final recipes = await RecipeService.fetchRecipes(
  'chicken',
  dietaryPreferences: preference != null ? [preference] : null,
);
```

### Display Preference Info
```dart
import 'services/dietary_filter_service.dart';

// Get display name
final displayName = DietaryFilterService.getDietaryPreferenceDisplayName(preference);
// Returns: 'Vegetarian' or 'All Recipes'

// Get description
final description = DietaryFilterService.getDietaryPreferenceDescription(preference);
// Returns: 'No meat, poultry, or seafood'
```

## Dietary Preference Options

| Preference | Excludes | Allows |
|-----------|----------|--------|
| **None** | Nothing | Everything |
| **Vegetarian** | Meat, poultry, fish, seafood | Dairy, eggs, plants |
| **Vegan** | All animal products | Plants only |
| **Pescatarian** | Meat, poultry | Fish, seafood, dairy, eggs, plants |
| **Keto** | High-carb foods | Low-carb, high-fat foods |
| **Low Carb** | High-carb foods (<30g) | Lower carb options |
| **Low Sodium** | High-sodium foods (<500mg) | Lower sodium options |
| **Halal** | Pork, alcohol | Halal meats, plants |

## Common Patterns

### Pattern 1: Page with Recipe Display
```dart
class MyRecipePage extends StatefulWidget {
  // ...
}

class _MyRecipePageState extends State<MyRecipePage> {
  String? _userDietaryPreference;
  List<Map<String, dynamic>> _recipes = [];

  @override
  void initState() {
    super.initState();
    _loadPreferenceAndRecipes();
  }

  Future<void> _loadPreferenceAndRecipes() async {
    // 1. Load preference
    final pref = await DietaryFilterService.getUserDietaryPreference();
    
    // 2. Fetch recipes
    final recipes = await RecipeService.fetchRecipes(
      'query',
      dietaryPreferences: pref != null ? [pref] : null,
    );
    
    // 3. Apply filtering
    final filtered = DietaryFilterService.filterRecipesByDiet(recipes, pref);
    
    setState(() {
      _userDietaryPreference = pref;
      _recipes = filtered;
    });
  }
}
```

### Pattern 2: Displaying Preference Info
```dart
if (_userDietaryPreference != null && _userDietaryPreference != 'None') {
  Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.green.shade50,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dietary Preference: $_userDietaryPreference',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        Text(
          DietaryFilterService.getDietaryPreferenceDescription(_userDietaryPreference),
          style: TextStyle(fontSize: 12),
        ),
      ],
    ),
  )
}
```

## Debugging

### Enable Debug Logging
The filtering service includes debug print statements:
```
DEBUG: Filtering X recipes for diet: Vegetarian
DEBUG: Recipe excluded from vegetarian - contains: chicken
```

### Check User Preference
```dart
final user = FirebaseAuth.instance.currentUser;
final doc = await FirebaseFirestore.instance
    .collection('users')
    .doc(user!.uid)
    .get();
final prefs = doc.data()?['dietaryPreferences'];
print('User dietary preferences: $prefs');
```

### Test Filtering
```dart
final testRecipes = [
  {'title': 'Chicken Salad', 'ingredients': ['chicken', 'lettuce']},
  {'title': 'Veggie Pasta', 'ingredients': ['pasta', 'tomato']},
];

final filtered = DietaryFilterService.filterRecipesByDiet(
  testRecipes,
  'Vegetarian',
);

print('Filtered count: ${filtered.length}'); // Should be 1 (Veggie Pasta)
```

## Migration Notes

### From Old Multi-Select System
- Old: `List<String> dietaryPreferences = ['Vegetarian', 'Keto']`
- New: `List<String> dietaryPreferences = ['Vegetarian']` (single item)

### Updating Existing Users
Users with multiple preferences will automatically use the first preference in their list. Consider adding a migration script or prompt to have them re-select their primary preference.

## Common Issues

### Issue: Recipes not filtering
**Solution**: Check that:
1. User has a dietary preference set
2. Preference is being passed to filtering functions
3. Recipe data includes ingredients/title for matching

### Issue: Too many recipes filtered out
**Solution**: Review filtering keywords in `DietaryFilterService` - they may be too strict

### Issue: Preference not loading
**Solution**: Ensure user document exists in Firestore and has `dietaryPreferences` field
