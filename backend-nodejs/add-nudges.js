const mongoose = require('mongoose');
const User = require('./models/User');
const Match = require('./models/Match');
require('dotenv').config();

async function addNudges() {
  try {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/sugarpot');
    console.log('Connected to MongoDB');

    // Find the target user
    const targetUser = await User.findOne({ email: 'pankaj@yopmail.com' });
    if (!targetUser) {
      console.error('User pankaj@yopmail.com not found');
      process.exit(1);
    }
    console.log(`Found target user: ${targetUser.name} (${targetUser._id})`);

    // Find random users (excluding the target user and users who already have a match record with target)
    const existingMatches = await Match.find({
      $or: [
        { user1: targetUser._id },
        { user2: targetUser._id }
      ]
    });
    const excludedUserIds = [
      targetUser._id,
      ...existingMatches.map(match => {
        return match.user1.toString() === targetUser._id.toString()
          ? match.user2
          : match.user1;
      })
    ];

    const randomUsers = await User.find({
      _id: { $nin: excludedUserIds },
      isOnboardingComplete: true,
      email: { $ne: 'pankaj@yopmail.com' }
    }).limit(12);

    if (randomUsers.length < 12) {
      console.log(`Warning: Only found ${randomUsers.length} available users. Creating ${randomUsers.length} nudge requests.`);
    }

    console.log(`Found ${randomUsers.length} random users to send nudges from`);

    // Create nudge requests
    const nudgePromises = randomUsers.map(async (sender) => {
      // Check if match already exists
      const existingMatch = await Match.findOne({
        $or: [
          { user1: sender._id, user2: targetUser._id },
          { user1: targetUser._id, user2: sender._id }
        ]
      });

      if (existingMatch) {
        console.log(`Match already exists between ${sender.name} and ${targetUser.name}, skipping...`);
        return null;
      }

      const nudge = new Match({
        user1: sender._id,
        user2: targetUser._id,
        status: 'nudge'
      });

      await nudge.save();
      console.log(`Created nudge request from ${sender.name} (${sender.email}) to ${targetUser.name}`);
      return nudge;
    });

    const results = await Promise.all(nudgePromises);
    const created = results.filter(r => r !== null).length;

    console.log(`\nSuccessfully created ${created} nudge requests for ${targetUser.name}`);
    console.log(`Total nudge requests for ${targetUser.name}: ${await Match.countDocuments({ user2: targetUser._id, status: 'nudge' })}`);

    process.exit(0);
  } catch (error) {
    console.error('Error adding nudges:', error);
    process.exit(1);
  } finally {
    if (mongoose.connection.readyState === 1) {
      await mongoose.connection.close();
      console.log('Database connection closed.');
    }
  }
}

addNudges();
