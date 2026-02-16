const mongoose = require('mongoose');

const userSchema = new mongoose.Schema({
  email: {
    type: String,
    required: true,
    unique: true,
    lowercase: true,
    trim: true
  },
  // Onboarding fields (all mandatory)
  name: {
    type: String,
    trim: true
  },
  dateOfBirth: {
    type: Date
  },
  gender: {
    type: String,
    enum: ['male', 'female', 'other']
  },
  profileImage: {
    type: String // URL to profile image
  },
  pickupLine: {
    type: String,
    maxlength: 50
  },
  // Check if onboarding is complete
  isOnboardingComplete: {
    type: Boolean,
    default: false
  },
  isProfileHidden: {
    type: Boolean,
    default: false
  },
  bio: {
    type: String,
    maxlength: 500
  },
  profession: {
    type: String,
    trim: true,
    maxlength: 100
  },
  eatingHabits: {
    type: String,
    enum: ['vegetarian', 'non-vegetarian', 'vegan']
  },
  smoking: {
    type: String,
    enum: ['yes', 'no', 'occasionally']
  },
  drinking: {
    type: String,
    enum: ['yes', 'no', 'occasionally']
  },
  photos: [{
    type: String, // URLs to photos
    default: []
  }],
  gallery: {
    public: [{
      url: {
        type: String,
        required: true
      },
      thumbnailUrl: {
        type: String
      },
      type: {
        type: String,
        enum: ['image', 'video'],
        required: true
      },
      uploadedAt: {
        type: Date,
        default: Date.now
      }
    }],
    locked: [{
      url: {
        type: String,
        required: true
      },
      thumbnailUrl: {
        type: String
      },
      type: {
        type: String,
        enum: ['image', 'video'],
        required: true
      },
      uploadedAt: {
        type: Date,
        default: Date.now
      }
    }]
  },
  location: {
    latitude: {
      type: Number
    },
    longitude: {
      type: Number
    },
    city: {
      type: String,
      trim: true
    },
    state: {
      type: String,
      trim: true
    },
    countryCode: {
      type: String,
      trim: true,
      uppercase: true,
      maxlength: 2 // ISO 3166-1 alpha-2 country codes (e.g., IN, NZ, US)
    }
  },
  preferences: {
    minAge: {
      type: Number,
      default: 18
    },
    maxAge: {
      type: Number,
      default: 100
    },
    maxDistance: {
      type: Number,
      default: 50 // in kilometers
    },
    interestedIn: [{
      type: String,
      enum: ['male', 'female', 'other']
    }]
  },
  firebaseToken: {
    type: String
  },
  lastSeenAt: {
    type: Date
  },
  createdAt: {
    type: Date,
    default: Date.now
  },
  updatedAt: {
    type: Date,
    default: Date.now
  }
});

// Method to check if onboarding is complete
// Users with Name, Profile image, dateOfBirth, and Gender won't see onboarding again
// (pickupLine is mandatory during onboarding but not required to skip onboarding screen)
userSchema.methods.checkOnboardingComplete = function() {
  return !!(
    this.name &&
    this.dateOfBirth &&
    this.gender &&
    this.profileImage
  );
};

// Update isOnboardingComplete before saving
userSchema.pre('save', async function(next) {
  try {
    this.isOnboardingComplete = this.checkOnboardingComplete();
    this.updatedAt = Date.now();
    if (typeof next === 'function') {
      next();
    }
  } catch (error) {
    if (typeof next === 'function') {
      next(error);
    } else {
      throw error;
    }
  }
});

module.exports = mongoose.model('User', userSchema);
