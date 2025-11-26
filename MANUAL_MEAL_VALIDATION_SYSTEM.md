# Manual Meal Validation System - Implementation Plan

## Overview
A comprehensive system where manually added meals by users are sent to nutritionists for validation before being added to meal plans. The system considers user's personal information, macro targets, health conditions, and dietary preferences.

## System Architecture

### 1. Data Structure

#### Firestore Collections

**`meal_validation_queue` (Collection)**
```dart
{
  "id": "auto-generated",
  "userId": "user_uid",
  "userName": "John Doe",
  "userEmail": "john@example.com",
  
  // Meal Details
  "mealData": {
    "name": "Grilled Chicken Salad",
    "mealType": "lunch", // breakfast, lunch, dinner, snack
    "ingredients": [
      {"name": "Chicken breast", "amount": "150g"},
      {"name": "Lettuce", "amount": "100g"},
      // ...
    ],
    "nutrition": {
      "calories": 350,
      "protein": 45,
      "carbs": 20,
      "fat": 12,
      "fiber": 5
    },
    "servingSize": "1 plate",
    "notes": "User's custom notes"
  },
  
  // User Context (for nutritionist review)
  "userProfile": {
    "age": 28,
    "gender": "Male",
    "height": 175,
    "weight": 75,
    "goal": "Lose weight",
    "activityLevel": "Moderately active",
    "healthConditions": ["None"],
    "allergies": ["Peanuts"],
    "dietaryPreferences": ["Low Carb"],
    
    // Calculated targets
    "macroTargets": {
      "calories": 2000,
      "protein": 150,
      "carbs": 150,
      "fat": 67
    },
    "bmi": 24.5,
    "bmr": 1750
  },
  
  // Validation Status
  "status": "pending", // pending, approved, rejected, revision_requested
  "submittedAt": Timestamp,
  "reviewedAt": Timestamp (nullable),
  "reviewedBy": "nutritionist_uid" (nullable),
  "nutritionistName": "Dr. Smith" (nullable),
  
  // Nutritionist Feedback
  "feedback": {
    "decision": "approved", // approved, rejected, revision_requested
    "comments": "Looks good! Well-balanced meal.",
    "suggestions": [
      "Consider adding more vegetables",
      "Reduce sodium content"
    ],
    "correctedNutrition": { // If nutritionist corrects values
      "calories": 380,
      "protein": 48,
      "carbs": 22,
      "fat": 13,
      "fiber": 6
    },
    "flaggedIssues": [
      "High in sodium for user's hypertension",
      "Exceeds daily fat target"
    ]
  },
  
  // Notification tracking
  "userNotified": false,
  "notificationSentAt": Timestamp (nullable)
}
```

### 2. User Flow

#### A. User Submits Manual Meal

**Location**: Meal Planner / Add Meal Dialog

```dart
// When user adds a manual meal
Future<void> submitMealForValidation({
  required Map<String, dynamic> mealData,
  required String userId,
}) async {
  // 1. Get user profile
  final userDoc = await FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .get();
  
  final userData = userDoc.data()!;
  
  // 2. Calculate macro targets
  final macroTargets = calculateMacroTargets(userData);
  
  // 3. Create validation request
  await FirebaseFirestore.instance
      .collection('meal_validation_queue')
      .add({
    'userId': userId,
    'userName': userData['fullName'],
    'userEmail': userData['email'],
    'mealData': mealData,
    'userProfile': {
      'age': userData['age'],
      'gender': userData['gender'],
      'height': userData['height'],
      'weight': userData['weight'],
      'goal': userData['goal'],
      'activityLevel': userData['activityLevel'],
      'healthConditions': userData['healthConditions'],
      'allergies': userData['allergies'],
      'dietaryPreferences': userData['dietaryPreferences'],
      'macroTargets': macroTargets,
      'bmi': calculateBMI(userData['height'], userData['weight']),
      'bmr': calculateBMR(userData),
    },
    'status': 'pending',
    'submittedAt': FieldValue.serverTimestamp(),
    'userNotified': false,
  });
  
  // 4. Show confirmation to user
  // "Your meal has been submitted for nutritionist review"
}
```

#### B. Nutritionist Reviews Meal

**Location**: New page `lib/admin/pages/meal_validation_page.dart`

### 3. UI Components

#### User Side

**1. Submission Confirmation Dialog**
```
┌─────────────────────────────────────┐
│ ✓ Meal Submitted for Review         │
├─────────────────────────────────────┤
│ Your meal "Grilled Chicken Salad"   │
│ has been sent to a nutritionist     │
│ for validation.                     │
│                                     │
│ You'll be notified once reviewed.   │
│                                     │
│ Estimated review time: 24-48 hours  │
│                                     │
│              [OK]                   │
└─────────────────────────────────────┘
```

