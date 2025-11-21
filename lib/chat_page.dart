import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';
import 'services/message_service.dart';
import 'user_profile_page.dart';
import 'recipe_detail_page.dart';

class ChatPage extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;

  const ChatPage({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Mark messages as read when opening chat
    MessageService.markMessagesAsRead(widget.conversationId, widget.otherUserId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    setState(() => _isSending = true);

    try {
      await MessageService.sendMessage(
        conversationId: widget.conversationId,
        recipientId: widget.otherUserId,
        message: message,
      );

      _messageController.clear();
      
      // Scroll to bottom after sending
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Parse user photo
    ImageProvider? profileImage;
    if (widget.otherUserPhoto != null && widget.otherUserPhoto!.isNotEmpty) {
      if (widget.otherUserPhoto!.startsWith('data:image')) {
        try {
          final base64Data = widget.otherUserPhoto!.split(',')[1];
          profileImage = MemoryImage(base64Decode(base64Data));
        } catch (e) {
          print('Error decoding base64: $e');
        }
      } else {
        profileImage = NetworkImage(widget.otherUserPhoto!);
      }
    }

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF2E7D32),
                Color(0xFF388E3C),
                Color(0xFF4CAF50),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(25),
              bottomRight: Radius.circular(25),
            ),
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UserProfilePage(
                      userId: widget.otherUserId,
                      isOwnProfile: false,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    backgroundImage: profileImage,
                    child: profileImage == null
                        ? Text(
                            widget.otherUserName[0].toUpperCase(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4CAF50),
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.otherUserName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                offset: Offset(0, 2),
                                blurRadius: 4,
                                color: Colors.black26,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        StreamBuilder<DocumentSnapshot>(
                          stream: FirebaseFirestore.instance
                              .collection('users')
                              .doc(widget.otherUserId)
                              .snapshots(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const SizedBox.shrink();
                            }
                            
                            final userData = snapshot.data!.data() as Map<String, dynamic>?;
                            final lastSeen = userData?['lastSeen'] as Timestamp?;
                            
                            return Text(
                              _getStatusText(lastSeen),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                                shadows: const [
                                  Shadow(
                                    offset: Offset(0, 1),
                                    blurRadius: 2,
                                    color: Colors.black26,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: MessageService.getMessages(widget.conversationId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF4CAF50)),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          'Error loading messages',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No messages yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Send a message to start chatting!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    return _buildMessageBubble(message);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> message) {
    final senderId = message['senderId'] as String;
    final messageText = message['message'] as String;
    final timestamp = message['timestamp'] as Timestamp?;
    final messageType = message['type'] as String?;
    final recipeData = message['recipeData'] as Map<String, dynamic>?;
    final isMe = senderId == currentUserId;

    String timeText = '';
    if (timestamp != null) {
      final messageTime = timestamp.toDate();
      timeText = '${messageTime.hour}:${messageTime.minute.toString().padLeft(2, '0')}';
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Profile picture for other user's messages (left side)
          if (!isMe) ...[
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(senderId).get(),
              builder: (context, snapshot) {
                String? profileImageUrl;
                String userName = widget.otherUserName;
                
                if (snapshot.hasData && snapshot.data!.exists) {
                  final userData = snapshot.data!.data() as Map<String, dynamic>?;
                  profileImageUrl = userData?['profileImage'];
                  userName = userData?['name'] ?? userData?['username'] ?? widget.otherUserName;
                }

                return CircleAvatar(
                  radius: 16,
                  backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                      ? (profileImageUrl.startsWith('data:image')
                          ? MemoryImage(base64Decode(profileImageUrl.split(',')[1]))
                          : NetworkImage(profileImageUrl) as ImageProvider)
                      : null,
                  backgroundColor: const Color(0xFF4CAF50),
                  child: profileImageUrl == null || profileImageUrl.isEmpty
                      ? Text(
                          userName[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                );
              },
            ),
            const SizedBox(width: 8),
          ],
          
          // Message bubble
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.65,
            ),
            decoration: BoxDecoration(
              color: isMe ? const Color(0xFF4CAF50) : Colors.grey[200],
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show recipe card if it's a recipe share, otherwise show regular text
                messageType == 'recipe_share' && recipeData != null
                    ? _buildRecipeCard(recipeData, isMe)
                    : Text(
                        messageText,
                        style: TextStyle(
                          color: isMe ? Colors.white : Colors.black87,
                          fontSize: 15,
                        ),
                      ),
                const SizedBox(height: 4),
                Text(
                  timeText,
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.grey[600],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          
          // Profile picture for current user's messages (right side)
          if (isMe) ...[
            const SizedBox(width: 8),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(currentUserId).get(),
              builder: (context, snapshot) {
                String? profileImageUrl;
                String userName = 'You';
                
                if (snapshot.hasData && snapshot.data!.exists) {
                  final userData = snapshot.data!.data() as Map<String, dynamic>?;
                  profileImageUrl = userData?['profileImage'];
                  userName = userData?['name'] ?? userData?['username'] ?? 'You';
                }

                return CircleAvatar(
                  radius: 16,
                  backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                      ? (profileImageUrl.startsWith('data:image')
                          ? MemoryImage(base64Decode(profileImageUrl.split(',')[1]))
                          : NetworkImage(profileImageUrl) as ImageProvider)
                      : null,
                  backgroundColor: const Color(0xFF2E7D32),
                  child: profileImageUrl == null || profileImageUrl.isEmpty
                      ? Text(
                          userName[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        )
                      : null,
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: _messageController,
                  maxLines: null,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _sendMessage(),
                  decoration: const InputDecoration(
                    hintText: 'Type a message...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFF2E7D32),
                    Color(0xFF4CAF50),
                  ],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF4CAF50).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                icon: _isSending
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 20),
                onPressed: _isSending ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText(Timestamp? lastSeen) {
    if (lastSeen == null) {
      return 'offline';
    }

    final now = DateTime.now();
    final lastSeenDate = lastSeen.toDate();
    final difference = now.difference(lastSeenDate);

    if (difference.inMinutes < 1) {
      return 'active now';
    } else if (difference.inMinutes < 60) {
      return 'active ${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return 'active ${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else if (difference.inDays < 7) {
      return 'active ${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    } else {
      return 'active ${(difference.inDays / 7).floor()} week${(difference.inDays / 7).floor() == 1 ? '' : 's'} ago';
    }
  }

  Widget _buildRecipeCard(Map<String, dynamic> recipeData, bool isMe) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: BoxDecoration(
        color: isMe ? Colors.white.withOpacity(0.2) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMe ? Colors.white.withOpacity(0.3) : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Recipe image
          if (recipeData['image'] != null && recipeData['image'].toString().isNotEmpty)
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              child: _buildRecipeImage(recipeData['image']),
            ),
          
          // Recipe details
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Recipe title
                Text(
                  recipeData['title'] ?? 'Unknown Recipe',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isMe ? Colors.white : Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                
                // Author
                Text(
                  'by ${recipeData['fullName'] ?? 'Unknown'}',
                  style: TextStyle(
                    fontSize: 12,
                    color: isMe ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                
                // Action buttons
                Row(
                  children: [
                    // View Recipe button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _viewSharedRecipe(recipeData),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isMe ? Colors.white : const Color(0xFF4CAF50),
                          foregroundColor: isMe ? const Color(0xFF4CAF50) : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: const Text('View Recipe'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    
                    // Add to Meal Plan button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _addSharedRecipeToMealPlan(recipeData),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isMe ? Colors.white.withOpacity(0.2) : Colors.grey[200],
                          foregroundColor: isMe ? Colors.white : Colors.black87,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                        child: const Text('Add to Plan'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeImage(String imagePath) {
    if (imagePath.startsWith('data:image')) {
      try {
        final base64String = imagePath.split(',')[1];
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          width: double.infinity,
          height: 120,
          fit: BoxFit.cover,
        );
      } catch (e) {
        return _buildPlaceholderImage();
      }
    } else {
      return Image.network(
        imagePath,
        width: double.infinity,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderImage(),
      );
    }
  }

  Widget _buildPlaceholderImage() {
    return Container(
      width: double.infinity,
      height: 120,
      color: Colors.grey[300],
      child: const Icon(
        Icons.restaurant,
        color: Colors.grey,
        size: 40,
      ),
    );
  }

  void _viewSharedRecipe(Map<String, dynamic> recipeData) {
    final normalizedRecipe = _normalizeSharedRecipe(recipeData);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RecipeDetailPage(
          recipe: normalizedRecipe,
        ),
      ),
    );
  }

  void _addSharedRecipeToMealPlan(Map<String, dynamic> recipeData) {
    final normalizedRecipe = _normalizeSharedRecipe(recipeData);

    showDialog(
      context: context,
      builder: (context) => _AddToMealPlanDialog(recipe: normalizedRecipe),
    );
  }

  Map<String, dynamic> _normalizeSharedRecipe(Map<String, dynamic> recipeData) {
    final normalized = Map<String, dynamic>.from(recipeData);

    // Ensure instructions exist as a human readable string
    final instructions = normalized['instructions'];
    if (instructions == null ||
        (instructions is String && instructions.trim().isEmpty) ||
        (instructions is List && instructions.isEmpty)) {
      final analyzed = normalized['analyzedInstructions'];
      final buffer = <String>[];

      if (analyzed is List) {
        for (final block in analyzed) {
          if (block is Map && block['steps'] is List) {
            final steps = block['steps'] as List;
            for (final step in steps) {
              if (step is Map && step['step'] != null) {
                buffer.add(step['step'].toString().trim());
              } else if (step != null) {
                buffer.add(step.toString().trim());
              }
            }
          }
        }
      }

      if (buffer.isNotEmpty) {
        normalized['instructions'] = buffer
            .asMap()
            .entries
            .map((entry) => '${entry.key + 1}. ${entry.value}')
            .join('\n');
      }
    } else if (instructions is List) {
      normalized['instructions'] = instructions
          .where((step) => step != null && step.toString().trim().isNotEmpty)
          .map((step) => step.toString().trim())
          .toList()
          .asMap()
          .entries
          .map((entry) => '${entry.key + 1}. ${entry.value}')
          .join('\n');
    }

    // Ensure ingredients list exists; fall back to extendedIngredients if needed
    if (normalized['ingredients'] == null && normalized['extendedIngredients'] != null) {
      final extendedIngredients = normalized['extendedIngredients'];
      if (extendedIngredients is List) {
        normalized['ingredients'] = extendedIngredients
            .map((ingredient) {
              if (ingredient is Map<String, dynamic>) {
                return ingredient['original']?.toString() ??
                    ingredient['name']?.toString() ??
                    '';
              }
              return ingredient?.toString() ?? '';
            })
            .where((ing) => ing.isNotEmpty)
            .toList();
      }
    }

    // Guarantee ingredients is a list for downstream usage
    if (normalized['ingredients'] is! List) {
      final ingredient = normalized['ingredients'];
      if (ingredient != null) {
        normalized['ingredients'] = [ingredient];
      } else {
        normalized['ingredients'] = [];
      }
    }

    return normalized;
  }
}

class _AddToMealPlanDialog extends StatefulWidget {
  final Map<String, dynamic> recipe;
  
  const _AddToMealPlanDialog({required this.recipe});
  
  @override
  State<_AddToMealPlanDialog> createState() => _AddToMealPlanDialogState();
}

class _AddToMealPlanDialogState extends State<_AddToMealPlanDialog> {
  DateTime _selectedDate = DateTime.now();
  String _selectedMealType = 'breakfast';
  
  final List<String> _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add to Meal Plan'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Add "${widget.recipe['title']}" to your meal plan:'),
          const SizedBox(height: 16),
          
          // Date picker
          ListTile(
            leading: const Icon(Icons.calendar_today),
            title: Text(
              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
            ),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date != null) {
                setState(() => _selectedDate = date);
              }
            },
          ),
          
          // Meal type dropdown
          DropdownButtonFormField<String>(
            value: _selectedMealType,
            decoration: const InputDecoration(
              labelText: 'Meal Type',
              prefixIcon: Icon(Icons.restaurant),
            ),
            items: _mealTypes.map((type) => DropdownMenuItem(
              value: type,
              child: Text(type.toUpperCase()),
            )).toList(),
            onChanged: (value) => setState(() => _selectedMealType = value!),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            await _addRecipeToMealPlan();
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4CAF50),
            foregroundColor: Colors.white,
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
  
  Future<void> _addRecipeToMealPlan() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final dateKey = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      
      // Add recipe to user's meal plan
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('meal_plans')
          .add({
        ...widget.recipe,
        'mealType': _selectedMealType,
        'date': dateKey,
        'addedAt': FieldValue.serverTimestamp(),
        'mealTime': _getDefaultTimeForMealType(_selectedMealType),
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Recipe added to meal plan!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding recipe: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  String _getDefaultTimeForMealType(String mealType) {
    switch (mealType) {
      case 'breakfast': return '07:00';
      case 'lunch': return '12:00';
      case 'dinner': return '18:00';
      case 'snack': return '15:00';
      default: return '12:00';
    }
  }
}
