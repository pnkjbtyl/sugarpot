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

// Increase server timeout for large file uploads (30 minutes)
server.timeout = 30 * 60 * 1000; // 30 minutes
server.keepAliveTimeout = 30 * 60 * 1000; // 30 minutes
server.headersTimeout = 31 * 60 * 1000; // 31 minutes (must be > keepAliveTimeout)

const io = new Server(server, {
  cors: {
    origin: process.env.NODE_ENV === 'production' 
      ? ['https://sugarpot.shree.systems', 'http://sugarpot.shree.systems']
      : "*",
    methods: ["GET", "POST"],
    credentials: true
  },
  // Allow Socket.io to work behind reverse proxy
  allowEIO3: true,
  // Increase buffer size for large file uploads via Socket.io
  maxHttpBufferSize: 100 * 1024 * 1024, // 100MB
  // Increase ping timeout for long-running operations
  pingTimeout: 30 * 60 * 1000, // 30 minutes
  pingInterval: 25000, // 25 seconds
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
const allowedOrigins = process.env.NODE_ENV === 'production' 
  ? ['https://sugarpot.shree.systems', 'http://sugarpot.shree.systems']
  : '*';

app.use(cors({
  origin: allowedOrigins,
  credentials: true
}));
// Increase JSON payload limit to 50MB for image uploads (base64 encoded)
app.use(express.json({ limit: '50mb' }));
app.use(express.urlencoded({ extended: true, limit: '50mb' }));

// Increase request timeout for all routes (30 minutes)
app.use((req, res, next) => {
  req.setTimeout(30 * 60 * 1000); // 30 minutes
  res.setTimeout(30 * 60 * 1000); // 30 minutes
  next();
});

if(process.env.NODE_ENV === 'development') {
  // 5 second delay on every response (e.g. for testing loading states)
  const RESPONSE_DELAY_MS = 5000;
  app.use((req, res, next) => {
    setTimeout(next, RESPONSE_DELAY_MS);
  });
}

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
// Suppress Mongoose deprecation warnings for 'new' option
// Note: This is a temporary workaround until all internal Mongoose operations are updated
mongoose.set('strictQuery', false);

mongoose.connect(process.env.MONGODB_URI || 'mongodb://localhost:27017/sugarpot', {
  // Use new returnDocument option format
  // This helps reduce deprecation warnings
})
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
