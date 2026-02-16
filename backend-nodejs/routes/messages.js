const express = require('express');
const router = express.Router();
const Message = require('../models/Message');
const Match = require('../models/Match');
const { authenticateToken } = require('../middleware/auth');

// Get message history for a match
router.get('/:matchId', authenticateToken, async (req, res) => {
  try {
    const { matchId } = req.params;
    const limit = parseInt(req.query.limit) || 50;
    const beforeSequenceId = req.query.beforeSequenceId ? parseInt(req.query.beforeSequenceId) : null;

    // Validate match exists and user is part of it
    const match = await Match.findById(matchId);
    if (!match) {
      return res.status(404).json({ message: 'Match not found' });
    }

    const userId = req.userId;
    const isUser1 = match.user1.toString() === userId.toString();
    const isUser2 = match.user2.toString() === userId.toString();
    
    if (!isUser1 && !isUser2) {
      return res.status(403).json({ message: 'Not authorized for this match' });
    }

    // Build query
    const query = { matchId };
    if (beforeSequenceId) {
      query.sequenceId = { $lt: beforeSequenceId };
    }

    const messages = await Message.find(query)
      .sort({ sequenceId: -1 })
      .limit(limit);

    const messagesPayload = messages.reverse().map(msg => ({
      id: msg.id,
      sequenceId: msg.sequenceId,
      messageType: msg.messageType,
      messageText: msg.messageText,
      isSent: msg.senderId.toString() === userId.toString(),
      isDelivered: msg.isDelivered,
      sentAt: msg.sentAt.toISOString(),
      deliveredAt: msg.deliveredAt ? msg.deliveredAt.toISOString() : null,
      senderId: msg.senderId.toString(),
      receiverId: msg.receiverId.toString()
    }));

    res.json(messagesPayload);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
