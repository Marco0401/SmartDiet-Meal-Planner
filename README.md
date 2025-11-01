# SmartDiet - Smart Nutrition Management
# Download Here:
https://github.com/Marco0401/SmartDiet-Meal-Planner/releases/download/v1.0.0/app-release.apk

## Overview

SmartDiet is a comprehensive Flutter-powered nutrition management app that puts **you in control** of your meal planning and tracking. Built with intelligent tools like ingredient scanning, allergen detection, and nutritionist-curated recipes—without automated AI meal generation.

**Perfect for users who want:**
- 🎯 Precision nutrition tracking with manual control
- 🍽️ Smart meal entry with ingredient parsing & barcode scanning
- ⚠️ Allergen detection and substitution suggestions
- 📊 Expert-curated meal plans from nutritionists
- 📱 Cross-platform experience (Android, iOS, Web admin)

---

## Table of Contents

1. [Features](#features)
2. [Screenshots](#screenshots)
3. [Architecture](#architecture)
4. [Tech Stack](#tech-stack)
5. [Key Features Deep Dive](#key-features-deep-dive)
6. [Admin Portal](#admin-portal)
7. [Testing](#testing)
8. [Contributing](#contributing)
9. [License](#license)

---

## Features

### 🍽️ Meal Management (No AI)
- **Smart Manual Meal Entry**
  - Two modes: Smart Mode (structured ingredients) & Manual Mode (free-form)
  - Ingredient parser that extracts amounts, units, and names
  - Per-100g nutrition lookup from Firestore database
  - Real-time per-ingredient macro breakdown (Cal, P, C, F)
  - Automatic total nutrition calculation without scaling/clamping

- **Meal Planner**
  - Calendar-based meal scheduling by date and meal type
  - Manual edits preserve exact nutrition values
  - Motivational progress notifications for specific dates
  - Pull-to-refresh and seamless UI updates

- **Favorites & Custom Recipes**
  - Save custom recipes with full nutrition data
  - Edit manual entry recipes without scaling
  - Replace ingredients with allergen-safe alternatives
  - Persistent storage in Firebase Firestore

### 🔍 Ingredient & Scanning Tools
- **Ingredient Scanner**
  - Camera upload with Google ML Kit OCR
  - Barcode scanning for instant product lookup
  - USDA and OpenFoodFacts API integration
  - Text recognition for ingredient labels

- **Barcode Scanner**
  - Quick product nutrition lookup
  - Auto-fill meal entry with scanned data
  - Mobile Scanner integration

### ⚠️ Allergen Detection & Safety
- **ML-Based Allergen Detection**
  - Machine learning model for ingredient analysis
  - Real-time allergen warnings during meal entry
  - Support for 8 major allergens (dairy, eggs, fish, shellfish, tree nuts, peanuts, wheat, soy)

- **Smart Substitutions**
  - Curated allergen-safe ingredient alternatives
  - One-tap ingredient replacement
  - Maintains recipe integrity and taste profiles

### 📊 Tracking & Analytics
- **Nutrition Progress**
  - Daily macro tracking (calories, protein, carbs, fat, fiber)
  - Visual progress indicators with percentage completion
  - Motivational notifications and milestone celebrations
  - Historical data and trends

- **Personalized Goals**
  - Custom TDEE and macro targets
  - Goal-based recommendations (weight loss, maintenance, muscle gain)
  - Activity level adjustments

### 👤 Personalization
- **Onboarding Flow**
  - Captures dietary preferences, health goals, allergens
  - Calculates personalized nutrition targets
  - Sets up user profile for tailored experience

- **Dietary Preferences**
  - Vegetarian, vegan, halal, kosher options
  - Custom dietary restrictions
  - Allergen profile management

### 🔔 Notifications & Updates
- **Notification Center**
  - Meal reminders and updates
  - Curated announcements from nutritionists
  - Recipe update notifications
  - Filter by type (meals, updates, announcements)

### 👨‍⚕️ Admin & Expert Tools (Web)
- **Admin Dashboard**
  - Manage curated recipes and meal plans
  - Bulk recipe operations (import, export, rollback)
  - Ingredient nutrition database management
  - User analytics and engagement metrics

- **Expert Meal Plan Creation**
  - Nutritionist-designed weekly meal plans
  - Themed plans (low-carb, high-protein, Mediterranean, etc.)
  - Allergen validation and warnings

- **Content Management**
  - Guidelines editor for nutrition advice
  - Substitution table management
  - Announcement creation and scheduling

---

## Screenshots

*Add screenshots of key screens: Dashboard, Manual Meal Entry, Meal Planner, Ingredient Scanner, etc.*

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    SmartDiet App                        │
│                                                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │
│  │   Mobile    │  │   Mobile    │  │   Web       │   │
│  │   (Android) │  │   (iOS)     │  │   (Admin)   │   │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘   │
│         │                 │                 │           │
│         └─────────────────┴─────────────────┘           │
│                           │                             │
│                    Flutter Framework                    │
│                           │                             │
│         ┌─────────────────┴─────────────────┐           │
│         │                                   │           │
│    ┌────▼─────┐                      ┌─────▼────┐     │
│    │ Services │                      │  Widgets  │     │
│    └────┬─────┘                      └──────────┘     │
│         │                                               │
└─────────┼───────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────────────────────────────────────────┐
│                    Firebase Backend                     │
│                                                         │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌────────┐│
│  │   Auth   │  │ Firestore│  │  Storage │  │   ML   ││
│  └──────────┘  └──────────┘  └──────────┘  │  Kit   ││
│                                             └────────┘│
└─────────────────────────────────────────────────────────┘
```

### Key Design Patterns
- **Service Layer Architecture**: All business logic encapsulated in services
- **StatefulWidget Pattern**: State management via Flutter's built-in widgets
- **Repository Pattern**: Firestore access abstracted through service classes
- **Observer Pattern**: Real-time updates via Firestore streams

---

## Tech Stack

| Category | Technology |
|----------|------------|
| **Language** | Dart |
| **Framework** | Flutter 3.22+ |
| **Backend** | Firebase (Auth, Firestore, Storage, Cloud Messaging) |
| **Database** | Cloud Firestore |
| **Authentication** | Firebase Auth (Email/Password, Google Sign-In) |
| **ML & OCR** | Google ML Kit (Text Recognition, Barcode Scanning) |
| **External APIs** | Spoonacular, USDA, OpenFoodFacts |
| **State Management** | StatefulWidget, InheritedWidget |
| **Build Tools** | Gradle (Android), Flutter CLI |
| **CI/CD** | GitHub Actions (optional) |

---

## Key Features Deep Dive

### Smart Manual Meal Entry

**Smart Mode:**
- Structured ingredient list with parser
- Real-time nutrition lookup from Firestore
- Per-ingredient macro breakdown
- Allergen detection and substitution suggestions
- Automatic total nutrition calculation

**Manual Mode:**
- Free-form ingredient and nutrition input
- No calculation interference
- Manual control over all values
### Allergen Detection

**ML-Based Detection:**
- Custom ML model trained on ingredient data
- Real-time predictions during meal entry
- Confidence scores for detected allergens

**Traditional Detection:**
- Curated allergen database
- Keyword matching for ingredients
- Cross-reference with user allergen profile

### Nutrition Progress Notifications

- Motivational overlay after saving meals
- Shows daily progress for **the meal's specific date**
- Real-time macro calculations
- Visual progress bars with percentage
- Auto-dismiss after 5 seconds
---

## Admin Portal

The admin dashboard is a Flutter web app for nutritionists and administrators.

### Features

- **Recipe Management**: CRUD operations for curated recipes
- **User Management**: View user profiles and activity
- **Expert Meal Plans**: Create weekly meal plans for users
- **Ingredient Database**: Manage per-100g nutrition data
- **Substitution Tables**: Allergen-safe ingredient alternatives
- **Analytics Dashboard**: User engagement metrics
- **Content Creation**: Guidelines, announcements, notifications

---

## Testing

### Widget Tests

Test critical UI flows:
- Manual meal entry (smart & manual modes)
- Meal planner interactions
- Allergen warning dialogs
- Ingredient scanner
  
---

## Contributing

This is currently a private academic project. Contributions are not being accepted at this time.

If you'd like to use this project as inspiration for your own work, feel free to fork and adapt it!

---

## License

This project is currently **closed-source** for academic/portfolio purposes.

If you plan to distribute or commercialize this app, please update this section with an appropriate license (MIT, Apache 2.0, etc.).

---

## Acknowledgments

- **Flutter Team** - Cross-platform framework
- **Firebase** - Backend infrastructure
- **Google ML Kit** - OCR and barcode scanning
- **Spoonacular API** - Recipe data
- **USDA FoodData Central** - Nutrition data
- **OpenFoodFacts** - Product database

---

**Made with ❤️ using Flutter**
