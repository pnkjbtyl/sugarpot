import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../main.dart';
import '../utils/config.dart';

class UserProfileDetailsScreen extends StatelessWidget {
  final Map<String, dynamic> user;

  const UserProfileDetailsScreen({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final profileImageUrl = user['profileImage'] != null
        ? AppConfig.buildImageUrl(user['profileImage'])
        : null;
    final gallery = user['gallery'] as Map<String, dynamic>?;
    final publicGallery = gallery?['public'] as List<dynamic>? ?? [];
    
    // Debug logging
    debugPrint('[PROFILE_DETAILS] User: ${user['name']}');
    debugPrint('[PROFILE_DETAILS] Gallery: $gallery');
    debugPrint('[PROFILE_DETAILS] Public Gallery count: ${publicGallery.length}');
    if (publicGallery.isNotEmpty) {
      debugPrint('[PROFILE_DETAILS] First gallery item: ${publicGallery[0]}');
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(user['name'] ?? 'Profile'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Image
            GestureDetector(
              onTap: profileImageUrl != null
                  ? () => _showImageViewer(context, profileImageUrl)
                  : null,
              child: profileImageUrl != null
                  ? Container(
                      width: double.infinity,
                      height: 300,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                      ),
                      child: CachedNetworkImage(
                        imageUrl: profileImageUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(Icons.person, size: 100, color: Colors.grey),
                        ),
                      ),
                    )
                  : Container(
                      width: double.infinity,
                      height: 300,
                      color: Colors.grey[300],
                      child: const Center(
                        child: Icon(Icons.person, size: 100, color: Colors.grey),
                      ),
                    ),
            ),

            // User Info Section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and Gender
                  Row(
                    children: [
                      Text(
                        user['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (user['gender'] != null) ...[
                        const SizedBox(width: 8),
                        Icon(
                          user['gender'] == 'male'
                              ? Icons.male
                              : user['gender'] == 'female'
                                  ? Icons.female
                                  : Icons.transgender,
                          color: primaryColor,
                          size: 28,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Location
                  if (user['location'] != null) ...[
                    Row(
                      children: [
                        Icon(
                          Icons.location_on,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _formatLocation(user['location']),
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Bio
                  if (user['bio'] != null && user['bio'].toString().isNotEmpty) ...[
                    Text(
                      'About',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      user['bio'],
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Pickup Line
                  if (user['pickupLine'] != null && user['pickupLine'].toString().isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: primaryColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.favorite,
                            color: primaryColor,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              user['pickupLine'],
                              style: TextStyle(
                                fontSize: 16,
                                fontStyle: FontStyle.italic,
                                color: Colors.grey[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Details Section
                  _buildDetailSection(
                    'Details',
                    [
                      if (user['profession'] != null)
                        _buildDetailItem(Icons.work, 'Profession', user['profession']),
                      if (user['eatingHabits'] != null)
                        _buildDetailItem(
                          Icons.restaurant,
                          'Eating Habits',
                          _capitalizeFirst(user['eatingHabits']),
                        ),
                      if (user['smoking'] != null)
                        _buildDetailItem(
                          Icons.smoking_rooms,
                          'Smoking',
                          _capitalizeFirst(user['smoking']),
                        ),
                      if (user['drinking'] != null)
                        _buildDetailItem(
                          Icons.local_bar,
                          'Drinking',
                          _capitalizeFirst(user['drinking']),
                        ),
                    ],
                  ),

                  // Gallery Section
                  const SizedBox(height: 24),
                  Text(
                    'Gallery',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (publicGallery.isNotEmpty)
                    _buildGalleryGrid(publicGallery)
                  else
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No gallery items available',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(String title, List<Widget> items) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 12),
        ...items,
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: primaryColor),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGalleryGrid(List<dynamic> gallery) {
    debugPrint('[GALLERY_GRID] Building grid with ${gallery.length} items');
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: gallery.length,
      itemBuilder: (context, index) {
        final media = gallery[index];
        debugPrint('[GALLERY_GRID] Item $index: $media');
        final thumbnailUrl = media['thumbnailUrl'] ?? media['url'];
        final mediaUrl = media['url'];
        final isVideo = media['type'] == 'video';
        
        final fullThumbnailUrl = AppConfig.buildImageUrl(thumbnailUrl);
        final fullMediaUrl = AppConfig.buildImageUrl(mediaUrl);
        debugPrint('[GALLERY_GRID] Thumbnail: $fullThumbnailUrl, Media: $fullMediaUrl, IsVideo: $isVideo');

        return GestureDetector(
          onTap: () => _viewMedia(context, media),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: isVideo
                    ? _buildVideoThumbnail(fullThumbnailUrl, fullMediaUrl)
                    : CachedNetworkImage(
                        imageUrl: fullThumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[300],
                          child: const Center(child: CircularProgressIndicator()),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[300],
                          child: const Icon(Icons.error),
                        ),
                      ),
              ),
              if (isVideo)
                const Center(
                  child: Icon(
                    Icons.play_circle_filled,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVideoThumbnail(String thumbnailUrl, String videoUrl) {
    return CachedNetworkImage(
      imageUrl: thumbnailUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(
        color: Colors.grey[300],
        child: const Center(child: CircularProgressIndicator()),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey[300],
        child: const Icon(Icons.error),
      ),
    );
  }

  void _viewMedia(BuildContext context, Map<String, dynamic> media) {
    final mediaUrl = media['url'];
    final isVideo = media['type'] == 'video';
    final fullMediaUrl = AppConfig.buildImageUrl(mediaUrl);

    if (isVideo) {
      _showVideoPlayer(context, fullMediaUrl);
    } else {
      _showImageViewer(context, fullMediaUrl);
    }
  }

  void _showImageViewer(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: primaryColor,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: SizedBox(
                  width: double.infinity,
                  height: double.infinity,
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
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoPlayer(BuildContext context, String videoUrl) {
    showDialog(
      context: context,
      barrierColor: primaryColor,
      builder: (context) => _VideoPlayerDialog(videoUrl: videoUrl),
    );
  }

  String _formatLocation(Map<String, dynamic> location) {
    final parts = <String>[];
    if (location['city'] != null && location['city'].toString().isNotEmpty) {
      parts.add(location['city']);
    }
    if (location['state'] != null && location['state'].toString().isNotEmpty) {
      parts.add(location['state']);
    }
    if (location['countryCode'] != null && location['countryCode'].toString().isNotEmpty) {
      parts.add('(${location['countryCode']})');
    }
    return parts.join(', ');
  }

  String _capitalizeFirst(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}

class _VideoPlayerDialog extends StatefulWidget {
  final String videoUrl;

  const _VideoPlayerDialog({required this.videoUrl});

  @override
  State<_VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<_VideoPlayerDialog> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
          _errorMessage = null;
        });
        _controller!.play();
      }
    } catch (e) {
      debugPrint('[VIDEO_PLAYER] Error initializing video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Center(
          child: _hasError
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.white, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Error loading video',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _hasError = false;
                          _isInitialized = false;
                          _errorMessage = null;
                        });
                        _initializeVideo();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                )
              : _isInitialized && _controller != null
                  ? Center(
                      child: AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      ),
                    )
                  : const CircularProgressIndicator(color: Colors.white),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 30),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        if (_isInitialized && _controller != null)
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton(
              onPressed: () {
                setState(() {
                  if (_controller!.value.isPlaying) {
                    _controller!.pause();
                  } else {
                    _controller!.play();
                  }
                });
              },
              backgroundColor: Colors.black54,
              child: Icon(
                _controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}
