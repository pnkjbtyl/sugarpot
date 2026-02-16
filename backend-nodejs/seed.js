const mongoose = require('mongoose');
const User = require('./models/User');
require('dotenv').config();

// Sample data arrays for realistic user generation
const firstNames = [
  'Alex', 'Jordan', 'Taylor', 'Morgan', 'Casey', 'Riley', 'Avery', 'Quinn',
  'Emma', 'Olivia', 'Sophia', 'Isabella', 'Mia', 'Charlotte', 'Amelia', 'Harper',
  'James', 'John', 'Robert', 'Michael', 'William', 'David', 'Richard', 'Joseph',
  'Sarah', 'Emily', 'Jessica', 'Ashley', 'Amanda', 'Melissa', 'Nicole', 'Michelle',
  'Daniel', 'Matthew', 'Christopher', 'Andrew', 'Joshua', 'Justin', 'Brandon', 'Ryan',
  'Priya', 'Anjali', 'Kavya', 'Riya', 'Arjun', 'Rohan', 'Aryan', 'Vikram',
  'Emma', 'Liam', 'Noah', 'Olivia', 'Ava', 'Ethan', 'Lucas', 'Mason'
];

const lastNames = [
  'Smith', 'Johnson', 'Williams', 'Brown', 'Jones', 'Garcia', 'Miller', 'Davis',
  'Rodriguez', 'Martinez', 'Hernandez', 'Lopez', 'Wilson', 'Anderson', 'Thomas', 'Taylor',
  'Moore', 'Jackson', 'Martin', 'Lee', 'Thompson', 'White', 'Harris', 'Sanchez',
  'Clark', 'Ramirez', 'Lewis', 'Robinson', 'Walker', 'Young', 'Allen', 'King',
  'Wright', 'Scott', 'Torres', 'Nguyen', 'Hill', 'Flores', 'Green', 'Adams',
  'Sharma', 'Patel', 'Kumar', 'Singh', 'Reddy', 'Nair', 'Iyer', 'Menon',
  'Chen', 'Wang', 'Li', 'Zhang', 'Liu', 'Yang', 'Huang', 'Zhao'
];

const cities = [
  { city: 'Mumbai', state: 'Maharashtra', countryCode: 'IN', lat: 19.0760, lng: 72.8777 },
  { city: 'Delhi', state: 'Delhi', countryCode: 'IN', lat: 28.6139, lng: 77.2090 },
  { city: 'Bangalore', state: 'Karnataka', countryCode: 'IN', lat: 12.9716, lng: 77.5946 },
  { city: 'Hyderabad', state: 'Telangana', countryCode: 'IN', lat: 17.3850, lng: 78.4867 },
  { city: 'Chennai', state: 'Tamil Nadu', countryCode: 'IN', lat: 13.0827, lng: 80.2707 },
  { city: 'Kolkata', state: 'West Bengal', countryCode: 'IN', lat: 22.5726, lng: 88.3639 },
  { city: 'Pune', state: 'Maharashtra', countryCode: 'IN', lat: 18.5204, lng: 73.8567 },
  { city: 'Ahmedabad', state: 'Gujarat', countryCode: 'IN', lat: 23.0225, lng: 72.5714 },
  { city: 'Auckland', state: 'Auckland', countryCode: 'NZ', lat: -36.8485, lng: 174.7633 },
  { city: 'Wellington', state: 'Wellington', countryCode: 'NZ', lat: -41.2865, lng: 174.7762 },
  { city: 'Christchurch', state: 'Canterbury', countryCode: 'NZ', lat: -43.5321, lng: 172.6362 },
  { city: 'New York', state: 'New York', countryCode: 'US', lat: 40.7128, lng: -74.0060 },
  { city: 'Los Angeles', state: 'California', countryCode: 'US', lat: 34.0522, lng: -118.2437 },
  { city: 'London', state: 'England', countryCode: 'GB', lat: 51.5074, lng: -0.1278 },
  { city: 'Sydney', state: 'New South Wales', countryCode: 'AU', lat: -33.8688, lng: 151.2093 }
];

