import 'package:flutter/material.dart';
import '../../utils/migrate_substitution_nutrition.dart';

class MigrationPage extends StatefulWidget {
  const MigrationPage({super.key});

  @override
  State<MigrationPage> createState() => _MigrationPageState();
}

class _MigrationPageState extends State<MigrationPage> {
  bool _isRunning = false;
  String _status = 'Ready to migrate';
  bool _migrationCompleted = false;
  bool _validationPassed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Substitution Nutrition Migration'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Migration Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'This migration will convert all your existing string-based substitutions to the new consolidated format with embedded nutrition data.',
                      style: TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '• All substitutions will get comprehensive nutrition information\n'
                      '• Data structure will be updated to version 2.0\n'
                      '• Existing nutrition data will be preserved\n'
                      '• Migration is safe and reversible',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.science,
                          color: _migrationCompleted ? Colors.green : Colors.orange,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Migration Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _status,
                      style: TextStyle(
                        fontSize: 14,
                        color: _isRunning ? Colors.blue : 
                               _migrationCompleted ? Colors.green : Colors.grey,
                      ),
                    ),
                    if (_migrationCompleted) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            _validationPassed ? Icons.check_circle : Icons.warning,
                            color: _validationPassed ? Colors.green : Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _validationPassed 
                                ? 'Validation passed - All substitutions have nutrition data'
                                : 'Validation failed - Some substitutions may be missing nutrition data',
                            style: TextStyle(
                              fontSize: 12,
                              color: _validationPassed ? Colors.green : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Migration Actions',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isRunning ? null : _runMigration,
                            icon: _isRunning 
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.play_arrow),
                            label: Text(_isRunning ? 'Migrating...' : 'Run Migration'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _migrationCompleted ? _validateMigration : null,
                            icon: const Icon(Icons.verified),
                            label: const Text('Validate'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _migrationCompleted ? _resetMigration : null,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset Migration'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What This Migration Does',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Before Migration:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text('• Substitutions stored as simple strings\n'
                        '• No nutrition data available\n'
                        '• Basic substitution functionality only'),
                    const SizedBox(height: 8),
                    const Text(
                      'After Migration:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const Text('• Substitutions stored as objects with nutrition data\n'
                        '• Comprehensive nutrition information for each substitution\n'
                        '• Smart nutrition calculation during meal planning\n'
                        '• Better user experience with accurate nutrition tracking'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runMigration() async {
    setState(() {
      _isRunning = true;
      _status = 'Starting migration...';
    });

    try {
      await MigrateSubstitutionNutrition.migrateAllSubstitutions();
      
      setState(() {
        _isRunning = false;
        _migrationCompleted = true;
        _status = 'Migration completed successfully!';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Migration completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isRunning = false;
        _status = 'Migration failed: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Migration failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _validateMigration() async {
    setState(() {
      _status = 'Validating migration...';
    });

    try {
      final isValid = await MigrateSubstitutionNutrition.validateMigration();
      
      setState(() {
        _validationPassed = isValid;
        _status = isValid 
            ? 'Validation passed - All substitutions have nutrition data'
            : 'Validation failed - Some substitutions may be missing nutrition data';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isValid 
                ? 'Validation passed!'
                : 'Validation failed - please check the data'),
            backgroundColor: isValid ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _status = 'Validation failed: $e';
        _validationPassed = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Validation failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _resetMigration() {
    setState(() {
      _isRunning = false;
      _migrationCompleted = false;
      _validationPassed = false;
      _status = 'Ready to migrate';
    });
  }
}
