const express = require('express');
const admin = require('firebase-admin');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(express.json());

// Initialize Firebase Admin SDK
// Service account key will be loaded from environment variable
const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT || '{}');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

console.log('🔥 Firebase Admin initialized!');

// Health check endpoint
app.get('/', (req, res) => {
  res.json({
    status: 'running',
    message: 'Push Notification Backend Active! 🔔',
    timestamp: new Date().toISOString(),
  });
});

// Listen to fcm_notifications collection and send push notifications
const startListener = () => {
  console.log('👂 Starting Firestore listener...');

  db.collection('fcm_notifications')
    .where('status', '==', 'pending')
    .onSnapshot(async (snapshot) => {
      console.log(`📬 Received ${snapshot.size} new notifications`);

      snapshot.docChanges().forEach(async (change) => {
        if (change.type === 'added') {
          const notification = change.doc.data();
          const docId = change.doc.id;

          console.log(`📤 Processing notification ${docId}`);

          try {
            // Send push notification
            await admin.messaging().send({
              notification: {
                title: notification.title,
                body: notification.body,
              },
              data: {
                type: notification.type || '',
                click_action: 'FLUTTER_NOTIFICATION_CLICK',
                ...(notification.senderId && {senderId: notification.senderId}),
                ...(notification.recipeTitle && {recipeTitle: notification.recipeTitle}),
              },
              token: notification.token,
              android: {
                priority: notification.priority === 'high' ? 'high' : 'normal',
                notification: {
                  sound: 'default',
                  clickAction: 'FLUTTER_NOTIFICATION_CLICK',
                },
              },
            });

            console.log(`✅ Push notification sent for ${docId}`);

            // Mark as sent
            await db.collection('fcm_notifications').doc(docId).update({
              status: 'sent',
              sentAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          } catch (error) {
            console.error(`❌ Error sending notification ${docId}:`, error);

            // Mark as failed
            await db.collection('fcm_notifications').doc(docId).update({
              status: 'failed',
              error: error.message,
              failedAt: admin.firestore.FieldValue.serverTimestamp(),
            });
          }
        }
      });
    }, (error) => {
      console.error('❌ Listener error:', error);
      // Restart listener after 5 seconds
      setTimeout(startListener, 5000);
    });
};

// Start the listener
startListener();

// Start server
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Server running on port ${PORT}`);
  console.log(`🔔 Push notification service active!`);
});

// Handle graceful shutdown
process.on('SIGTERM', () => {
  console.log('👋 SIGTERM received, shutting down gracefully...');
  process.exit(0);
});
