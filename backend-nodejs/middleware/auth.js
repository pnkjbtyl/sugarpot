const jwt = require('jsonwebtoken');
const User = require('../models/User');

async function authenticateToken(req, res, next) {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ 
      message: 'Access token required',
      code: 'TOKEN_REQUIRED'
    });
  }

  jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key', async (err, decoded) => {
    if (err) {
      // If token is expired, return specific error
      if (err.name === 'TokenExpiredError') {
        return res.status(401).json({ 
          message: 'Token expired',
          code: 'TOKEN_EXPIRED'
        });
      }
      return res.status(403).json({ 
        message: 'Invalid token',
        code: 'TOKEN_INVALID'
      });
    }
    req.userId = decoded.userId;
    
    // Update lastSeenAt timestamp for the user (non-blocking)
    try {
      await User.findByIdAndUpdate(
        decoded.userId,
        { lastSeenAt: new Date() },
        { returnDocument: 'before' } // Don't return the updated document, just update it
      );
    } catch (updateError) {
      // Log error but don't block the request
      console.error('Error updating lastSeenAt:', updateError);
    }
    
    next();
  });
}

module.exports = { authenticateToken };
