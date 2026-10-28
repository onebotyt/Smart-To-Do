# SyncTask Pure — Deployment & Google Play Store Publishing Guide

This guide walks you step-by-step through setting up your **MongoDB Atlas** database, deploying your backend to **Render**, configuring **Google Authentication**, connecting **Multi-Service Ad Mediation (AdMob + Unity + AppLovin + House Sponsors)**, and publishing the app to the **Google Play Store** with the **₹10/month Ad-Free** subscription.

---

## 1. MongoDB Atlas Setup (Free M0 Cloud Database)

> **Note**: Your cluster `Cluster0` is already active and tested at `cluster0.kapk3ey.mongodb.net`.

1. Go to [MongoDB Atlas](https://www.mongodb.com/cloud/atlas) and sign in.
2. **Database Access (User)**:
   - Go to **Security > Database Access** in the left sidebar.
   - User `gdhami115_db_user` is active with role `atlasAdmin@admin`.
3. **Network Access (IP Whitelist)**:
   - Go to **Security > Network Access** in the left sidebar.
   - Ensure `0.0.0.0/0` ("Allow Access from Anywhere") is Active so Render's cloud servers can connect.
4. **Connection String**:
   ```text
   mongodb+srv://gdhami115_db_user:SyncTask2026Pass@cluster0.kapk3ey.mongodb.net/synctask_pure?retryWrites=true&w=majority
   ```

---

## 2. Deploying Backend to Render.com

> **Note**: Your backend is live and operational at: `https://to-do-backend-zndz.onrender.com`.

Repository: [onebotyt/to-do-backend](https://github.com/onebotyt/to-do-backend.git).

### Environment Variables on Render
| Key | Value | Description |
| :--- | :--- | :--- |
| `PORT` | `10000` | Port Render binds to |
| `NODE_ENV` | `production` | Production mode |
| `MONGODB_URI` | `mongodb+srv://gdhami115_db_user:...@cluster0...` | MongoDB Atlas URI |
| `JWT_SECRET` | `synctask_jwt_secret_token_998877_secure_prod` | Secret for signing auth tokens |
| `GOOGLE_CLIENT_ID` | `placeholder_google_oauth_client_id.apps.googleusercontent.com` | Google OAuth Client ID |
| `CORS_ORIGIN` | `*` | Allowed origins |

---

## 3. Google OAuth 2.0 Setup

1. Go to [Google Cloud Console](https://console.cloud.google.com/).
2. Create a new project named `SyncTask Pure`.
3. Go to **APIs & Services > OAuth consent screen**:
   - User Type: **External**.
   - App Name: `SyncTask`.
   - Scopes: `email`, `profile`, `openid`.
4. Go to **APIs & Services > Credentials**:
   - Click **Create Credentials** > **OAuth Client ID**.
   - Application type: **Web Application**.
   - Copy the generated **Client ID** and update `GOOGLE_CLIENT_ID` in Render's Environment tab.

---

## 4. Multi-Service Ad Mediation (`AdMediationController`)

The app does **not** depend on a single ad provider. If Google AdMob has No-Fill, is blocked by DNS/ad blockers, or is temporarily unavailable, the mediation engine automatically waterfalls to secondary networks and failsafe house sponsors.

```
┌─────────────────────────────────────────────────────────────┐
│                    AdMediationController                    │
│                                                             │
│  [1. Google AdMob] ──► Fails / No-Fill                      │
│         │                                                   │
│         ▼                                                   │
│  [2. Unity Ads / AppLovin MAX] ──► Fails / Offline          │
│         │                                                   │
│         ▼                                                   │
│  [3. House Sponsor Network] ──► Guaranteed 100% Fill        │
└─────────────────────────────────────────────────────────────┘
```

### Safety & UX Constraints
1. **Silent & Non-Intrusive**: Never plays uninvited audio; never freezes the UI.
2. **Containerized**: Strictly bounded inside a 64dp bottom container frame.
3. **Emergency Dismissal `[✕]`**: User can tap the top-right close icon on the container to close it immediately.
4. **₹10/mo Ad-Free Awareness**: When the user subscribes, all ad networks are unmounted instantly.

---

### How to Connect Each Ad Service

#### A. Google AdMob (Primary Network)
1. Go to [Google AdMob](https://admob.google.com/) and register your account.
2. Click **Apps > Add App**:
   - Platform: **Android**.
   - Store: Select **No** (until published).
   - App Name: `SyncTask Pure`.
3. Click **Add Ad Unit > Banner**:
   - Name: `Tasks_Bottom_Container`.
   - Copy your **AdMob App ID** (`ca-app-pub-xxxxxxxx~yyyyyyyy`) and **Ad Unit ID** (`ca-app-pub-xxxxxxxx/zzzzzzzz`).
4. In `android/app/src/main/AndroidManifest.xml`, ensure your App ID is set inside `<application>`:
   ```xml
   <meta-data
       android:name="com.google.android.gms.ads.APPLICATION_ID"
       android:value="ca-app-pub-xxxxxxxx~yyyyyyyy"/>
   ```
5. In `lib/features/monetization/ad_mediation_controller.dart`:
   ```dart
   GoogleAdMobProvider(
     appId: 'ca-app-pub-xxxxxxxx~yyyyyyyy',
     bannerUnitId: 'ca-app-pub-xxxxxxxx/zzzzzzzz',
   )
   ```

#### B. Unity Ads (Secondary Network)
1. Go to [Unity Cloud Monetization](https://cloud.unity.com/).
2. Create a project named `SyncTask Pure` and enable **Monetization**.
3. Under **Ad Units**, create a **Banner** ad unit and copy the **Placement ID** (e.g., `Banner_Android`) and **Game ID**.
4. In `lib/features/monetization/ad_mediation_controller.dart`:
   ```dart
   SecondaryAdNetworkProvider(
     providerType: AdProviderType.unityAds,
     placementId: 'Banner_Android',
   )
   ```

#### C. AppLovin MAX (Alternative Network)
1. Go to [AppLovin MAX Dashboard](https://dash.applovin.com/).
2. Navigate to **MAX > Ad Units > Create Ad Unit**:
   - Platform: **Android**.
   - Format: **Banner**.
3. Copy the **Ad Unit ID**.
4. In `lib/features/monetization/ad_mediation_controller.dart`:
   ```dart
   SecondaryAdNetworkProvider(
     providerType: AdProviderType.appLovin,
     placementId: 'your_applovin_banner_ad_unit_id',
   )
   ```

#### D. House Sponsor / Direct Promotions (Failsafe Network)
- **Zero setup required.**
- Directly managed in `HouseSponsorProvider` in `lib/features/monetization/ad_mediation_controller.dart`.
- Rotates direct offers:
  1. *SyncTask Pro Ad-Free (₹10/mo)*
  2. *SyncTask Direct P2P Media Quick Share*

---

## 5. Google Play In-App Subscription (₹10 / Month)

1. Go to [Google Play Console](https://play.google.com/console).
2. Create your developer account ($25 one-time registration fee).
3. Create App:
   - App name: **SyncTask: Fast To-Do & Tasks**
   - Default language: English (India / US)
   - App or game: App
   - Free or paid: Free
4. Under **Monetize with Play > Subscriptions**:
   - Click **Create subscription**.
   - Product ID: `ad_free_monthly_inr10`
   - Name: `Ad-Free Monthly`
   - Add Base Plan:
     - Billing period: **Monthly** (1 month auto-renewing).
     - Price: **₹10 INR** (Google automatically converts equivalent prices for other countries).
5. When a user clicks **Remove Ads ₹10/mo** in the app:
   - Google Play processes the ₹10 payment.
   - The app unlocks ad-free mode, and your backend records `isPremium: true`.

---

## 6. Building the Android App Bundle (`.aab`) for Play Store

1. **Generate Keystore**:
   ```bash
   keytool -genkey -v -keystore C:\Users\GD\upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
   ```
2. **Configure `android/key.properties`**:
   ```properties
   storePassword=<your-password>
   keyPassword=<your-password>
   keyAlias=upload
   storeFile=C:\\Users\\GD\\upload-keystore.jks
   ```
3. **Build Production App Bundle (Pure Flavor)**:
   ```bash
   flutter build appbundle --release --dart-define=APP_EDITION=pure
   ```
   The output bundle will be at:
   `build/app/outputs/bundle/release/app-release.aab`
4. Upload `app-release.aab` to Google Play Console under **Testing > Internal testing** or **Production**.
