# Manual Meal Validation System - Testing Guide

## 🧪 Complete Testing Workflow

### Prerequisites
1. Deploy Firestore security rules from `MEAL_VALIDATION_FIRESTORE_RULES.md`
2. Create a nutritionist test account with `role: "Nutritionist"` in Firestore
3. Have a regular user account for testing submissions

---

## Test Scenario 1: User Submits Meal to Meal Planner (Auto-Validation)

### Steps:
1. **Login as Regular User**
2. **Navigate to Meal Planner** → Click "+" to add meal
3. **Select "Manual Entry"**
4. **Fill in meal details:**
   - Food Name: "Grilled Chicken Salad"
   - Meal Type: Lunch
   - Calories: 450
   - Protein: 35g
   - Carbs: 25g
   - Fat: 20g
   - Add ingredients and instructions

5. **Notice the Auto-Review Banner:**
   - Should see green info box: "This meal will be automatically sent to a nutritionist for validation..."

6. **Click "Save Meal"**

### Expected Results:
✅ Success message: "Meal sent for nutritionist review!"
✅ Meal NOT immediately visible in meal planner
✅ Document created in `meal_validation_queue` collection with status "pending"

---

## Test Scenario 2: User Saves Recipe to Favorites (Optional Review)

### Steps:
1. **Navigate to "My Recipes"** → Click "+"
2. **Fill in recipe details:**
   - Recipe Name: "Protein Smoothie Bowl"
   - Meal Type: Breakfast
   - Nutrition values
   - Ingredients and instructions

3. **Toggle "Send for Nutritionist Review?"**
   - Test with toggle ON
   - Test with toggle OFF

4. **Click "Save Recipe"**

### Expected Results (Toggle ON):
✅ Success message: "Recipe saved and sent for nutritionist review!"
✅ Recipe saved to favorites
✅ Document created in `meal_validation_queue`

### Expected Results (Toggle OFF):
✅ Success message: "Recipe saved to favorites!"
✅ Recipe saved to favorites
✅ NO document in `meal_validation_queue`

---

## Test Scenario 3: Nutritionist Reviews Pending Meals

### Steps:
1. **Login as Nutritionist Account**
2. **Navigate to Admin → Nutritional Data Validation**
3. **Click "Meal Validation" tab**

### Expected Results:
✅ See list of pending validations
✅ Each card shows:
   - User name and email
   - Meal name and type
   - Submission date
   - User profile summary (age, BMI, allergies, goals)
   - AI analysis warnings (if any)

---

## Test Scenario 4: Quick Approve Meal

### Steps:
1. **As Nutritionist**, find a pending meal
2. **Click "Quick Approve" button**
3. **Confirm approval**

### Expected Results:
✅ Success message: "Meal approved successfully!"
✅ Meal disappears from pending queue
✅ Meal added to user's meal planner (check user's account)
✅ Document status changed to "approved" in Firestore

---

## Test Scenario 5: Reject Meal with Feedback

### Steps:
1. **As Nutritionist**, find a pending meal
2. **Click "Reject" button**
3. **Enter rejection reason:** "Protein content seems too high for your current goal. Consider reducing portion size."
4. **Click "Submit Rejection"**

### Expected Results:
✅ Success message: "Meal rejected with feedback"
✅ Meal disappears from pending queue
✅ Meal NOT added to user's meal planner
✅ Document status changed to "rejected" with feedback

---

## Test Scenario 6: Detailed Review with Nutrition Correction

### Steps:
1. **As Nutritionist**, find a pending meal
2. **Click "Review" button**
3. **Review user profile context:**
   - Check age, BMI, health conditions
   - Review allergies and dietary restrictions
   - Compare meal nutrition to user's targets

4. **Correct nutrition values:**
   - Change Calories: 450 → 420
   - Change Protein: 35g → 32g
   - Add feedback: "Adjusted values based on standard portion sizes"

5. **Click "Approve with Corrections"**

### Expected Results:
✅ Success message: "Meal approved with corrections!"
✅ Meal added to user's planner with CORRECTED nutrition values
✅ Original values preserved in validation document
✅ Feedback stored for reference

---

## Test Scenario 7: AI Analysis Warnings

### Steps:
1. **As User**, create a meal with potential issues:
   - Very high calories (>1500)
   - Very high sodium (>2000mg)
   - Contains allergen (if user has allergies)
   - Conflicts with dietary restrictions

2. **Submit for validation**

3. **As Nutritionist**, review the meal

### Expected Results:
✅ Red warning banner appears with specific issues:
   - "⚠️ High calorie content detected"
   - "⚠️ Contains allergen: Peanuts"
   - "⚠️ Not suitable for Vegetarian diet"
✅ Nutritionist can see all warnings before approving

---

## Test Scenario 8: User Profile Context Display

### Steps:
1. **As Nutritionist**, open detailed review
2. **Check User Profile section shows:**
   - Age and BMI
   - Health conditions (Diabetes, Hypertension, etc.)
   - Allergies list
   - Dietary restrictions
   - Current goal (Weight Loss, Muscle Gain, etc.)
   - Calculated macro targets

