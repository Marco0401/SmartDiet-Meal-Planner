# 🔔 SmartDiet Push Notification Backend

Free backend service for sending push notifications via Firebase Cloud Messaging (FCM).

## 🚀 Deploy to Render.com (FREE)

### Step 1: Get Firebase Service Account Key

1. Go to Firebase Console: https://console.firebase.google.com/project/smartdiet-3fc8b/settings/serviceaccounts/adminsdk
2. Click **"Generate New Private Key"**
3. Download the JSON file
4. Open it in notepad, you'll need this for Render

### Step 2: Create Render Account

1. Go to: https://render.com
2. Sign up with GitHub or Email (FREE, no card needed)
3. Verify your email

### Step 3: Deploy to Render

1. Click **"New +"** → **"Web Service"**
2. Connect your GitHub repo OR use "Deploy from a Git URL"
3. If using Git URL, enter: (you'll need to push this to GitHub first)
4. OR manually upload this folder

**Settings:**
- **Name:** `smartdiet-push-notifications`
- **Environment:** `Node`
- **Build Command:** `npm install`
- **Start Command:** `npm start`
- **Plan:** `Free`

### Step 4: Add Environment Variable

In Render dashboard:
1. Go to **"Environment"** tab
2. Add new environment variable:
   - **Key:** `FIREBASE_SERVICE_ACCOUNT`
   - **Value:** (paste entire contents of your service account JSON file)
3. Click **"Save Changes"**

### Step 5: Deploy!

1. Click **"Manual Deploy"** → **"Deploy latest commit"**
2. Wait 2-3 minutes for deployment
3. Check logs - should see "🚀 Server running"
4. Visit your service URL - should see: `{"status":"running"}`

## ✅ Testing

Once deployed, send a test message in your app:
- Backend automatically picks up pending notifications
- Sends push notification via FCM
- Updates status to "sent"

## 📊 Monitoring

Check Render logs to see:
- ✅ Push notifications sent
- ❌ Any errors
- 📬 Number of notifications processed

## 🔧 Local Testing (Optional)

```bash
cd backend
npm install

# Create .env file with:
# FIREBASE_SERVICE_ACCOUNT={"type":"service_account",...}

npm start
```

## 💰 Cost

**100% FREE on Render.com:**
- 750 hours/month free (enough for 24/7)
- Sleeps after 15min inactivity (wakes up automatically)
- Perfect for push notifications!

## 🛠️ Troubleshooting

**Service sleeping?**
- Render free tier sleeps after 15min inactivity
- First notification after sleep takes ~30 seconds
- Consider: ping service every 14 min to keep awake (optional)

**Not receiving notifications?**
- Check Render logs for errors
- Verify FIREBASE_SERVICE_ACCOUNT is correct
- Check FCM tokens in Firestore are valid

## 📝 Notes

- Service runs 24/7 automatically
- Auto-restarts if crashes
- Listens to Firestore in real-time
- Sends push notifications instantly
