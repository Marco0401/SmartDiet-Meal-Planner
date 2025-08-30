# AI Meal Planner - SmartDiet App

## Overview

The AI Meal Planner is an intelligent system that analyzes user profiles and generates personalized meal plans based on their goals, preferences, and health information. It uses scientific nutritional calculations and smart recipe selection to create optimal meal recommendations.

## Features

### 🧠 Smart Analysis
- **BMR Calculation**: Uses the Mifflin-St Jeor Equation to calculate Basal Metabolic Rate
- **Activity Level Adjustment**: Applies appropriate multipliers based on exercise frequency
- **Goal-Based Optimization**: Adjusts calorie targets and macronutrient ratios based on user goals
- **Health Condition Awareness**: Considers medical conditions and dietary restrictions

### 🎯 Goal-Based Planning
- **Weight Loss**: Reduced calories, high protein, fiber-rich foods
- **Muscle Building**: Increased calories, high protein, complex carbohydrates
- **Weight Maintenance**: Balanced approach with moderate calorie intake
- **Healthy Eating**: Focus on whole foods and nutrient density

### 🍽️ Personalized Meal Generation
- **Dietary Restrictions**: Respects vegetarian, vegan, gluten-free, and other preferences
- **Allergy Awareness**: Filters out recipes containing user allergens
- **Meal Type Optimization**: Suggests appropriate foods for breakfast, lunch, dinner, and snacks
- **Portion Sizing**: Calculates optimal portions to meet calorie targets

### 📊 Comprehensive Analysis
- **Nutritional Breakdown**: Detailed macronutrient and micronutrient information
- **Health Insights**: BMI calculation and weight category classification
- **Personalized Recommendations**: Actionable advice based on user profile
- **Progress Tracking**: Daily and weekly nutritional summaries

## How It Works

### 1. User Profile Analysis
The system analyzes the following user data:
- Age, height, weight, and gender
- Activity level and exercise frequency
- Health conditions and medications
- Allergies and dietary restrictions
- Fitness goals and preferences

### 2. Calorie Calculation
```
BMR = (10 × weight) + (6.25 × height) - (5 × age) + 5 (male)
BMR = (10 × weight) + (6.25 × height) - (5 × age) - 161 (female)

Daily Calories = BMR × Activity Multiplier × Goal Multiplier
```

### 3. Macronutrient Distribution
- **Protein**: 25-35% of daily calories (4 calories per gram)
- **Carbohydrates**: 40-50% of daily calories (4 calories per gram)
- **Fat**: 20-30% of daily calories (9 calories per gram)
- **Fiber**: Gender-specific recommendations (25g for women, 38g for men)

### 4. Recipe Selection
- Searches recipe database using intelligent query building
- Filters recipes based on user preferences and restrictions
- Scores recipes using nutritional alignment and calorie proximity
- Calculates optimal portion sizes to meet daily targets

### 5. Meal Plan Generation
- Creates daily meal schedules with 3-4 meals
- Distributes calories appropriately across meals
- Provides nutritional summaries and recommendations
- Includes fallback meal suggestions when recipes aren't available

## Technical Implementation

### Core Services

#### `AIMealPlannerService`
- Main service class handling meal plan generation
- Profile analysis and nutritional calculations
- Recipe filtering and scoring algorithms
- Fallback meal generation

#### `AIMealPlannerPage`
- Main UI for the meal planner
- Tabbed interface (Meal Plan, Analysis, Recommendations)
- Interactive controls for plan customization
- Real-time meal plan generation

#### `AIMealPlannerDemoPage`
- Demo interface for users without profiles
- Feature explanations and sample data
- Call-to-action for profile setup

### Data Flow

1. **User Authentication**: Firebase Auth integration
2. **Profile Retrieval**: Firestore user data collection
3. **Recipe Fetching**: Integration with RecipeService
4. **Allergen Checking**: Integration with AllergenService
5. **Plan Generation**: AI algorithms and nutritional calculations
6. **UI Rendering**: Flutter widgets with Material Design

### Key Algorithms

