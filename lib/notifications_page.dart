import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'services/notification_service.dart';
import 'meal_planner_page.dart';
import 'meal_suggestions_page.dart';
import 'recipe_detail_page.dart';
import 'account_settings_page.dart';

class NotificationsPage extends StatefulWidget {
  final VoidCallback? onNotificationRead;
  
  const NotificationsPage({super.key, this.onNotificationRead});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';
  List<String> _userPreferences = [];
  
  final List<String> _filterOptions = ['All', 'Meal reminders', 'Tips', 'Updates', 'News', 'Unread'];

  @override
  void initState() {
    super.initState();
    _loadUserPreferences();
    _loadNotifications();
  }

  Future<void> _loadUserPreferences() async {
    try {
      final preferences = await NotificationService.getUserNotificationPreferences();
      setState(() {
        _userPreferences = preferences;
      });
    } catch (e) {
      print('Error loading user preferences: $e');
    }
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
    });

    try {
      String? typeFilter;
      bool? readFilter;
      
      // Handle filter logic
      if (_selectedFilter == 'All') {
        typeFilter = null;
        readFilter = null;
      } else if (_selectedFilter == 'Unread') {
        typeFilter = null;
        readFilter = false;
      } else {
        // Map filter names to actual notification types
        typeFilter = _mapFilterToNotificationType(_selectedFilter);
        readFilter = null;
      }

      final notifications = await NotificationService.getUserNotifications(
        type: typeFilter,
        isRead: readFilter,
      );

      // Debug: Print filter info
      print('Filter: $_selectedFilter, Type: $typeFilter, Read: $readFilter');
      print('Found ${notifications.length} notifications');

      setState(() {
        _notifications = notifications;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading notifications: $e')),
      );
    }
  }

  String? _mapFilterToNotificationType(String filter) {
    switch (filter) {
      case 'Meal reminders':
        return 'Meal reminders';
      case 'Tips':
        return 'Tips';
      case 'Updates':
        return 'Updates';
      case 'News':
        return 'News';
      default:
        return null;
    }
  }

  Future<void> _markAsRead(String notificationId) async {
    await NotificationService.markAsRead(notificationId);
    _loadNotifications();
    // Notify parent widget to refresh badge count
    if (widget.onNotificationRead != null) {
      widget.onNotificationRead!();
    }
  }

  Future<void> _markAllAsRead() async {
    await NotificationService.markAllAsRead();
    _loadNotifications();
    // Notify parent widget to refresh badge count
    if (widget.onNotificationRead != null) {
      widget.onNotificationRead!();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All notifications marked as read')),
    );
  }

  Future<void> _deleteNotification(String notificationId) async {
    await NotificationService.deleteNotification(notificationId);
    _loadNotifications();
  }

  Future<void> _deleteAllNotifications() async {
    await NotificationService.deleteAllNotifications();
    _loadNotifications();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All notifications deleted')),
    );
  }

  void _onFilterChanged(String filter) {
    setState(() {
      _selectedFilter = filter;
    });
    _loadNotifications();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_notifications.isNotEmpty)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'mark_all_read') {
                  _markAllAsRead();
                } else if (value == 'delete_all') {
                  _showDeleteAllDialog();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'mark_all_read',
                  child: Row(
                    children: [
                      Icon(Icons.done_all),
                      SizedBox(width: 8),
                      Text('Mark all as read'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete_all',
                  child: Row(
                    children: [
                      Icon(Icons.delete_forever, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Delete all', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          // Filter chips
          Container(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filterOptions.map((filter) {
                  final isSelected = _selectedFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (selected) => _onFilterChanged(filter),
                      backgroundColor: Colors.grey[200],
                      selectedColor: Colors.green[200],
                      checkmarkColor: Colors.green[800],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          
          // Notifications list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _notifications.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        itemCount: _notifications.length,
                        itemBuilder: (context, index) {
                          final notification = _notifications[index];
                          return _buildNotificationCard(notification);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'All' 
                ? 'You\'re all caught up!'
                : 'No $_selectedFilter notifications',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          // Note: In-app notifications are always shown regardless of user preferences
          // User preferences only control push notifications
        ],
      ),
    );
  }

  Widget _buildNotificationCard(Map<String, dynamic> notification) {
    final isRead = notification['isRead'] ?? false;
    final timestamp = notification['createdAt'];
    DateTime dateTime;
    
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      dateTime = DateTime.now();
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: isRead ? 1 : 3,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (notification['color'] as Color?)?.withOpacity(0.1) ?? Colors.green.withOpacity(0.1),
          child: Icon(
            notification['icon'] as IconData? ?? Icons.notifications,
            color: notification['color'] as Color? ?? Colors.green,
          ),
        ),
        title: Text(
          notification['title'] ?? 'Notification',
          style: TextStyle(
            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
            color: isRead ? Colors.grey[600] : Colors.black87,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              notification['message'] ?? '',
              style: TextStyle(
                color: isRead ? Colors.grey[500] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(dateTime),
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isRead)
              IconButton(
                icon: const Icon(Icons.done, size: 20),
                onPressed: () => _markAsRead(notification['id']),
                tooltip: 'Mark as read',
              ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _deleteNotification(notification['id']),
              tooltip: 'Delete',
            ),
          ],
        ),
        onTap: () {
          if (!isRead) {
            _markAsRead(notification['id']);
          }
          _showNotificationDetails(notification);
        },
      ),
    );
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return DateFormat('MMM d, y').format(dateTime);
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  void _showDeleteAllDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Notifications'),
        content: const Text('Are you sure you want to delete all notifications? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _deleteAllNotifications();
            },
            child: const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showNotificationDetails(Map<String, dynamic> notification) {
    final title = notification['title'] ?? 'Notification';
    final message = notification['message'] ?? '';
    final type = notification['type'] ?? 'general';
    final actionData = notification['actionData'];
    final timestamp = notification['createdAt'];
    final isRead = notification['isRead'] ?? false;
    
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      dateTime = timestamp;
    } else {
      dateTime = DateTime.now();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: (notification['color'] as Color?)?.withOpacity(0.1) ?? Colors.green.withOpacity(0.1),
              child: Icon(
                notification['icon'] as IconData? ?? Icons.notifications,
                color: notification['color'] as Color? ?? Colors.green,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    _getNotificationTypeDisplayName(type),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Message content
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
              
              // Notification info
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    _formatTimestamp(dateTime),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  if (!isRead)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'NEW',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          // Action buttons based on notification type
          ..._buildActionButtons(notification, actionData),
          
          // Close button
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons(Map<String, dynamic> notification, String? actionData) {
    final type = notification['type'] ?? 'general';
    final List<Widget> buttons = [];

    // Add action buttons based on notification type
    switch (type) {
      case 'Meal reminders':
        buttons.add(
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToMealLogging();
            },
            icon: const Icon(Icons.restaurant, size: 16),
            label: const Text('Log Meal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        );
        break;
        
      case 'Tips':
        buttons.add(
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToNutritionTips();
            },
            icon: const Icon(Icons.lightbulb, size: 16),
            label: const Text('View Tips'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
            ),
          ),
        );
        break;
        
      case 'News':
        if (actionData != null && actionData.startsWith('recipe:')) {
          buttons.add(
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToRecipe(actionData);
              },
              icon: const Icon(Icons.restaurant_menu, size: 16),
              label: const Text('View Recipe'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          );
        }
        break;
        
      case 'Updates':
        buttons.add(
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToUpdates();
            },
            icon: const Icon(Icons.update, size: 16),
            label: const Text('Learn More'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        );
        break;
    }

    return buttons;
  }

  String _getNotificationTypeDisplayName(String type) {
    switch (type) {
      case 'Meal reminders':
        return 'Meal Reminder';
      case 'Tips':
        return 'Nutrition Tip';
      case 'News':
        return 'Health News';
      case 'Updates':
        return 'App Update';
      default:
        return 'Notification';
    }
  }

  void _navigateToMealLogging() {
    // Navigate to meal planner page
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MealPlannerPage()),
    );
  }

  void _navigateToNutritionTips() {
    // Navigate to meal suggestions page (nutrition tips)
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MealSuggestionsPage()),
    );
  }

  void _navigateToRecipe(String actionData) {
    // Extract recipe name from actionData
    final recipeName = actionData.replaceFirst('recipe:', '');
    
    // For now, navigate to meal suggestions page
    // In the future, this could navigate to a specific recipe detail page
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MealSuggestionsPage()),
    );
    
    // Show a snackbar with the recipe name
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Looking for recipe: $recipeName'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _navigateToUpdates() {
    // Navigate to account settings page (where updates info might be)
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AccountSettingsPage()),
    );
  }
}