const professions = [
  'Software Engineer', 'Doctor', 'Teacher', 'Lawyer', 'Designer', 'Marketing Manager',
  'Accountant', 'Nurse', 'Engineer', 'Consultant', 'Entrepreneur', 'Artist',
  'Photographer', 'Writer', 'Chef', 'Architect', 'Pilot', 'Scientist',
  'Therapist', 'Sales Manager', 'HR Manager', 'Project Manager', 'Data Analyst',
  'Graphic Designer', 'Musician', 'Actor', 'Fitness Trainer', 'Real Estate Agent',
  'Financial Advisor', 'Social Worker', 'Journalist', 'Veterinarian', 'Dentist'
];

const pickupLines = [
  'Are you a magician? Because whenever I look at you, everyone else disappears.',
  'Do you have a map? I keep getting lost in your eyes.',
  'Is your name Google? Because you have everything I\'ve been searching for.',
  'Are you made of copper and tellurium? Because you\'re Cu-Te.',
  'If you were a vegetable, you\'d be a cute-cumber.',
  'Do you believe in love at first sight, or should I walk by again?',
  'Are you a camera? Because every time I look at you, I smile.',
  'Is your dad a baker? Because you\'re a cutie pie.',
  'Do you have a Band-Aid? Because I just scraped my knee falling for you.',
  'Are you a parking ticket? Because you\'ve got FINE written all over you.',
  'Do you like Star Wars? Because Yoda one for me!',
  'Are you a time traveler? Because I can see you in my future.',
  'Is your name Wi-Fi? Because I\'m really feeling a connection.',
  'Do you have a sunburn, or are you always this hot?',
  'Are you French? Because Eiffel for you.',
  'Do you have a map? I keep getting lost in your smile.',
  'Is your name Chapstick? Because you\'re da balm!',
  'Are you a loan? Because you have my interest.',
  'Do you like raisins? How do you feel about a date?',
  'Are you a campfire? Because you\'re hot and I want s\'more.'
];

const bios = [
  'Love traveling, good food, and great conversations.',
  'Adventure seeker, coffee enthusiast, and dog lover.',
  'Passionate about life, music, and making memories.',
  'Fitness enthusiast, bookworm, and sunset chaser.',
  'Foodie, traveler, and always up for new experiences.',
  'Yoga practitioner, nature lover, and mindfulness advocate.',
  'Creative soul, art lover, and weekend explorer.',
  'Tech geek, gaming enthusiast, and movie buff.',
  'Fitness coach, health advocate, and positive thinker.',
  'Artist, dreamer, and believer in magic moments.',
  'Entrepreneur, coffee addict, and adventure seeker.',
  'Musician, traveler, and lover of life\'s simple pleasures.',
  'Writer, reader, and seeker of meaningful connections.',
  'Photographer, nature enthusiast, and sunset admirer.',
  'Chef, food blogger, and culinary explorer.'
];

// Gallery images available in gallery/public
// Note: Thumbnails should exist in gallery/public/thumbnails/ with matching names
const galleryImages = [
  { url: '/uploads/gallery/public/user-1-gallery-1.jpg', thumbnailUrl: '/uploads/gallery/public/thumbnails/user-1-gallery-1.jpg', type: 'image' },
  { url: '/uploads/gallery/public/user-1-gallery-2.mp4', thumbnailUrl: '/uploads/gallery/public/thumbnails/user-1-gallery-2.jpg', type: 'video' },
  { url: '/uploads/gallery/public/user-2-gallery-1.jpg', thumbnailUrl: '/uploads/gallery/public/thumbnails/user-2-gallery-1.jpg', type: 'image' },
  { url: '/uploads/gallery/public/user-2-gallery-2.mp4', thumbnailUrl: '/uploads/gallery/public/thumbnails/user-2-gallery-2.jpg', type: 'video' },
  { url: '/uploads/gallery/public/user-3-gallery-1.jpg', thumbnailUrl: '/uploads/gallery/public/thumbnails/user-3-gallery-1.jpg', type: 'image' },
  { url: '/uploads/gallery/public/user-3-gallery-2.mp4', thumbnailUrl: '/uploads/gallery/public/thumbnails/user-3-gallery-2.jpg', type: 'video' },
  { url: '/uploads/gallery/public/user-4-gallery-1.jpg', thumbnailUrl: '/uploads/gallery/public/thumbnails/user-4-gallery-1.jpg', type: 'image' },
  { url: '/uploads/gallery/public/user-4-gallery-2.mp4', thumbnailUrl: '/uploads/gallery/public/thumbnails/user-4-gallery-2.jpg', type: 'video' },
  { url: '/uploads/gallery/public/user-5-gallery-1.jpg', thumbnailUrl: '/uploads/gallery/public/thumbnails/user-5-gallery-1.jpg', type: 'image' },
  { url: '/uploads/gallery/public/user-5-gallery-2.mp4', thumbnailUrl: '/uploads/gallery/public/thumbnails/user-5-gallery-2.jpg', type: 'video' }
];

