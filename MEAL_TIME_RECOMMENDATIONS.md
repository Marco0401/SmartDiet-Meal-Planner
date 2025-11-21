# Meal Time Recommendations System

## Overview
The Meal Time Recommendations system provides intelligent recipe suggestions based on the current time of day, ensuring users see meals appropriate for breakfast, lunch, dinner, or snacks.

## Features

### 1. Automatic Time Detection
The system automatically detects the current time and determines the appropriate meal period:

| Time Range | Meal Period | Icon |
|------------|-------------|------|
| 6:00 AM - 11:00 AM | Breakfast | 🌅 |
| 11:00 AM - 2:00 PM | Lunch | 🌞 |
| 2:00 PM - 5:00 PM | Snack | 🍎 |
| 5:00 PM - 10:00 PM | Dinner | 🌙 |
| 10:00 PM - 6:00 AM | Late Night | 🌃 |

### 2. Recipe Suitability Scoring
Each recipe is scored (0.0 to 1.0) based on its suitability for each meal period:

**Scoring Factors:**
- **Dish Types**: Matches against meal-specific dish types
- **Keywords**: Checks title/description for meal-appropriate keywords
- **Preparation Time**: Considers typical time constraints for each meal
- **Meal Characteristics**: Evaluates if recipe fits meal expectations

**Example Scores:**
```
Pancakes:
  🌅 Breakfast: 95%
  🌞 Lunch: 30%
  🍎 Snack: 20%
  🌙 Dinner: 15%

Steak Dinner:
  🌅 Breakfast: 10%
  🌞 Lunch: 60%
  🍎 Snack: 5%
  🌙 Dinner: 90%
```

### 3. Meal Period Characteristics

#### Breakfast (6 AM - 11 AM)
**Suitable Dishes:**
- Pancakes, waffles, french toast
- Eggs (scrambled, fried, boiled, omelet)
- Cereal, oatmeal, porridge
- Smoothies, smoothie bowls
- Bagels, muffins, croissants
- Yogurt, granola

**Characteristics:**
- Quick preparation (< 30 minutes preferred)
- Light to moderate portions
- Energy-boosting ingredients

**Keywords:** breakfast, morning, brunch, eggs, pancake, waffle, smoothie, yogurt

#### Lunch (11 AM - 2 PM)
**Suitable Dishes:**
- Sandwiches, wraps, burgers
- Salads, soups
- Grain bowls, rice bowls
- Pasta salads
- Light meals

**Characteristics:**
- Moderate preparation time (< 45 minutes)
- Balanced nutrition
- Portable options

**Keywords:** lunch, sandwich, wrap, salad, soup, bowl

#### Snack (2 PM - 5 PM)
**Suitable Dishes:**
- Appetizers, finger foods
- Chips, crackers, dips
- Fruit, vegetables
- Energy bars, trail mix
- Light bites

**Characteristics:**
- Very quick (< 15 minutes preferred)
- Small portions
- Easy to eat

**Keywords:** snack, appetizer, finger food, dip, chips, fruit

#### Dinner (5 PM - 10 PM)
**Suitable Dishes:**
- Main courses, entrees
- Roasts, casseroles, stews
- Pasta, rice dishes, noodles
- Grilled, baked, braised dishes
- Hearty meals

**Characteristics:**
- Can take longer (up to 90 minutes)
- Larger portions
- More complex preparations

**Keywords:** dinner, main course, roast, stew, casserole, pasta, grilled

#### Late Night (10 PM - 6 AM)
**Suitable Dishes:**
- Light meals
- Quick snacks
- Simple preparations
- Comfort foods

**Characteristics:**
- Very quick (< 20 minutes)
- Light and easy to digest
- Minimal preparation

**Keywords:** light, simple, quick, easy

## Implementation

### MealTimeService API

#### Get Current Meal Period
```dart
final period = MealTimeService.getCurrentMealPeriod();
// Returns: 'breakfast', 'lunch', 'snack', 'dinner', or 'late_night'
```

#### Get Recipe Suitability
```dart
final score = MealTimeService.getRecipeSuitability(recipe, 'breakfast');
// Returns: 0.0 to 1.0 (0% to 100% suitable)
```

#### Filter Recipes by Meal Period
```dart
final breakfastRecipes = MealTimeService.filterRecipesByMealPeriod(
  allRecipes,
  'breakfast',
  minSuitability: 0.3, // Only show recipes with 30%+ suitability
);
// Returns: Recipes sorted by suitability (highest first)
```

#### Get Recommended Meal Period
```dart
final bestPeriod = MealTimeService.getRecommendedMealPeriod(recipe);
// Returns: The meal period with highest suitability score
```

#### Get All Suitability Scores
```dart
final scores = MealTimeService.getAllMealPeriodSuitability(recipe);
// Returns: {'breakfast': 0.9, 'lunch': 0.3, 'snack': 0.2, ...}
```

### Integration in Meal Suggestions Page

