const express = require('express');
const router = express.Router();
const multer = require('multer');
const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Otp = require('../models/Otp');
const { authenticateToken } = require('../middleware/auth');
const { sendOTPEmail } = require('../services/emailService');
const { processAndSaveImage, deleteImage } = require('../services/imageService');
const { processAndSaveGalleryImage, processAndSaveGalleryVideo, deleteGalleryMedia } = require('../services/mediaService');

// Configure multer for image uploads
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 10 * 1024 * 1024, // 10MB limit
  },
  fileFilter: (req, file, cb) => {
    // Accept only image files
    if (file.mimetype.startsWith('image/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image files are allowed'), false);
    }
  },
});

// Configure multer for media uploads (images and videos)
const mediaUpload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 200 * 1024 * 1024, // 200MB limit for videos (after compression)
    files: 2, // Allow media file + optional thumbnail
  },
  fileFilter: (req, file, cb) => {
    // Accept images, videos, and thumbnails
    if (file.mimetype.startsWith('image/') || file.mimetype.startsWith('video/')) {
      cb(null, true);
    } else {
      cb(new Error('Only image and video files are allowed'), false);
    }
  },
  onError: (err, next) => {
    if (err instanceof multer.MulterError) {
      if (err.code === 'LIMIT_FILE_SIZE') {
        return next(new Error('File is too large. Maximum size is 200MB after compression. Please compress the file before uploading.'));
      }
    }
    next(err);
  },
});

// Generate 6-digit OTP
function generateOTP() {
  return Math.floor(100000 + Math.random() * 900000).toString();
}

