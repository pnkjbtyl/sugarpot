const mongoose = require('mongoose');
const User = require('./models/User');
const Match = require('./models/Match');
require('dotenv').config();

async function checkNudges() {
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
    console.log(`Found target user: ${targetUser.name} (${targetUser._id})\n`);

    // Count received heart requests (nudges)
    const count = await Match.countDocuments({
      user2: targetUser._id,
      status: 'nudge'
    });

    console.log(`Total received heart requests (nudges): ${count}`);

    // Get details of all received heart requests
    const matches = await Match.find({
      user2: targetUser._id,
      status: 'nudge'
    })
    .populate('user1', 'name email')
    .sort({ createdAt: -1 });

    console.log(`\nDetails of ${matches.length} received heart requests:`);
    console.log('─'.repeat(80));
    matches.forEach((match, index) => {
      const sender = match.user1;
      console.log(`${index + 1}. From: ${sender.name} (${sender.email})`);
      console.log(`   Match ID: ${match._id}`);
      console.log(`   Created: ${match.createdAt}`);
      console.log('');
    });

    process.exit(0);
  } catch (error) {
    console.error('Error checking nudges:', error);
    process.exit(1);
  } finally {
    if (mongoose.connection.readyState === 1) {
      await mongoose.connection.close();
      console.log('Database connection closed.');
    }
  }
}

checkNudges();