#### Recipe Scoring System
```dart
double score = 0;

// Calorie proximity scoring
final calorieDiff = (recipeCalories - targetCalories).abs();
score += 100 - (calorieDiff / targetCalories * 100);

// Goal-based scoring
if (goal == 'Build muscle' || goal == 'Lose weight') {
  score += protein * 2;
}

if (goal == 'Lose weight' || goal == 'Eat healthier') {
  score += fiber * 3;
}
```

#### Portion Size Calculation
```dart
double portionSize = targetCalories / recipeCalories;
```

## Usage Instructions

### For Users

1. **Setup Profile**: Complete your account settings with health information
2. **Access Planner**: Navigate to "AI Meal Planner" from the main menu
3. **Customize Plan**: Choose plan duration and specific goals
4. **Generate Plan**: Click "Generate New Plan" to create personalized meals
5. **View Details**: Explore meal plans, nutritional analysis, and recommendations
6. **Recipe Details**: Tap on meals to view full recipe information

### For Developers

1. **Service Integration**: Import `AIMealPlannerService` into your pages
2. **API Usage**: Call `generatePersonalizedMealPlan()` with optional parameters
3. **Customization**: Modify goal strategies and nutritional algorithms
4. **UI Extension**: Add new tabs or modify existing interface components

## Configuration Options

### Plan Duration
- 3 days (quick start)
- 5 days (weekday planning)
- 7 days (full week)
- 14 days (bi-weekly planning)

### Goal Overrides
- Auto-detect from user profile
- Manual goal selection
- Custom nutritional targets

### Meal Frequency
- 3 meals per day (standard)
- 4 meals per day (with snacks)
- Adjustable based on user preferences

## Health Considerations

### Medical Conditions
- **Diabetes**: Low-GI foods, controlled carbohydrates
- **Hypertension**: Low-sodium, potassium-rich foods
- **High Cholesterol**: Heart-healthy fats, soluble fiber
- **Obesity**: Low-calorie, high-protein, fiber-rich foods

### Dietary Restrictions
- **Vegetarian/Vegan**: Plant-based protein sources
- **Gluten-Free**: Alternative grains and flours
- **Low-Carb/Keto**: High-fat, moderate-protein options
- **Halal**: Religious dietary compliance

## Future Enhancements

### Machine Learning Integration
- Recipe preference learning
- Nutritional pattern recognition
- Personalized taste profiles
- Seasonal ingredient optimization

### Advanced Analytics
- Progress tracking over time
- Nutritional goal achievement
- Meal satisfaction ratings
- Social sharing and recommendations

### Integration Features
- Grocery list generation
- Meal prep scheduling
- Restaurant recommendations
- Fitness app synchronization

## Dependencies

- **Firebase**: Authentication and data storage
- **Flutter**: UI framework and cross-platform development
- **Recipe Service**: External recipe API integration
- **Allergen Service**: Food allergy detection and management

## Performance Considerations

- **Caching**: Recipe data caching for faster generation
- **Async Operations**: Non-blocking UI during plan generation
- **Error Handling**: Graceful fallbacks for API failures
- **Memory Management**: Efficient data structures for large meal plans

## Security & Privacy

- **User Data**: All profile information is stored securely in Firebase
- **Authentication**: Firebase Auth ensures secure user access
- **Data Privacy**: User information is not shared with third parties
- **API Keys**: Secure storage of external service credentials

## Support & Troubleshooting

### Common Issues

1. **No Meal Plan Generated**: Check user profile completion
2. **Recipe Loading Errors**: Verify internet connection and API status
3. **Calorie Mismatches**: Ensure accurate weight and height data
4. **Allergen Warnings**: Review and update allergy information

### Debug Information

- Enable debug mode for detailed logging
- Check Firebase console for data issues
- Verify recipe service connectivity
- Review user profile completeness

## Contributing

1. Fork the repository
2. Create a feature branch
3. Implement your changes
4. Add comprehensive tests
5. Submit a pull request

## License

This project is part of the SmartDiet application and follows the same licensing terms.

---

**Note**: The AI Meal Planner is designed to provide general nutritional guidance and should not replace professional medical advice. Users with specific health conditions should consult healthcare providers before making significant dietary changes. 