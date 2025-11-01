# Manual Entry Recipe Routing

## Overview
Manual entry recipes now have special handling to ensure they're edited with the correct page and don't get scaled/clamped.

## Changes Made

### 1. **Recipe Detail Page (`recipe_detail_page.dart`)**

#### Added Imports
```dart
import 'package:intl/intl.dart';
import 'manual_meal_entry_page.dart';
```

#### Modified `_editMeal()` Method (Lines 377-442)
- Detects manual entry recipes by checking `source == 'manual_entry'`
- Routes manual entry recipes to `ManualMealEntryPage` instead of `EditMealDialog`
- Other recipes continue using `EditMealDialog`

**Logic:**
```dart
final source = baseRecipe['source']?.toString() ?? '';
final isManualEntry = source == 'manual_entry';

if (isManualEntry) {
  // Navigate to ManualMealEntryPage with prefilled data
  result = await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => ManualMealEntryPage(
        selectedDate: dateKey.isNotEmpty ? dateKey : DateFormat('yyyy-MM-dd').format(DateTime.now()),
        mealType: baseRecipe['mealType']?.toString(),
        prefilledData: baseRecipe,
      ),
    ),
  );
} else {
  // Show EditMealDialog for other recipes
  result = await showDialog(...);
}
```

### 2. **Manual Meal Entry Page (`manual_meal_entry_page.dart`)**

#### Added Import
```dart
import 'package:flutter/scheduler.dart';
```

#### Added Edit Mode Tracking (Lines 62-65)
```dart
// Edit mode tracking
bool _isEditMode = false;
String? _editingMealId; // For meal planner
String? _editingFavoriteId; // For favorites
```

#### Enhanced `_prefillFormData()` Method (Lines 112-200)
Now properly handles manual entry recipe format for editing:

**Features:**
- **Detects edit mode** by checking for `id` or `docId`
- Stores meal/favorite IDs for updating
- Handles both `title` and `foodName` fields
- Extracts nutrition from `nutrition` map object
- Parses ingredient list (both string format and structured format)
- **Calculates individual ingredient nutrition** using `_calculateIndividualNutrition`
- Parses instruction steps (numbered or plain text)
- Loads local image files
- Automatically switches to Smart Mode if ingredients are structured
- Recalculates total nutrition after all ingredients are loaded

**Nutrition Calculation Fix:**
```dart
// Calculate nutrition for each prefilled ingredient
SchedulerBinding.instance.addPostFrameCallback((_) async {
  for (int i = 0; i < _editedIngredients.length; i++) {
    final ing = _editedIngredients[i];
    final nutrition = await _calculateIndividualNutrition(
      ing['name']?.toString() ?? '',
      ing['amount'] as double,
      ing['unit']?.toString() ?? 'piece',
    );
    if (mounted) {
      setState(() {
        _editedIngredients[i]['nutrition'] = nutrition;
      });
    }
  }
  // After all ingredients have nutrition, recalculate total
  if (mounted) {
    _recalculateNutrition();
  }
});
```

#### Updated `_saveMeal()` Method (Lines 1316-1387)
Now handles both **create** and **update** operations:

**Create Mode** (new recipes):
- Uses `NutritionService.saveMealWithNutrition` with `customNutrition`
- Saves to both meal_plans and favorites

**Edit Mode** (existing recipes):
- Detects edit mode via `_isEditMode` flag
- Updates meal planner document directly if `_editingMealId` exists
- Updates favorites document directly if `_editingFavoriteId` exists
- **Uses direct Firestore `.update()` with exact nutrition values**
- **NO scaling or clamping applied**

```dart
if (_isEditMode) {
  // UPDATE EXISTING RECIPE
  if (_editingMealId != null) {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('meal_plans')
        .doc(_editingMealId)
        .update({
      'nutrition': nutritionData, // Direct nutrition, no scaling
      ...
    });
  }
}

**Format Support:**
```dart
// Nutrition object format
final nutrition = data['nutrition'] as Map<String, dynamic>?;

// Ingredients as List<String> format
if (ingredients is List) {
  _editedIngredients = ingredients.map((ing) => parseAndStructure(ing)).toList();
  _recalculateNutrition(); // Recalculate with correct values
}

