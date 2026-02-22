/**
 * Send FCM (Firebase Cloud Messaging) notifications.
 * Requires: npm install firebase-admin
 * Env: GOOGLE_APPLICATION_CREDENTIALS = path to Firebase service account JSON
 *      (or FIREBASE_SERVICE_ACCOUNT_PATH for require()-style path)
 */
let admin = null;
let initialized = false;

function getAdmin() {
  if (admin) return admin;
  try {
    admin = require('firebase-admin');
  } catch (e) {
    console.warn('firebase-admin not installed. Run: npm install firebase-admin');
    return null;
  }
  return admin;
}

function initialize() {
  if (initialized) return true;
  const adm = getAdmin();
  if (!adm) return false;
  try {
    if (adm.apps.length > 0) return true;
    const path = require('path');
    const fs = require('fs');
    const credPath = process.env.GOOGLE_APPLICATION_CREDENTIALS || process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
    if (credPath) {
      const resolved = path.isAbsolute(credPath) ? credPath : path.resolve(process.cwd(), credPath);
      const key = JSON.parse(fs.readFileSync(resolved, 'utf8'));
      adm.initializeApp({
        credential: adm.credential.cert(key),
        projectId: key.project_id,
      });
    } else {
      adm.initializeApp({ credential: adm.credential.applicationDefault() });
    }
    initialized = true;
    return true;
  } catch (e) {
    console.warn('FCM init failed:', e.message);
    return false;
  }
}

/**
 * Send a chat message notification to the receiver's device.
 * @param {string} receiverFcmToken - FCM token of the receiver
 * @param {string} senderName - Display name of the sender
 * @param {string} messageText - Body text (e.g. message content or "[Image]")
 * @param {object} data - { matchId, senderId, senderName } (all strings for FCM data)
 */
async function sendChatNotification(receiverFcmToken, senderName, messageText, data) {
  if (!receiverFcmToken || !receiverFcmToken.trim()) return;
  if (!initialize()) return;
  const adm = getAdmin();
  const payload = {
    token: receiverFcmToken.trim(),
    notification: {
      title: senderName || 'New message',
      body: (messageText && String(messageText).trim()) ? String(messageText).substring(0, 200) : 'New message',
    },
    data: {
      type: 'chat',
      matchId: String(data.matchId || ''),
      senderId: String(data.senderId || ''),
      senderName: String(data.senderName || ''),
    },
    android: {
      priority: 'high',
      notification: { channelId: 'chat', priority: 'high' },
    },
  };
  try {
    await adm.messaging().send(payload);
  } catch (e) {
    const msg = (e.message || '').toLowerCase();
    const code = (e.code || '').toLowerCase();
    const invalidToken = msg.includes('not found') || msg.includes('unregistered') || msg.includes('invalid') || code.includes('not-found') || code.includes('invalid-argument');
    if (invalidToken) {
      console.warn('FCM send failed (invalid token):', e.message);
      return { sent: false, invalidToken: true };
    }
    console.warn('FCM send failed:', e.message);
    return { sent: false };
  }
}

/**
 * Send a "heart request received" notification to the receiver.
 * @param {string} receiverFcmToken - FCM token of the receiver (user who received the heart)
 * @param {string} senderName - Display name of the sender
 * @param {object} data - { matchId, senderId } (all strings for FCM data)
 */
async function sendHeartRequestNotification(receiverFcmToken, senderName, data) {
  if (!receiverFcmToken || !receiverFcmToken.trim()) return { sent: false };
  if (!initialize()) return { sent: false };
  const adm = getAdmin();
  const payload = {
    token: receiverFcmToken.trim(),
    notification: {
      title: 'New heart!',
      body: (senderName && String(senderName).trim()) ? `${senderName} sent you a heart!` : 'Someone sent you a heart!',
    },
    data: {
      type: 'heart_request',
      matchId: String(data.matchId || ''),
      senderId: String(data.senderId || ''),
      senderName: String(senderName || ''),
    },
    android: {
      priority: 'high',
      notification: { channelId: 'chat', priority: 'high' },
    },
  };
  try {
    await adm.messaging().send(payload);
    return { sent: true };
  } catch (e) {
    const msg = (e.message || '').toLowerCase();
    const code = (e.code || '').toLowerCase();
    const invalidToken = msg.includes('not found') || msg.includes('unregistered') || msg.includes('invalid') || code.includes('not-found') || code.includes('invalid-argument');
    if (invalidToken) {
      console.warn('FCM heart notification failed (invalid token):', e.message);
      return { sent: false, invalidToken: true };
    }
    console.warn('FCM heart notification failed:', e.message);
    return { sent: false };
  }
}

/**
 * Send a "heart request accepted" notification to the heart sender.
 * @param {string} senderFcmToken - FCM token of the heart sender (user who gets notified)
 * @param {string} accepterName - Display name of the user who accepted
 * @param {object} data - { matchId, accepterId } (all strings for FCM data)
 */
async function sendHeartAcceptedNotification(senderFcmToken, accepterName, data) {
  if (!senderFcmToken || !senderFcmToken.trim()) return { sent: false };
  if (!initialize()) return { sent: false };
  const adm = getAdmin();
  const payload = {
    token: senderFcmToken.trim(),
    notification: {
      title: 'Heart accepted!',
      body: (accepterName && String(accepterName).trim()) ? `${accepterName} accepted your heart!` : 'Someone accepted your heart!',
    },
    data: {
      type: 'heart_accepted',
      matchId: String(data.matchId || ''),
      accepterId: String(data.accepterId || ''),
      accepterName: String(accepterName || ''),
    },
    android: {
      priority: 'high',
      notification: { channelId: 'chat', priority: 'high' },
    },
  };
  try {
    await adm.messaging().send(payload);
    return { sent: true };
  } catch (e) {
    const msg = (e.message || '').toLowerCase();
    const code = (e.code || '').toLowerCase();
    const invalidToken = msg.includes('not found') || msg.includes('unregistered') || msg.includes('invalid') || code.includes('not-found') || code.includes('invalid-argument');
    if (invalidToken) {
      console.warn('FCM heart-accepted notification failed (invalid token):', e.message);
      return { sent: false, invalidToken: true };
    }
    console.warn('FCM heart-accepted notification failed:', e.message);
    return { sent: false };
  }
}

module.exports = { initialize, sendChatNotification, sendHeartRequestNotification, sendHeartAcceptedNotification };
