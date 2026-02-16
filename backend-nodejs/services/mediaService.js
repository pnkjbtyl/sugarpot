const sharp = require('sharp');
const path = require('path');
const fs = require('fs');

const galleryDir = path.join(__dirname, '..', 'uploads', 'gallery');
const galleryPublicDir = path.join(galleryDir, 'public');
const galleryLockedDir = path.join(galleryDir, 'locked');
const galleryPublicThumbnailsDir = path.join(galleryPublicDir, 'thumbnails');
const galleryLockedThumbnailsDir = path.join(galleryLockedDir, 'thumbnails');

// Ensure directories exist
[galleryDir, galleryPublicDir, galleryLockedDir, galleryPublicThumbnailsDir, galleryLockedThumbnailsDir].forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

/**
 * Process and save gallery image
 * @param {Buffer} imageBuffer - Image buffer from multer
 * @param {string} userId - User ID for filename
 * @param {string} galleryType - 'public' or 'locked'
 * @returns {Promise<{url: string, thumbnailUrl: string, type: string}>}
 */
async function processAndSaveGalleryImage(imageBuffer, userId, galleryType) {
  const timestamp = Date.now();
  const imageFilename = `${userId}_${timestamp}.jpg`;
  const thumbnailFilename = `${userId}_${timestamp}_thumb.jpg`;
  
  const targetDir = galleryType === 'public' ? galleryPublicDir : galleryLockedDir;
  const thumbnailDir = galleryType === 'public' ? galleryPublicThumbnailsDir : galleryLockedThumbnailsDir;
  const imagePath = path.join(targetDir, imageFilename);
  const thumbnailPath = path.join(thumbnailDir, thumbnailFilename);

  try {
    // Resize main image to max 800px width (keeping aspect ratio)
    await sharp(imageBuffer)
      .resize(800, null, {
        withoutEnlargement: true,
        fit: 'inside',
      })
      .jpeg({ quality: 85 })
      .toFile(imagePath);

    // Create thumbnail (max 200px width, keeping aspect ratio)
    await sharp(imageBuffer)
      .resize(200, null, {
        withoutEnlargement: true,
        fit: 'inside',
      })
      .jpeg({ quality: 85 })
      .toFile(thumbnailPath);

    const basePath = galleryType === 'public' ? '/uploads/gallery/public' : '/uploads/gallery/locked';
    return {
      url: `${basePath}/${imageFilename}`,
      thumbnailUrl: `${basePath}/thumbnails/${thumbnailFilename}`,
      type: 'image',
    };
  } catch (error) {
    console.error('Error processing gallery image:', error);
    throw new Error('Failed to process image: ' + error.message);
  }
}

/**
 * Process and save gallery video
 * Note: Video compression will be handled on the frontend before upload
 * @param {Buffer} videoBuffer - Video buffer from multer
 * @param {string} userId - User ID for filename
 * @param {string} galleryType - 'public' or 'locked'
 * @param {Buffer} thumbnailBuffer - Optional thumbnail buffer from frontend
 * @returns {Promise<{url: string, thumbnailUrl: string, type: string}>}
 */
async function processAndSaveGalleryVideo(videoBuffer, userId, galleryType, thumbnailBuffer = null) {
  const timestamp = Date.now();
  // Determine file extension from buffer or default to mp4
  const videoFilename = `${userId}_${timestamp}.mp4`;
  
  const targetDir = galleryType === 'public' ? galleryPublicDir : galleryLockedDir;
  const thumbnailDir = galleryType === 'public' ? galleryPublicThumbnailsDir : galleryLockedThumbnailsDir;
  const videoPath = path.join(targetDir, videoFilename);

  try {
    // Video is already compressed on the frontend
    // Just save it directly to the target location
    console.log('Saving video file (already compressed on frontend)...');
    fs.writeFileSync(videoPath, videoBuffer);
    console.log('Video saved successfully:', videoPath);

    const thumbnailFilename = `${userId}_${timestamp}_thumb.jpg`;
    const thumbnailPath = path.join(thumbnailDir, thumbnailFilename);
    
    // Thumbnail is already generated on the frontend
    if (thumbnailBuffer && thumbnailBuffer.length > 0) {
      console.log('Processing thumbnail from frontend, size:', thumbnailBuffer.length, 'bytes');
      // Thumbnail is already resized and processed on frontend, just save it
      await sharp(thumbnailBuffer)
        .resize(200, null, {
          withoutEnlargement: true,
          fit: 'inside',
        })
        .jpeg({ quality: 85 })
        .toFile(thumbnailPath);
      console.log('Video thumbnail saved from frontend to:', thumbnailPath);
    } else {
      // No thumbnail provided - create a placeholder
      console.warn('WARNING: No thumbnail provided from frontend. Creating placeholder.');
      try {
        await sharp({
          create: {
            width: 200,
            height: 200,
            channels: 3,
            background: { r: 100, g: 100, b: 100 }
          }
        })
        .jpeg()
        .toFile(thumbnailPath);
        console.log('Placeholder thumbnail created');
      } catch (sharpErr) {
        console.error('Error creating placeholder thumbnail:', sharpErr);
      }
    }

    const basePath = galleryType === 'public' ? '/uploads/gallery/public' : '/uploads/gallery/locked';
    return {
      url: `${basePath}/${videoFilename}`,
      thumbnailUrl: `${basePath}/thumbnails/${thumbnailFilename}`,
      type: 'video',
    };
  } catch (error) {
    console.error('Error processing gallery video:', error);
    throw new Error('Failed to process video: ' + error.message);
  }
}

/**
 * Delete gallery media file
 * @param {string} mediaUrl - Media URL to delete
 */
async function deleteGalleryMedia(mediaUrl) {
  try {
    if (!mediaUrl) return;
    
    // Extract gallery type and filename from URL
    // URL format: /uploads/gallery/public/filename or /uploads/gallery/locked/filename
    const urlParts = mediaUrl.replace('/uploads/gallery/', '').split('/');
    if (urlParts.length < 2) return;
    
    const galleryType = urlParts[0]; // 'public' or 'locked'
    const filename = urlParts[urlParts.length - 1];
    
    const targetDir = galleryType === 'public' ? galleryPublicDir : galleryLockedDir;
    const thumbnailDir = galleryType === 'public' ? galleryPublicThumbnailsDir : galleryLockedThumbnailsDir;
    
    const mediaPath = path.join(targetDir, filename);
    
    // Delete media file if exists
    if (fs.existsSync(mediaPath)) {
      fs.unlinkSync(mediaPath);
    }
    
    // Try to delete thumbnail (for both images and videos)
    const thumbnailFilename = filename.replace(/\.(jpg|mp4)$/, '_thumb.jpg');
    const thumbnailPath = path.join(thumbnailDir, thumbnailFilename);
    if (fs.existsSync(thumbnailPath)) {
      fs.unlinkSync(thumbnailPath);
    }
  } catch (error) {
    console.error('Error deleting gallery media:', error);
    // Don't throw, just log the error
  }
}

module.exports = {
  processAndSaveGalleryImage,
  processAndSaveGalleryVideo,
  deleteGalleryMedia,
};
