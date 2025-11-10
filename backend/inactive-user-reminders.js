const admin = require('firebase-admin');

/**
 * Send reminders to inactive users
 * Run this as a cron job (e.g., daily at 10 AM)
 */
async function sendInactiveUserReminders() {
  try {
    const db = admin.firestore();
    const now = new Date();
    const threeDaysAgo = new Date(now.getTime() - (3 * 24 * 60 * 60 * 1000));

    console.log('🔍 Checking for inactive users...');

    // Get all users
    const usersSnapshot = await db.collection('users').get();
    let remindersSent = 0;

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data();
      
      // Skip if user doesn't have FCM token
      if (!userData.fcmToken) {
        continue;
      }

      // Check if user has disabled tips (reminders use Tips category)
      const preferences = userData.notificationPreferences || userData.notifications || [];
      if (preferences.includes('None') || !preferences.includes('Tips')) {
        continue; // User disabled reminders
      }

      // Check last activity
      const lastActive = userData.lastActive?.toDate() || userData.createdAt?.toDate();
      
      if (!lastActive || lastActive < threeDaysAgo) {
        // User is inactive for 3+ days, send reminder
        const reminderTypes = ['hydration', 'healthy_eating', 'meal_tracking', 'exercise'];
        const randomType = reminderTypes[Math.floor(Math.random() * reminderTypes.length)];
        
        // Get reminder message
        const reminder = getReminderMessage(randomType);
        
        // Create notification document
        await db.collection('fcm_notifications').add({
          token: userData.fcmToken,
          title: reminder.title,
          body: reminder.body,
          type: 'inactive_reminder',
          reminderType: randomType,
          recipientId: userId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          status: 'pending',
        });

        remindersSent++;
        console.log(`✅ Reminder sent to user ${userId} (${randomType})`);
      }
    }

    console.log(`📊 Total reminders sent: ${remindersSent}`);
    return { success: true, remindersSent };
  } catch (error) {
    console.error('❌ Error sending inactive user reminders:', error);
    return { success: false, error: error.message };
  }
}

/**
 * Get reminder message based on type
 */
function getReminderMessage(type) {
  const messages = {
    hydration: {
      title: '💧 Stay Hydrated!',
      body: "Don't forget to drink water! Your body needs hydration.",
    },
    healthy_eating: {
      title: '🥗 Eat Healthy Today!',
      body: 'Remember to make healthy food choices. Your body will thank you!',
    },
    meal_tracking: {
      title: '📝 Track Your Meals',
      body: 'Keep track of your meals to reach your health goals!',
    },
    exercise: {
      title: '💪 Stay Active!',
      body: 'A little movement goes a long way. Try to stay active today!',
    },
  };

  return messages[type] || {
    title: '🌟 SmartDiet Reminder',
    body: 'We miss you! Come back and continue your healthy journey.',
  };
}

/**
 * Send daily hydration reminders to all active users
 * Run at specific times (e.g., 8 AM, 12 PM, 4 PM, 8 PM)
 */
async function sendDailyHydrationReminders() {
  try {
    const db = admin.firestore();
    console.log('💧 Sending daily hydration reminders...');

    const usersSnapshot = await db.collection('users').get();
    let remindersSent = 0;

    for (const userDoc of usersSnapshot.docs) {
      const userId = userDoc.id;
      const userData = userDoc.data();
      
      // Skip if no FCM token
      if (!userData.fcmToken) continue;

      // Check preferences
      const preferences = userData.notificationPreferences || userData.notifications || [];
      if (preferences.includes('None') || !preferences.includes('Tips')) {
        continue;
      }

      // Send hydration reminder
      await db.collection('fcm_notifications').add({
        token: userData.fcmToken,
        title: '💧 Hydration Reminder',
        body: 'Time to drink some water! Stay hydrated! 💦',
        type: 'hydration_reminder',
        recipientId: userId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'pending',
      });

      remindersSent++;
    }

    console.log(`✅ Hydration reminders sent: ${remindersSent}`);
    return { success: true, remindersSent };
  } catch (error) {
    console.error('❌ Error sending hydration reminders:', error);
    return { success: false, error: error.message };
  }
}

module.exports = {
  sendInactiveUserReminders,
  sendDailyHydrationReminders,
};
