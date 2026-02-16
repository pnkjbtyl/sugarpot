# Backend Node.js API

Backend server for the Tinder-like mobile app built with Express.js and MongoDB.

## Setup

1. Install dependencies:
```bash
npm install
```

2. Create a `.env` file based on `.env.example`:
```bash
cp .env.example .env
```

3. Update `.env` with your MongoDB connection string and JWT secret.

4. Start MongoDB (make sure MongoDB is running on your system).

5. Seed initial locations data:
```bash
npm run seed
```

6. Start the server:
```bash
npm start
```

For development with auto-reload:
```bash
npm install -g nodemon
npm run dev
```

## API Endpoints

### Users
- `POST /api/users/register` - Register new user
- `POST /api/users/login` - Login user
- `GET /api/users/profile` - Get user profile (requires auth)
- `PUT /api/users/profile` - Update user profile (requires auth)
- `PUT /api/users/firebase-token` - Update Firebase token (requires auth)
- `GET /api/users/potential-matches` - Get potential matches (requires auth)

### Locations
- `GET /api/locations` - Get all locations
- `GET /api/locations/:id` - Get location by ID
- `POST /api/locations/nearby-between-users` - Get locations within 20km between two users (requires auth)
- `POST /api/locations` - Create new location (for seeding)

### Matches
- `POST /api/matches/swipe` - Swipe right on a user (requires auth)
- `POST /api/matches/pass` - Swipe left on a user (requires auth)
- `GET /api/matches/my-matches` - Get all matches for current user (requires auth)
- `PUT /api/matches/:matchId/location` - Update location for a match (requires auth)

## Authentication

Most endpoints require authentication. Include the JWT token in the Authorization header:
```
Authorization: Bearer <your-token>
```

## Database Models

### User
- name, email, password, age, bio
- photos (array of URLs)
- location (latitude, longitude)
- preferences (minAge, maxAge, maxDistance)
- firebaseToken

### Location
- name, description, category
- address
- location (latitude, longitude)
- imageUrl, rating

### Match
- user1, user2 (references to User)
- location (reference to Location)
- selectedBy (reference to User)
- status (pending, matched, unmatched)