// Send OTP to email
router.post('/send-otp', async (req, res) => {
  try {
    const { email } = req.body;

    if (!email || !email.includes('@')) {
      return res.status(400).json({ message: 'Valid email is required' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    const code = generateOTP();

    // Mark all previous OTPs as expired (only 1 valid OTP at a time)
    // This includes OTPs that don't have the expired field set (for backward compatibility)
    await Otp.updateMany(
      { 
        email: normalizedEmail, 
        verified: false,
        $or: [
          { expired: false },
          { expired: { $exists: false } }
        ]
      },
      { expired: true }
    );

    // Create new OTP (valid for 1 hour)
    const otp = new Otp({
      email: normalizedEmail,
      code,
      expiresAt: new Date(Date.now() + 60 * 60 * 1000) // 1 hour
    });

    await otp.save();

    // Send OTP via email
    try {
      await sendOTPEmail(normalizedEmail, code);
      console.log(`OTP sent to ${normalizedEmail}`);
    } catch (emailError) {
      console.error('Failed to send OTP email:', emailError);
      // Still return success if OTP is saved, but log the error
      // In production, you might want to handle this differently
    }

    res.json({
      message: 'OTP sent to email',
      // Only return OTP in development for testing
      otp: process.env.NODE_ENV === 'development' ? code : undefined
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Verify OTP without logging in (for email change)
router.post('/verify-otp-only', async (req, res) => {
  try {
    const { email, code } = req.body;

    if (!email || !code) {
      return res.status(400).json({ message: 'Email and OTP code are required' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    const normalizedCode = code.toString().trim();

    // Find valid OTP
    const otp = await Otp.findOne({
      email: normalizedEmail,
      code: normalizedCode,
      verified: false,
      expired: false,
      expiresAt: { $gt: new Date() }
    }).sort({ createdAt: -1 });

    if (!otp) {
      return res.status(400).json({ message: 'Invalid or expired OTP' });
    }

    res.json({
      message: 'OTP verified successfully',
      valid: true
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Verify OTP and login/register
router.post('/verify-otp', async (req, res) => {
  try {
    const { email, code } = req.body;

    if (!email || !code) {
      return res.status(400).json({ message: 'Email and OTP code are required' });
    }

    const normalizedEmail = email.toLowerCase().trim();
    const normalizedCode = code.toString().trim(); // Ensure code is string and trimmed

    // Find valid OTP - must be: not verified, not expired, and not past expiration time
    const otp = await Otp.findOne({
      email: normalizedEmail,
      code: normalizedCode,
      verified: false,
      expired: false,
      expiresAt: { $gt: new Date() }
    }).sort({ createdAt: -1 });

    if (!otp) {
      // Check if OTP exists to provide better error messages
      const existingOtp = await Otp.findOne({
        email: normalizedEmail,
        code: normalizedCode
      }).sort({ createdAt: -1 });
      
      if (existingOtp) {
        if (existingOtp.verified) {
          return res.status(400).json({ message: 'This OTP has already been used. Please request a new one.' });
        }
        if (existingOtp.expired) {
          return res.status(400).json({ message: 'This OTP has been replaced by a newer one. Please use the latest OTP sent to your email.' });
        }
        if (new Date() > existingOtp.expiresAt) {
          return res.status(400).json({ message: 'OTP has expired. Please request a new one.' });
        }
      }
      
      return res.status(400).json({ message: 'Invalid or expired OTP. Please request a new one.' });
    }

    // Mark OTP as verified
    otp.verified = true;
    await otp.save();

    // Find or create user
    let user = await User.findOne({ email: normalizedEmail });

    if (!user) {
      // Create new user
      user = new User({
        email: normalizedEmail,
        isOnboardingComplete: false
      });
      await user.save();
    }

    // Generate JWT token (30 days)
    const token = jwt.sign(
      { userId: user._id.toString() },
      process.env.JWT_SECRET || 'your-secret-key',
      { expiresIn: '30d' }
    );

    res.json({
      message: 'OTP verified successfully',
      token,
      user: {
        id: user._id,
        email: user.email,
        isOnboardingComplete: user.isOnboardingComplete,
        name: user.name,
        dateOfBirth: user.dateOfBirth,
        gender: user.gender,
        profileImage: user.profileImage,
        pickupLine: user.pickupLine
      }
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Refresh token
router.post('/refresh-token', authenticateToken, async (req, res) => {
  try {
    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Generate new token (30 days)
    const token = jwt.sign(
      { userId: user._id },
      process.env.JWT_SECRET || 'your-secret-key',
      { expiresIn: '30d' }
    );

    res.json({
      message: 'Token refreshed',
      token
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Get user profile
router.get('/profile', authenticateToken, async (req, res) => {
  try {
    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }
    res.json(user);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Upload profile image
router.post('/upload-image', authenticateToken, upload.single('image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ message: 'No image file provided' });
    }

    // Process and save image (resize to 800px, create thumbnail)
    const { imageUrl, thumbnailUrl } = await processAndSaveImage(req.file.buffer, req.userId);

    res.json({
      message: 'Image uploaded successfully',
      imageUrl,
      thumbnailUrl,
    });
  } catch (error) {
    console.error('Error uploading image:', error);
    res.status(500).json({ message: error.message || 'Failed to upload image' });
  }
});

// Update user profile (including onboarding)
router.put('/profile', authenticateToken, async (req, res) => {
  try {
    const updates = req.body;

    // Check if user exists first
    const existingUser = await User.findById(req.userId);
    if (!existingUser) {
      return res.status(404).json({ 
        message: 'User not found. Please log in again.',
        code: 'USER_NOT_FOUND'
      });
    }

    // Validate age - users must be at least 18 years old
    if (updates.dateOfBirth) {
      const birthDate = new Date(updates.dateOfBirth);
      const today = new Date();
      let age = today.getFullYear() - birthDate.getFullYear();
      const monthDiff = today.getMonth() - birthDate.getMonth();
      const dayDiff = today.getDate() - birthDate.getDate();
      
      // Adjust age if birthday hasn't occurred this year
      if (monthDiff < 0 || (monthDiff === 0 && dayDiff < 0)) {
        age--;
      }
      
      if (age < 18) {
        return res.status(400).json({ 
          message: 'You must be at least 18 years old to use this app' 
        });
      }
    }

    // If updating profile image, delete old image
    if (updates.profileImage && existingUser.profileImage && existingUser.profileImage !== updates.profileImage) {
      await deleteImage(existingUser.profileImage);
    }

    // Log ALL updates for debugging
    console.log('Profile update request received:', {
      userId: req.userId,
      updates: JSON.stringify(updates, null, 2),
    });

    // Log location updates specifically
    if (updates.lastSeenAt || updates.location) {
      console.log('Location update detected:', {
        userId: req.userId,
        location: updates.location,
        lastSeenAt: updates.lastSeenAt,
      });
    }

    // Convert lastSeenAt from ISO string to Date if provided
    if (updates.lastSeenAt && typeof updates.lastSeenAt === 'string') {
      updates.lastSeenAt = new Date(updates.lastSeenAt);
    }

    const user = await User.findByIdAndUpdate(
      req.userId,
      { ...updates, updatedAt: Date.now() },
      { returnDocument: 'after', runValidators: true }
    );
    
    if (!user) {
      console.error('ERROR: User not found after update:', req.userId);
      return res.status(404).json({ 
        message: 'User not found. Please log in again.',
        code: 'USER_NOT_FOUND'
      });
    }
    
    // Log saved user data for debugging
    console.log('User updated successfully:', {
      userId: user._id,
      email: user.email,
      lastSeenAt: user.lastSeenAt,
      location: user.location,
    });

    if (!user) {
      return res.status(404).json({ 
        message: 'User not found. Please log in again.',
        code: 'USER_NOT_FOUND'
      });
    }

    // Check onboarding status will be updated automatically by pre-save hook
    res.json(user);
  } catch (error) {
    res.status(400).json({ message: error.message });
  }
});

// Update Firebase token
router.put('/firebase-token', authenticateToken, async (req, res) => {
  try {
    const { firebaseToken } = req.body;
    const user = await User.findByIdAndUpdate(
      req.userId,
      { firebaseToken, updatedAt: Date.now() },
      { returnDocument: 'after' }
    );

    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    res.json({ message: 'Firebase token updated', user });
  } catch (error) {
    res.status(400).json({ message: error.message });
  }
});

// Get potential matches (users within distance)
router.get('/potential-matches', authenticateToken, async (req, res) => {
  try {
    const Match = require('../models/Match');
    const currentUser = await User.findById(req.userId);
    if (!currentUser) {
      return res.status(404).json({ message: 'User not found' });
    }

    if (!currentUser.location || !currentUser.location.latitude) {
      console.log(`[POTENTIAL-MATCHES] User ${req.userId} has no location set`);
      return res.status(400).json({ message: 'User location not set' });
    }

    const { latitude, longitude } = currentUser.location;
    const maxDistance = currentUser.preferences?.maxDistance || 50; // in km
    const interestedIn = currentUser.preferences?.interestedIn || ['male', 'female', 'other'];
    const minAge = currentUser.preferences?.minAge || 18;
    const maxAge = currentUser.preferences?.maxAge || 100;
    
    console.log(`[POTENTIAL-MATCHES] User ${req.userId} - Location: ${latitude}, ${longitude}, MaxDistance: ${maxDistance}km, InterestedIn: ${JSON.stringify(interestedIn)}, AgeRange: ${minAge}-${maxAge}`);

    // Get all users that should be excluded from feed:
    // 1. Users with whom current user has sent or received a nudge (status: 'nudge')
    // 2. Users with whom user has a match already (status: 'matched')
    // 3. Users with whom user has unmatched (status: 'unmatched')
    const existingMatches = await Match.find({
      $or: [
        { user1: req.userId },
        { user2: req.userId }
      ],
      status: { $in: ['nudge', 'matched', 'unmatched'] }
    });
    const excludedUserIds = existingMatches.map(match => {
      return match.user1.toString() === req.userId 
        ? match.user2.toString() 
        : match.user1.toString();
    });

    // Build query for gender preference
    const genderQuery = interestedIn.length > 0 
      ? { gender: { $in: interestedIn } }
      : {};

    // Find users within maxDistance km, matching preferences, and not already swiped
    const allUsers = await User.find({
      _id: { 
        $ne: req.userId,
        $nin: excludedUserIds
      },
      isOnboardingComplete: true, // Only show users who completed onboarding
      isProfileHidden: false, // Don't show hidden profiles
      ...genderQuery, // Filter by gender preference
      'location.latitude': { $exists: true },
      'location.longitude': { $exists: true }
    });

    // Calculate age from dateOfBirth and filter
    const now = new Date();
    const filteredByAge = allUsers.filter(user => {
      if (!user.dateOfBirth) return false;
      const birthDate = new Date(user.dateOfBirth);
      const age = now.getFullYear() - birthDate.getFullYear();
      const monthDiff = now.getMonth() - birthDate.getMonth();
      if (monthDiff < 0 || (monthDiff === 0 && now.getDate() < birthDate.getDate())) {
        return age - 1 >= minAge && age - 1 <= maxAge;
      }
      return age >= minAge && age <= maxAge;
    });

    // Filter by distance and add age to user object
    const potentialMatches = filteredByAge
      .map(user => {
        const birthDate = new Date(user.dateOfBirth);
        const age = now.getFullYear() - birthDate.getFullYear();
        const monthDiff = now.getMonth() - birthDate.getMonth();
        const calculatedAge = (monthDiff < 0 || (monthDiff === 0 && now.getDate() < birthDate.getDate())) 
          ? age - 1 
          : age;
        
        const distance = calculateDistance(
          latitude,
          longitude,
          user.location.latitude,
          user.location.longitude
        );
        
        return {
          ...user.toObject(),
          age: calculatedAge,
          distance: Math.round(distance * 10) / 10 // Round to 1 decimal place
        };
      })
      .filter(user => user.distance <= maxDistance)
      .sort((a, b) => a.distance - b.distance); // Sort by distance (closest first)

    console.log(`[POTENTIAL-MATCHES] Found ${allUsers.length} total users, ${filteredByAge.length} after age filter, ${potentialMatches.length} after distance filter`);
    console.log(`[POTENTIAL-MATCHES] Excluded ${excludedUserIds.length} users (nudge/matched/unmatched)`);
    
    res.json(potentialMatches);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Helper function to calculate distance between two coordinates (Haversine formula)
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Radius of the Earth in km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
    Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

// Change email - requires OTP verification for both old and new email
router.post('/change-email', authenticateToken, async (req, res) => {
  try {
    const { currentEmailOtp, newEmail, newEmailOtp } = req.body;

    if (!currentEmailOtp || !newEmail || !newEmailOtp) {
      return res.status(400).json({ 
        message: 'Current email OTP, new email, and new email OTP are required' 
      });
    }

    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    const normalizedCurrentEmail = user.email.toLowerCase().trim();
    const normalizedNewEmail = newEmail.toLowerCase().trim();

    // Check if new email is different
    if (normalizedCurrentEmail === normalizedNewEmail) {
      return res.status(400).json({ message: 'New email must be different from current email' });
    }

    // Check if new email is already in use
    const existingUser = await User.findOne({ email: normalizedNewEmail });
    if (existingUser) {
      return res.status(400).json({ message: 'This email is already registered' });
    }

    // Verify current email OTP
    const currentOtp = await Otp.findOne({
      email: normalizedCurrentEmail,
      code: currentEmailOtp.toString().trim(),
      verified: false,
      expired: false,
      expiresAt: { $gt: new Date() }
    }).sort({ createdAt: -1 });

    if (!currentOtp) {
      return res.status(400).json({ message: 'Invalid or expired OTP for current email' });
    }

    // Verify new email OTP
    const newOtp = await Otp.findOne({
      email: normalizedNewEmail,
      code: newEmailOtp.toString().trim(),
      verified: false,
      expired: false,
      expiresAt: { $gt: new Date() }
    }).sort({ createdAt: -1 });

    if (!newOtp) {
      return res.status(400).json({ message: 'Invalid or expired OTP for new email' });
    }

    // Mark both OTPs as verified
    currentOtp.verified = true;
    await currentOtp.save();
    newOtp.verified = true;
    await newOtp.save();

    // Update user email
    user.email = normalizedNewEmail;
    await user.save();

    res.json({
      message: 'Email changed successfully',
      user: {
        id: user._id,
        email: user.email
      }
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Toggle profile visibility (hide/show profile)
router.put('/toggle-profile-visibility', authenticateToken, async (req, res) => {
  try {
    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    user.isProfileHidden = !user.isProfileHidden;
    await user.save();

    res.json({
      message: user.isProfileHidden ? 'Profile hidden successfully' : 'Profile visible successfully',
      isProfileHidden: user.isProfileHidden
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Delete user profile
router.delete('/delete-profile', authenticateToken, async (req, res) => {
  try {
    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Delete profile image if exists
    if (user.profileImage) {
      try {
        await deleteImage(user.profileImage);
      } catch (imageError) {
        console.error('Error deleting profile image:', imageError);
        // Continue with deletion even if image deletion fails
      }
    }

    // Delete user
    await User.findByIdAndDelete(req.userId);

    res.json({ message: 'Profile deleted successfully' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Upload media to gallery (image or video)
router.post('/upload-gallery-media', authenticateToken, mediaUpload.fields([
  { name: 'media', maxCount: 1 },
  { name: 'thumbnail', maxCount: 1 }
]), async (req, res) => {
  const startTime = Date.now();
  try {
    if (!req.files || !req.files['media'] || req.files['media'].length === 0) {
      return res.status(400).json({ message: 'No media file provided' });
    }

    const mediaFile = req.files['media'][0];
    const thumbnailFile = req.files['thumbnail'] ? req.files['thumbnail'][0] : null;
    
    console.log('Upload request received:', {
      mediaType: mediaFile.mimetype,
      mediaSize: mediaFile.size,
      hasThumbnail: !!thumbnailFile,
      thumbnailSize: thumbnailFile ? thumbnailFile.size : 0,
      userId: req.userId,
      timestamp: new Date().toISOString(),
    });

    // Check file size
    const fileSize = mediaFile.size;
    const maxSize = 200 * 1024 * 1024; // 200MB
    if (fileSize > maxSize) {
      return res.status(400).json({ 
        message: `File is too large (${(fileSize / 1024 / 1024).toFixed(1)}MB). Maximum size is 200MB after compression. Please compress the file before uploading.` 
      });
    }

    const { galleryType } = req.body; // 'public' or 'locked'
    
    if (!galleryType || !['public', 'locked'].includes(galleryType)) {
      return res.status(400).json({ message: 'Invalid gallery type. Must be "public" or "locked"' });
    }

    // Check if user exists
    const existingUser = await User.findById(req.userId);
    if (!existingUser) {
      return res.status(404).json({ message: 'User not found' });
    }

    let mediaData;
    const isImage = mediaFile.mimetype.startsWith('image/');
    const isVideo = mediaFile.mimetype.startsWith('video/');

    if (isImage) {
      console.log('Processing image...');
      mediaData = await processAndSaveGalleryImage(mediaFile.buffer, req.userId, galleryType);
      console.log('Image processed successfully');
    } else if (isVideo) {
      console.log('Processing video... (this may take a while for large files)');
      // If thumbnail is provided, use it; otherwise backend will create placeholder
      mediaData = await processAndSaveGalleryVideo(mediaFile.buffer, req.userId, galleryType, thumbnailFile?.buffer);
      console.log('Video processed successfully');
    } else {
      return res.status(400).json({ message: 'Unsupported file type' });
    }

    // Prepare new media item
    const newMediaItem = {
      url: mediaData.url,
      thumbnailUrl: mediaData.thumbnailUrl,
      type: mediaData.type,
      uploadedAt: new Date(),
    };

    // Build update query using $push (MongoDB will create array if it doesn't exist)
    // First ensure gallery structure exists if needed
    const updateOperations = {};
    
    if (!existingUser.gallery) {
      // Initialize gallery structure
      updateOperations.$set = { gallery: { public: [], locked: [] } };
    }
    
    // Push new media item to the appropriate gallery array
    updateOperations.$push = { [`gallery.${galleryType}`]: newMediaItem };

    console.log('Saving user gallery data...');
    // Use findByIdAndUpdate with returnDocument to avoid Mongoose deprecation warnings
    const user = await User.findByIdAndUpdate(
      req.userId,
      updateOperations,
      { returnDocument: 'after', runValidators: true }
    );
    
    if (!user) {
      return res.status(404).json({ message: 'User not found after update' });
    }
    
    console.log('User gallery data saved');

    const processingTime = ((Date.now() - startTime) / 1000).toFixed(2);
    console.log(`Media upload completed in ${processingTime} seconds`);

    res.json({
      message: 'Media uploaded successfully',
      media: {
        url: mediaData.url,
        thumbnailUrl: mediaData.thumbnailUrl,
        type: mediaData.type,
        uploadedAt: new Date(),
      },
    });
  } catch (error) {
    const processingTime = ((Date.now() - startTime) / 1000).toFixed(2);
    console.error(`Error uploading gallery media (after ${processingTime}s):`, error);
    console.error('Error stack:', error.stack);
    
    // Check if response was already sent
    if (!res.headersSent) {
      res.status(500).json({ 
        message: error.message || 'Failed to upload media',
        error: process.env.NODE_ENV === 'development' ? error.stack : undefined
      });
    }
  }
});

// Delete media from gallery
router.delete('/gallery-media/:galleryType/:index', authenticateToken, async (req, res) => {
  try {
    const { galleryType, index } = req.params;
    
    if (!['public', 'locked'].includes(galleryType)) {
      return res.status(400).json({ message: 'Invalid gallery type' });
    }

    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    if (!user.gallery || !user.gallery[galleryType]) {
      return res.status(404).json({ message: 'Gallery not found' });
    }

    const mediaIndex = parseInt(index);
    if (mediaIndex < 0 || mediaIndex >= user.gallery[galleryType].length) {
      return res.status(400).json({ message: 'Invalid media index' });
    }

    const media = user.gallery[galleryType][mediaIndex];
    
    // Delete file from filesystem
    await deleteGalleryMedia(media.url);

    // Remove from array
    user.gallery[galleryType].splice(mediaIndex, 1);
    await user.save();

    res.json({ message: 'Media deleted successfully' });
  } catch (error) {
    console.error('Error deleting gallery media:', error);
    res.status(500).json({ message: error.message || 'Failed to delete media' });
  }
});

// Get user gallery
router.get('/gallery', authenticateToken, async (req, res) => {
  try {
    const user = await User.findById(req.userId);
    if (!user) {
      return res.status(404).json({ message: 'User not found' });
    }

    res.json({
      gallery: user.gallery || { public: [], locked: [] },
    });
  } catch (error) {
    console.error('Error getting gallery:', error);
    res.status(500).json({ message: error.message || 'Failed to get gallery' });
  }
});

module.exports = router;
