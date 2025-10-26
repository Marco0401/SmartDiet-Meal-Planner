# Onboarding Process Flowchart

## Overview
This flowchart represents the complete user onboarding process for the SmartDiet app, showing all steps, validation checks, and decision points.

## Flowchart Structure

```
                    ┌─────────────────┐
                    │   Start (J)     │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │  User Registers │
                    │   & Logs In     │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Check if User   │
                    │ Profile Exists? │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   Profile       │
                    │   Exists?       │
                    └─────┬─────┬─────┘
                          │     │
                    ┌─────▼─┐   │
                    │  Yes  │   │
                    └─────┬─┘   │
                          │     │
                          ▼     │
                    ┌─────────────────┐
                    │ Navigate to     │
                    │ Dashboard       │
                    └─────────────────┘
                              │
                              │
                    ┌─────────▼───────┐
                    │      No         │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Start Onboarding│
                    │   Process       │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   Step 1:       │
                    │  Basic Info     │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Collect:        │
                    │ • Full Name     │
                    │ • Birthday      │
                    │ • Gender        │
                    │ • Height (cm)   │
                    │ • Weight (kg)   │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ All Required    │
                    │ Fields Valid?   │
                    └─────┬─────┬─────┘
                          │     │
                    ┌─────▼─┐   │
                    │  No   │   │
                    └─────┬─┘   │
                          │     │
                          ▼     │
                    ┌─────────────────┐
                    │ Show Error:     │
                    │ "Please complete│
                    │ all required    │
                    │ fields"         │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   J1            │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   Step 2:       │
                    │  Health Info    │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Collect:        │
                    │ • Health        │
                    │   Conditions    │
                    │ • Food          │
                    │   Allergies     │
                    │ • Other         │
                    │   Conditions    │
                    │ • Medications   │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ At Least One    │
                    │ Health Condition│
                    │ & Allergy       │
                    │ Selected?       │
                    └─────┬─────┬─────┘
                          │     │
                    ┌─────▼─┐   │
                    │  No   │   │
                    └─────┬─┘   │
                          │     │
                          ▼     │
                    ┌─────────────────┐
                    │ Show Error:     │
                    │ "Please select  │
                    │ at least one    │
                    │ health condition│
                    │ and one allergy │
                    │ (or None)"      │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   J2            │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   Step 3:       │
                    │ Dietary         │
                    │ Preferences     │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Collect:        │
                    │ • Diet Type     │
                    │   (Vegetarian,  │
                    │   Vegan, Keto,  │
                    │   etc.)         │
                    │ • Other Diet    │
                    │   (optional)    │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ At Least One    │
                    │ Dietary         │
                    │ Preference      │
                    │ Selected?       │
                    └─────┬─────┬─────┘
                          │     │
                    ┌─────▼─┐   │
                    │  No   │   │
                    └─────┬─┘   │
                          │     │
                          ▼     │
                    ┌─────────────────┐
                    │ Show Error:     │
                    │ "Please select  │
                    │ at least one    │
                    │ dietary         │
                    │ preference      │
                    │ (or None)"      │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   J3            │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   Step 4:       │
                    │  Body Goals     │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Collect:        │
                    │ • Goal          │
                    │   (Lose/Gain/   │
                    │   Maintain      │
                    │   Weight, etc.) │
                    │ • Activity      │
                    │   Level         │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Goal & Activity │
                    │ Level Selected? │
                    └─────┬─────┬─────┘
                          │     │
                    ┌─────▼─┐   │
                    │  No   │   │
                    └─────┬─┘   │
                          │     │
                          ▼     │
                    ┌─────────────────┐
                    │ Show Error:     │
                    │ "Please select  │
                    │ your goal and   │
                    │ activity level" │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   J4            │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   Step 5:       │
                    │ Notifications   │
                    │   (Optional)    │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Collect:        │
                    │ • Notification  │
                    │   Preferences   │
                    │   (Meal         │
                    │   reminders,    │
                    │   Tips, etc.)   │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ User Clicks     │
                    │ "Finish"        │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Validate All    │
                    │ Previous Steps  │
                    └─────┬─────┬─────┘
                          │     │
                    ┌─────▼─┐   │
                    │  No   │   │
                    └─────┬─┘   │
                          │     │
                          ▼     │
                    ┌─────────────────┐
                    │ Show Error:     │
                    │ "Please complete│
                    │ all required    │
                    │ fields"         │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   J5            │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Calculate Age   │
                    │ from Birthday   │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Create User     │
                    │ Profile Object  │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Save Profile to │
                    │ Firestore       │
                    │ Database        │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │ Navigate to     │
                    │ Dashboard       │
                    └─────────┬───────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   End (1)       │
                    └─────────────────┘
```

## Key Features of the Onboarding Process

### 1. **Step-by-Step Validation**
- Each step has specific validation requirements
- Users cannot proceed without completing required fields
- Clear error messages guide users to fix issues

### 2. **Data Collection Steps**
- **Step 1 (Basic Info)**: Personal information, physical measurements
- **Step 2 (Health Info)**: Medical conditions, allergies, medications
- **Step 3 (Dietary Preferences)**: Diet types and restrictions
- **Step 4 (Body Goals)**: Fitness goals and activity levels
- **Step 5 (Notifications)**: Communication preferences (optional)

### 3. **Navigation Controls**
- **Back Button**: Available from step 2 onwards
- **Next Button**: Validates current step before proceeding
- **Finish Button**: Final validation and profile creation

### 4. **Progress Indicator**
- Visual progress bar shows completion status
- Step titles displayed in app bar
- Green indicators for completed steps

### 5. **Data Persistence**
- Profile data saved to Firebase Firestore
- Preserves existing user data (email, timestamps)
- Calculates age from birthday automatically

### 6. **Error Handling**
- Field-specific validation messages
- Prevents navigation with incomplete data
- User-friendly error display

## Validation Rules

| Step | Required Fields | Validation Logic |
|------|----------------|------------------|
| 1 | Full Name, Birthday, Gender, Height, Weight | All fields must be non-empty, height/weight > 0 |
| 2 | Health Conditions, Allergies | At least one condition and one allergy (or "None") |
| 3 | Dietary Preferences | At least one preference (or "None") |
| 4 | Goal, Activity Level | Both must be selected |
| 5 | Notifications | Optional - no validation required |

## User Experience Features

- **Intuitive Interface**: Clean, step-by-step design
- **Flexible Input**: Multiple selection options with "None" choices
- **Custom Options**: Text fields for "Other" categories
- **Smart Validation**: Real-time feedback on form completion
- **Seamless Navigation**: Smooth transitions between steps
- **Data Safety**: Preserves existing user information during updates
