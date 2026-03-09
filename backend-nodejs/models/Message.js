const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
  id: {
    type: Number,
    required: true,
    unique: true,
    index: true
  },
  matchId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Match',
    required: true,
    index: true
  },
  senderId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  receiverId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  sequenceId: {
    type: Number,
    required: true
  },
  messageType: {
    type: String,
    enum: ['text', 'image', 'video', 'audio'],
    required: true,
    default: 'text'
  },
  messageText: {
    type: String,
    required: true
  },
  isSent: {
    type: Boolean,
    default: true
  },
  isDelivered: {
    type: Boolean,
    default: false
  },
  sentAt: {
    type: Date,
    default: Date.now
  },
  deliveredAt: {
    type: Date
  },
  readAt: {
    type: Date
  },
  // Unsend: when true, message is hidden from both users (only admins can see)
  hidden: {
    type: Boolean,
    default: false,
    index: true
  },
  // Reply: reference to the message being replied to (same match)
  replyToSequenceId: {
    type: Number,
    default: null
  },
  replyToSnippet: {
    type: String,
    default: null
  },
  replyToMessageType: {
    type: String,
    default: null
  }
}, {
  timestamps: true
});

// Compound index for efficient querying
messageSchema.index({ matchId: 1, sequenceId: 1 });
messageSchema.index({ senderId: 1, receiverId: 1 });

module.exports = mongoose.model('Message', messageSchema);
