const mongoose = require('mongoose');
const Match = require('./models/Match');
require('dotenv').config();

async function deleteAllMatches() {
  try {
    // Connect to MongoDB
    const mongoUri = process.env.MONGODB_URI || 'mongodb://localhost:27017/sugarpot';
    console.log('Connecting to MongoDB...');
    await mongoose.connect(mongoUri);
    console.log('Connected to MongoDB');

    // Count existing matches
    const countBefore = await Match.countDocuments();
    console.log(`Found ${countBefore} matches in the database`);

    if (countBefore === 0) {
      console.log('No matches to delete.');
      await mongoose.connection.close();
      return;
    }

    // Delete all matches
    const result = await Match.deleteMany({});
    console.log(`Successfully deleted ${result.deletedCount} matches from the database.`);

    // Verify deletion
    const countAfter = await Match.countDocuments();
    console.log(`Remaining matches: ${countAfter}`);

    // Close connection
    await mongoose.connection.close();
    console.log('Database connection closed.');
  } catch (error) {
    console.error('Error deleting matches:', error);
    await mongoose.connection.close();
    process.exit(1);
  }
}

deleteAllMatches();
