import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class NotificationCenterPage extends StatefulWidget {
  const NotificationCenterPage({super.key});

  @override
  State<NotificationCenterPage> createState() => _NotificationCenterPageState();
}

class _NotificationCenterPageState extends State<NotificationCenterPage> with TickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Center'),
        backgroundColor: const Color(0xFFE91E63),
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: 'Draft Notifications', icon: Icon(Icons.drafts)),
            Tab(text: 'Sent Notifications', icon: Icon(Icons.send)),
            Tab(text: 'Scheduled', icon: Icon(Icons.schedule)),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _showCreateNotificationDialog(),
            icon: const Icon(Icons.add),
            tooltip: 'Create New Notification',
          ),
          IconButton(
            onPressed: () {
              setState(() {});
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search notifications...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        icon: const Icon(Icons.clear),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildNotificationList('draft'),
                _buildNotificationList('sent'),
                _buildNotificationList('scheduled'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationList(String status) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('notifications')
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red.shade400),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final notifications = snapshot.data?.docs ?? [];
        final filteredNotifications = notifications.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final title = data['title']?.toString().toLowerCase() ?? '';
          final message = data['message']?.toString().toLowerCase() ?? '';
          return title.contains(_searchQuery) || message.contains(_searchQuery);
        }).toList();

        if (filteredNotifications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  status == 'draft' ? Icons.drafts : 
                  status == 'sent' ? Icons.send : Icons.schedule,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  status == 'draft' ? 'No draft notifications' :
                  status == 'sent' ? 'No sent notifications' : 'No scheduled notifications',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showCreateNotificationDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Create First Notification'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredNotifications.length,
          itemBuilder: (context, index) {
            final doc = filteredNotifications[index];
            final data = doc.data() as Map<String, dynamic>;
            return _buildNotificationCard(doc.id, data, status);
          },
        );
      },
    );
  }

  Widget _buildNotificationCard(String notificationId, Map<String, dynamic> data, String status) {
    final title = data['title'] ?? 'Untitled Notification';
    final message = data['message'] ?? '';
    final type = data['type'] ?? 'general';
    final targetAudience = data['targetAudience'] ?? 'all';
    final createdAt = data['createdAt'] as Timestamp?;
    final scheduledFor = data['scheduledFor'] as Timestamp?;
    final sentAt = data['sentAt'] as Timestamp?;
    final sentCount = data['sentCount'] ?? 0;
    final readCount = data['readCount'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getNotificationTypeColor(type).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _getNotificationTypeIcon(type),
                    color: _getNotificationTypeColor(type),
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
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _getNotificationTypeDisplayName(type),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      color: _getStatusColor(status),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Message Preview
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Message:',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message.length > 200 ? '${message.substring(0, 200)}...' : message,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Target Audience and Stats
            Row(
              children: [
                _buildInfoItem('Target', _getTargetAudienceDisplayName(targetAudience), Colors.blue),
                const SizedBox(width: 16),
                if (status == 'sent') ...[
                  _buildInfoItem('Sent', sentCount.toString(), Colors.green),
                  const SizedBox(width: 16),
                  _buildInfoItem('Read', readCount.toString(), Colors.orange),
                ] else if (status == 'scheduled' && scheduledFor != null) ...[
                  _buildInfoItem('Scheduled', DateFormat('MMM dd, HH:mm').format(scheduledFor.toDate()), Colors.purple),
                ],
                const Spacer(),
                Text(
                  status == 'sent' && sentAt != null 
                    ? 'Sent: ${DateFormat('MMM dd, yyyy').format(sentAt.toDate())}'
                    : 'Created: ${createdAt != null ? DateFormat('MMM dd, yyyy').format(createdAt.toDate()) : 'Unknown'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Actions
            Row(
              children: [
                if (status == 'draft') ...[
                  TextButton.icon(
                    onPressed: () => _scheduleNotification(notificationId, data),
                    icon: const Icon(Icons.schedule, size: 16),
                    label: const Text('Schedule'),
                    style: TextButton.styleFrom(foregroundColor: Colors.purple),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _sendNotification(notificationId),
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Send Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ] else if (status == 'scheduled') ...[
                  TextButton.icon(
                    onPressed: () => _cancelScheduledNotification(notificationId),
                    icon: const Icon(Icons.cancel, size: 16),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _editNotification(notificationId, data),
                    icon: const Icon(Icons.edit, size: 16),
                    label: const Text('Edit'),
                  ),
                ] else if (status == 'sent') ...[
                  TextButton.icon(
                    onPressed: () => _viewNotificationStats(notificationId, data),
                    icon: const Icon(Icons.analytics, size: 16),
                    label: const Text('View Stats'),
                  ),
                ],
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _viewNotificationDetails(notificationId, data),
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('View Details'),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () => _deleteNotification(notificationId, title),
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  String _getNotificationTypeDisplayName(String type) {
    switch (type) {
      case 'tips':
        return 'Nutrition Tips';
      case 'updates':
        return 'App Updates';
      case 'news':
        return 'Health News';
      case 'reminders':
        return 'Meal Reminders';
      default:
        return 'General Notification';
    }
  }

  Color _getNotificationTypeColor(String type) {
    switch (type) {
      case 'tips':
        return Colors.amber;
      case 'updates':
        return Colors.blue;
      case 'news':
        return Colors.green;
      case 'reminders':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getNotificationTypeIcon(String type) {
    switch (type) {
      case 'tips':
        return Icons.lightbulb;
      case 'updates':
        return Icons.system_update;
      case 'news':
        return Icons.newspaper;
      case 'reminders':
        return Icons.notifications;
      default:
        return Icons.message;
    }
  }

  String _getTargetAudienceDisplayName(String audience) {
    switch (audience) {
      case 'all':
        return 'All Users';
      case 'nutritionist':
        return 'Nutritionists';
      case 'admin':
        return 'Admins';
      default:
        return 'Specific Users';
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'draft':
        return Colors.orange;
      case 'sent':
        return Colors.green;
      case 'scheduled':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  void _showCreateNotificationDialog() {
    showDialog(
      context: context,
      builder: (context) => _CreateNotificationDialog(
        onNotificationCreated: () {
          setState(() {});
        },
      ),
    );
  }

  void _editNotification(String notificationId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => _CreateNotificationDialog(
        notificationId: notificationId,
        initialData: data,
        onNotificationCreated: () {
          setState(() {});
        },
      ),
    );
  }

  void _viewNotificationDetails(String notificationId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(data['title'] ?? 'Notification Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Type: ${_getNotificationTypeDisplayName(data['type'] ?? '')}'),
              Text('Target: ${_getTargetAudienceDisplayName(data['targetAudience'] ?? '')}'),
              Text('Status: ${data['status'] ?? 'Unknown'}'),
              if (data['scheduledFor'] != null)
                Text('Scheduled: ${DateFormat('MMM dd, yyyy HH:mm').format((data['scheduledFor'] as Timestamp).toDate())}'),
              if (data['sentAt'] != null)
                Text('Sent: ${DateFormat('MMM dd, yyyy HH:mm').format((data['sentAt'] as Timestamp).toDate())}'),
              Text('Sent Count: ${data['sentCount'] ?? 0}'),
              Text('Read Count: ${data['readCount'] ?? 0}'),
              const SizedBox(height: 8),
              const Text('Message:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text(data['message'] ?? 'No message'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _viewNotificationStats(String notificationId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Notification Statistics'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildStatCard('Sent', data['sentCount']?.toString() ?? '0', Colors.green),
            const SizedBox(height: 16),
            _buildStatCard('Read', data['readCount']?.toString() ?? '0', Colors.blue),
            const SizedBox(height: 16),
            _buildStatCard('Read Rate', '${((data['readCount'] ?? 0) / (data['sentCount'] ?? 1) * 100).toStringAsFixed(1)}%', Colors.orange),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16)),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Future<void> _sendNotification(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({
        'status': 'sent',
        'sentAt': FieldValue.serverTimestamp(),
        'sentCount': 0, // This would be updated by the actual sending logic
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notification sent successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _scheduleNotification(String notificationId, Map<String, dynamic> data) async {
    // This would open a date/time picker dialog
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (selectedDate != null) {
      final selectedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (selectedTime != null) {
        final scheduledDateTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          selectedTime.hour,
          selectedTime.minute,
        );

        try {
          await FirebaseFirestore.instance
              .collection('notifications')
              .doc(notificationId)
              .update({
            'status': 'scheduled',
            'scheduledFor': Timestamp.fromDate(scheduledDateTime),
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Notification scheduled for ${DateFormat('MMM dd, yyyy HH:mm').format(scheduledDateTime)}'),
                backgroundColor: Colors.purple,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error scheduling notification: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _cancelScheduledNotification(String notificationId) async {
    try {
      await FirebaseFirestore.instance
          .collection('notifications')
          .doc(notificationId)
          .update({
        'status': 'draft',
        'scheduledFor': FieldValue.delete(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Scheduled notification cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cancelling notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteNotification(String notificationId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notification'),
        content: Text('Are you sure you want to delete "$title"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(notificationId)
            .delete();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Notification deleted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting notification: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

class _CreateNotificationDialog extends StatefulWidget {
  final String? notificationId;
  final Map<String, dynamic>? initialData;
  final VoidCallback onNotificationCreated;

  const _CreateNotificationDialog({
    this.notificationId,
    this.initialData,
    required this.onNotificationCreated,
  });

  @override
  State<_CreateNotificationDialog> createState() => _CreateNotificationDialogState();
}

class _CreateNotificationDialogState extends State<_CreateNotificationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedType = 'tips';
  String _selectedTargetAudience = 'all';

  @override
  void initState() {
    super.initState();
    
    if (widget.initialData != null) {
      _titleController.text = widget.initialData!['title'] ?? '';
      _messageController.text = widget.initialData!['message'] ?? '';
      _selectedType = widget.initialData!['type'] ?? 'tips';
      _selectedTargetAudience = widget.initialData!['targetAudience'] ?? 'all';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              widget.notificationId != null ? 'Edit Notification' : 'Create New Notification',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Title
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Type
                      DropdownButtonFormField<String>(
                        value: _selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Notification Type',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'tips', child: Text('Nutrition Tips')),
                          DropdownMenuItem(value: 'updates', child: Text('App Updates')),
                          DropdownMenuItem(value: 'news', child: Text('Health News')),
                          DropdownMenuItem(value: 'reminders', child: Text('Meal Reminders')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedType = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Target Audience
                      DropdownButtonFormField<String>(
                        value: _selectedTargetAudience,
                        decoration: const InputDecoration(
                          labelText: 'Target Audience',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Users')),
                          DropdownMenuItem(value: 'nutritionist', child: Text('Nutritionists')),
                          DropdownMenuItem(value: 'admin', child: Text('Admins')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedTargetAudience = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Message
                      TextFormField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          labelText: 'Message',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 8,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a message';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _saveNotification,
                  child: Text(widget.notificationId != null ? 'Update' : 'Create'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveNotification() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      final data = {
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
        'type': _selectedType,
        'targetAudience': _selectedTargetAudience,
        'status': 'draft',
        'lastUpdated': FieldValue.serverTimestamp(),
        'createdBy': 'nutritionist',
        'sentCount': 0,
        'readCount': 0,
      };

      if (widget.notificationId != null) {
        // Update existing notification
        await FirebaseFirestore.instance
            .collection('notifications')
            .doc(widget.notificationId)
            .update(data);
      } else {
        // Create new notification
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance
            .collection('notifications')
            .add(data);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onNotificationCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.notificationId != null ? 'Notification updated!' : 'Notification created!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
