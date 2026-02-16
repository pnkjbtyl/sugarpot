const express = require('express');
const router = express.Router();
const Location = require('../models/Location');
const User = require('../models/User');
const { authenticateToken } = require('../middleware/auth');

// Get all locations
router.get('/', async (req, res) => {
  try {
    const locations = await Location.find().sort({ createdAt: -1 });
    res.json(locations);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Get locations within 20km radius between two users
router.post('/nearby-between-users', authenticateToken, async (req, res) => {
  try {
    const { otherUserId } = req.body;
    const User = require('../models/User');
    
    const currentUser = await User.findById(req.userId);
    const otherUser = await User.findById(otherUserId);

    if (!currentUser || !otherUser) {
      return res.status(404).json({ message: 'User not found' });
    }

    // Calculate midpoint between two users
    const midLat = (currentUser.location.latitude + otherUser.location.latitude) / 2;
    const midLon = (currentUser.location.longitude + otherUser.location.longitude) / 2;

    // Find locations within 20km radius from midpoint
    const radiusInKm = 20;
    const radiusInRadians = radiusInKm / 6371; // Earth's radius in km

    const locations = await Location.find({
      location: {
        $geoWithin: {
          $centerSphere: [[midLon, midLat], radiusInRadians]
        }
      }
    });

    res.json(locations);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Get location by ID
router.get('/:id', async (req, res) => {
  try {
    const location = await Location.findById(req.params.id);
    if (!location) {
      return res.status(404).json({ message: 'Location not found' });
    }
    res.json(location);
  } catch (error) {
    res.status(500).json({ message: error.message });
  }
});

// Create new location (admin only - for seeding)
router.post('/', async (req, res) => {
  try {
    const location = new Location(req.body);
    await location.save();
    res.status(201).json(location);
  } catch (error) {
    res.status(400).json({ message: error.message });
  }
});

module.exports = router;
