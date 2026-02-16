const mongoose = require('mongoose');

const otpSchema = new mongoose.Schema({
  email: {
    type: String,
    required: true,
    lowercase: true,
    trim: true,
    index: true
  },
  code: {
    type: String,
    required: true
  },
  expiresAt: {
    type: Date,
    required: true,
    default: () => new Date(Date.now() + 60 * 60 * 1000) // 1 hour
  },
  verified: {
    type: Boolean,
    default: false
  },
  expired: {
    type: Boolean,
    default: false
  },
  createdAt: {
    type: Date,
    default: Date.now,
    expires: 3600 // Auto-delete after 1 hour
  }
});

// Index for faster lookups
otpSchema.index({ email: 1, createdAt: -1 });
otpSchema.index({ email: 1, expired: 1, verified: 1 });

module.exports = mongoose.model('Otp', otpSchema);
