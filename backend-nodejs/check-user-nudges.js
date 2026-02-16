const mongoose = require('mongoose');
const User = require('./models/User');
const Match = require('./models/Match');
require('dotenv').config();

async function checkUserNudges() {
  try {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/sugarpot');
    console.log('Connected to MongoDB');

    const userId = '6991daa14967fabd76f78392';
    
    // Find the user
    const user = await User.findById(userId);
    if (!user) {
      console.error(`User with ID ${userId} not found`);
      process.exit(1);
    }
    console.log(`Found user: ${user.name} (${user.email})\n`);

    // Check received nudges (where user is user2)
    const receivedNudges = await Match.find({
      user2: userId,
      status: 'nudge'
    })
    .populate('user1', 'name email')
    .sort({ createdAt: -1 });

    console.log(`Total received nudges: ${receivedNudges.length}\n`);

    if (receivedNudges.length > 0) {
      console.log('Received nudges:');
      console.log('─'.repeat(80));
      receivedNudges.forEach((match, index) => {
        const sender = match.user1;
        console.log(`${index + 1}. From: ${sender.name} (${sender.email})`);
        console.log(`   Match ID: ${match._id}`);
        console.log(`   Status: ${match.status}`);
        console.log(`   Created: ${match.createdAt}`);
        console.log(`   user1: ${match.user1._id}`);
        console.log(`   user2: ${match.user2._id}`);
        console.log('');
      });
    } else {
      console.log('No received nudges found.');
      
      // Check if there are any matches at all for this user
      const allMatches = await Match.find({
        $or: [
          { user1: userId },
          { user2: userId }
        ]
      });
      console.log(`\nTotal matches for this user: ${allMatches.length}`);
      
      if (allMatches.length > 0) {
        console.log('\nAll matches:');
        allMatches.forEach((match, index) => {
          console.log(`${index + 1}. Match ID: ${match._id}`);
          console.log(`   user1: ${match.user1}`);
          console.log(`   user2: ${match.user2}`);
          console.log(`   Status: ${match.status}`);
          console.log(`   Created: ${match.createdAt}`);
          console.log('');
        });
      }
    }

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

checkUserNudges();
