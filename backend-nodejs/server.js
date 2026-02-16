const express = require('express');
const mongoose = require('mongoose');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const http = require('http');
const { Server } = require('socket.io');
require('dotenv').config();

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Create uploads directories if they don't exist
const uploadsDir = path.join(__dirname, 'uploads', 'user-images');
const thumbnailsDir = path.join(uploadsDir, 'thumbnails');
const galleryDir = path.join(__dirname, 'uploads', 'gallery');
const galleryPublicDir = path.join(galleryDir, 'public');
const galleryLockedDir = path.join(galleryDir, 'locked');
const galleryPublicThumbnailsDir = path.join(galleryPublicDir, 'thumbnails');
const galleryLockedThumbnailsDir = path.join(galleryLockedDir, 'thumbnails');

[uploadsDir, thumbnailsDir, galleryPublicDir, galleryLockedDir, galleryPublicThumbnailsDir, galleryLockedThumbnailsDir].forEach(dir => {
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
});

// Middleware
app.use(cors());
// Increase JSON payload limit to 50MB for image uploads (base64 encoded)
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));
// Serve uploaded files (images and videos) with proper headers for video streaming
app.use('/uploads', express.static(path.join(__dirname, 'uploads'), {
  setHeaders: (res, filePath) => {
    // Set proper MIME types for videos
    if (filePath.endsWith('.mp4')) {
      res.setHeader('Content-Type', 'video/mp4');
      // Enable range requests for video seeking
      res.setHeader('Accept-Ranges', 'bytes');
    }
  }
}));

// MongoDB Connection
mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/sugarpot')
.then(() => console.log('MongoDB connected successfully'))
.catch(err => console.error('MongoDB connection error:', err));

// Routes
app.use('/api/users', require('./routes/users'));
app.use('/api/locations', require('./routes/locations'));
app.use('/api/matches', require('./routes/matches'));
app.use('/api/messages', require('./routes/messages'));
app.use('/api/chat-media', require('./routes/chatMedia'));
app.use('/api/reports', require('./routes/reports'));

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'OK', message: 'Server is running' });
});

// Socket.io setup
require('./sockets/chatSocket')(io);

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
  console.log(`Socket.io server initialized`);
});
