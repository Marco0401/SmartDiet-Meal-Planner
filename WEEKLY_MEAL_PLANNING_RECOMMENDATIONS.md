# Weekly/Monthly Meal Planning - Implementation Recommendations

## Problem Statement
Daily manual input is inconvenient; users need weekly or monthly meal plan options to reduce repetitive planning effort.

## Solution Overview
Implement a comprehensive meal planning system that allows users to:
1. Generate automatic weekly/monthly meal plans
2. Manually customize and adjust plans
3. Save and reuse favorite meal plans
4. Get smart suggestions based on preferences and health goals

---

## Implementation Approach

### Phase 1: Data Models & Storage

#### 1.1 Meal Plan Model
```dart
class MealPlan {
  final String id;
  final String userId;
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final PlanType type; // weekly, biweekly, monthly
  final List<PlannedMeal> meals;
  final bool isTemplate;
  final DateTime createdAt;
  final DateTime? lastModified;
  
  // Metadata
  final Map<String, dynamic> nutritionSummary;
  final double estimatedCost;
  final List<String> shoppingList;
}

class PlannedMeal {
  final String id;
  final DateTime dateTime;
  final MealType mealType; // breakfast, lunch, dinner, snack
  final String recipeId;
  final String recipeName;
  final int servings;
  final bool isCooked;
  final String? notes;
  final String? substitutions;
}

enum PlanType { weekly, biweekly, monthly, custom }
enum MealType { breakfast, lunch, dinner, snack }
```

#### 1.2 Firebase Structure
```
users/{userId}/
  ├── mealPlans/
  │   ├── {planId}/
  │   │   ├── metadata: { name, startDate, endDate, type, isTemplate }
  │   │   ├── meals/
  │   │   │   ├── {mealId}: { dateTime, mealType, recipeId, servings, ... }
  │   │   ├── nutritionSummary: { totalCalories, avgProtein, ... }
  │   │   └── shoppingList: [...]
  │   
  ├── mealPlanTemplates/
  │   ├── {templateId}/
  │   │   ├── name: "Low Carb Week"
  │   │   ├── meals: [...]
  │   │   └── tags: ["low-carb", "high-protein"]
```

---

### Phase 2: Core Services

#### 2.1 Meal Plan Service
Create `lib/services/meal_plan_service.dart`:

**Key Functions:**
- `generateWeeklyPlan()` - Auto-generate 7-day plan
- `generateMonthlyPlan()` - Auto-generate 30-day plan
- `saveMealPlan()` - Save plan to Firebase
- `getMealPlans()` - Fetch user's plans
- `updatePlannedMeal()` - Modify specific meal
- `duplicatePlan()` - Copy existing plan
- `saveAsTemplate()` - Save plan as reusable template
- `applyTemplate()` - Apply template to new dates

**Smart Generation Logic:**
```dart
Future<MealPlan> generateWeeklyPlan({
  required DateTime startDate,
  required UserProfile userProfile,
  Map<String, dynamic>? preferences,
}) async {
  // 1. Get user's dietary restrictions & allergens
  // 2. Fetch suitable recipes from database
  // 3. Apply variety rules (no same recipe twice in 3 days)
  // 4. Balance nutrition across the week
  // 5. Consider meal time preferences (breakfast vs dinner foods)
  // 6. Optimize for ingredient reuse (reduce shopping list)
  // 7. Return complete meal plan
}
```

#### 2.2 Recipe Recommendation Engine
Enhance existing recommendation with planning context:

```dart
class PlanningRecommendationService {
  // Suggest recipes that share ingredients
  List<Recipe> getComplementaryRecipes(List<Recipe> existingMeals);
  
  // Ensure nutritional balance across week
  List<Recipe> balanceNutrition(List<Recipe> currentPlan, NutritionGoals goals);
  
  // Avoid recipe repetition
  List<Recipe> filterRecentlyUsed(List<Recipe> candidates, List<String> recentRecipeIds);
  
  // Optimize for batch cooking
  List<Recipe> suggestBatchCookingRecipes(int servingsNeeded);
}
```

---

### Phase 3: User Interface

#### 3.1 Meal Plan Calendar View
Create `lib/pages/meal_plan_calendar_page.dart`:

**Features:**
- Calendar grid showing 7 or 30 days
- Each day shows breakfast, lunch, dinner slots
- Tap to view recipe details
- Long-press to edit/replace meal
- Swipe to navigate weeks/months
- Color coding by meal type or nutrition status

**UI Layout:**
```
┌─────────────────────────────────────┐
│  Week of Dec 1-7, 2024        [⚙️]  │
├─────────────────────────────────────┤
│  Mon  │  Tue  │  Wed  │  Thu  │ ... │
├───────┼───────┼───────┼───────┼─────┤
│  🌅   │  🌅   │  🌅   │  🌅   │     │
│ Oatmeal│Smoothie│Eggs  │Pancakes│   │
├───────┼───────┼───────┼───────┼─────┤
│  🌞   │  🌞   │  🌞   │  🌞   │     │
│ Salad │Sandwich│Pasta │Burrito│     │
├───────┼───────┼───────┼───────┼─────┤
│  🌙   │  🌙   │  🌙   │  🌙   │     │
│ Chicken│Salmon │Stir-fry│Tacos│     │
└───────┴───────┴───────┴───────┴─────┘
  [Generate New Plan] [Save Template]
```