// Profile images (user1.jpg through user5.jpg)
const profileImages = [
  '/uploads/user-images/user1.jpg',
  '/uploads/user-images/user2.jpg',
  '/uploads/user-images/user3.jpg',
  '/uploads/user-images/user4.jpg',
  '/uploads/user-images/user5.jpg'
];

// Helper function to get random item from array
function getRandomItem(array) {
  return array[Math.floor(Math.random() * array.length)];
}

// Helper function to get random items from array
function getRandomItems(array, count) {
  const shuffled = [...array].sort(() => 0.5 - Math.random());
  return shuffled.slice(0, count);
}

// Helper function to generate random date of birth (18-50 years old)
function getRandomDateOfBirth() {
  const now = new Date();
  const minAge = 18;
  const maxAge = 50;
  const randomAge = Math.floor(Math.random() * (maxAge - minAge + 1)) + minAge;
  const year = now.getFullYear() - randomAge;
  const month = Math.floor(Math.random() * 12);
  const day = Math.floor(Math.random() * 28) + 1;
  return new Date(year, month, day);
}

// Helper function to generate random email
function generateEmail(firstName, lastName, index) {
  const domains = ['gmail.com', 'yahoo.com', 'hotmail.com', 'outlook.com', 'icloud.com'];
  const randomDomain = getRandomItem(domains);
  return `${firstName.toLowerCase()}.${lastName.toLowerCase()}${index}@${randomDomain}`;
}

