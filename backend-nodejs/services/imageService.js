const sharp = require('sharp');
const path = require('path');
const fs = require('fs');

const uploadsDir = path.join(__dirname, '..', 'uploads', 'user-images');
const thumbnailsDir = path.join(uploadsDir, 'thumbnails');

/**
 * Process and save image with resizing and thumbnail generation
 * @param {Buffer} imageBuffer - Image buffer from multer
 * @param {string} userId - User ID for filename
 * @returns {Promise<{imageUrl: string, thumbnailUrl: string}>}
 */
async function processAndSaveImage(imageBuffer, userId) {
  const timestamp = Date.now();
  const imageFilename = `${userId}_${timestamp}.jpg`;
  const thumbnailFilename = `${userId}_${timestamp}_thumb.jpg`;
  
  const imagePath = path.join(uploadsDir, imageFilename);
  const thumbnailPath = path.join(thumbnailsDir, thumbnailFilename);

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

    return {
      imageUrl: `/uploads/user-images/${imageFilename}`,
      thumbnailUrl: `/uploads/user-images/thumbnails/${thumbnailFilename}`,
    };
  } catch (error) {
    console.error('Error processing image:', error);
    throw new Error('Failed to process image: ' + error.message);
  }
}

/**
 * Delete image and its thumbnail
 * @param {string} imageUrl - Image URL to delete
 */
async function deleteImage(imageUrl) {
  try {
    if (!imageUrl) return;
    
    // Extract filename from URL
    const filename = path.basename(imageUrl);
    const thumbnailFilename = filename.replace('.jpg', '_thumb.jpg');
    
    const imagePath = path.join(uploadsDir, filename);
    const thumbnailPath = path.join(thumbnailsDir, thumbnailFilename);

    // Delete files if they exist
    if (fs.existsSync(imagePath)) {
      fs.unlinkSync(imagePath);
    }
    if (fs.existsSync(thumbnailPath)) {
      fs.unlinkSync(thumbnailPath);
    }
  } catch (error) {
    console.error('Error deleting image:', error);
    // Don't throw, just log the error
  }
}

module.exports = {
  processAndSaveImage,
  deleteImage,
};
