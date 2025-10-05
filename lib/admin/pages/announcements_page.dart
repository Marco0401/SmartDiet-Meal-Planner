import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedStatus = 'All';

  final List<String> _statusOptions = ['All', 'Draft', 'Scheduled', 'Sent'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Broadcast System & Announcements'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {}); // Refresh
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Action Bar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search announcements...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                    ),
                    onChanged: (value) {
                      // TODO: Implement search functionality
                    },
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _selectedStatus,
                  items: _statusOptions.map((status) {
                    return DropdownMenuItem(value: status, child: Text(status));
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedStatus = value!;
                    });
                  },
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _showCreateAnnouncementDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('New Announcement'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Quick Actions
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    'Send Push Notification',
                    'Send immediate notification to all users',
                    Icons.notifications_active,
                    Colors.orange,
                    () => _showQuickNotificationDialog(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildQuickActionCard(
                    'Send Tips',
                    'Share helpful tips with users',
                    Icons.build,
                    Colors.blue,
                    () => _showTipsDialog(),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildQuickActionCard(
                    'Send Updates',
                    'Announce app updates and improvements',
                    Icons.new_releases,
                    Colors.green,
                    () => _showUpdatesDialog(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Announcements List
            Expanded(
              child: Card(
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Expanded(flex: 2, child: Text('Title', style: TextStyle(fontWeight: FontWeight.bold))),
                          const Expanded(flex: 1, child: Text('Type', style: TextStyle(fontWeight: FontWeight.bold))),
                          const Expanded(flex: 1, child: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          const Expanded(flex: 1, child: Text('Recipients', style: TextStyle(fontWeight: FontWeight.bold))),
                          const Expanded(flex: 1, child: Text('Scheduled', style: TextStyle(fontWeight: FontWeight.bold))),
                          const SizedBox(width: 120, child: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                    
                    // Announcements List
                    Expanded(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('announcements')
                            .orderBy('createdAt', descending: true)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError) {
                            return Center(
                              child: Text('Error: ${snapshot.error}'),
                            );
                          }

                          final announcements = snapshot.data?.docs ?? [];

                          if (announcements.isEmpty) {
                            return const Center(
                              child: Text('No announcements yet'),
                            );
                          }

                          return ListView.builder(
                            itemCount: announcements.length,
                            itemBuilder: (context, index) {
                              final doc = announcements[index];
                              final announcement = doc.data() as Map<String, dynamic>;
                          
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: Row(
                              children: [
                                // Title
                                Expanded(
                                  flex: 2,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        announcement['title'] ?? '',
                                        style: const TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        announcement['message'] ?? '',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Type
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getTypeColor(announcement['type'] ?? '').withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      announcement['type'] ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _getTypeColor(announcement['type'] ?? ''),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                
                                // Status
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(announcement['status'] ?? '').withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      announcement['status'] ?? '',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _getStatusColor(announcement['status'] ?? ''),
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                                
                                // Recipients
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    announcement['recipients'] ?? '',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                
                                // Scheduled
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    announcement['scheduled'] ?? '',
                                    style: const TextStyle(fontSize: 12),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                
                                // Actions
                                SizedBox(
                                  width: 120,
                                  child: Row(
                                    children: [
                                      IconButton(
                                        onPressed: () => _viewAnnouncement(announcement),
                                        icon: const Icon(Icons.visibility, size: 18),
                                        tooltip: 'View',
                                      ),
                                      IconButton(
                                        onPressed: () => _editAnnouncement(announcement),
                                        icon: const Icon(Icons.edit, size: 18),
                                        tooltip: 'Edit',
                                      ),
                                      IconButton(
                                        onPressed: () => _deleteAnnouncement(announcement),
                                        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                                        tooltip: 'Delete',
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }


  Color _getTypeColor(String type) {
    switch (type) {
      case 'Meal reminders': return Colors.orange;
      case 'Tips': return Colors.green;
      case 'Updates': return Colors.blue;
      case 'News': return Colors.purple;
      case 'None': return Colors.grey;
      default: return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Sent': return Colors.green;
      case 'Scheduled': return Colors.blue;
      case 'Draft': return Colors.orange;
      case 'Failed': return Colors.red;
      default: return Colors.grey;
    }
  }

  Future<void> _createAndSendAnnouncement(
    String title,
    String message,
    String type,
    String recipients,
  ) async {
    try {
      // Create announcement document
      final announcementRef = await FirebaseFirestore.instance
          .collection('announcements')
          .add({
        'title': title,
        'message': message,
        'type': type,
        'recipients': recipients,
        'status': 'Sent',
        'createdAt': FieldValue.serverTimestamp(),
        'scheduled': DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()),
        'sentBy': 'Admin',
      });

      // Get target users based on recipients filter
      Query usersQuery = FirebaseFirestore.instance.collection('users');
      
      if (recipients == 'Premium Users') {
        usersQuery = usersQuery.where('role', isEqualTo: 'premium');
      } else if (recipients == 'New Users') {
        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
        usersQuery = usersQuery.where('createdAt', isGreaterThan: Timestamp.fromDate(thirtyDaysAgo));
      }
      // For 'All Users', we don't add any filter

      final usersSnapshot = await usersQuery.get();
      
      print('DEBUG: Found ${usersSnapshot.docs.length} users for announcement');
      
      // Create notifications for each user
      final batch = FirebaseFirestore.instance.batch();
      int notificationCount = 0;
      int skippedCount = 0;
      
      for (final userDoc in usersSnapshot.docs) {
        final userData = userDoc.data() as Map<String, dynamic>;
        
        // Check if user has this type of notification enabled
        final userNotifications = userData['notifications'];
        
        // Handle both String and List formats for notifications
        bool shouldSkip = false;
        if (type != 'Maintenance') { // Maintenance notifications are always sent
          if (userNotifications is String) {
            shouldSkip = userNotifications == 'None';
          } else if (userNotifications is List) {
            shouldSkip = userNotifications.contains('None');
            // Don't skip if the list doesn't contain the type - assume they want all types unless explicitly disabled
          } else if (userNotifications == null) {
            // If no notification preferences set, assume they want all notifications
            shouldSkip = false;
          }
        }
        
        if (shouldSkip) {
          print('DEBUG: Skipping user ${userDoc.id} - notifications: $userNotifications');
          skippedCount++;
          continue; // Skip if user disabled notifications
        }
        
        print('DEBUG: Sending notification to user ${userDoc.id} - notifications: $userNotifications');
        
        // Create notification document in user's subcollection
        final notificationRef = FirebaseFirestore.instance
            .collection('users')
            .doc(userDoc.id)
            .collection('notifications')
            .doc();
            
        batch.set(notificationRef, {
          'title': title,
          'message': message,
          'type': type,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
          'announcementId': announcementRef.id,
          'icon': _getTypeIcon(type),
          'color': _getTypeColor(type).value,
        });
        
        notificationCount++;
      }
      
      // Commit all notifications
      await batch.commit();
      
      // Update announcement with sent count
      await announcementRef.update({
        'sentCount': notificationCount,
      });

      print('DEBUG: Final stats - Sent: $notificationCount, Skipped: $skippedCount, Total: ${usersSnapshot.docs.length}');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Announcement sent to $notificationCount users! (Skipped: $skippedCount)'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      print('Error sending announcement: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending announcement: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  int _getTypeIcon(String type) {
    switch (type) {
      case 'Meal reminders':
        return Icons.restaurant.codePoint;
      case 'Tips':
        return Icons.lightbulb.codePoint;
      case 'Updates':
        return Icons.system_update.codePoint;
      case 'News':
        return Icons.newspaper.codePoint;
      case 'None':
        return Icons.circle.codePoint;
      default:
        return Icons.notifications.codePoint;
    }
  }


  void _showCreateAnnouncementDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String selectedType = 'News';
    String selectedRecipients = 'All Users';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create New Announcement'),
          content: SizedBox(
            width: 500,
            height: 400,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Message
                Expanded(
                  child: TextField(
                    controller: messageController,
                    maxLines: null,
                    expands: true,
                    decoration: const InputDecoration(
                      labelText: 'Message',
                      border: OutlineInputBorder(),
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Type
                Row(
                  children: [
                    const Text('Type: '),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: selectedType,
                      items: ['None', 'Meal reminders', 'Tips', 'Updates', 'News']
                          .map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(type),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedType = value!;
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Recipients
                Row(
                  children: [
                    const Text('Recipients: '),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: selectedRecipients,
                      items: ['All Users', 'Premium Users', 'New Users']
                          .map((recipient) => DropdownMenuItem(
                                value: recipient,
                                child: Text(recipient),
                              ))
                          .toList(),
                      onChanged: (value) {
                        setState(() {
                          selectedRecipients = value!;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty || 
                    messageController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill in all fields'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }
                
                await _createAndSendAnnouncement(
                  titleController.text.trim(),
                  messageController.text.trim(),
                  selectedType,
                  selectedRecipients,
                );
                
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
              ),
              child: const Text('Send Announcement'),
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickNotificationDialog() {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Quick Notification'),
        content: SizedBox(
          width: 400,
          height: 200,
          child: Column(
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: messageController,
                  maxLines: null,
                  expands: true,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty || 
                  messageController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              await _createAndSendAnnouncement(
                titleController.text.trim(),
                messageController.text.trim(),
                'Updates',
                'All Users',
              );
              
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  void _showTipsDialog() {
    final titleController = TextEditingController(text: 'Health Tips');
    final messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Tips Notification'),
        content: SizedBox(
          width: 400,
          height: 200,
          child: Column(
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: messageController,
                  maxLines: null,
                  expands: true,
                  decoration: const InputDecoration(
                    labelText: 'Tips Content',
                    hintText: 'e.g., Did you know that drinking water before meals can help with portion control?',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty || 
                  messageController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              await _createAndSendAnnouncement(
                titleController.text.trim(),
                messageController.text.trim(),
                'Tips',
                'All Users',
              );
              
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send Notification'),
          ),
        ],
      ),
    );
  }

  void _showUpdatesDialog() {
    final titleController = TextEditingController(text: 'App Update Available!');
    final messageController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Updates Notification'),
        content: SizedBox(
          width: 400,
          height: 200,
          child: Column(
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TextField(
                  controller: messageController,
                  maxLines: null,
                  expands: true,
                  decoration: const InputDecoration(
                    labelText: 'Update Description',
                    hintText: 'e.g., We\'ve improved the meal planning algorithm for better recommendations...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty || 
                  messageController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please fill in all fields'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              await _createAndSendAnnouncement(
                titleController.text.trim(),
                messageController.text.trim(),
                'Updates',
                'All Users',
              );
              
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            child: const Text('Announce'),
          ),
        ],
      ),
    );
  }

  void _viewAnnouncement(Map<String, dynamic> announcement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(announcement['title'] ?? 'Announcement'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Type: ${announcement['type'] ?? 'Unknown'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Recipients: ${announcement['recipients'] ?? 'Unknown'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Status: ${announcement['status'] ?? 'Unknown'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(announcement['message'] ?? 'No message'),
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

  void _editAnnouncement(Map<String, dynamic> announcement) {
    showDialog(
      context: context,
      builder: (context) => EditAnnouncementDialog(
        announcement: announcement,
        onAnnouncementUpdated: () {
          setState(() {});
        },
      ),
    );
  }

  void _deleteAnnouncement(Map<String, dynamic> announcement) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Announcement'),
        content: Text('Are you sure you want to delete "${announcement['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                // Find the document ID - we need to get it from the document reference
                final querySnapshot = await FirebaseFirestore.instance
                    .collection('announcements')
                    .where('title', isEqualTo: announcement['title'])
                    .where('message', isEqualTo: announcement['message'])
                    .limit(1)
                    .get();

                if (querySnapshot.docs.isNotEmpty) {
                  await querySnapshot.docs.first.reference.delete();
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Announcement deleted successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting announcement: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class EditAnnouncementDialog extends StatefulWidget {
  final Map<String, dynamic> announcement;
  final VoidCallback onAnnouncementUpdated;

  const EditAnnouncementDialog({
    super.key,
    required this.announcement,
    required this.onAnnouncementUpdated,
  });

  @override
  State<EditAnnouncementDialog> createState() => _EditAnnouncementDialogState();
}

class _EditAnnouncementDialogState extends State<EditAnnouncementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _messageController = TextEditingController();
  
  String? _selectedType;
  String? _selectedPriority;
  DateTime? _selectedScheduledDate;
  bool _isUpdating = false;

  final List<String> _types = [
    'None', 'Meal reminders', 'Tips', 'Updates', 'News'
  ];
  final List<String> _priorities = ['Low', 'Medium', 'High', 'Critical'];

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    _titleController.text = widget.announcement['title'] ?? '';
    _messageController.text = widget.announcement['message'] ?? '';
    _selectedType = widget.announcement['type'] ?? 'None';
    _selectedPriority = widget.announcement['priority'] ?? 'Medium';
    
    // Parse scheduled date
    if (widget.announcement['scheduledDate'] != null) {
      try {
        _selectedScheduledDate = DateTime.parse(widget.announcement['scheduledDate']);
      } catch (e) {
        print('Error parsing scheduled date: $e');
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _updateAnnouncement() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isUpdating = true;
    });

    try {
      final announcementData = {
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
        'type': _selectedType,
        'priority': _selectedPriority,
        'scheduledDate': _selectedScheduledDate?.toIso8601String(),
        'updatedAt': DateTime.now().toIso8601String(),
        'updatedBy': 'admin',
      };

      await FirebaseFirestore.instance
          .collection('announcements')
          .doc(widget.announcement['id'])
          .update(announcementData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Announcement "${_titleController.text.trim()}" updated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }

      widget.onAnnouncementUpdated();

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('Error updating announcement: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating announcement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 20,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFE8F5E8),
              Color(0xFFC8E6C9),
            ],
          ),
        ),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.edit, color: Colors.purple, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Edit Announcement',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.purple,
                            ),
                          ),
                          Text(
                            'Update: ${_titleController.text}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // Form fields
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Announcement Title',
                  prefixIcon: Icon(Icons.title),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _messageController,
                decoration: const InputDecoration(
                  labelText: 'Message',
                  prefixIcon: Icon(Icons.message),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                maxLines: 4,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a message';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        prefixIcon: Icon(Icons.category),
                        border: OutlineInputBorder(),
                      ),
                      items: _types.map((type) {
                        return DropdownMenuItem<String>(
                          value: type,
                          child: Text(type),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedType = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a type';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedPriority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        prefixIcon: Icon(Icons.priority_high),
                        border: OutlineInputBorder(),
                      ),
                      items: _priorities.map((priority) {
                        return DropdownMenuItem<String>(
                          value: priority,
                          child: Text(priority),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedPriority = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please select a priority';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              InkWell(
                onTap: _selectScheduledDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Scheduled Date (optional)',
                    prefixIcon: Icon(Icons.schedule),
                    border: OutlineInputBorder(),
                  ),
                  child: Text(
                    _selectedScheduledDate != null
                        ? '${_selectedScheduledDate!.day}/${_selectedScheduledDate!.month}/${_selectedScheduledDate!.year} ${_selectedScheduledDate!.hour}:${_selectedScheduledDate!.minute.toString().padLeft(2, '0')}'
                        : 'Select scheduled date',
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isUpdating ? null : () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isUpdating ? null : _updateAnnouncement,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                      child: _isUpdating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Update Announcement'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectScheduledDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedScheduledDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    
    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime: _selectedScheduledDate != null
            ? TimeOfDay.fromDateTime(_selectedScheduledDate!)
            : TimeOfDay.now(),
      );
      
      if (time != null) {
        setState(() {
          _selectedScheduledDate = DateTime(
            picked.year,
            picked.month,
            picked.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }
}
