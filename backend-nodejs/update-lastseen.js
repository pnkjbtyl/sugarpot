const mongoose = require('mongoose');
const User = require('./models/User');
require('dotenv').config();

async function updateLastSeen() {
  try {
    console.log('Connecting to MongoDB...');
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/sugarpot');
    console.log('Connected to MongoDB');

    // Get all users
    const users = await User.find({});
    console.log(`Found ${users.length} users`);

    const now = Date.now();
    const fourMinutesAgo = now - (4 * 60 * 1000); // 4 minutes in milliseconds

    let updatedCount = 0;

    // Update each user with a random lastSeenAt between now and 4 minutes ago
    for (const user of users) {
      // Generate random timestamp between now and 4 minutes ago
      const randomTime = Math.floor(Math.random() * (now - fourMinutesAgo)) + fourMinutesAgo;
      const randomDate = new Date(randomTime);

      await User.findByIdAndUpdate(
        user._id,
        { lastSeenAt: randomDate },
        { new: true }
      );

      updatedCount++;
      console.log(`Updated ${user.name || user.email} - lastSeenAt: ${randomDate.toISOString()}`);
    }

    console.log(`\nSuccessfully updated ${updatedCount} users with random lastSeenAt timestamps (within last 4 minutes)`);

    process.exit(0);
  } catch (error) {
    console.error('Error updating lastSeenAt:', error);
    process.exit(1);
  } finally {
    if (mongoose.connection.readyState === 1) {
      await mongoose.connection.close();
      console.log('Database connection closed.');
    }
  }
}

updateLastSeen();
