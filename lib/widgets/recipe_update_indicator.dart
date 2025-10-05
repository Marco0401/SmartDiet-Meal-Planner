import 'package:flutter/material.dart';

/// Widget to show visual indicators for recipe updates
class RecipeUpdateIndicator extends StatelessWidget {
  final Map<String, dynamic> recipe;
  final Widget child;
  final bool showBadge;
  final bool showHistory;

  const RecipeUpdateIndicator({
    super.key,
    required this.recipe,
    required this.child,
    this.showBadge = true,
    this.showHistory = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasUpdates = _hasRecentUpdates();
    final updateHistory = recipe['recipeUpdateHistory'] as List<dynamic>? ?? [];

    return Stack(
      children: [
        child,
        if (hasUpdates && showBadge)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.update,
                    size: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    'Updated',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (showHistory && updateHistory.isNotEmpty)
          Positioned(
            bottom: 8,
            left: 8,
            child: GestureDetector(
              onTap: () => _showUpdateHistory(context, updateHistory),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.history,
                      size: 12,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      '${updateHistory.length} updates',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  bool _hasRecentUpdates() {
    final updateHistory = recipe['recipeUpdateHistory'] as List<dynamic>? ?? [];
    if (updateHistory.isEmpty) return false;

    final lastUpdate = updateHistory.last as Map<String, dynamic>;
    final updatedAt = DateTime.tryParse(lastUpdate['updatedAt'] ?? '');
    if (updatedAt == null) return false;

    // Show as "recent" if updated within last 7 days
    final daysSinceUpdate = DateTime.now().difference(updatedAt).inDays;
    return daysSinceUpdate <= 7;
  }

  void _showUpdateHistory(BuildContext context, List<dynamic> updateHistory) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Recipe Update History'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: ListView.builder(
            itemCount: updateHistory.length,
            itemBuilder: (context, index) {
              final update = updateHistory[index] as Map<String, dynamic>;
              final updatedAt = DateTime.tryParse(update['updatedAt'] ?? '');
              final changes = update['changes'] as List<dynamic>? ?? [];
              final updatedBy = update['updatedBy'] ?? 'Unknown';

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.update,
                            size: 16,
                            color: Colors.orange[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            updatedAt != null
                                ? '${_formatDate(updatedAt)} at ${_formatTime(updatedAt)}'
                                : 'Unknown date',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Updated by: $updatedBy',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      if (changes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'Changes:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        ...changes.map((change) => Padding(
                          padding: const EdgeInsets.only(left: 8, bottom: 2),
                          child: Text(
                            '• $change',
                            style: const TextStyle(fontSize: 12),
                          ),
                        )),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) return 'Today';
    if (difference == 1) return 'Yesterday';
    if (difference < 7) return '${difference} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

/// Widget to show a notification banner for recipe updates
class RecipeUpdateBanner extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback? onDismiss;
  final VoidCallback? onViewDetails;

  const RecipeUpdateBanner({
    super.key,
    required this.notification,
    this.onDismiss,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final details = notification['details'] as Map<String, dynamic>? ?? {};
    final changes = details['changes'] as List<dynamic>? ?? [];
    final recipeTitle = details['recipeTitle'] ?? 'Unknown Recipe';

    return Container(
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange[100]!, Colors.orange[50]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange[600],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.update,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recipe Updated: $recipeTitle',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification['message'] ?? 'A recipe has been updated',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontSize: 12,
                    ),
                  ),
                  if (changes.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Changes: ${changes.take(2).join(', ')}${changes.length > 2 ? '...' : ''}',
                      style: TextStyle(
                        color: Colors.orange[800],
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onViewDetails != null)
              IconButton(
                onPressed: onViewDetails,
                icon: const Icon(Icons.visibility, size: 16),
                tooltip: 'View Details',
              ),
            if (onDismiss != null)
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close, size: 16),
                tooltip: 'Dismiss',
              ),
          ],
        ),
      ),
    );
  }
}
