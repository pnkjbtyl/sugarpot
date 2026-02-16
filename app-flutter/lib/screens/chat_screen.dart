import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:file_picker/file_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/match_provider.dart';
import '../main.dart';
import '../services/socket_service.dart';
import '../services/api_service.dart';
import '../utils/config.dart';
import 'user_profile_details_screen.dart';
import 'home_screen.dart';

class ChatScreen extends StatefulWidget {
  final String matchId;
  final Map<String, dynamic> otherUser;
  final Map<String, dynamic>? location;

  const ChatScreen({
    super.key,
    required this.matchId,
    required this.otherUser,
    this.location,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ApiService _apiService = ApiService();
  IO.Socket? _socket;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isUploading = false;
  String? _currentUserId;
  DateTime? _clearedAt; // Timestamp when chat was cleared

  @override
  void initState() {
    super.initState();
    _loadClearedState();
    _initializeSocket();
  }

  Future<void> _loadClearedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final clearedTimestamp = prefs.getInt('cleared_chat_${widget.matchId}');
      if (clearedTimestamp != null) {
        setState(() {
          _clearedAt = DateTime.fromMillisecondsSinceEpoch(clearedTimestamp);
        });
      }
    } catch (e) {
      debugPrint('Error loading cleared state: $e');
    }
  }

  Future<void> _initializeSocket() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      _currentUserId = authProvider.user?['id'] ?? authProvider.user?['_id'] ?? '';
      
      _socket = await SocketService.getSocket();
      
      // Listen for new messages
      _socket!.on('new_message', (data) {
        // Always show new messages, even if chat was cleared
        setState(() {
          _messages.add(data);
        });
        _scrollToBottom();
        _markAsDelivered([data['id']]);
      });

      // Listen for message sent confirmation
      _socket!.on('message_sent', (data) {
        // Always show sent messages, even if chat was cleared
        setState(() {
          final index = _messages.indexWhere((msg) => 
            msg['id'] == null && msg['messageText'] == data['messageText']
          );
          if (index != -1) {
            _messages[index] = data;
          } else {
            _messages.add(data);
          }
        });
        _scrollToBottom();
      });

      // Listen for delivery confirmation
      _socket!.on('message_delivered', (data) {
        setState(() {
          final index = _messages.indexWhere((msg) => msg['id'] == data['id']);
          if (index != -1) {
            _messages[index]['isDelivered'] = true;
            _messages[index]['deliveredAt'] = data['deliveredAt'];
          }
        });
      });

      // Listen for message history
      _socket!.on('messages_history', (data) {
        setState(() {
          final allMessages = List<Map<String, dynamic>>.from(data);
          // Filter out messages before cleared timestamp if chat was cleared
          if (_clearedAt != null) {
            _messages = allMessages.where((msg) {
              try {
                final sentAt = DateTime.parse(msg['sentAt'] ?? '');
                return sentAt.isAfter(_clearedAt!);
              } catch (e) {
                // If parsing fails, include the message (better safe than sorry)
                return true;
              }
            }).toList();
          } else {
            _messages = allMessages;
          }
          _isLoading = false;
        });
        _scrollToBottom();
      });