The system is integrated into the Meal Suggestions page with:

1. **Automatic Detection**: Shows current meal period at the top
2. **Toggle Switch**: Users can enable/disable time-based filtering
3. **Visual Indicator**: Displays meal period icon, name, and time range
4. **Smart Filtering**: Automatically filters recipes by current time

**UI Elements:**
```
🌅 Breakfast (6:00 AM - 11:00 AM) [Toggle Switch]
```

## User Experience

### Morning (6 AM - 11 AM)
```
User opens app at 8:00 AM
System shows: 🌅 Breakfast (6:00 AM - 11:00 AM)
Suggestions: Pancakes, Eggs, Smoothies, Oatmeal
Hidden: Steak Dinner, Heavy Pasta, Complex Meals
```

### Afternoon (2 PM - 5 PM)
```
User opens app at 3:30 PM
System shows: 🍎 Snack (2:00 PM - 5:00 PM)
Suggestions: Fruit Salad, Chips & Dip, Energy Bars
Hidden: Full Meals, Heavy Dishes
```

### Evening (5 PM - 10 PM)
```
User opens app at 7:00 PM
System shows: 🌙 Dinner (5:00 PM - 10:00 PM)
Suggestions: Grilled Chicken, Pasta, Stir Fry, Casserole
Hidden: Breakfast Items, Light Snacks
```

## Benefits

### For Users
- ✅ See relevant meal suggestions for current time
- ✅ No need to scroll through breakfast recipes at dinner time
- ✅ Discover appropriate meals automatically
- ✅ Can toggle filter on/off for flexibility

### For the System
- ✅ Better user engagement
- ✅ More relevant recommendations
- ✅ Improved user satisfaction
- ✅ Reduced decision fatigue

## Configuration

### Minimum Suitability Threshold
Default: 0.3 (30%)

Adjust in code:
```dart
MealTimeService.filterRecipesByMealPeriod(
  recipes,
  period,
  minSuitability: 0.5, // Stricter filtering (50%+)
);
```

### Time Ranges
Modify in `MealTimeService.getMealPeriodForTime()`:
```dart
if (hour >= 6 && hour < 11) {
  return breakfast; // Adjust these ranges
}
```

## Testing

### Test Cases

1. **Morning Filtering**
   - Time: 8:00 AM
   - Expected: Breakfast recipes shown
   - Expected: Dinner recipes hidden

2. **Afternoon Filtering**
   - Time: 3:00 PM
   - Expected: Snack recipes shown
   - Expected: Heavy meals hidden

3. **Evening Filtering**
   - Time: 7:00 PM
   - Expected: Dinner recipes shown
   - Expected: Breakfast recipes hidden

4. **Toggle Functionality**
   - Action: Disable time filter
   - Expected: All recipes shown regardless of time

5. **Suitability Scoring**
   - Recipe: "Pancakes"
   - Expected: High breakfast score (>80%)
   - Expected: Low dinner score (<30%)

## Debug Features

### Print Suitability Analysis
```dart
MealTimeService.printRecipeSuitabilityAnalysis(recipe);
```

Output:
```
=== Recipe Suitability Analysis ===
Recipe: Fluffy Pancakes
Ready in: 20 minutes

Suitability Scores:
  🌅 Breakfast: 95%
  🌞 Lunch: 30%
  🍎 Snack: 25%
  🌙 Dinner: 15%
  🌃 Late Night: 20%

Recommended: Breakfast
===================================
```

## Future Enhancements

1. **User Preferences**
   - Allow users to customize time ranges
   - Personal meal time preferences
   - Cultural meal pattern support

2. **Machine Learning**
   - Learn from user's meal choices
   - Improve suitability scoring
   - Personalized recommendations

3. **Advanced Filtering**
   - Combine with dietary preferences
   - Consider user's schedule
   - Meal prep time availability

4. **Notifications**
   - Suggest meals at appropriate times
   - Remind users to plan meals
   - Weekly meal planning

5. **Analytics**
   - Track meal time patterns
   - Popular meals by time
   - User engagement metrics

## Performance

- **Fast**: O(n) complexity for filtering
- **Efficient**: Scoring algorithm optimized
- **Lightweight**: No external API calls
- **Responsive**: Instant filtering

## Accessibility

- Clear visual indicators
- Toggle for user control
- Works with all recipes
- No required user input

## Summary

The Meal Time Recommendations system provides intelligent, time-aware recipe suggestions that enhance user experience by showing relevant meals for the current time of day. Users can easily toggle the feature on/off, and the system automatically adapts to show breakfast in the morning, lunch at midday, and dinner in the evening.

**Key Features:**
- ✅ Automatic time detection
- ✅ Smart recipe filtering
- ✅ Suitability scoring
- ✅ User-controllable toggle
- ✅ Visual meal period indicator
- ✅ Comprehensive meal databases

**Result:** Users see the right meals at the right time! 🎯
