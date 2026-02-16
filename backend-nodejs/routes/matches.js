const express = require('express');
const router = express.Router();
const mongoose = require('mongoose');
const Match = require('../models/Match');
const User = require('../models/User');
const { authenticateToken } = require('../middleware/auth');

// Swipe right (like) on a user
router.post('/swipe', authenticateToken, async (req, res) => {
  try {
    const { targetUserId, locationId } = req.body;

    if (!targetUserId) {
      return res.status(400).json({ message: 'Target user ID is required' });
    }

    // Check if match already exists
    let match = await Match.findOne({
      $or: [
        { user1: req.userId, user2: targetUserId },
        { user1: targetUserId, user2: req.userId }
      ]
    });

    if (match) {
      // If other user already swiped right, it's a match
      if (match.user2.toString() === req.userId && match.status === 'pending') {
        match.status = 'matched';
        if (locationId) {
          match.location = locationId;
          match.selectedBy = req.userId;
        }
        await match.save();
        return res.json({ 
          message: 'It\'s a match!', 
          match: true,
          matchData: match
        });
      }
      return res.status(400).json({ message: 'Already swiped on this user' });
    }

    // Create new match record
    match = new Match({
      user1: req.userId,
      user2: targetUserId,
      location: locationId || null,
      selectedBy: locationId ? req.userId : null,
      status: 'pending'
    });

    await match.save();
    res.json({ message: 'Swiped right', match: false, matchData: match });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Swipe left (pass) on a user
router.post('/pass', authenticateToken, async (req, res) => {
  try {
    const { targetUserId } = req.body;

    // Create or update match record as unmatched
    let match = await Match.findOne({
      $or: [
        { user1: req.userId, user2: targetUserId },
        { user1: targetUserId, user2: req.userId }
      ]
    });

    if (!match) {
      match = new Match({
        user1: req.userId,
        user2: targetUserId,
        status: 'unmatched'
      });
    } else {
      match.status = 'unmatched';
    }

    await match.save();
    res.json({ message: 'Passed on user' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Get all matches for current user
router.get('/my-matches', authenticateToken, async (req, res) => {
  try {
    const matches = await Match.find({
      $or: [
        { user1: req.userId },
        { user2: req.userId }
      ],
      status: 'matched'
    })
    .populate('user1', 'name age bio photos profileImage gender location gallery lastSeenAt')
    .populate('user2', 'name age bio photos profileImage gender location gallery lastSeenAt')
    .populate('location')
    .sort({ createdAt: -1 });

    // Format matches to show the other user
    const formattedMatches = matches.map(match => {
      const otherUser = match.user1._id.toString() === req.userId 
        ? match.user2 
        : match.user1;
      
      // Properly serialize user object
      const serializedUser = otherUser ? {
        _id: otherUser._id.toString(),
        id: otherUser._id.toString(),
        name: otherUser.name,
        email: otherUser.email,
        age: otherUser.age,
        bio: otherUser.bio,
        profileImage: otherUser.profileImage,
        gender: otherUser.gender,
        photos: otherUser.photos,
        location: otherUser.location,
        gallery: otherUser.gallery,
        lastSeenAt: otherUser.lastSeenAt ? otherUser.lastSeenAt.toISOString() : null
      } : null;
      
      return {
        matchId: match._id.toString(),
        user: serializedUser,
        location: match.location,
        selectedBy: match.selectedBy,
        createdAt: match.createdAt
      };
    }).filter(m => m.user !== null); // Filter out any null users

    res.json(formattedMatches);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Send heart request to a user
router.post('/heart-request', authenticateToken, async (req, res) => {
  try {
    const { targetUserId } = req.body;

    if (!targetUserId) {
      return res.status(400).json({ message: 'Target user ID is required' });
    }

    // Check if match already exists
    let match = await Match.findOne({
      $or: [
        { user1: req.userId, user2: targetUserId },
        { user1: targetUserId, user2: req.userId }
      ]
    });

    if (match) {
      // If match exists with 'nudge' status from other user, and current user is sending heart back, it becomes a match
      if (match.user2.toString() === req.userId && match.status === 'nudge') {
        // User 2 is sending heart back to User 1 - it's a match!
        match.status = 'matched';
        match.updatedAt = Date.now();
        await match.save();
        return res.json({ 
          message: 'It\'s a match!', 
          match: true,
          matchData: match
        });
      }
      // If current user already sent a heart request, return error
      if (match.user1.toString() === req.userId && match.status === 'nudge') {
        return res.status(400).json({ message: 'You already sent a heart request to this user' });
      }
      // If already matched, return error
      if (match.status === 'matched') {
        return res.status(400).json({ message: 'You are already matched with this user' });
      }
      // If unmatched, update to nudge (heart request)
      match.status = 'nudge';
      match.user1 = req.userId;
      match.user2 = targetUserId;
      match.updatedAt = Date.now();
      await match.save();
      return res.json({ message: 'Heart request sent!', match: false, matchData: match });
    }

    // Create new heart request (stored as 'nudge' in DB)
    match = new Match({
      user1: req.userId,
      user2: targetUserId,
      status: 'nudge'
    });

    await match.save();
    res.json({ message: 'Heart request sent!', match: false, matchData: match });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Get received heart requests (paginated)
router.get('/received-hearts', authenticateToken, async (req, res) => {
  try {
    const page = parseInt(req.query.page) || 1;
    const limit = parseInt(req.query.limit) || 10;
    const skip = (page - 1) * limit;

    // Ensure userId is ObjectId
    const userId = mongoose.Types.ObjectId.isValid(req.userId) 
      ? new mongoose.Types.ObjectId(req.userId)
      : req.userId;

    const query = {
      user2: userId, // User is the target (user2)
      status: 'nudge' // Only get heart requests
    };

    console.log(`[RECEIVED-HEARTS] Query for user ${req.userId} (ObjectId: ${userId}):`, JSON.stringify(query));
    
    // Get total count for pagination
    const total = await Match.countDocuments(query);
    console.log(`[RECEIVED-HEARTS] Total matches found: ${total}`);

    // Get paginated matches
    const matches = await Match.find(query)
      .populate('user1', 'name age bio profileImage gender location gallery')
      .sort({ createdAt: -1 })
      .skip(skip)
      .limit(limit);

    console.log(`[RECEIVED-HEARTS] Found ${matches.length} matches for page ${page}`);
    if (matches.length > 0) {
      console.log(`[RECEIVED-HEARTS] First match: user1=${matches[0].user1?._id}, user2=${matches[0].user2}, status=${matches[0].status}`);
    }

    // Format to show the user who sent the heart request
    const formattedRequests = matches.map(match => {
      const user = match.user1;
      return {
        matchId: match._id.toString(),
        user: user ? {
          _id: user._id.toString(),
          id: user._id.toString(),
          name: user.name,
          email: user.email,
          age: user.age,
          bio: user.bio,
          profileImage: user.profileImage,
          gender: user.gender,
          location: user.location,
          gallery: user.gallery
        } : null,
        createdAt: match.createdAt
      };
    }).filter(req => req.user !== null); // Filter out any null users

    console.log(`[RECEIVED-HEARTS] Returning ${formattedRequests.length} requests for page ${page}`);

    res.json({
      requests: formattedRequests,
      pagination: {
        page,
        limit,
        total,
        totalPages: Math.ceil(total / limit),
        hasMore: page * limit < total
      }
    });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Decline a heart request
router.post('/decline-heart/:matchId', authenticateToken, async (req, res) => {
  try {
    const match = await Match.findById(req.params.matchId);

    if (!match) {
      return res.status(404).json({ message: 'Heart request not found' });
    }

    // Verify user is the target (user2) of this heart request
    if (match.user2.toString() !== req.userId) {
      return res.status(403).json({ message: 'Not authorized to decline this request' });
    }

    // Update status to unmatched
    match.status = 'unmatched';
    match.updatedAt = Date.now();
    await match.save();

    res.json({ message: 'Heart request declined' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Update location for a match
router.put('/:matchId/location', authenticateToken, async (req, res) => {
  try {
    const { locationId } = req.body;
    const match = await Match.findById(req.params.matchId);

    if (!match) {
      return res.status(404).json({ message: 'Match not found' });
    }

    // Verify user is part of this match
    if (match.user1.toString() !== req.userId && match.user2.toString() !== req.userId) {
      return res.status(403).json({ message: 'Not authorized' });
    }

    match.location = locationId;
    match.selectedBy = req.userId;
    match.updatedAt = Date.now();
    await match.save();

    res.json(match);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Unmatch a user
router.post('/:matchId/unmatch', authenticateToken, async (req, res) => {
  try {
    const match = await Match.findById(req.params.matchId);

    if (!match) {
      return res.status(404).json({ message: 'Match not found' });
    }

    // Verify user is part of this match
    if (match.user1.toString() !== req.userId && match.user2.toString() !== req.userId) {
      return res.status(403).json({ message: 'Not authorized' });
    }

    // Update status to unmatched
    match.status = 'unmatched';
    match.updatedAt = Date.now();
    await match.save();

    res.json({ message: 'User unmatched successfully' });
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

module.exports = router;
