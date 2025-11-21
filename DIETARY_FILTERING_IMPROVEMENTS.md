# Dietary Filtering System Improvements

## Overview
Improved the meal planner system to implement single-select dietary preferences with comprehensive filtering across all recipe displays.

## Key Changes

### 1. Single-Select Dietary Preferences
**File: `lib/onboarding/steps/dietary_preferences_step.dart`**
- Changed from multi-select checkboxes to single-select radio buttons
- Users now select ONE primary dietary preference
- Options: None, Vegetarian, Vegan, Pescatarian, Keto, Low Carb, Low Sodium, Halal, Other
- Prevents conflicting dietary preferences (e.g., can't be both Vegan and Keto)

### 2. New Dietary Filter Service
**File: `lib/services/dietary_filter_service.dart`**
- Centralized filtering logic for all dietary preferences
- Comprehensive ingredient checking for each diet type:
  - **Vegetarian**: Excludes meat, poultry, fish, seafood
  - **Vegan**: Excludes all animal products (meat, dairy, eggs, honey)
  - **Pescatarian**: Excludes meat and poultry, allows fish
  - **Keto**: Excludes high-carb foods (bread, pasta, rice, sugar)
  - **Low Carb**: Checks nutrition data (<30g carbs) or uses keto rules
  - **Low Sodium**: Checks nutrition data (<500mg) or excludes high-sodium ingredients
  - **Halal**: Excludes pork and alcohol

### 3. Recipe Search Page Updates
**File: `lib/recipe_search_page.dart`**
- Loads user's dietary preference on init
- Applies dietary filtering to all search results
- Displays user's dietary preference as read-only info (set in account settings)
- Removed conflicting diet filter dropdown
- Filters applied: Dietary preference → Cooking time

### 4. Meal Suggestions Page Updates
**File: `lib/meal_suggestions_page.dart`**
- Loads user's dietary preference from profile
- Applies dietary filtering to all category suggestions
- Applies dietary filtering to search results
- Separates allergen filtering from dietary filtering
- Filters applied: Dietary preference → Allergen filtering

### 5. Main Page Updates
**File: `lib/main.dart`**
- Updated to use single dietary preference (first item in list)
- Passes dietary preference to RecipeService
- Consistent filtering across home page recipe display

## How It Works

### User Flow
1. **Onboarding**: User selects ONE dietary preference
2. **Storage**: Preference stored in Firestore as single-item list
3. **Retrieval**: Apps load preference and apply filtering automatically
4. **Filtering**: All recipe displays filter based on user's preference

### Filtering Logic
```
Recipe Sources (Spoonacular, TheMealDB, Filipino, Admin)
    ↓
RecipeService.fetchRecipes() - Initial API filtering
    ↓
DietaryFilterService.filterRecipesByDiet() - Comprehensive filtering
    ↓
Additional filters (cooking time, allergens, etc.)
    ↓
Display to user
```

### Benefits
1. **No Conflicts**: Single-select prevents impossible combinations
2. **Consistent**: Same filtering logic across all pages
3. **Comprehensive**: Checks title, description, ingredients, and nutrition
4. **Maintainable**: Centralized filtering service
5. **User-Friendly**: Set once in onboarding, applies everywhere

## Testing Recommendations

### Test Cases
1. **Vegetarian**: Should exclude all meat, poultry, fish
2. **Vegan**: Should exclude all animal products
3. **Pescatarian**: Should allow fish but exclude meat/poultry
4. **Keto**: Should exclude high-carb foods
5. **None**: Should show all recipes

### Test Locations
- Home page recipe carousel
- Recipe search page
- Meal suggestions page
- Meal planner suggestions

## Allergen Detection Improvements (Latest)

### Enhanced Allergen Detection Service
**Files: `lib/services/allergen_detection_service.dart`, `lib/services/allergen_service.dart`**

#### Key Improvements:
1. **Case-Insensitive Matching**: All allergen detection now uses case-insensitive regex matching
2. **Expanded Keyword Lists**: Added more comprehensive allergen keywords:
   - Tree Nuts: Added pine nuts
   - Milk: Added specific cheese types (mozzarella, cheddar, parmesan, ricotta, cottage cheese, sour cream, heavy cream)
   - Eggs: Added prepared forms (scrambled, fried egg, boiled egg)
   - Fish: Added worcestershire sauce, mackerel, trout, bass
   - Shellfish: Added crawfish, crayfish
   - Wheat: Renamed from 'wheat_gluten' to 'wheat', added specific forms (all-purpose flour, wheat flour, whole wheat, breadcrumbs, croutons, pizza dough, pie crust)
   - Soy: Added soy milk, soy protein
   - Sesame: Added sesame seed oil

3. **Better Allergen Key Normalization**: 
   - New `_normalizeAllergenKey()` method handles variations
   - Maps "Tree Nuts" → "tree_nuts"
   - Maps "Wheat/Gluten" → "wheat"
   - Handles spaces and case variations

4. **Improved False Positive Detection**:
   - Enhanced `_isFalsePositive()` method in both services
   - Detects "eggplant" vs "egg"
   - Detects "nutmeg", "coconut", "butternut", "donut" vs "nut"
   - Recognizes safe milk alternatives (coconut milk, almond milk, oat milk, soy milk, rice milk)
   - **NEW**: Handles "cream of mushroom/chicken/celery" soups (ambiguous dairy content)
   - **NEW**: Distinguishes nut butters from dairy butter
   - Checks false positives BEFORE allergen matching to prevent incorrect detections

5. **Two-Pass Ingredient Checking**:
   - First pass: Word boundary regex matching on all text
   - Second pass: Direct substring matching on individual ingredients
   - Ensures allergens are caught even in complex ingredient descriptions

6. **Better Debugging**:
   - Added debug logging to track which ingredients trigger allergen detection
   - Helps identify false positives and improve detection accuracy

#### Updated Substitution Keys:
- Changed 'wheat_gluten' → 'wheat' for consistency
- All substitution lookups now use normalized keys

#### Bug Fixes:
- Fixed "cream of mushroom soup" being incorrectly detected as dairy
- Fixed ingredient count showing "0 ingredients found" when allergens are present
- Improved consistency between AllergenDetectionService and AllergenService

## Future Enhancements
1. Add ability to change dietary preference in account settings
2. Add temporary "override" option for special occasions
3. Add dietary preference badges on recipe cards
4. Add statistics showing how many recipes match preference
5. Add "why was this filtered?" explanation feature
6. Add allergen severity levels (mild, moderate, severe)
7. Add user-customizable allergen keywords
