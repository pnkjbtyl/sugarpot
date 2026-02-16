const mongoose = require('mongoose');
const Location = require('../models/Location');
require('dotenv').config();

// Popular locations in Chandigarh, India
const chandigarhLocations = [
  {
    name: 'Sukhna Lake',
    description: 'A beautiful man-made lake perfect for peaceful walks and boating',
    category: 'park',
    address: 'Sukhna Lake, Sector 1, Chandigarh',
    location: {
      latitude: 30.7415,
      longitude: 76.8174
    },
    rating: 4.5
  },
  {
    name: 'Rock Garden',
    description: 'Unique sculpture garden made from industrial and home waste',
    category: 'museum',
    address: 'Rock Garden, Sector 1, Chandigarh',
    location: {
      latitude: 30.7589,
      longitude: 76.8017
    },
    rating: 4.6
  },
  {
    name: 'Elante Mall',
    description: 'One of the largest malls in North India with shopping, dining, and entertainment',
    category: 'mall',
    address: 'Elante Mall, Industrial Area Phase 1, Chandigarh',
    location: {
      latitude: 30.7104,
      longitude: 76.8014
    },
    rating: 4.4
  },
  {
    name: 'Rose Garden',
    description: 'Asia\'s largest rose garden with over 1600 varieties of roses',
    category: 'park',
    address: 'Rose Garden, Sector 16, Chandigarh',
    location: {
      latitude: 30.7372,
      longitude: 76.7876
    },
    rating: 4.3
  },
  {
    name: 'Sector 17 Plaza',
    description: 'Famous shopping and dining area in the heart of Chandigarh',
    category: 'mall',
    address: 'Sector 17, Chandigarh',
    location: {
      latitude: 30.7372,
      longitude: 76.7876
    },
    rating: 4.2
  },
  {
    name: 'Cafe Coffee Day - Sector 35',
    description: 'Popular coffee chain perfect for casual meetups',
    category: 'cafe',
    address: 'Sector 35, Chandigarh',
    location: {
      latitude: 30.7200,
      longitude: 76.7800
    },
    rating: 4.1
  },
  {
    name: 'Zirakpur Food Street',
    description: 'Famous food street with various cuisines and street food',
    category: 'restaurant',
    address: 'Zirakpur, Chandigarh',
    location: {
      latitude: 30.6500,
      longitude: 76.8200
    },
    rating: 4.3
  },
  {
    name: 'Fun City Water Park',
    description: 'Exciting water park for fun-filled day out',
    category: 'other',
    address: 'Fun City, Zirakpur, Chandigarh',
    location: {
      latitude: 30.6400,
      longitude: 76.8300
    },
    rating: 4.0
  },
  {
    name: 'Gurudwara Sri Guru Singh Sabha',
    description: 'Beautiful and peaceful Gurudwara for spiritual visits',
    category: 'other',
    address: 'Sector 8, Chandigarh',
    location: {
      latitude: 30.7500,
      longitude: 76.7900
    },
    rating: 4.5
  },
  {
    name: 'Capitol Complex',
    description: 'UNESCO World Heritage Site with stunning architecture',
    category: 'other',
    address: 'Sector 1, Chandigarh',
    location: {
      latitude: 30.7589,
      longitude: 76.8017
    },
    rating: 4.4
  }
];

async function seedLocations() {
  try {
    // Connect to MongoDB
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/sugarpot', {
      useNewUrlParser: true,
      useUnifiedTopology: true,
    });

    console.log('Connected to MongoDB');

    // Clear existing locations (optional - comment out if you want to keep existing)
    // await Location.deleteMany({});
    // console.log('Cleared existing locations');

    // Insert locations
    const inserted = await Location.insertMany(chandigarhLocations);
    console.log(`Successfully seeded ${inserted.length} locations`);

    process.exit(0);
  } catch (error) {
    console.error('Error seeding locations:', error);
    process.exit(1);
  }
}

seedLocations();