**2. Pending Meals Section**
```
┌─────────────────────────────────────┐
│ Pending Validation (2)              │
├─────────────────────────────────────┤
│ ⏳ Grilled Chicken Salad            │
│    Submitted: 2 hours ago           │
│    Status: Under Review             │
│                                     │
│ ⏳ Vegetable Stir Fry               │
│    Submitted: 1 day ago             │
│    Status: Pending                  │
└─────────────────────────────────────┘
```

**3. Validation Result Notification**
```
┌─────────────────────────────────────┐
│ ✅ Meal Approved!                   │
├─────────────────────────────────────┤
│ "Grilled Chicken Salad" has been    │
│ approved by Dr. Smith               │
│                                     │
│ 💬 Feedback:                        │
│ "Well-balanced meal! Great choice   │
│  for your weight loss goal."        │
│                                     │
│ The meal has been added to your     │
│ meal plan.                          │
│                                     │
│         [View Meal] [Dismiss]       │
└─────────────────────────────────────┘
```

#### Nutritionist Side

**Main Validation Dashboard**
```
┌──────────────────────────────────────────────────────────┐
│ Meal Validation Queue                    [Filter ▼]      │
├──────────────────────────────────────────────────────────┤
│                                                          │
│ ┌────────────────────────────────────────────────────┐  │
│ │ 👤 John Doe (john@example.com)                     │  │
│ │ 🍽️ Grilled Chicken Salad                          │  │
│ │ ⏰ Submitted: 2 hours ago                          │  │
│ │                                                    │  │
│ │ 📊 Nutrition:                                      │  │
│ │ • Calories: 350 (Target: 500)  ✓                  │  │
│ │ • Protein: 45g (Target: 37g)   ⚠️ Slightly high   │  │
│ │ • Carbs: 20g (Target: 37g)     ✓                  │  │
│ │ • Fat: 12g (Target: 17g)       ✓                  │  │
│ │                                                    │  │
│ │ 👤 User Profile:                                   │  │
│ │ • Goal: Lose weight                               │  │
│ │ • Health: Hypertension                            │  │
│ │ • Allergies: Peanuts                              │  │
│ │ • Diet: Low Carb                                  │  │
│ │                                                    │  │
│ │ ⚠️ AI Analysis:                                    │  │
│ │ • High sodium (caution for hypertension)          │  │
│ │ • Good protein content for weight loss            │  │
│ │                                                    │  │
│ │        [Review] [Quick Approve] [Reject]          │  │
│ └────────────────────────────────────────────────────┘  │
│                                                          │
└──────────────────────────────────────────────────────────┘
```

**Detailed Review Dialog**
```
┌──────────────────────────────────────────────────────────┐
│ Review Meal: Grilled Chicken Salad                       │
├──────────────────────────────────────────────────────────┤
│                                                          │
│ [User Info] [Meal Details] [Nutrition] [Analysis]       │
│                                                          │
│ ┌─ Nutrition Values ─────────────────────────────────┐  │
│ │                                                    │  │
│ │ Calories:  [350] kcal  (Target: 500)  ✓          │  │
│ │ Protein:   [45]  g     (Target: 37)   ⚠️          │  │
│ │ Carbs:     [20]  g     (Target: 37)   ✓          │  │
│ │ Fat:       [12]  g     (Target: 17)   ✓          │  │
│ │ Fiber:     [5]   g                                │  │
│ │                                                    │  │
│ │ ☑ Correct nutrition values                        │  │
│ │ ☐ Use corrected values (edit above)               │  │
│ └────────────────────────────────────────────────────┘  │
│                                                          │
│ ┌─ Health Considerations ────────────────────────────┐  │
│ │ ⚠️ User has Hypertension                          │  │
│ │ ⚠️ Meal may be high in sodium                     │  │
│ │ ✓ Aligns with Low Carb preference                 │  │
│ │ ✓ No allergen conflicts                           │  │
│ └────────────────────────────────────────────────────┘  │
│                                                          │
│ Decision:                                                │
│ ○ Approve  ○ Request Revision  ○ Reject                 │
│                                                          │
│ Comments to User:                                        │
│ ┌────────────────────────────────────────────────────┐  │
│ │ Great meal choice! Well-balanced for your goal.    │  │
│ │ Consider reducing salt for your blood pressure.    │  │
│ └────────────────────────────────────────────────────┘  │
│                                                          │
│ Suggestions (optional):                                  │
│ • [Add suggestion]                                       │
│                                                          │
│              [Cancel]  [Submit Review]                   │
└──────────────────────────────────────────────────────────┘
```

### 4. Implementation Steps

#### Phase 1: Backend Setup (Week 1)

