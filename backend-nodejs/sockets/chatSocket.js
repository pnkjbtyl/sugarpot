const jwt = require('jsonwebtoken');
const User = require('../models/User');
const Message = require('../models/Message');
const Match = require('../models/Match');

// Store user socket connections: userId -> socketId
const userSockets = new Map();

// Get next message ID (auto-increment)
async function getNextMessageId() {
  const lastMessage = await Message.findOne().sort({ id: -1 }).limit(1);
  return lastMessage ? lastMessage.id + 1 : 1;
}

// Get next sequence ID for a match
async function getNextSequenceId(matchId) {
  const lastMessage = await Message.findOne({ matchId }).sort({ sequenceId: -1 }).limit(1);
  return lastMessage ? lastMessage.sequenceId + 1 : 1;
}

// Authenticate socket connection
function authenticateSocket(socket, next) {
  const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.split(' ')[1];
  
  if (!token) {
    return next(new Error('Authentication error: No token provided'));
  }

  jwt.verify(token, process.env.JWT_SECRET || 'your-secret-key', (err, decoded) => {
    if (err) {
      return next(new Error('Authentication error: Invalid token'));
    }
    socket.userId = decoded.userId;
    next();
  });
}

module.exports = (io) => {
  // Socket authentication middleware
  io.use(authenticateSocket);

  io.on('connection', (socket) => {
    const userId = socket.userId;
    console.log(`User ${userId} connected with socket ${socket.id}`);
    
    // Store user's socket connection
    userSockets.set(userId.toString(), socket.id);

    // Join room for this user
    socket.join(`user_${userId}`);

    // Send message
    socket.on('send_message', async (data) => {
      try {
        const { matchId, receiverId, messageType, messageText } = data;

        // Validate match exists and user is part of it
        const match = await Match.findById(matchId);
        if (!match) {
          socket.emit('error', { message: 'Match not found' });
          return;
        }

        const senderId = userId;
        const isUser1 = match.user1.toString() === senderId.toString();
        const isUser2 = match.user2.toString() === senderId.toString();
        
        if (!isUser1 && !isUser2) {
          socket.emit('error', { message: 'Not authorized for this match' });
          return;
        }

        // Verify receiver is the other user in the match
        const actualReceiverId = isUser1 ? match.user2 : match.user1;
        if (actualReceiverId.toString() !== receiverId.toString()) {
          socket.emit('error', { message: 'Invalid receiver' });
          return;
        }

        // Get next IDs
        const messageId = await getNextMessageId();
        const sequenceId = await getNextSequenceId(matchId);

        // Create message
        const message = new Message({
          id: messageId,
          matchId,
          senderId,
          receiverId,
          sequenceId,
          messageType: messageType || 'text',
          messageText,
          isSent: true,
          isDelivered: false,
          sentAt: new Date()
        });

        await message.save();

        // Prepare message payload
        const messagePayload = {
          id: message.id,
          sequenceId: message.sequenceId,
          messageType: message.messageType,
          messageText: message.messageText,
          isSent: message.isSent,
          isDelivered: message.isDelivered,
          sentAt: message.sentAt.toISOString(),
          deliveredAt: message.deliveredAt ? message.deliveredAt.toISOString() : null,
          senderId: senderId.toString(),
          receiverId: receiverId.toString()
        };

        // Emit to sender (confirmation)
        socket.emit('message_sent', messagePayload);

        // Check if receiver is online
        const receiverSocketId = userSockets.get(receiverId.toString());
        if (receiverSocketId) {
          // Receiver is online - mark as delivered immediately
          message.isDelivered = true;
          message.deliveredAt = new Date();
          await message.save();
          messagePayload.isDelivered = true;
          messagePayload.deliveredAt = message.deliveredAt.toISOString();

          // Emit to receiver
          io.to(`user_${receiverId}`).emit('new_message', messagePayload);
          
          // Notify sender that message was delivered
          socket.emit('message_delivered', {
            id: message.id,
            sequenceId: message.sequenceId,
            deliveredAt: message.deliveredAt.toISOString()
          });
        } else {
          // Receiver is offline - emit to receiver's room (they'll get it when they connect)
          io.to(`user_${receiverId}`).emit('new_message', messagePayload);
        }
      } catch (error) {
        console.error('Error sending message:', error);
        socket.emit('error', { message: 'Failed to send message', error: error.message });
      }
    });

    // Mark messages as delivered
    socket.on('mark_delivered', async (data) => {
      try {
        const { messageIds } = data;
        
        await Message.updateMany(
          {
            id: { $in: messageIds },
            receiverId: userId,
            isDelivered: false
          },
          {
            isDelivered: true,
            deliveredAt: new Date()
          }
        );

        // Notify sender that messages were delivered
        const messages = await Message.find({ id: { $in: messageIds } });
        messages.forEach(message => {
          io.to(`user_${message.senderId}`).emit('message_delivered', {
            id: message.id,
            sequenceId: message.sequenceId,
            deliveredAt: new Date().toISOString()
          });
        });
      } catch (error) {
        console.error('Error marking messages as delivered:', error);
      }
    });

    // Mark messages as read
    socket.on('mark_read', async (data) => {
      try {
        const { messageIds } = data;
        
        await Message.updateMany(
          {
            id: { $in: messageIds },
            receiverId: userId,
            readAt: null
          },
          {
            readAt: new Date()
          }
        );
      } catch (error) {
        console.error('Error marking messages as read:', error);
      }
    });

    // Get message history
    socket.on('get_messages', async (data) => {
      try {
        const { matchId, limit = 50, beforeSequenceId } = data;

        // Validate match
        const match = await Match.findById(matchId);
        if (!match) {
          socket.emit('error', { message: 'Match not found' });
          return;
        }

        const isUser1 = match.user1.toString() === userId.toString();
        const isUser2 = match.user2.toString() === userId.toString();
        
        if (!isUser1 && !isUser2) {
          socket.emit('error', { message: 'Not authorized for this match' });
          return;
        }

        // Build query
        const query = { matchId };
        if (beforeSequenceId) {
          query.sequenceId = { $lt: beforeSequenceId };
        }

        const messages = await Message.find(query)
          .sort({ sequenceId: -1 })
          .limit(limit);

        const messagesPayload = messages.reverse().map(msg => ({
          id: msg.id,
          sequenceId: msg.sequenceId,
          messageType: msg.messageType,
          messageText: msg.messageText,
          isSent: msg.senderId.toString() === userId.toString(),
          isDelivered: msg.isDelivered,
          sentAt: msg.sentAt.toISOString(),
          deliveredAt: msg.deliveredAt ? msg.deliveredAt.toISOString() : null,
          senderId: msg.senderId.toString(),
          receiverId: msg.receiverId.toString()
        }));

        socket.emit('messages_history', messagesPayload);

        // Mark undelivered messages as delivered when user requests history (they're online now)
        const undeliveredMessages = messages.filter(msg => 
          msg.receiverId.toString() === userId.toString() && !msg.isDelivered
        );
        if (undeliveredMessages.length > 0) {
          const undeliveredIds = undeliveredMessages.map(msg => msg.id);
          await Message.updateMany(
            { id: { $in: undeliveredIds } },
            { isDelivered: true, deliveredAt: new Date() }
          );

          // Notify senders that messages were delivered
          undeliveredMessages.forEach(message => {
            io.to(`user_${message.senderId}`).emit('message_delivered', {
              id: message.id,
              sequenceId: message.sequenceId,
              deliveredAt: new Date().toISOString()
            });
          });
        }
      } catch (error) {
        console.error('Error getting messages:', error);
        socket.emit('error', { message: 'Failed to get messages', error: error.message });
      }
    });

    // Handle disconnect
    socket.on('disconnect', () => {
      console.log(`User ${userId} disconnected`);
      userSockets.delete(userId.toString());
    });
  });
};
