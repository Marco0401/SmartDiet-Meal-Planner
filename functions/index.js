const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

exports.sendPushNotification = functions.firestore
    .document("fcm_notifications/{notificationId}")
    .onCreate(async (snapshot, context) => {
      const notification = snapshot.data();

      // Only process pending notifications
      if (notification.status !== "pending") {
        console.log("Skipping non-pending notification");
        return null;
      }

      try {
        // Send push notification via FCM
        await admin.messaging().send({
          notification: {
            title: notification.title,
            body: notification.body,
          },
          data: {
            type: notification.type || "",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          token: notification.token,
          android: {
            priority:
              notification.priority === "high" ? "high" : "normal",
          },
        });

        console.log("✅ Push notification sent successfully!");

        // Mark as sent
        await snapshot.ref.update({
          status: "sent",
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      } catch (error) {
        console.error("❌ Error sending notification:", error);

        // Mark as failed
        await snapshot.ref.update({
          status: "failed",
          error: error.message,
        });
      }

      return null;
    });