### Expected Results:
✅ All user profile data displays correctly
✅ Macro comparison shows user's targets vs meal nutrition
✅ Health conditions highlighted if relevant
✅ Allergies clearly visible

---

## Test Scenario 9: Security Rules Validation

### Test as Regular User:
1. Try to access another user's validation documents
2. Try to approve your own meal
3. Try to modify validation status directly

### Expected Results:
✅ Cannot read other users' validations
✅ Cannot approve own meals
✅ Cannot modify validation status
✅ Firestore security rules block unauthorized access

### Test as Nutritionist:
1. Read all pending validations
2. Approve/reject any meal
3. Cannot delete validations

### Expected Results:
✅ Can read all validations
✅ Can update validation status
✅ Cannot delete (admin only)

---

## Test Scenario 10: Edge Cases

### Test Empty/Invalid Data:
1. Submit meal with missing nutrition values
2. Submit meal with zero calories
3. Submit meal with negative values

### Expected Results:
✅ Validation service handles gracefully
✅ AI analysis flags unusual values
✅ Nutritionist can see and correct issues

### Test Concurrent Submissions:
1. Submit multiple meals quickly
2. Check all appear in queue
3. Approve them in different order

### Expected Results:
✅ All submissions tracked correctly
✅ No data loss or conflicts
✅ Each meal processed independently

---

## 🔍 Firestore Data Verification

### Check `meal_validation_queue` Collection:

```javascript
{
  "userId": "user123",
  "userName": "John Doe",
  "userEmail": "john@example.com",
  "mealData": {
    "name": "Grilled Chicken Salad",
    "mealType": "lunch",
    "nutrition": { /* nutrition values */ },
    "ingredients": ["chicken", "lettuce", "tomatoes"],
    "instructions": "Grill chicken, mix with vegetables",
    "servingSize": "1 bowl",
    "image": "base64...",
    "goal": "Weight Loss",
    "dietType": "Balanced"
  },
  "userProfile": {
    "age": 30,
    "bmi": 24.5,
    "healthConditions": ["None"],
    "allergies": [],
    "dietaryRestrictions": [],
    "goal": "Weight Loss",
    "calculatedMacros": { /* macro targets */ }
  },
  "status": "pending",
  "submittedAt": Timestamp,
  "reviewedAt": null,
  "reviewedBy": null,
  "feedback": null
}
```

### After Approval:

```javascript
{
  // ... same fields ...
  "status": "approved",
  "reviewedAt": Timestamp,
  "reviewedBy": "nutritionist@example.com",
  "feedback": {
    "decision": "approved",
    "comments": "Looks good!",
    "correctedNutrition": { /* if any corrections */ }
  }
}
```

---

## 📊 Success Metrics

After testing, verify:
- [ ] Users can submit meals for validation
- [ ] Nutritionists see all pending submissions
- [ ] Quick approve works correctly
- [ ] Rejection with feedback works
- [ ] Detailed review with corrections works
- [ ] AI analysis flags issues appropriately
- [ ] User profile context displays correctly
- [ ] Security rules prevent unauthorized access
- [ ] Approved meals appear in user's meal planner
- [ ] Rejected meals do NOT appear in meal planner
- [ ] All Firestore documents created correctly
- [ ] No console errors during any operation

---

## 🐛 Common Issues & Solutions

### Issue: Nutritionist doesn't see pending meals
**Solution:** Check user role in Firestore: `role: "Nutritionist"` (case-sensitive)

### Issue: Security rules deny access
**Solution:** Deploy updated Firestore rules from `MEAL_VALIDATION_FIRESTORE_RULES.md`

### Issue: Meal not added after approval
**Solution:** Check console for errors, verify user's meal_plans collection permissions

### Issue: AI analysis not showing warnings
**Solution:** Verify user profile data exists and is complete

### Issue: User profile context missing
**Solution:** Ensure user has completed onboarding with all health info

---

## 🎯 Performance Testing

1. **Submit 10 meals rapidly** - Check all are queued
2. **Approve 5 meals in quick succession** - Verify no conflicts
3. **Check Firestore read/write counts** - Monitor for efficiency
4. **Test with large images** - Verify base64 encoding works
5. **Test with long ingredient lists** - Check UI doesn't break

---

## ✅ Final Checklist

Before considering testing complete:
- [ ] All 10 test scenarios pass
- [ ] Security rules deployed and working
- [ ] Nutritionist role configured correctly
- [ ] User and nutritionist flows work end-to-end
- [ ] Firestore data structure matches specification
- [ ] No console errors or warnings
- [ ] UI displays correctly on different screen sizes
- [ ] All success/error messages display appropriately
- [ ] Performance is acceptable (< 2 seconds for operations)
- [ ] Documentation reviewed and accurate

---

## 🚀 Ready for Production!

Once all tests pass, the Manual Meal Validation System is ready for production use. Users will have their meals validated by nutritionists, ensuring accuracy and safety in their meal planning.