1. **Create Firestore Security Rules**
```javascript
// firestore.rules
match /meal_validation_queue/{mealId} {
  // Users can create and read their own submissions
  allow create: if request.auth != null && 
                   request.resource.data.userId == request.auth.uid;
  allow read: if request.auth != null && 
                 (resource.data.userId == request.auth.uid ||
                  get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'Nutritionist');
  
  // Only nutritionists can update
  allow update: if request.auth != null && 
                   get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'Nutritionist';
}
```

2. **Create Validation Service**
```dart
// lib/services/meal_validation_service.dart
class MealValidationService {
  static Future<String> submitMealForValidation(...) async {}
  static Future<List<Map<String, dynamic>>> getPendingValidations() async {}
  static Future<void> approveMeal(...) async {}
  static Future<void> rejectMeal(...) async {}
  static Future<void> requestRevision(...) async {}
  static Map<String, double> calculateMacroTargets(userData) {}
}
```

#### Phase 2: User Interface (Week 2)

1. **Modify Meal Addition Flow**
   - Add "Submit for Validation" option
   - Show pending meals section
   - Display validation status

2. **Create Notification System**
   - In-app notifications
   - Push notifications (optional)
   - Email notifications (optional)

#### Phase 3: Nutritionist Dashboard (Week 3)

1. **Create Meal Validation Page**
   - Queue view with filters
   - Detailed review dialog
   - Batch actions

2. **Add AI-Assisted Analysis**
   - Automatic health flag detection
   - Macro target comparison
   - Allergen checking

#### Phase 4: Testing & Refinement (Week 4)

1. **Test all flows**
2. **Add analytics**
3. **Performance optimization**
4. **Documentation**

### 5. Key Features

#### Auto-Analysis System
```dart
class MealAnalyzer {
  static List<String> analyzeMeal(
    Map<String, dynamic> mealData,
    Map<String, dynamic> userProfile,
  ) {
    final issues = <String>[];
    
    // Check macro targets
    final nutrition = mealData['nutrition'];
    final targets = userProfile['macroTargets'];
    
    if (nutrition['calories'] > targets['calories'] * 1.2) {
      issues.add('⚠️ Calories significantly exceed target');
    }
    
    // Check health conditions
    if (userProfile['healthConditions'].contains('Diabetes')) {
      if (nutrition['carbs'] > 45) {
        issues.add('⚠️ High carbs - caution for diabetes');
      }
    }
    
    if (userProfile['healthConditions'].contains('Hypertension')) {
      // Estimate sodium (would need ingredient analysis)
      issues.add('⚠️ Check sodium content for hypertension');
    }
    
    // Check allergens
    for (final ingredient in mealData['ingredients']) {
      if (userProfile['allergies'].contains(ingredient['name'])) {
        issues.add('🚨 ALLERGEN ALERT: ${ingredient['name']}');
      }
    }
    
    // Check dietary preferences
    if (userProfile['dietaryPreferences'].contains('Vegetarian')) {
      // Check for meat ingredients
    }
    
    return issues;
  }
}
```

### 6. Notification Templates

**Approval Notification**
```
Title: ✅ Meal Approved!
Body: Your meal "[Meal Name]" has been approved by [Nutritionist Name] and added to your meal plan.
```

**Rejection Notification**
```
Title: ❌ Meal Not Approved
Body: Your meal "[Meal Name]" was not approved. Reason: [Comments]
```

**Revision Request**
```
Title: 📝 Revision Requested
Body: [Nutritionist Name] has requested changes to "[Meal Name]". View suggestions.
```

### 7. Database Indexes

```
Collection: meal_validation_queue
Indexes:
- status (ASC), submittedAt (DESC)
- userId (ASC), status (ASC)
- reviewedBy (ASC), reviewedAt (DESC)
```

### 8. Analytics to Track

- Average review time
- Approval rate
- Most common rejection reasons
- Nutritionist workload
- User satisfaction

### 9. Future Enhancements

- [ ] Bulk approval for similar meals
- [ ] Meal templates from approved meals
- [ ] Nutritionist chat with users
- [ ] AI-powered auto-approval for simple meals
- [ ] Meal history and patterns
- [ ] Nutritionist performance metrics
- [ ] User rating system for nutritionists

---

## Quick Start Implementation

**Minimal Viable Product (MVP) - 1 Week**

1. Create `meal_validation_queue` collection
2. Add submit button in meal planner
3. Create basic nutritionist review page
4. Implement approve/reject functionality
5. Add simple notifications

This gets the core functionality working, then iterate with enhancements.

---

**Status**: 📋 Implementation Plan Ready
**Estimated Time**: 4 weeks for full implementation, 1 week for MVP
**Priority**: High - Critical for nutritional accuracy
