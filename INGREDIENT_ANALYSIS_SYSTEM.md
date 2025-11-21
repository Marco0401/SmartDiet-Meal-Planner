# Ingredient Analysis System

## Overview
The Ingredient Analysis Service provides advanced ingredient composition extraction and allergen detection to prevent errors in substitution and allergen identification.

## Key Features

### 1. Base Ingredient Extraction
Extracts the core ingredient from complex descriptions by removing:
- Measurements and quantities (1 cup, 250ml, 2 tbsp)
- Preparation methods (chopped, diced, minced, melted)
- Descriptors (large, medium, organic, low-fat)
- Parenthetical content
- Punctuation and extra spaces

**Examples:**
```
"1 cup (250ml) low-fat milk" → "milk"
"2 tbsp butter, melted" → "butter"
"1 large egg, beaten" → "egg"
"1/2 cup all-purpose flour, sifted" → "flour"
```

### 2. Hidden Allergen Detection
Identifies allergens in:
- **Derivatives**: whey, casein, albumin, lecithin
- **Processed foods**: cream of mushroom soup, worcestershire sauce
- **Byproducts**: milk powder, egg solids, wheat starch

**Confidence Levels:**
- 1.0 (100%): Direct derivatives (e.g., "whey" contains dairy)
- 0.9 (90%): Known processed foods (e.g., "cream of mushroom soup" likely contains dairy)
- < 0.9: Uncertain detections (generates warnings)

### 3. Comprehensive Allergen Coverage

#### Dairy Derivatives
- whey, casein, lactose, curds, ghee
- buttermilk, cream cheese, sour cream
- milk powder, milk solids, milk protein
- lactalbumin, lactoglobulin, rennet casein

#### Egg Derivatives
- albumin, ovalbumin, ovomucoid
- egg white, egg yolk, egg powder
- lysozyme, meringue, mayonnaise, aioli

#### Wheat Derivatives
- wheat starch, wheat protein, wheat germ
- vital wheat gluten, hydrolyzed wheat protein
- durum, semolina, farina, kamut, spelt

#### Soy Derivatives
- soy protein, soy lecithin, soy flour
- textured vegetable protein (TVP)
- soy protein isolate/concentrate

#### Fish Derivatives
- fish oil, fish sauce, fish stock
- worcestershire sauce, anchovy paste
- omega-3, DHA, EPA, caviar, roe

#### Shellfish Derivatives
- shellfish extract, shellfish stock
- oyster sauce, clam juice, shrimp paste

#### Tree Nut Derivatives
- nut oil, nut butter, nut flour, nut milk
- almond extract, walnut oil, hazelnut paste
- praline, marzipan, nougat

#### Peanut Derivatives
- peanut oil, peanut butter, peanut flour
- groundnut oil, arachis oil

### 4. Hidden Allergen Foods Database

#### Dairy-Containing Foods
- Cream soups (mushroom, chicken, celery, potato)
- Sauces (alfredo, bechamel, white sauce, ranch, caesar)
- Sweets (chocolate, caramel, toffee, butterscotch, fudge)
- Baked goods (biscuits, crackers, cookies, cakes, bread)

#### Egg-Containing Foods
- Pasta (egg noodles, fresh pasta)
- Sauces (mayonnaise, aioli, hollandaise)
- Sweets (meringue, marshmallows, nougat, custard, pudding)
- Baked goods (cakes, cookies, brownies, muffins)

#### Wheat-Containing Foods
- Sauces (soy sauce, teriyaki, hoisin, worcestershire)
- Beverages (beer, ale, lager, malt beverages)
- Processed foods (seitan, imitation crab, surimi)
- Seasonings (bouillon cubes, soup mixes, gravy mixes)

#### Soy-Containing Foods
- Oils and broths (vegetable oil, vegetable broth)
- Seasonings (bouillon, stock cubes, soup bases)
- Processed foods (protein bars, energy bars, processed meats)

## API Reference

### `extractBaseIngredient(String ingredient)`
Extracts the core ingredient from a complex description.

```dart
final base = IngredientAnalysisService.extractBaseIngredient(
  "1 cup (250ml) low-fat milk, room temperature"
);
// Returns: "milk"
```

### `detectHiddenAllergens(String ingredient)`
Detects hidden allergens with confidence levels.

```dart
final hidden = IngredientAnalysisService.detectHiddenAllergens(
  "cream of mushroom soup"
);
// Returns: {'dairy': 0.9}
```

### `analyzeRecipeIngredients(List<dynamic> ingredients)`
Performs comprehensive analysis of all recipe ingredients.

```dart
final analysis = IngredientAnalysisService.analyzeRecipeIngredients(
  recipe['extendedIngredients']
);

// Returns:
// {
//   'directAllergens': {...},
//   'hiddenAllergens': {...},
//   'warnings': [...],
//   'totalIngredients': 15,
//   'analyzedSuccessfully': true,
// }
```

