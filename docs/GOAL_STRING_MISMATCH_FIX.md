# Goal String Mismatch Fix

## 🐛 **Problem: "Build Muscle" Not Recognized**

### **User's Issue:**
- Goal set to **"Build muscle"** in Account Settings
- App showing **1754 kcal** (deficit) instead of **2312 kcal** (surplus)
- Expected target for muscle gain: **~2300 kcal**

---

## 🔍 **Root Cause: String Mismatch**

### **Onboarding Goal Options:**
```dart
static const List<String> goals = [
  'None',
  'Lose weight',
  'Gain weight',
  'Maintain current weight',
  'Build muscle',  // ← User selected this
  'Eat healthier / clean eating',
];
```

### **Old Calculation Logic:**
```dart
switch (profile.goal.toLowerCase()) {
  case 'lose weight':
    targetCalories *= 0.85;
    break;
  case 'gain weight':
  case 'gain muscle':  // ← Only checked for 'gain muscle'
    targetCalories *= 1.15;
    break;
  // Falls through to default (no adjustment)
}
```

**Problem:** 
- User's goal: `"Build muscle"` → lowercase: `"build muscle"`
- Switch case checks for: `"gain muscle"` ❌
- **No match** → Falls through → No multiplier applied!

---

## ✅ **The Fix**

### **Updated Both Calculation Methods:**

```dart
switch (profile.goal.toLowerCase()) {
  case 'lose weight':
    targetCalories *= 0.85; // 15% deficit
    break;
  case 'gain weight':
  case 'gain muscle':
  case 'build muscle': // ✅ ADDED - Now matches onboarding option
    targetCalories *= 1.15; // 15% surplus
    break;
  case 'maintain current weight': // ✅ ADDED - Explicit handling
  case 'maintain weight':
  case 'eat healthier / clean eating': // ✅ ADDED
  case 'none': // ✅ ADDED
  default:
    // Keep same calories (maintenance)
    break;
}
```

---

## 📊 **Expected Results After Fix**

### **For User Profile:**
- Age: 22, Weight: 56kg, Height: 156cm, Male
- Activity: Lightly Active (1.375)
- Goal: **Build muscle**

### **Calculation:**
```
BMR = 1,462 kcal (Harris-Benedict)
TDEE = 1,462 × 1.375 = 2,010 kcal (maintenance)
Muscle Gain = 2,010 × 1.15 = 2,312 kcal ✅
```

### **Macros (25/45/30 distribution):**
- **Protein:** 145g (25%)
- **Carbs:** 260g (45%)
- **Fat:** 77g (30%)

---

## 🎯 **All Goal Options Now Handled**

| Goal Option | Multiplier | Effect |
|-------------|------------|--------|
| Lose weight | 0.85 | 15% deficit |
| Gain weight | 1.15 | 15% surplus |
| **Build muscle** ✅ | 1.15 | 15% surplus |
| Maintain current weight | 1.0 | Maintenance |
| Eat healthier / clean eating | 1.0 | Maintenance |
| None | 1.0 | Maintenance |

---

## 🧪 **Testing Steps**

1. **Restart the app** (hot restart)
2. **Check Nutrition Analytics** → Should show ~2312 kcal
3. **Log a meal** → Notification should show ~2312 kcal
4. **Tap on today** → Detail dialog should show ~2312 kcal
5. **Verify percentages** calculate correctly against new target

---

## 📝 **Files Modified**

- `lib/services/nutrition_calculator_service.dart`
  - Added `'build muscle'` case to both calculation methods
  - Added explicit cases for all onboarding goal options
  - Added default fallback for maintenance

---

## ✅ **Benefits**

1. **✅ Accurate Targets** - "Build muscle" now properly applies 15% surplus
2. **✅ All Goals Covered** - Every onboarding option explicitly handled
3. **✅ User Expectations Met** - 2312 kcal matches manual calculation (~2300 kcal)
4. **✅ Consistency** - Same logic in both calculation methods
5. **✅ Maintainability** - Clear, explicit cases (no silent failures)

---

## 💡 **Lesson Learned**

**Always ensure string matching logic covers ALL user-facing options!**

In this case, the onboarding offered "Build muscle" but the calculation code only checked for "Gain muscle", causing a silent failure where the goal was ignored.

---

**Implementation Date:** October 31, 2025  
**Status:** ✅ Fixed - Ready for Testing  
**Priority:** 🔴 HIGH - Directly affects user experience and goal achievement