      // Listen for errors
      _socket!.on('error', (data) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message'] ?? 'An error occurred'),
            backgroundColor: Colors.red,
          ),
        );
      });

      // Request message history
      _socket!.emit('get_messages', {
        'matchId': widget.matchId,
        'limit': 50
      });

      // Mark existing messages as delivered
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final undeliveredIds = _messages
            .where((msg) => 
              msg['senderId'] == _currentUserId && 
              !msg['isDelivered'] && 
              msg['id'] != null
            )
            .map((msg) => msg['id'] as int)
            .toList();
        if (undeliveredIds.isNotEmpty) {
          _markAsDelivered(undeliveredIds);
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _markAsDelivered(List<int> messageIds) {
    _socket?.emit('mark_delivered', {'messageIds': messageIds});
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage({String? messageType, String? messageText}) {
    final text = messageText ?? _messageController.text.trim();
    if (text.isEmpty || _socket == null || !_socket!.connected) return;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.user?['id'] ?? authProvider.user?['_id'] ?? '';
    final receiverId = widget.otherUser['id'] ?? widget.otherUser['_id'] ?? '';

    // Add temporary message to UI immediately
    final tempMessage = {
      'id': null,
      'sequenceId': _messages.length + 1,
      'messageType': messageType ?? 'text',
      'messageText': text,
      'isSent': true,
      'isDelivered': false,
      'sentAt': DateTime.now().toIso8601String(),
      'deliveredAt': null,
      'senderId': currentUserId.toString(),
      'receiverId': receiverId.toString(),
    };

    setState(() {
      _messages.add(tempMessage);
    });
    if (messageType == null) {
      _messageController.clear();
    }
    _scrollToBottom();

    // Send via socket
    _socket!.emit('send_message', {
      'matchId': widget.matchId,
      'receiverId': receiverId,
      'messageType': messageType ?? 'text',
      'messageText': text,
    });
  }

  Future<void> _pickAndUploadFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'gif', 'webp', 'mp4', 'mov', 'avi', 'mp3', 'wav', 'aac', 'ogg'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        await _uploadFile(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<File?> _compressImage(File imageFile) async {
    try {
      final result = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path,
        '${imageFile.path}_compressed.jpg',
        minWidth: 800,
        minHeight: 800,
        quality: 85,
        keepExif: false,
      );
      return result != null ? File(result.path) : null;
    } catch (e) {
      debugPrint('Error compressing image: $e');
      return imageFile; // Return original if compression fails
    }
  }

  Future<File?> _compressVideo(File videoFile) async {
    try {
      // Check original file size first
      final originalSize = await videoFile.length();
      final maxSize = 200 * 1024 * 1024; // 200MB
      
      debugPrint('[COMPRESS] Original video size: ${(originalSize / 1024 / 1024).toStringAsFixed(2)}MB');
      
      // Compress video with aggressive settings to reduce size
      debugPrint('[COMPRESS] Starting video compression...');
      
      try {
        // Try resolution-based quality first to force lower resolution (closest to 800px width)
        // Res960x540Quality = 960x540 (closest to 800px width constraint)
        debugPrint('[COMPRESS] Attempting compression with Res960x540Quality (960x540 resolution)...');
        MediaInfo? mediaInfo;
        
        try {
          mediaInfo = await VideoCompress.compressVideo(
            videoFile.path,
            quality: VideoQuality.Res960x540Quality, // Force 960x540 resolution (closest to 800px width)
            deleteOrigin: false,
            includeAudio: true,
          );
          debugPrint('[COMPRESS] Res960x540Quality compression completed');
        } catch (e) {
          debugPrint('[COMPRESS] Res960x540Quality failed: $e, trying Res640x480Quality...');
          // Fallback to lower resolution
          try {
            mediaInfo = await VideoCompress.compressVideo(
              videoFile.path,
              quality: VideoQuality.Res640x480Quality, // Force 640x480 resolution
              deleteOrigin: false,
              includeAudio: true,
            );
            debugPrint('[COMPRESS] Res640x480Quality compression completed');
          } catch (e2) {
            debugPrint('[COMPRESS] Res640x480Quality also failed: $e2, trying LowQuality...');
            // Final fallback to quality-based compression
            mediaInfo = await VideoCompress.compressVideo(
              videoFile.path,
              quality: VideoQuality.LowQuality,
              deleteOrigin: false,
              includeAudio: true,
            );
            debugPrint('[COMPRESS] LowQuality compression completed');
          }
        }
        
        debugPrint('[COMPRESS] VideoCompress.compressVideo completed');
        debugPrint('[COMPRESS] MediaInfo: ${mediaInfo?.path ?? "null"}');
        
        if (mediaInfo != null && mediaInfo.path != null && mediaInfo.path!.isNotEmpty) {
          final compressedFile = File(mediaInfo.path!);
          
          debugPrint('[COMPRESS] Compressed file path: ${compressedFile.path}');
          debugPrint('[COMPRESS] Original file path: ${videoFile.path}');
          debugPrint('[COMPRESS] Are paths the same? ${compressedFile.path == videoFile.path}');
          
          // Check if compression actually created a different file
          if (compressedFile.path == videoFile.path) {
            debugPrint('[COMPRESS] WARNING: Compressed file path is same as original - compression may not have occurred');
            debugPrint('[COMPRESS] Trying DefaultQuality as last resort...');
            try {
              final fallbackInfo = await VideoCompress.compressVideo(
                videoFile.path,
                quality: VideoQuality.DefaultQuality,
                deleteOrigin: false,
                includeAudio: true,
              );
              if (fallbackInfo != null && fallbackInfo.path != null && fallbackInfo.path!.isNotEmpty) {
                final fallbackFile = File(fallbackInfo.path!);
                if (fallbackFile.path != videoFile.path) {
                  debugPrint('[COMPRESS] Using DefaultQuality result');
                  mediaInfo = fallbackInfo;
                }
              }
            } catch (e) {
              debugPrint('[COMPRESS] DefaultQuality also failed: $e');
            }
          }
          
          // Re-validate mediaInfo after potential fallback reassignment
          if (mediaInfo == null || mediaInfo.path == null || mediaInfo.path!.isEmpty) {
            debugPrint('[COMPRESS] MediaInfo is null or path is empty after fallback attempt');
            return null;
          }
          
          final finalFile = File(mediaInfo.path!);
          
          // Wait for file to be fully written (compression can take time)
          int retries = 0;
          while (!await finalFile.exists() && retries < 10) {
            await Future.delayed(const Duration(milliseconds: 500));
            retries++;
            debugPrint('[COMPRESS] Waiting for compressed file... (attempt $retries)');
          }
          
          if (await finalFile.exists()) {
            final compressedSize = await finalFile.length();
            debugPrint('[COMPRESS] Compressed video size: ${(compressedSize / 1024 / 1024).toStringAsFixed(2)}MB');
            debugPrint('[COMPRESS] Size reduction: ${((originalSize - compressedSize) / 1024 / 1024).toStringAsFixed(2)}MB (${((1 - compressedSize / originalSize) * 100).toStringAsFixed(1)}%)');
            
            // Check if compression actually reduced size (at least 5% reduction)
            if (compressedSize >= originalSize * 0.95) {
              debugPrint('[COMPRESS] WARNING: Compression didn\'t reduce size significantly (less than 5% reduction)');
              debugPrint('[COMPRESS] This may indicate video_compress is not working properly for this video format');
              // Still return the file if it's under the limit
            }
            
            // Check if compressed file is still too large
            if (compressedSize > maxSize) {
              debugPrint('[COMPRESS] Warning: Compressed video still exceeds size limit (${(compressedSize / 1024 / 1024).toStringAsFixed(2)}MB > ${(maxSize / 1024 / 1024).toStringAsFixed(2)}MB)');
              return null;
            }
            
            return finalFile;
          } else {
            debugPrint('[COMPRESS] Compressed file does not exist at: ${mediaInfo.path ?? "unknown"}');
          }
        } else {
          debugPrint('[COMPRESS] MediaInfo is null or path is empty');
        }
      } catch (e, stackTrace) {
        debugPrint('[COMPRESS] Error during compression: $e');
        debugPrint('[COMPRESS] Stack trace: $stackTrace');
        // If compression fails but original is under limit, use original
        if (originalSize <= maxSize) {
          debugPrint('[COMPRESS] Compression failed but original is under limit, using original');
          return videoFile;
        }
        // If compression fails and original is too large, return null to reject
        debugPrint('[COMPRESS] Compression failed and original is too large, rejecting file');
        return null;
      }
      
      debugPrint('[COMPRESS] Compression returned null or empty path');
      return null;
    } catch (e, stackTrace) {
      debugPrint('[COMPRESS] Error compressing video: $e');
      debugPrint('[COMPRESS] Stack trace: $stackTrace');
      return null;
    }
  }

  bool _isImageFile(String path) {
    final extension = path.toLowerCase();
    return extension.endsWith('.jpg') ||
        extension.endsWith('.jpeg') ||
        extension.endsWith('.png') ||
        extension.endsWith('.gif') ||
        extension.endsWith('.webp');
  }

  bool _isVideoFile(String path) {
    final extension = path.toLowerCase();
    return extension.endsWith('.mp4') ||
        extension.endsWith('.mov') ||
        extension.endsWith('.avi');
  }

  Future<void> _uploadFile(File file) async {
    setState(() {
      _isUploading = true;
    });

    try {
      File? fileToUpload = file;
      
      // Compress image or video before uploading
      if (_isImageFile(file.path)) {
        debugPrint('[CHAT_UPLOAD] Compressing image...');
        final compressedFile = await _compressImage(file);
        if (compressedFile != null) {
          fileToUpload = compressedFile;
          debugPrint('[CHAT_UPLOAD] Image compressed successfully');
        } else {
          debugPrint('[CHAT_UPLOAD] Image compression failed, using original');
          fileToUpload = file;
        }
      } else if (_isVideoFile(file.path)) {
        debugPrint('[CHAT_UPLOAD] Compressing video...');
        final compressedFile = await _compressVideo(file);
        if (compressedFile != null) {
          fileToUpload = compressedFile;
          debugPrint('[CHAT_UPLOAD] Video compressed successfully');
        } else {
          // Check if original is under limit
          final originalSize = await file.length();
          final maxSize = 200 * 1024 * 1024; // 200MB
          if (originalSize <= maxSize) {
            debugPrint('[CHAT_UPLOAD] Video compression failed but original is under limit, using original');
            fileToUpload = file;
          } else {
            if (mounted) {
              setState(() {
                _isUploading = false;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Video compression failed. File size is ${(originalSize / 1024 / 1024).toStringAsFixed(1)}MB. Maximum size is 200MB after compression. Please try again or select a smaller video.',
                  ),
                  backgroundColor: Colors.red,
                  duration: const Duration(seconds: 5),
                ),
              );
            }
            return;
          }
        }
      }
      // Audio files are uploaded as-is (no compression)

      final response = await _apiService.uploadChatMedia(fileToUpload);
      
      if (response['url'] != null && response['messageType'] != null) {
        _sendMessage(
          messageType: response['messageType'],
          messageText: response['url'],
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showUnmatchConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Unmatch User'),
        content: const Text('Are you sure you want to unmatch this user? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _showSecondUnmatchConfirmation();
            },
            child: const Text('Continue', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSecondUnmatchConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Unmatch'),
        content: const Text('This will remove the match and all chat history. Are you absolutely sure?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _unmatchUser();
            },
            child: const Text('Unmatch', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _unmatchUser() async {
    try {
      await _apiService.unmatchUser(widget.matchId);
      if (mounted) {
        // Refresh matches list
        final matchProvider = Provider.of<MatchProvider>(context, listen: false);
        await matchProvider.loadMyMatches();
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User unmatched successfully')),
        );
        
        // Navigate back to HomeScreen with Chat/Matches tab (index 2) selected
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HomeScreen(initialIndex: 2)),
          (route) => false, // Remove all previous routes
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to unmatch user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showReportDialog() {
    final descriptionController = TextEditingController();
    String selectedReason = '';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Report User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Reason:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...['Inappropriate content', 'Harassment', 'Spam', 'Fake profile', 'Other'].map((reason) {
                  return RadioListTile<String>(
                    title: Text(reason),
                    value: reason,
                    groupValue: selectedReason,
                    onChanged: (value) {
                      setDialogState(() {
                        selectedReason = value!;
                      });
                    },
                  );
                }),
                if (selectedReason.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Additional details (optional):'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      hintText: 'Provide more details...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: selectedReason.isEmpty
                  ? null
                  : () async {
                      Navigator.of(context).pop();
                      await _reportUser(selectedReason, descriptionController.text);
                    },
              child: const Text('Report'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _reportUser(String reason, String description) async {
    try {
      final reportedUserId = widget.otherUser['id'] ?? widget.otherUser['_id'] ?? '';
      await _apiService.reportUser(reportedUserId, reason, description: description);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User reported successfully. Thank you for your feedback.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to report user: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showClearChatConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Chat'),
        content: const Text('This will hide all messages from your device. Messages will still be visible to the other user. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearChat();
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _clearChat() async {
    final now = DateTime.now();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('cleared_chat_${widget.matchId}', now.millisecondsSinceEpoch);
      
      setState(() {
        _clearedAt = now;
        // Filter out messages before cleared timestamp
        _messages = _messages.where((msg) {
          try {
            final sentAt = DateTime.parse(msg['sentAt'] ?? '');
            return sentAt.isAfter(now);
          } catch (e) {
            return false; // Exclude messages with invalid timestamps
          }
        }).toList();
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat cleared')),
        );
      }
    } catch (e) {
      debugPrint('Error clearing chat: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _socket?.off('new_message');
    _socket?.off('message_sent');
    _socket?.off('message_delivered');
    _socket?.off('messages_history');
    _socket?.off('error');
    super.dispose();
  }

  Widget _buildProfileImage() {
    final profileImageUrl = widget.otherUser['profileImage'] != null
        ? AppConfig.buildImageUrl(widget.otherUser['profileImage'])
        : null;

    if (profileImageUrl != null) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: profileImageUrl,
          width: 40,
          height: 40,
          fit: BoxFit.cover,
          placeholder: (context, url) => const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          errorWidget: (context, url, error) => const Icon(Icons.person),
        ),
      );
    } else {
      return const Icon(Icons.person, color: Colors.grey);
    }
  }

  bool _isUserActive(dynamic lastSeenAt) {
    if (lastSeenAt == null) {
      return false;
    }
    
    try {
      DateTime lastSeen;
      
      if (lastSeenAt is String) {
        lastSeen = DateTime.parse(lastSeenAt);
      } else if (lastSeenAt is Map) {
        final milliseconds = lastSeenAt['\$date'] ?? lastSeenAt['_seconds'] * 1000;
        lastSeen = DateTime.fromMillisecondsSinceEpoch(milliseconds is int ? milliseconds : milliseconds.toInt());
      } else if (lastSeenAt is int) {
        lastSeen = DateTime.fromMillisecondsSinceEpoch(lastSeenAt);
      } else {
        return false;
      }
      
      final now = DateTime.now();
      final difference = now.difference(lastSeen);
      final minutesAgo = difference.inMinutes;
      
      return minutesAgo < 3;
    } catch (e) {
      return false;
    }
  }

  String _formatTime(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dateTime = DateTime.parse(timestamp);
      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inDays == 0) {
        // Today - show time
        final hour = dateTime.hour;
        final minute = dateTime.minute.toString().padLeft(2, '0');
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
        return '$displayHour:$minute $period';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return '';
    }
  }

  Widget _buildMessageContent(Map<String, dynamic> message, bool isMe) {
    final messageType = message['messageType'] ?? 'text';
    final messageText = message['messageText'] ?? '';
    
    if (messageType == 'text') {
      return Text(
        messageText,
        style: TextStyle(
          color: isMe ? Colors.black87 : Colors.black87,
        ),
      );
    } else if (messageType == 'image') {
      final imageUrl = messageText.startsWith('http') ? messageText : AppConfig.buildImageUrl(messageText);
      return GestureDetector(
        onTap: () {
          showDialog(
            context: context,
            barrierColor: primaryColor,
            barrierDismissible: true,
            builder: (context) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.zero,
              child: Stack(
                children: [
                  Center(
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height,
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => const Center(
                            child: CircularProgressIndicator(color: Colors.white),
                          ),
                          errorWidget: (context, url, error) => const Center(
                            child: Icon(Icons.error, color: Colors.white, size: 48),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).padding.top + 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 28),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 250,
              maxHeight: 250,
            ),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: 250,
              height: 250,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 250,
                height: 250,
                color: Colors.grey[300],
                child: const Center(child: CircularProgressIndicator()),
              ),
              errorWidget: (context, url, error) => Container(
                width: 250,
                height: 250,
                color: Colors.grey[300],
                child: const Icon(Icons.error),
              ),
            ),
          ),
        ),
      );
    } else if (messageType == 'video') {
      final videoUrl = messageText.startsWith('http') ? messageText : AppConfig.buildImageUrl(messageText);
      return _VideoMessageWidget(videoUrl: videoUrl);
    } else if (messageType == 'audio') {
      final audioUrl = messageText.startsWith('http') ? messageText : AppConfig.buildImageUrl(messageText);
      return _AudioMessageWidget(audioUrl: audioUrl, isMe: isMe);
    }
    
    return Text(
      '[${messageType}]',
      style: TextStyle(
        color: isMe ? Colors.black87 : Colors.black87,
      ),
    );
  }

  Widget _buildMessageStatus(Map<String, dynamic> message) {
    if (message['senderId'] != _currentUserId) {
      return const SizedBox.shrink();
    }

    if (message['isDelivered'] == true) {
      return const Icon(Icons.done_all, size: 16, color: primaryColor);
    } else if (message['isSent'] == true) {
      return const Icon(Icons.done, size: 16, color: Colors.grey);
    }
    return const SizedBox(width: 16);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => UserProfileDetailsScreen(user: widget.otherUser),
              ),
            );
          },
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white,
                    child: _buildProfileImage(),
                  ),
                  if (_isUserActive(widget.otherUser['lastSeenAt']))
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.otherUser['name'] ?? 'Chat',
                      style: const TextStyle(fontSize: 16),
                    ),
                    if (widget.location != null)
                      Text(
                        widget.location!['name'] ?? '',
                        style: const TextStyle(fontSize: 12),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'unmatch') {
                _showUnmatchConfirmation();
              } else if (value == 'report') {
                _showReportDialog();
              } else if (value == 'clear') {
                _showClearChatConfirmation();
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'unmatch',
                child: Row(
                  children: [
                    Icon(Icons.block, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Unmatch'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'report',
                child: Row(
                  children: [
                    Icon(Icons.flag, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Report'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline, color: Colors.grey),
                    SizedBox(width: 8),
                    Text('Clear Chat'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (widget.location != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: primaryColor.withOpacity(0.1),
              child: Row(
                children: [
                  Icon(Icons.location_on, color: primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Meeting at: ${widget.location!['name']}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        if (widget.location!['address'] != null)
                          Text(
                            widget.location!['address'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty && _clearedAt != null
                    ? const Center(
                        child: Text('Chat cleared'),
                      )
                    : _messages.isEmpty
                        ? const Center(
                            child: Text('No messages yet. Start the conversation!'),
                          )
                        : ListView.builder(
                        reverse: true,
                        controller: _scrollController,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[_messages.length - 1 - index];
                          final isMe = message['senderId'] == _currentUserId;
                          final sentAt = message['sentAt'] as String?;

                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.75,
                              ),
                              child: Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 4,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                              decoration: BoxDecoration(
                                color: isMe ? const Color(0xFFF7D9ED) : Colors.grey[300],
                                borderRadius: BorderRadius.circular(20),
                              ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    _buildMessageContent(message, isMe),
                                    const SizedBox(height: 4),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (sentAt != null)
                                          Text(
                                            _formatTime(sentAt),
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: isMe
                                                  ? Colors.black54
                                                  : Colors.black54,
                                            ),
                                          ),
                                        const SizedBox(width: 4),
                                        _buildMessageStatus(message),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 0),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.attach_file, color: primaryColor),
                    onPressed: _isUploading ? null : _pickAndUploadFile,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.send, color: primaryColor),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Video message widget for chat
class _VideoMessageWidget extends StatefulWidget {
  final String videoUrl;

  const _VideoMessageWidget({required this.videoUrl});

  @override
  State<_VideoMessageWidget> createState() => _VideoMessageWidgetState();
}

class _VideoMessageWidgetState extends State<_VideoMessageWidget> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller!.initialize();
      _controller!.addListener(_videoListener);
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
    }
  }

  void _videoListener() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_videoListener);
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    if (_controller == null || !_isInitialized) return;

    if (_controller!.value.isPlaying) {
      _controller!.pause();
    } else {
      _controller!.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 250,
          maxHeight: 250,
        ),
        child: Container(
          width: 250,
          height: 250,
          color: Colors.grey[300],
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          barrierColor: primaryColor,
          barrierDismissible: true,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.zero,
            child: Stack(
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: _controller!.value.aspectRatio,
                    child: VideoPlayer(_controller!),
                  ),
                ),
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  right: 16,
                  child: FloatingActionButton(
                    onPressed: _togglePlayPause,
                    backgroundColor: Colors.black54,
                    child: Icon(
                      _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: 250,
          maxHeight: 250,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: Icon(
                  _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 48,
                ),
                onPressed: _togglePlayPause,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Audio message widget for chat
class _AudioMessageWidget extends StatefulWidget {
  final String audioUrl;
  final bool isMe;

  const _AudioMessageWidget({
    required this.audioUrl,
    required this.isMe,
  });

  @override
  State<_AudioMessageWidget> createState() => _AudioMessageWidgetState();
}

class _AudioMessageWidgetState extends State<_AudioMessageWidget> {
  // Static variable to track the currently playing audio player
  static AudioPlayer? _currentlyPlayingPlayer;
  
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initializeAudio();
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          _isLoading = state.processingState == ProcessingState.loading ||
              state.processingState == ProcessingState.buffering;
        });
        
        // Update currently playing player reference
        if (state.playing) {
          // If another player is playing, pause it
          if (_currentlyPlayingPlayer != null && _currentlyPlayingPlayer != _audioPlayer) {
            _currentlyPlayingPlayer!.pause();
          }
          _currentlyPlayingPlayer = _audioPlayer;
        } else if (_currentlyPlayingPlayer == _audioPlayer) {
          // If this player stopped and it was the currently playing one, clear reference
          _currentlyPlayingPlayer = null;
        }
      }
    });
    _audioPlayer.durationStream.listen((duration) {
      if (mounted && duration != null) {
        setState(() {
          _duration = duration;
        });
      }
    });
    _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() {
          _position = position;
        });
      }
    });
  }

  Future<void> _initializeAudio() async {
    try {
      setState(() {
        _isLoading = true;
      });
      await _audioPlayer.setUrl(widget.audioUrl);
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error initializing audio: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        // Pause this player
        await _audioPlayer.pause();
        if (_currentlyPlayingPlayer == _audioPlayer) {
          _currentlyPlayingPlayer = null;
        }
      } else {
        // Pause any currently playing audio
        if (_currentlyPlayingPlayer != null && _currentlyPlayingPlayer != _audioPlayer) {
          try {
            await _currentlyPlayingPlayer!.pause();
          } catch (e) {
            debugPrint('Error pausing previous audio: $e');
          }
        }
        // Start playing this audio
        await _audioPlayer.play();
        _currentlyPlayingPlayer = _audioPlayer;
      }
    } catch (e) {
      debugPrint('Error toggling playback: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play audio: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _seek(Duration position) async {
    try {
      await _audioPlayer.seek(position);
    } catch (e) {
      debugPrint('Error seeking: $e');
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  void dispose() {
    // If this player was the currently playing one, clear the reference
    if (_currentlyPlayingPlayer == _audioPlayer) {
      _currentlyPlayingPlayer = null;
    }
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        maxWidth: 250,
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: widget.isMe ? const Color.fromARGB(255, 252, 234, 246) : Colors.grey[400],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              widget.isMe ? primaryColor : Colors.black87,
                            ),
                          ),
                        )
                      : Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: widget.isMe ? primaryColor : Colors.black87,
                        ),
                  onPressed: _isInitialized ? _togglePlayPause : null,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Audio message',
                        style: TextStyle(
                          color: widget.isMe ? Colors.black87 : Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (_isInitialized && _duration != Duration.zero)
                        Text(
                          '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                          style: TextStyle(
                            color: widget.isMe ? Colors.black54 : Colors.black54,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (_isInitialized && _duration != Duration.zero)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: widget.isMe ? primaryColor : Colors.black87,
                    inactiveTrackColor: widget.isMe
                        ? primaryColor.withOpacity(0.3)
                        : Colors.black26,
                    thumbColor: widget.isMe ? primaryColor : Colors.black87,
                    overlayColor: widget.isMe
                        ? primaryColor.withOpacity(0.2)
                        : Colors.black12,
                    trackHeight: 2,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: math.min(
                      _position.inMilliseconds.toDouble(),
                      _duration.inMilliseconds.toDouble(),
                    ),
                    min: 0,
                    max: _duration.inMilliseconds.toDouble(),
                    onChanged: (value) {
                      _seek(Duration(milliseconds: value.toInt()));
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
