import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:video_player/video_player.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../main.dart';
import '../theme/app_colors.dart';
import '../utils/config.dart';

class PhotosMediaScreen extends StatefulWidget {
  const PhotosMediaScreen({super.key});

  @override
  State<PhotosMediaScreen> createState() => _PhotosMediaScreenState();
}

class _PhotosMediaScreenState extends State<PhotosMediaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ApiService _apiService = ApiService();
  List<dynamic> _publicMedia = [];
  List<dynamic> _lockedMedia = [];
  bool _isLoading = false;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String? _uploadingFileName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadGallery();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGallery() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.getGallery();
      if (mounted) {
        setState(() {
          _publicMedia = response['gallery']?['public'] ?? [];
          _lockedMedia = response['gallery']?['locked'] ?? [];
          _isLoading = false;
        });
        // Refresh user data in auth provider
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.loadUser();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading gallery: $e'),
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

  Future<File?> _generateVideoThumbnail(File videoFile) async {
    try {
      debugPrint('[THUMBNAIL] Starting thumbnail generation for: ${videoFile.path}');
      
      // Check if video file exists
      final exists = await videoFile.exists();
      debugPrint('[THUMBNAIL] Video file exists: $exists');
      if (!exists) {
        debugPrint('[THUMBNAIL] Video file does not exist: ${videoFile.path}');
        return null;
      }
      
      final fileSize = await videoFile.length();
      debugPrint('[THUMBNAIL] Video file size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)}MB');
      
      // Use video_thumbnail package to extract a frame from the video
      final tempDir = Directory.systemTemp;
      debugPrint('[THUMBNAIL] Temp directory: ${tempDir.path}');
      
      // Ensure temp directory exists
      if (!await tempDir.exists()) {
        await tempDir.create(recursive: true);
      }
      
      // Create a unique filename for the thumbnail
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final thumbnailFileName = 'thumb_$timestamp.jpg';
      final thumbnailPath = '${tempDir.path}/$thumbnailFileName';
      
      debugPrint('[THUMBNAIL] Target thumbnail path: $thumbnailPath');
      debugPrint('[THUMBNAIL] Calling VideoThumbnail.thumbnailFile...');
      
      String? generatedPath;
      try {
        // Try with full file path first
        generatedPath = await VideoThumbnail.thumbnailFile(
          video: videoFile.path,
          thumbnailPath: thumbnailPath, // Full file path
          imageFormat: ImageFormat.JPEG,
          maxWidth: 200, // Max width for thumbnail
          quality: 85,
          timeMs: 1000, // Extract frame at 1 second
        );
        debugPrint('[THUMBNAIL] First attempt returned: $generatedPath');
      } catch (e) {
        debugPrint('[THUMBNAIL] Exception during first attempt: $e');
        // Try with directory path
        try {
          debugPrint('[THUMBNAIL] Trying with directory path...');
          generatedPath = await VideoThumbnail.thumbnailFile(
            video: videoFile.path,
            thumbnailPath: tempDir.path, // Directory path
            imageFormat: ImageFormat.JPEG,
            maxWidth: 200,
            quality: 85,
            timeMs: 1000,
          );
          debugPrint('[THUMBNAIL] Second attempt returned: $generatedPath');
        } catch (e2) {
          debugPrint('[THUMBNAIL] Second attempt failed: $e2');
          // Try without thumbnailPath parameter
          try {
            debugPrint('[THUMBNAIL] Trying without thumbnailPath...');
            generatedPath = await VideoThumbnail.thumbnailFile(
              video: videoFile.path,
              imageFormat: ImageFormat.JPEG,
              maxWidth: 200,
              quality: 85,
              timeMs: 1000,
            );
            debugPrint('[THUMBNAIL] Third attempt returned: $generatedPath');
          } catch (e3) {
            debugPrint('[THUMBNAIL] All attempts failed. Last error: $e3');
            return null;
          }
        }
      }
      
      debugPrint('[THUMBNAIL] VideoThumbnail.thumbnailFile returned: $generatedPath');
      
      if (generatedPath != null && generatedPath.isNotEmpty) {
        final thumbnailFile = File(generatedPath);
        final fileExists = await thumbnailFile.exists();
        debugPrint('[THUMBNAIL] Thumbnail file exists: $fileExists at: $generatedPath');
        
        if (fileExists) {
          final thumbnailSize = await thumbnailFile.length();
          debugPrint('[THUMBNAIL] Video thumbnail generated successfully: $generatedPath, size: ${(thumbnailSize / 1024).toStringAsFixed(2)}KB');
          return thumbnailFile;
        } else {
          debugPrint('[THUMBNAIL] Thumbnail file does not exist at: $generatedPath');
        }
      } else {
        debugPrint('[THUMBNAIL] VideoThumbnail.thumbnailFile returned null or empty');
      }
      
      debugPrint('[THUMBNAIL] Returning null - thumbnail generation failed');
      return null;
    } catch (e, stackTrace) {
      debugPrint('[THUMBNAIL] Error generating video thumbnail: $e');
      debugPrint('[THUMBNAIL] Stack trace: $stackTrace');
      return null;
    }
  }

  Future<File?> _compressVideo(File videoFile) async {
    try {
      // Check original file size first
      final originalSize = await videoFile.length();
      final maxSize = 200 * 1024 * 1024; // 200MB
      
      debugPrint('[COMPRESS] Original video size: ${(originalSize / 1024 / 1024).toStringAsFixed(2)}MB');
      
      // Compress video with aggressive settings to reduce size
      // Note: video_compress doesn't directly support frame size constraints
      // Uses resolution-based quality to force lower resolution
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
            debugPrint('[COMPRESS] Compressed file does not exist at: ${mediaInfo?.path ?? "unknown"}');
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

  Future<void> _pickAndUploadMedia() async {
    final currentTab = _tabController.index;
    final galleryType = currentTab == 0 ? 'public' : 'locked';

    // Show dialog to choose between image and video
    final mediaType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Media Type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo),
              title: const Text('Image'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Video'),
              onTap: () => Navigator.pop(context, 'video'),
            ),
          ],
        ),
      ),
    );

    if (mediaType == null) return;

    final picker = ImagePicker();
    XFile? pickedFile;

    if (mediaType == 'image') {
      pickedFile = await picker.pickImage(source: ImageSource.gallery);
    } else if (mediaType == 'video') {
      pickedFile = await picker.pickVideo(source: ImageSource.gallery);
    }

    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    await _uploadMedia(file, galleryType);
  }

  Future<void> _uploadMedia(File file, String galleryType) async {
    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadingFileName = file.path.split('/').last;
    });

    try {
      // Check file size before processing
      final fileSize = await file.length();
      const maxSize = 200 * 1024 * 1024; // 200MB - final upload limit
      const rejectSize = 500 * 1024 * 1024; // 500MB - reject immediately if over this
      
      if (fileSize > rejectSize) {
        // File is way too large, reject immediately
        if (mounted) {
          setState(() {
            _isUploading = false;
            _uploadProgress = 0.0;
            _uploadingFileName = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'File is too large (${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB). Maximum size is 500MB before compression. Please select a smaller file.',
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      File? fileToUpload = file;
      final isImage = file.path.toLowerCase().endsWith('.jpg') ||
          file.path.toLowerCase().endsWith('.jpeg') ||
          file.path.toLowerCase().endsWith('.png') ||
          file.path.toLowerCase().endsWith('.webp');

      // Compress image if it's an image
      if (isImage) {
        setState(() {
          _uploadProgress = 0.2;
        });
        fileToUpload = await _compressImage(file);
        if (fileToUpload == null) {
          fileToUpload = file; // Use original if compression fails
        }
        
        // Upload image (no thumbnail needed for images)
        setState(() {
          _uploadProgress = 0.5;
        });
        
        await _apiService.uploadGalleryMedia(fileToUpload, galleryType);
      } else {
        // Compress video and generate thumbnail - MUST be done on frontend
        setState(() {
          _uploadProgress = 0.2;
        });
        
        debugPrint('[VIDEO] Starting video compression and thumbnail generation on frontend...');
        
        // Step 1: Compress video first
        debugPrint('[VIDEO] Step 1: Compressing video...');
        fileToUpload = await _compressVideo(file);
        
        if (fileToUpload == null) {
          // Compression failed or file still too large
          debugPrint('[VIDEO] Video compression returned null');
          
          // Check if original file is under limit (compression might have failed)
          final originalSize = await file.length();
          if (originalSize <= maxSize) {
            debugPrint('[VIDEO] Using original file as it is under limit');
            fileToUpload = file;
          } else {
            // File is too large and compression failed
            if (mounted) {
              setState(() {
                _isUploading = false;
                _uploadProgress = 0.0;
                _uploadingFileName = null;
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
        
        // Step 2: Check if compressed video is below 200MB
        final compressedSize = await fileToUpload.length();
        debugPrint('[VIDEO] Step 2: Checking compressed video size: ${(compressedSize / 1024 / 1024).toStringAsFixed(2)}MB');
        
        if (compressedSize > maxSize) {
          debugPrint('[VIDEO] Compressed video exceeds 200MB limit');
          if (mounted) {
            setState(() {
              _isUploading = false;
              _uploadProgress = 0.0;
              _uploadingFileName = null;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Video is still too large (${(compressedSize / 1024 / 1024).toStringAsFixed(1)}MB). Maximum size is 200MB after compression.',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 5),
              ),
            );
          }
          return;
        }
        
        debugPrint('[VIDEO] Compressed video is under 200MB, proceeding to thumbnail generation...');
        
        // Step 3: Generate thumbnail from compressed video (not original)
        setState(() {
          _uploadProgress = 0.35;
        });
        
        debugPrint('[VIDEO] Step 3: Generating thumbnail from compressed video file...');
        File? videoThumbnailFile;
        try {
          // Use compressed video file for thumbnail generation
          videoThumbnailFile = await _generateVideoThumbnail(fileToUpload);
          if (videoThumbnailFile != null) {
            final thumbnailSize = await videoThumbnailFile.length();
            debugPrint('[VIDEO] Thumbnail generated successfully from compressed video: ${videoThumbnailFile.path}, size: ${(thumbnailSize / 1024).toStringAsFixed(2)}KB');
          } else {
            debugPrint('[VIDEO] WARNING: Thumbnail generation failed. Backend will create a placeholder.');
          }
        } catch (e, stackTrace) {
          debugPrint('[VIDEO] Error generating thumbnail: $e');
          debugPrint('[VIDEO] Stack trace: $stackTrace');
          videoThumbnailFile = null;
        }
        
        // Upload video with thumbnail
        setState(() {
          _uploadProgress = 0.5;
        });
        
        await _apiService.uploadGalleryMedia(fileToUpload, galleryType, thumbnailFile: videoThumbnailFile);
      }

      setState(() {
        _uploadProgress = 1.0;
      });

      // Reload gallery
      await _loadGallery();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Media uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error uploading media: $e';
        
        // Provide user-friendly error messages
        if (e.toString().contains('File too large') || 
            e.toString().contains('too large') ||
            e.toString().contains('LIMIT_FILE_SIZE')) {
          errorMessage = 'File is too large. Maximum size is 200MB after compression. Please select a smaller file or compress it before uploading.';
        } else if (e.toString().contains('timeout')) {
          errorMessage = 'Upload timed out. Please check your internet connection and try again.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
          _uploadingFileName = null;
        });
      }
    }
  }

  Future<void> _deleteMedia(String galleryType, int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Media'),
        content: const Text('Are you sure you want to delete this media?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _apiService.deleteGalleryMedia(galleryType, index);
      await _loadGallery();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Media deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting media: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photos & Media'),
        backgroundColor: context.appPrimaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.7),
          indicatorColor: Colors.white,
          onTap: (index) {
            setState(() {}); // Refresh to show correct gallery
          },
          tabs: const [
            Tab(text: 'Public Gallery'),
            Tab(text: 'Locked Gallery'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildGalleryGrid(_publicMedia, 'public'),
                _buildGalleryGrid(_lockedMedia, 'locked'),
              ],
            ),
      floatingActionButton: _isUploading
          ? FloatingActionButton(
              onPressed: null,
              backgroundColor: context.appPrimaryColor.withOpacity(0.7),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      value: _uploadProgress,
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                  // if (_uploadingFileName != null)
                  //   Padding(
                  //     padding: const EdgeInsets.only(top: 8.0),
                  //     child: Text(
                  //       _uploadingFileName!.length > 15
                  //           ? '${_uploadingFileName!.substring(0, 15)}...'
                  //           : _uploadingFileName!,
                  //       style: const TextStyle(
                  //         color: Colors.white,
                  //         fontSize: 10,
                  //       ),
                  //       textAlign: TextAlign.center,
                  //       maxLines: 1,
                  //       overflow: TextOverflow.ellipsis,
                  //     ),
                  //   ),
                ],
              ),
            )
          : FloatingActionButton(
              onPressed: _pickAndUploadMedia,
              backgroundColor: context.appPrimaryColor,
              child: const Icon(Icons.add, color: Colors.white),
            ),
    );
  }

  Widget _buildGalleryGrid(List<dynamic> mediaList, String galleryType) {
    if (mediaList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              galleryType == 'public' ? Icons.photo_library : Icons.lock,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No ${galleryType} media yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              galleryType == 'public'
                  ? 'Tap the + button to add media'
                  : 'Locked media can be shared on-demand with other users',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: mediaList.length,
      itemBuilder: (context, index) {
        final media = mediaList[index];
        // Always use thumbnail for gallery display (fallback to full URL only if thumbnail missing)
        final thumbnailUrl = media['thumbnailUrl'] ?? media['url'];
        final mediaUrl = media['url'];
        final isVideo = media['type'] == 'video';
        // Build full URLs - always use thumbnail for grid display
        final fullThumbnailUrl = AppConfig.buildImageUrl(thumbnailUrl);
        final fullMediaUrl = AppConfig.buildImageUrl(mediaUrl);

        return GestureDetector(
          onTap: () => _viewMedia(media),
          onLongPress: () => _deleteMedia(galleryType, index),
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
              Positioned(
                top: 4,
                right: 4,
                child: GestureDetector(
                  onTap: () => _deleteMedia(galleryType, index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
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
        child: const Icon(Icons.videocam),
      ),
    );
  }

  void _viewMedia(Map<String, dynamic> media) {
    final mediaUrl = media['url'];
    final isVideo = media['type'] == 'video';
    final fullUrl = AppConfig.buildImageUrl(mediaUrl);

    debugPrint('[VIEW_MEDIA] Media type: ${isVideo ? "video" : "image"}');
    debugPrint('[VIEW_MEDIA] Media URL: $mediaUrl');
    debugPrint('[VIEW_MEDIA] Full URL: $fullUrl');

    if (isVideo) {
      _showVideoPlayer(fullUrl);
    } else {
      _showImageViewer(fullUrl);
    }
  }

  void _showImageViewer(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: context.appPrimaryColor,
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
  }

  void _showVideoPlayer(String videoUrl) {
    showDialog(
      context: context,
      barrierColor: context.appPrimaryColor,
      barrierDismissible: true,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: _VideoPlayerScreen(videoUrl: videoUrl),
      ),
    );
  }
}

class _VideoPlayerScreen extends StatefulWidget {
  final String videoUrl;

  const _VideoPlayerScreen({required this.videoUrl});

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
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
      debugPrint('[VIDEO_PLAYER] Initializing video player with URL: ${widget.videoUrl}');
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      
      await _controller!.initialize();
      
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _controller!.play();
        debugPrint('[VIDEO_PLAYER] Video initialized and playing successfully');
      }
    } catch (e, stackTrace) {
      debugPrint('[VIDEO_PLAYER] Error initializing video: $e');
      debugPrint('[VIDEO_PLAYER] Stack trace: $stackTrace');
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
        // Close button
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          right: 8,
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 28),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        // Play/Pause button
        if (_isInitialized && _controller != null)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
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
