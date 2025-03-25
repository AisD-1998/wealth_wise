# Social Authentication Setup Guide for WealthWise

This guide explains how to properly configure Facebook and Google authentication for the WealthWise app.

## Google Sign-In Setup

1. **Create a Firebase Project** (if not already done)
   - Go to the [Firebase Console](https://console.firebase.google.com/)
   - Create a new project or use an existing one
   - Add your Android and iOS apps to the project

2. **Configure Google Sign-In in Firebase**
   - In Firebase Console, go to Authentication > Sign-in method
   - Enable Google as a sign-in provider
   - Save changes

3. **Configure Android**
   - Generate a SHA-1 fingerprint for your Android app:
     ```
     cd android
     ./gradlew signingReport
     ```
   - In Firebase Console, go to Project settings > Your apps > Add fingerprint
   - Add the SHA-1 fingerprint from the gradle output
   - Download the latest `google-services.json` file
   - Place it in the `android/app` directory

4. **Update Web Client ID**
   - In Firebase Console, go to Project settings > General
   - Copy the Web Client ID (Web API Key)
   - Edit `android/app/src/main/res/values/web_client_id.xml`
   - Replace `YOUR_WEB_CLIENT_ID` with the actual Web Client ID

## Facebook Sign-In Setup

1. **Create a Facebook Developer Account**
   - Go to [Facebook for Developers](https://developers.facebook.com/)
   - Create a new account if you don't have one

2. **Create a Facebook App**
   - Click on "My Apps" > "Create App"
   - Select "Consumer" as the app type
   - Fill in the app details and create it

3. **Configure Facebook Login**
   - In your Facebook App Dashboard, add "Facebook Login" product
   - Select Android platform
   - Enter your Android package name (e.g., `com.example.wealth_wise`)
   - Enter your app's class name: `com.facebook.FacebookActivity`
   - Generate a key hash and enter it
   - Save changes

4. **Get Facebook App ID and Client Token**
   - From your Facebook App Dashboard, note your App ID
   - Go to Settings > Advanced > Client Token to get your Client Token
   - Edit `android/app/src/main/res/values/strings.xml`
   - Replace the following placeholders:
     - `YOUR_FACEBOOK_APP_ID` with your actual Facebook App ID
     - `YOUR_FACEBOOK_CLIENT_TOKEN` with your actual Client Token
   - Also update `fb_login_protocol_scheme` to `fb` followed by your App ID (no spaces)

5. **Configure Firebase**
   - In Firebase Console, go to Authentication > Sign-in method
   - Enable Facebook as a sign-in provider
   - Enter your Facebook App ID and App Secret
   - Save changes

## Testing Your Social Sign-In

1. **Build and run your app in debug mode**
   ```
   flutter run
   ```

2. **Monitor logs**
   - Use the logger statements we've added to help diagnose any issues
   - Look for specific error messages that could indicate misconfiguration

3. **Common issues:**
   - SHA-1 fingerprint mismatch (Google)
   - Incorrect App ID or Client Token (Facebook)
   - Missing or incorrect configuration files
   - App not properly registered in Firebase

## Troubleshooting

If you encounter issues:

1. **Google Sign-In Error 10:**
   - This typically indicates an issue with your SHA-1 key in Firebase
   - Verify you've added the correct SHA-1 key for the build variant you're using (debug/release)
   - Make sure you've downloaded the latest `google-services.json` after adding the SHA-1 key

2. **Facebook MissingPluginException:**
   - Verify you've added all the required Facebook SDK configurations in your AndroidManifest.xml
   - Check that strings.xml has the correct App ID and Client Token
   - Ensure you've completed the Facebook Developer Console setup correctly

3. **General Issues:**
   - Clean and rebuild your project:
     ```
     flutter clean
     flutter pub get
     flutter run
     ```
   - Verify the latest plugin versions in pubspec.yaml
   - Check Android minSdkVersion (should be at least 21 for these plugins) 