// Instructions as numbered string
"1. Step one\n2. Step two" -> ["Step one", "Step two"]
```

### 3. **Nutrition Service (`nutrition_service.dart`)**

#### Fixed `saveMealWithNutrition()` Method (Line 614)
**Before:**
```dart
final nutrition = await calculateRecipeNutrition(ingredients); // ❌ Always recalculated
```

**After:**
```dart
final nutrition = customNutrition ?? await calculateRecipeNutrition(ingredients); // ✅ Use custom if provided
```

**Impact:**
- Manual entry recipes now save with their **correct calculated nutrition**
- No more scaling/clamping applied to manual entry values
- Other recipes can still use auto-calculation if no custom nutrition provided

## User Experience

### Editing Manual Entry Recipes
1. **From Meal Planner:**
   - Click edit button on manual entry meal
   - Opens ManualMealEntryPage with all data prefilled
   - Edit ingredients, instructions, nutrition, etc.
   - Save updates back to meal planner

2. **From Favorites:**
   - Click edit button on manual entry recipe
   - Opens ManualMealEntryPage with all data prefilled
   - Edit and save updates back to favorites

3. **Other Recipes:**
   - Continue using EditMealDialog
   - Normal ingredient replacement and editing

### Why This Approach?

**Manual Entry Page Benefits:**
- Full control over all fields (name, nutrition, image, etc.)
- Smart mode for structured ingredients
- Manual mode for free-form entry
- Consistent UI with original creation

**Edit Dialog Benefits:**
- Quick ingredient swapping
- Focused on allergen substitution
- Works with API recipe format
- Lighter weight for simple edits

## Technical Notes

### Detection Logic
```dart
final source = baseRecipe['source']?.toString() ?? '';
final isManualEntry = source == 'manual_entry';
```

All manual entry recipes have `source: 'manual_entry'` in Firestore.

### No Scaling/Clamping
Manual entry recipes bypass the scaling logic in `NutritionService` by providing `customNutrition` parameter, which is now properly used instead of being ignored.

### Data Flow
```
Manual Entry Edit:
  Recipe Detail Page
    ↓ (detect source='manual_entry')
  Manual Meal Entry Page (prefilled)
    ↓ (edit and save)
  NutritionService.saveMealWithNutrition(customNutrition)
    ↓ (uses custom nutrition, no recalculation)
  Firestore (correct values saved)

Other Recipe Edit:
  Recipe Detail Page
    ↓ (detect source ≠ 'manual_entry')
  Edit Meal Dialog
    ↓ (swap ingredients, recalculate)
  Direct Firestore Update
    ↓ (saves calculated values)
  Firestore (correct values saved)
```

## Testing Checklist

- [ ] Edit manual entry meal from meal planner
- [ ] Edit manual entry recipe from favorites
- [ ] Verify all fields are prefilled correctly
- [ ] Verify nutrition values are correct after save
- [ ] Verify ingredients display in smart mode
- [ ] Verify instructions are parsed correctly
- [ ] Verify image loads if present
- [ ] Verify other recipes still use edit dialog
- [ ] Verify no scaling happens on manual entry saves
- [ ] Verify edit dialog still works for API recipes

## Summary of Fixes

### ✅ Issue #1: Zero Nutrition Values When Editing
**Problem:** When editing manual entry recipes, all ingredient nutrition values showed as 0.

**Root Cause:** The prefill logic set `nutrition: {}` but never calculated individual ingredient nutrition.

**Solution:** Added async calculation loop in `addPostFrameCallback` that:
1. Calls `_calculateIndividualNutrition` for each ingredient
2. Updates each ingredient's nutrition map
3. Then calls `_recalculateNutrition` to sum totals

### ✅ Issue #2: Scaling/Clamping on Edit
**Problem:** Manual entry recipes were being scaled/clamped when edited.

**Root Cause:** `_saveMeal` always created new documents using `NutritionService.saveMealWithNutrition`, which could recalculate.

**Solution:** 
1. Added edit mode detection (`_isEditMode`, `_editingMealId`, `_editingFavoriteId`)
2. When editing, use direct Firestore `.update()` instead of service method
3. Pass exact `nutritionData` without any service-layer processing
4. NO scaling or clamping applied during updates

### ✅ Issue #3: Routing
**Problem:** All recipes opened Edit Dialog, even manual entries.

**Solution:** Added source detection in `recipe_detail_page.dart`:
- `source == 'manual_entry'` → Navigate to `ManualMealEntryPage`
- Other sources → Show `EditMealDialog`

## Files Modified

1. `lib/recipe_detail_page.dart` - Routing logic
2. `lib/manual_meal_entry_page.dart` - Prefill logic, edit mode, save logic
3. `lib/services/nutrition_service.dart` - Custom nutrition fix

## Related Documents

- `PULL_TO_REFRESH_FEATURE.md` - Manual entry nutrition issue
- `NUTRITION_CALCULATION_FIX.md` - Original nutrition bug documentation
