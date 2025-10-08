import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/allergen_detection_service.dart';

class AllergenWarningDialog extends StatelessWidget {
  final Map<String, dynamic> recipe;
  final List<String> detectedAllergens;
  final List<String> substitutionSuggestions;
  final String riskLevel;
  final VoidCallback onContinue;
  final VoidCallback onSubstitute;

  const AllergenWarningDialog({
    super.key,
    required this.recipe,
    required this.detectedAllergens,
    required this.substitutionSuggestions,
    required this.riskLevel,
    required this.onContinue,
    required this.onSubstitute,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 20,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFFFF3E0),
              Color(0xFFFFE0B2),
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
            // Warning Icon
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getRiskColor().withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 48,
                color: _getRiskColor(),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Title
            Text(
              'Allergen Alert!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _getRiskColor(),
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Recipe Name
            Text(
              recipe['title'] ?? 'Unknown Recipe',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E7D32),
              ),
              textAlign: TextAlign.center,
            ),
              const SizedBox(height: 12),
              
              // Validation Badge
              FutureBuilder<bool>(
                future: _checkAllergenValidation(),
                builder: (context, snapshot) {
                  // Only show badge if validated
                  if (snapshot.data == true) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green, width: 1),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.verified_user, size: 16, color: Colors.green),
                          SizedBox(width: 6),
                          Text(
                            'Allergen System Validated by Nutritionist',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            const SizedBox(height: 16),
            
            // Warning Message
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getRiskColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _getRiskColor().withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    AllergenDetectionService.getWarningMessage(detectedAllergens),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _getRiskColor(),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  if (substitutionSuggestions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      AllergenDetectionService.getSubstitutionMessage(substitutionSuggestions),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF2E7D32),
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Risk Level Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _getRiskColor().withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Risk Level: ${riskLevel.toUpperCase()}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _getRiskColor(),
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Action Buttons
            Row(
              children: [
                // Substitute Button
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF4CAF50), Color(0xFF66BB6A)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.green.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: onSubstitute,
                      icon: const Icon(Icons.swap_horiz, color: Colors.white),
                      label: const Text(
                        'Find Substitutes',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Continue Button
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getRiskColor().withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getRiskColor(),
                        width: 2,
                      ),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: onContinue,
                      icon: Icon(Icons.check, color: _getRiskColor()),
                      label: Text(
                        'Continue',
                        style: TextStyle(
                          color: _getRiskColor(),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Disclaimer
            Text(
              'Please consult with a healthcare professional if you have severe allergies.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          ),
        ),
      ),
    );
  }

  Color _getRiskColor() {
    switch (riskLevel.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.amber;
      default:
        return Colors.green;
    }
  }

  Future<bool> _checkAllergenValidation() async {
    try {
      print('DEBUG: Checking allergen validation for: $detectedAllergens');
      
      final doc = await FirebaseFirestore.instance
          .collection('system_data')
          .doc('validation_status')
          .get();
      
      if (!doc.exists) {
        print('DEBUG: Validation status document does not exist');
        return false;
      }
      
      final data = doc.data() ?? {};
      print('DEBUG: Validation data: $data');
      
      // Check if allergens category exists
      final allergensData = data['allergens'] as Map<String, dynamic>?;
      if (allergensData == null) {
        print('DEBUG: No allergens data found');
        return false;
      }
      
      print('DEBUG: Allergens data: $allergensData');
      
      // Check if any detected allergen type is validated (case-insensitive)
      for (final allergen in detectedAllergens) {
        print('DEBUG: Checking allergen: $allergen');
        
        // Try both exact match and lowercase
        final allergenLower = allergen.toLowerCase();
        final allergenData = allergensData[allergen] ?? allergensData[allergenLower];
        
        print('DEBUG: Allergen data for $allergen (also checked $allergenLower): $allergenData');
        final validated = allergenData?['validated'] == true;
        print('DEBUG: Is $allergen validated? $validated');
        if (validated) return true;
      }
      
      return false;
    } catch (e) {
      print('Error checking allergen validation: $e');
      return false;
    }
  }
}