#### 3.2 Plan Generation Wizard
Create `lib/widgets/meal_plan_wizard.dart`:

**Steps:**
1. **Duration Selection**
   - Weekly (7 days)
   - Bi-weekly (14 days)
   - Monthly (30 days)
   - Custom range

2. **Meal Preferences**
   - Which meals to plan? (breakfast/lunch/dinner/snacks)
   - Servings per meal
   - Cooking frequency (daily vs batch cooking)

3. **Dietary Focus** (optional)
   - Weight loss / maintenance / gain
   - High protein / low carb / balanced
   - Budget-friendly / gourmet
   - Quick meals (<30 min) / elaborate

4. **Review & Customize**
   - Show generated plan
   - Swap individual meals
   - Adjust servings
   - Add notes

5. **Save & Activate**
   - Name the plan
   - Save as template option
   - Set reminders

#### 3.3 Quick Actions
Add to existing pages:

**Home Page:**
- "View This Week's Plan" card
- "Today's Meals" section with checkboxes
- Quick access to shopping list

**Recipe Search:**
- "Add to Meal Plan" button on each recipe
- Date/meal type selector

**Meal Suggestions:**
- "Plan Entire Week" button
- "Fill Empty Days" option

---

### Phase 4: Smart Features

#### 4.1 Ingredient Optimization
```dart
class IngredientOptimizer {
  // Group recipes that share ingredients
  List<Recipe> optimizeForSharedIngredients(List<Recipe> recipes);
  
  // Suggest using leftovers
  List<Recipe> suggestLeftoverRecipes(List<String> availableIngredients);
  
  // Generate consolidated shopping list
  ShoppingList generateShoppingList(MealPlan plan);
}
```

#### 4.2 Nutrition Balancing
```dart
class NutritionBalancer {
  // Ensure weekly nutrition goals are met
  bool validateWeeklyNutrition(MealPlan plan, NutritionGoals goals);
  
  // Suggest swaps to improve balance
  List<RecipeSwap> suggestNutritionImprovements(MealPlan plan);
  
  // Calculate weekly nutrition summary
  NutritionSummary calculateWeeklySummary(MealPlan plan);
}
```

#### 4.3 Variety Engine
```dart
class VarietyEngine {
  // Ensure diverse cuisines
  bool hasGoodCuisineVariety(List<Recipe> recipes);
  
  // Avoid protein repetition
  bool hasProteinVariety(List<Recipe> recipes);
  
  // Mix cooking methods
  bool hasCookingMethodVariety(List<Recipe> recipes);
}
```

---

### Phase 5: Templates & Presets

#### 5.1 Built-in Templates
Provide starter templates:
- "Balanced Week" - Standard healthy meals
- "Quick & Easy" - All recipes under 30 minutes
- "Meal Prep Sunday" - Batch cooking focused
- "Budget-Friendly" - Cost-effective meals
- "High Protein" - Fitness focused
- "Family Favorites" - Kid-friendly meals
- "Mediterranean Week" - Mediterranean diet
- "Vegetarian Week" - Plant-based meals

#### 5.2 User Templates
Allow users to save their own:
- Save current plan as template
- Name and tag templates
- Share templates with family
- Browse community templates (optional)

---

### Phase 6: Integration Points

#### 6.1 Shopping List Integration
- Auto-generate from meal plan
- Group by store section
- Check off purchased items
- Sync across family members
- Export to notes/email

#### 6.2 Notification System
- Weekly plan reminder (Sunday evening)
- Daily meal prep reminders
- Ingredient expiration alerts
- "Did you cook this?" check-ins

#### 6.3 Progress Tracking
- Mark meals as cooked
- Rate meals after cooking
- Track adherence to plan
- Adjust future plans based on feedback

---

## Implementation Priority

### Must Have (MVP)
1. ✅ Basic meal plan data model
2. ✅ Weekly plan generation
3. ✅ Calendar view UI
4. ✅ Manual meal editing
5. ✅ Save/load plans from Firebase

### Should Have (Phase 2)
6. ⏳ Monthly plan generation
7. ⏳ Template system
8. ⏳ Shopping list generation
9. ⏳ Nutrition balancing
10. ⏳ Ingredient optimization

### Nice to Have (Phase 3)
11. ⏳ Community templates
12. ⏳ Family sharing
13. ⏳ Advanced analytics
14. ⏳ Recipe substitution suggestions
15. ⏳ Budget tracking

---

## Technical Considerations

### Performance
- Cache meal plans locally for offline access
- Lazy load recipe details
- Paginate monthly views
- Optimize Firebase queries with indexes

### User Experience
- Allow drag-and-drop meal rearrangement
- Provide undo/redo functionality
- Auto-save changes
- Show loading states during generation

### Data Sync
- Handle conflicts when editing same plan on multiple devices
- Implement optimistic updates
- Queue offline changes

---

## Next Steps

1. **Create the data models** - Start with MealPlan and PlannedMeal classes
2. **Build MealPlanService** - Core business logic for generation and storage
3. **Design Calendar UI** - Create the visual meal plan calendar
4. **Implement generation wizard** - Step-by-step plan creation
5. **Test with real users** - Gather feedback and iterate

Would you like me to start implementing any of these components?