// Generate a single user
function generateUser(index) {
  const firstName = getRandomItem(firstNames);
  const lastName = getRandomItem(lastNames);
  const gender = getRandomItem(['male', 'female', 'other']);
  const location = getRandomItem(cities);
  const dateOfBirth = getRandomDateOfBirth();
  
  // Calculate age
  const now = new Date();
  const age = now.getFullYear() - dateOfBirth.getFullYear();
  
  // Generate preferences based on age
  const minAge = Math.max(18, age - 5);
  const maxAge = Math.min(100, age + 10);
  
  // Randomly assign interestedIn (can be multiple)
  const interestedInOptions = ['male', 'female', 'other'];
  const interestedInCount = Math.floor(Math.random() * 3) + 1; // 1-3 options
  const interestedIn = getRandomItems(interestedInOptions, interestedInCount);
  
  // Randomly assign profile image
  const profileImage = getRandomItem(profileImages);
  
  // Randomly assign gallery images (0-5 images)
  const galleryCount = Math.floor(Math.random() * 6); // 0-5 images
  const selectedGalleryImages = getRandomItems(galleryImages, galleryCount);
  
  // Randomly assign optional fields (some users might not have them)
  const hasProfession = Math.random() > 0.3; // 70% have profession
  const hasEatingHabits = Math.random() > 0.4; // 60% have eating habits
  const hasSmoking = Math.random() > 0.3; // 70% have smoking preference
  const hasDrinking = Math.random() > 0.3; // 70% have drinking preference
  const hasBio = Math.random() > 0.5; // 50% have bio
  const hasPickupLine = Math.random() > 0.2; // 80% have pickup line
  
  const user = {
    email: generateEmail(firstName, lastName, index),
    name: `${firstName} ${lastName}`,
    dateOfBirth: dateOfBirth,
    gender: gender,
    profileImage: profileImage,
    isOnboardingComplete: true,
    isProfileHidden: Math.random() > 0.95, // 5% have hidden profiles
    location: {
      latitude: location.lat + (Math.random() * 0.1 - 0.05), // Add small random variation
      longitude: location.lng + (Math.random() * 0.1 - 0.05),
      city: location.city,
      state: location.state,
      countryCode: location.countryCode
    },
    preferences: {
      minAge: minAge,
      maxAge: maxAge,
      maxDistance: Math.floor(Math.random() * 50) + 10, // 10-60 km
      interestedIn: interestedIn
    },
    gallery: {
      public: selectedGalleryImages.map(img => ({
        ...img,
        uploadedAt: new Date(Date.now() - Math.random() * 30 * 24 * 60 * 60 * 1000) // Random date in last 30 days
      })),
      locked: [] // No locked images for seed data
    },
    lastSeenAt: new Date(Date.now() - Math.random() * 7 * 24 * 60 * 60 * 1000), // Random date in last 7 days
    createdAt: new Date(Date.now() - Math.random() * 90 * 24 * 60 * 60 * 1000), // Random date in last 90 days
    updatedAt: new Date()
  };
  
  // Add optional fields
  if (hasProfession) {
    user.profession = getRandomItem(professions);
  }
  
  if (hasEatingHabits) {
    user.eatingHabits = getRandomItem(['vegetarian', 'non-vegetarian', 'vegan']);
  }
  
  if (hasSmoking) {
    user.smoking = getRandomItem(['yes', 'no', 'occasionally']);
  }
  
  if (hasDrinking) {
    user.drinking = getRandomItem(['yes', 'no', 'occasionally']);
  }
  
  if (hasBio) {
    user.bio = getRandomItem(bios);
  }
  
  if (hasPickupLine) {
    user.pickupLine = getRandomItem(pickupLines).substring(0, 50); // Ensure max 50 chars
  }
  
  return user;
}

// Main seeder function
async function seedDatabase() {
  try {
    // Connect to MongoDB
    await mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/sugarpot');
    console.log('Connected to MongoDB');

    // Clear existing users (optional - comment out if you want to keep existing users)
    const existingCount = await User.countDocuments();
    console.log(`Found ${existingCount} existing users`);
    
    // Ask if user wants to clear existing users (for safety, we'll skip this by default)
    // Uncomment the next line if you want to delete all users before seeding
    // await User.deleteMany({});
    // console.log('Cleared existing users');

    // Generate 200 users
    console.log('Generating 200 user profiles...');
    const users = [];
    for (let i = 1; i <= 200; i++) {
      users.push(generateUser(i));
      if (i % 50 === 0) {
        console.log(`Generated ${i}/200 users...`);
      }
    }

    // Insert users in batches
    console.log('Inserting users into database...');
    const batchSize = 50;
    for (let i = 0; i < users.length; i += batchSize) {
      const batch = users.slice(i, i + batchSize);
      await User.insertMany(batch);
      console.log(`Inserted batch ${Math.floor(i / batchSize) + 1}/${Math.ceil(users.length / batchSize)}`);
    }

    console.log(`\n✅ Successfully seeded ${users.length} users!`);
    console.log(`\nSummary:`);
    console.log(`- Total users: ${await User.countDocuments()}`);
    console.log(`- Users with profile images: ${await User.countDocuments({ profileImage: { $exists: true } })}`);
    console.log(`- Users with gallery images: ${await User.countDocuments({ 'gallery.public.0': { $exists: true } })}`);
    console.log(`- Hidden profiles: ${await User.countDocuments({ isProfileHidden: true })}`);

    process.exit(0);
  } catch (error) {
    console.error('Error seeding database:', error);
    process.exit(1);
  }
}

// Run the seeder
seedDatabase();
