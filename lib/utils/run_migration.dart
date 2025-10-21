import 'package:firebase_core/firebase_core.dart';
import 'migrate_substitution_nutrition.dart';

/// Simple script to run the substitution nutrition migration
/// Run this with: dart lib/utils/run_migration.dart
Future<void> main() async {
  try {
    print('🚀 Starting Substitution Nutrition Migration...');
    
    // Initialize Firebase
    await Firebase.initializeApp();
    print('✅ Firebase initialized');
    
    // Run migration
    await MigrateSubstitutionNutrition.migrateAllSubstitutions();
    
    // Validate migration
    final isValid = await MigrateSubstitutionNutrition.validateMigration();
    
    if (isValid) {
      print('🎉 Migration completed and validated successfully!');
      print('💡 You can now use the smart nutrition calculation in your app.');
    } else {
      print('⚠️ Migration completed but validation failed. Please check the data.');
    }
    
  } catch (e) {
    print('❌ Migration failed: $e');
  }
}
