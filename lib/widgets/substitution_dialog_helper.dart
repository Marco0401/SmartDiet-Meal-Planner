import 'package:flutter/material.dart';
import 'ingredient_substitution_dialog.dart';
import 'multi_substitution_dialog.dart';

class SubstitutionDialogHelper {
  /// Shows the appropriate substitution dialog based on allergen count
  static Future<Map<String, dynamic>?> showSubstitutionDialog(
    BuildContext context,
    Map<String, dynamic> recipe,
    List<String> detectedAllergens,
  ) async {
    if (detectedAllergens.length > 1) {
      // Use multi-substitution dialog for multiple allergens
      return await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => MultiSubstitutionDialog(
          recipe: recipe,
          detectedAllergens: detectedAllergens,
        ),
      );
    } else {
      // Use single substitution dialog for one allergen
      return await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => IngredientSubstitutionDialog(
          recipe: recipe,
          detectedAllergens: detectedAllergens,
        ),
      );
    }
  }
}
