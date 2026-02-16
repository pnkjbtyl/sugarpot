# SugarPot - Tinder-like Dating App

A full-stack mobile dating application with location-based matching and real-time chat.

## Project Structure

```
sugarpot/
├── app-flutter/          # Flutter mobile app (Android & iOS)
└── backend-nodejs/      # Node.js backend API with MongoDB
```

## Features

1. **User Authentication**: Register, login, and profile management
2. **Location-based Matching**: Find users within your preferred distance
3. **Swipe Functionality**: Like or pass on potential matches
4. **Location Selection**: When swiping right, select a location within 20km between you and the other user
5. **Real-time Chat**: Firebase Firestore for messaging
6. **Push Notifications**: Firebase Cloud Messaging for notifications
7. **Location Database**: Pre-seeded with popular locations in Chandigarh, India

## Tech Stack

### Backend
- Node.js with Express.js
- MongoDB with Mongoose
- JWT authentication
- RESTful API

### Frontend
- Flutter (Android & iOS)
- Firebase (Firestore & Cloud Messaging)
- Provider for state management
- Geolocator for location services

## Quick Start

### Backend Setup

1. Navigate to backend directory:
```bash
cd backend-nodejs
```

2. Install dependencies:
```bash
npm install
```

3. Create `.env` file:
```bash
cp .env.example .env
```

4. Update `.env` with your MongoDB connection string:
```
MONGODB_URI=mongodb://localhost:27017/sugarpot
JWT_SECRET=your-secret-key-here
PORT=3000
```

5. Make sure MongoDB is running on your system

6. Seed initial locations:
```bash
npm run seed
```

7. Start the server:
```bash
npm start
```

The backend will run on `http://localhost:3000`

### Flutter App Setup

1. Navigate to app directory:
```bash
cd app-flutter
```

2. Install dependencies:
```bash
flutter pub get
```

3. Firebase Setup:
   - Create a Firebase project
   - Add Android and iOS apps
   - Download configuration files:
     - `google-services.json` → `android/app/`
     - `GoogleService-Info.plist` → `ios/Runner/`
   - Enable Firestore and Cloud Messaging in Firebase Console

4. Update API URL in `lib/services/api_service.dart`:
   - For Android emulator: `http://10.0.2.2:3000/api`
   - For iOS simulator: `http://localhost:3000/api`
   - For physical device: `http://YOUR_IP:3000/api`

5. Run the app:
```bash
flutter run
```

## API Documentation

See `backend-nodejs/README.md` for detailed API documentation.

## Database Schema

### Users Collection
- Personal info (name, email, age, bio, photos)
- Location (latitude, longitude)
- Preferences (minAge, maxAge, maxDistance)
- Firebase token for notifications

### Locations Collection
- Location details (name, description, category, address)
- Coordinates (latitude, longitude)
- Rating and image URL

### Matches Collection
- User references (user1, user2)
- Selected location reference
- Match status (pending, matched, unmatched)

## Development Notes

- The app uses Firebase for chat and notifications
- Location selection happens when swiping right
- Selected location appears as a sticky header in the chat
- MongoDB is used for all user data and matches
- JWT tokens are used for API authentication

## Next Steps

1. Set up Firebase project and add configuration files
2. Update backend API URL in Flutter app
3. Test the app on Android/iOS device or emulator
4. Add more locations to the database as needed
5. Customize UI/UX as per requirements
