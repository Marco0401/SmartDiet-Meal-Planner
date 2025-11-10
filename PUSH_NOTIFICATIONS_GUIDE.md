# 🔔 Push Notifications Implementation Guide

## ✅ What's Been Implemented

### 1. **FCM Service** (`lib/services/fcm_service.dart`)
Complete Firebase Cloud Messaging service with:
- ✅ FCM initialization and permission requests
- ✅ Token management (save/update/clear)
- ✅ User preference checks before sending
- ✅ Push notification methods for all events

### 2. **Integrated Push Notifications**

| Event | Trigger | Preference Category | Status |
|-------|---------|-------------------|--------|
| **New Message** | When someone sends you a message | Messages | ✅ Integrated |
| **Recipe Like** | When someone likes your recipe | Updates | ✅ Integrated |
| **New Follower** | When someone follows you | Updates | ✅ Integrated |
| **Recipe Comment** | When someone comments on your recipe | Updates | ✅ Integrated |
| **Allergen Warning** | When allergen detected in recipe | Always Sent | Ready |
| **Meal Reminder** | 15 min before scheduled meal | Meal reminders | Ready |
| **Nutrition Tip** | Daily nutrition tips | Tips | Ready |
| **Nutrition Progress** | Weekly progress updates | Tips | Ready |

### 3. **Notification Preferences** (Account Settings)
Users can now control which push notifications they receive:
- **None** - No push notifications (in-app only)
- **Messages** - New chat messages
- **Meal reminders** - Upcoming meal alerts
- **Tips** - Nutrition tips and progress
- **Updates** - Likes, follows, comments
- **News** - General app news

---

## 🔧 How It Works Now

### **Current Implementation (Client-Side)**

```
User Action → FCM Notification Queued → Stored in Firestore → Needs Backend to Send
```

**Example Flow:**
1. Marco sends message to User B
2. App checks User B's notification preferences
3. If "Messages" enabled → Creates notification document in Firestore
4. **Backend** (needs implementation) picks up the document and sends via FCM
5. User B receives push notification

---

## 📱 What Users See

### **In-App Notifications** (Always Created)
- ✅ Stored in Firestore under `users/{uid}/notifications`
- ✅ Visible in Notifications page
- ✅ NOT affected by notification preferences
- ✅ Always created for all events

### **Push Notifications** (Respects Preferences)
- ✅ Only sent if user enabled that category
- ✅ Requires backend implementation
- ✅ Shows on phone even when app closed
- ❌ Not fully functional yet (needs backend)

---

## 🚀 To Complete Push Notifications

### **Option 1: Cloud Functions (Recommended)**

Create Firebase Cloud Functions to send notifications:

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// Listen for new FCM notification documents
exports.sendPushNotification = functions.firestore
  .document('fcm_notifications/{notificationId}')
  .onCreate(async (snapshot, context) => {
    const notification = snapshot.data();
    
    if (notification.status !== 'pending') return;
    
    const message = {
      notification: {
        title: notification.title,
        body: notification.body,
      },
      data: {
        type: notification.type,
        ...notification,
      },
      token: notification.token,
    };
    
    try {
      await admin.messaging().send(message);
      
      // Mark as sent
      await snapshot.ref.update({ status: 'sent' });
      
      console.log('Notification sent successfully');
    } catch (error) {
      console.error('Error sending notification:', error);
      await snapshot.ref.update({ 
        status: 'failed',
        error: error.message 
      });
    }
  });
```

**Deploy:**
```bash
cd functions
npm install firebase-functions firebase-admin
firebase deploy --only functions
```

### **Option 2: Backend Server**

Create a backend service that:
1. Listens to `fcm_notifications` collection
2. Sends notifications via FCM Admin SDK
3. Updates notification status

---

## 📋 Android Configuration Required

### **1. Update `android/app/src/main/AndroidManifest.xml`:**

```xml
<manifest>
  <application>
    <!-- Add inside <application> tag -->
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_channel_id"
        android:value="high_importance_channel" />
  </application>
</manifest>
```

### **2. Download `google-services.json`:**

1. Go to Firebase Console → Project Settings
2. Download `google-services.json`
3. Place in `android/app/` directory

---

## 🧪 Testing Push Notifications

### **Test with Firebase Console:**

1. **Firebase Console** → Cloud Messaging → Send test message
2. Get FCM token from Firestore: `users/{uid}/fcmToken`
3. Send notification to that token
4. Check if notification appears on device

### **Test Locally:**

```dart
// In any page, add a test button:
ElevatedButton(
  onPressed: () async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FCMService.sendNewMessageNotification(
        recipientUserId: user.uid,
        senderName: 'Test User',
        messagePreview: 'This is a test notification!',
      );
    }
  },
  child: Text('Test Push Notification'),
)
```

---

## 📊 Notification Preference Logic

### **How Preferences Work:**

```dart
// User has ["Messages", "Tips"] selected

// This WILL send push notification:
FCMService.sendNewMessageNotification(...) // ✅ "Messages" enabled

// This WILL send push notification:
FCMService.sendNutritionTipNotification(...) // ✅ "Tips" enabled

// This WON'T send push notification:
FCMService.sendNewLikeNotification(...) // ❌ "Updates" not selected

// This WILL ALWAYS send (safety):
FCMService.sendAllergenWarningNotification(...) // ✅ Always sent
```

### **Preference Categories:**

| Preference | Covers |
|-----------|--------|
| **Messages** | Chat messages |
| **Meal reminders** | Upcoming meal alerts |
| **Tips** | Nutrition tips + Progress updates |
| **Updates** | Likes + Follows + Comments |
| **News** | App announcements (not implemented yet) |
| **None** | Disables all push notifications |

---

## 🔒 Important Notes

### **Security:**
- FCM tokens are stored securely in Firestore
- Tokens are user-specific and auto-refresh
- Cleared on logout

### **Privacy:**
- In-app notifications are ALWAYS created (for app UI)
- Push notifications respect user preferences
- Allergen warnings ALWAYS sent (user safety)

### **Performance:**
- FCM notifications are queued in Firestore
- Backend processes them asynchronously
- No impact on app performance

---

## 📝 Summary

### **What Works Now:**
✅ FCM initialization and token management  
✅ User preference settings in Account Settings  
✅ Notification queueing for all events  
✅ In-app notifications (Notifications page)  

### **What Needs Backend:**
❌ Actually sending push notifications via FCM  
❌ Processing queued notifications  
❌ Updating notification status  

### **Recommendation:**
**Use Firebase Cloud Functions** - It's free, serverless, and integrates perfectly with Firestore!

---

## 🎯 Next Steps

1. ✅ **Code is ready** - All client-side work complete
2. ⚙️ **Setup Cloud Functions** - Deploy notification sender
3. 📱 **Configure Android** - Add FCM metadata
4. 🧪 **Test** - Send test notifications
5. 🚀 **Launch** - Users get real-time push notifications!

---

**Free FCM Quota:** Unlimited messages! 🎉