### `getSafeSubstitutions(String ingredient, List<String> userAllergens)`
Gets substitution suggestions that avoid user's allergens.

```dart
final substitutions = IngredientAnalysisService.getSafeSubstitutions(
  "milk",
  ["Tree Nuts", "Soy"]
);
// Returns: ["Oat milk or oat cream", "Coconut milk or coconut cream"]
// (Excludes almond milk and soy milk due to user allergies)
```

### `isSubstitutionSafe(String substitution, List<String> userAllergens)`
Validates that a substitution doesn't introduce new allergens.

```dart
final isSafe = IngredientAnalysisService.isSubstitutionSafe(
  "almond milk",
  ["Tree Nuts"]
);
// Returns: false (almond is a tree nut)
```

### `generateIngredientReport(Map<String, dynamic> analysis)`
Generates a human-readable analysis report.

```dart
final report = IngredientAnalysisService.generateIngredientReport(analysis);
print(report);
```

## Integration Examples

### Example 1: Enhanced Allergen Detection

```dart
// In AllergenDetectionService
final ingredients = recipe['extendedIngredients'] ?? recipe['ingredients'];
final analysis = IngredientAnalysisService.analyzeRecipeIngredients(ingredients);

// Check both direct and hidden allergens
final allAllergens = <String>{};
allAllergens.addAll(analysis['directAllergens'].keys);
allAllergens.addAll(analysis['hiddenAllergens'].keys);

// Show warnings to user
for (final warning in analysis['warnings']) {
  print('⚠️  $warning');
}
```

### Example 2: Safe Substitution Selection

```dart
// In SubstitutionDialog
final userAllergens = await AllergenDetectionService.getUserAllergens();
final safeSubs = IngredientAnalysisService.getSafeSubstitutions(
  ingredient,
  userAllergens,
);

// Validate each substitution
final validatedSubs = safeSubs.where((sub) {
  return IngredientAnalysisService.isSubstitutionSafe(sub, userAllergens);
}).toList();
```

### Example 3: Ingredient Preprocessing

```dart
// Before allergen checking
for (final ingredient in ingredients) {
  final baseIngredient = IngredientAnalysisService.extractBaseIngredient(
    ingredient['name']
  );
  
  // Check both original and base ingredient
  checkForAllergens(ingredient['name']);
  checkForAllergens(baseIngredient);
}
```

## Benefits

### 1. Accuracy
- Detects allergens in derivatives and byproducts
- Identifies hidden allergens in processed foods
- Reduces false negatives

### 2. Safety
- Prevents unsafe substitutions
- Validates substitutions against user allergens
- Provides confidence levels for uncertain detections

### 3. Transparency
- Generates detailed analysis reports
- Shows confidence levels
- Provides warnings for uncertain detections

### 4. Maintainability
- Centralized allergen knowledge base
- Easy to add new derivatives and foods
- Consistent across the application

## Testing Recommendations

### Test Cases

1. **Base Ingredient Extraction**
   - "1 cup (250ml) low-fat milk" → "milk"
   - "2 tbsp butter, melted and cooled" → "butter"
   - "3 large eggs, beaten" → "eggs"

2. **Hidden Allergen Detection**
   - "cream of mushroom soup" → dairy (0.9 confidence)
   - "worcestershire sauce" → fish (0.9 confidence)
   - "whey protein" → dairy (1.0 confidence)

3. **Safe Substitution**
   - User allergic to tree nuts → exclude almond milk
   - User allergic to soy → exclude soy milk
   - User allergic to both → suggest oat milk, coconut milk

4. **Substitution Validation**
   - "almond milk" + ["Tree Nuts"] → unsafe
   - "oat milk" + ["Tree Nuts"] → safe
   - "soy milk" + ["Soy"] → unsafe

## Future Enhancements

1. **Machine Learning Integration**
   - Train model on ingredient-allergen pairs
   - Improve confidence level accuracy
   - Learn from user feedback

2. **Regional Variations**
   - Support for different ingredient names by region
   - Cultural food knowledge bases
   - Local allergen regulations

3. **Nutritional Analysis**
   - Extract nutritional information from ingredients
   - Calculate recipe nutrition from components
   - Suggest nutritionally equivalent substitutions

4. **User Customization**
   - Allow users to add custom allergen derivatives
   - Personal ingredient blacklist/whitelist
   - Sensitivity level settings

5. **API Integration**
   - Connect to ingredient databases (USDA, Open Food Facts)
   - Real-time allergen information lookup
   - Automatic updates to allergen knowledge base

## Performance Considerations

- **Caching**: Cache analysis results for frequently used ingredients
- **Batch Processing**: Analyze multiple ingredients in parallel
- **Lazy Loading**: Load allergen databases on demand
- **Optimization**: Use efficient string matching algorithms

## Security & Privacy

- All analysis happens locally on device
- No ingredient data sent to external servers
- User allergen profiles encrypted in storage
- Compliance with food allergen labeling regulations
