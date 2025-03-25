# Social Authentication Setup for WealthWise

This guide will help you set up Firebase and social authentication (Google and Facebook) for the WealthWise application.

## Prerequisites

- A Firebase project created in the [Firebase Console](https://console.firebase.google.com/)
- Facebook Developer account (for Facebook login)
- Google account (for Google login)

## Firebase Configuration

1. Go to the [Firebase Console](https://console.firebase.google.com/) and create a new project or select an existing one.
2. Add an Android app to your Firebase project:
   - Package name: `com.example.wealth_wise` (or your actual package name)
   - App nickname: "WealthWise"
   - Debug signing certificate SHA-1: Optional for development but required for Google Sign-In

3. Download the `google-services.json` file and place it in the `android/app` directory of your project.

4. Update the `firebase_options.dart` file with your Firebase configuration.

## Google Sign-In Setup

1. In the Firebase Console, go to Authentication → Sign-in method.
2. Enable Google as a sign-in provider.
3. In the Google Cloud Console project linked to your Firebase project:
   - Go to APIs & Services → OAuth consent screen
   - Configure the consent screen (External or Internal)
   - Add necessary scopes (email, profile)
   - Add test users if using External user type
   
4. Go to APIs & Services → Credentials
   - Create an OAuth 2.0 Client ID (Web application)
   - Add authorized redirect URIs
   - Copy the Client ID

5. Update the `android/app/src/main/res/values/web_client_id.xml` file with the Web Client ID:
```xml
<resources>
    <string name="default_web_client_id">YOUR_WEB_CLIENT_ID</string>
</resources>
```

## Facebook Sign-In Setup

1. Go to [Facebook Developers](https://developers.facebook.com/) and create a new app.
   - Choose "Consumer" or "Business" as the app type
   - Enter app details

2. In your Facebook app dashboard:
   - Add the Facebook Login product
   - Go to Settings → Basic
   - Note your App ID and App Secret

3. Configure Android platform:
   - Package Name: Same as your Android app package name
   - Class Name: `com.facebook.FacebookActivity`
   - Key Hashes: Generate a development key hash using:
     ```
     keytool -exportcert -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android | openssl sha1 -binary | openssl base64
     ```

4. Update the `android/app/src/main/res/values/strings.xml` file:
```xml
<resources>
    <string name="app_name">WealthWise</string>
    <string name="facebook_app_id">YOUR_FACEBOOK_APP_ID</string>
    <string name="fb_login_protocol_scheme">fbYOUR_FACEBOOK_APP_ID</string>
    <string name="facebook_client_token">YOUR_FACEBOOK_CLIENT_TOKEN</string>
</resources>
```

5. In the Firebase Console, go to Authentication → Sign-in method:
   - Enable Facebook as a sign-in provider
   - Enter your Facebook App ID and App Secret

## Android Manifest Configuration

Make sure your `AndroidManifest.xml` has the required configurations:

```xml
<manifest ...>
  <application ...>
    <!-- Facebook configurations -->
    <meta-data 
        android:name="com.facebook.sdk.ApplicationId" 
        android:value="@string/facebook_app_id"/>
    <meta-data 
        android:name="com.facebook.sdk.ClientToken" 
        android:value="@string/facebook_client_token"/>
        
    <activity 
        android:name="com.facebook.FacebookActivity"
        android:configChanges="keyboard|keyboardHidden|screenLayout|screenSize|orientation"
        android:label="@string/app_name" />
        
    <activity
        android:name="com.facebook.CustomTabActivity"
        android:exported="true">
        <intent-filter>
            <action android:name="android.intent.action.VIEW" />
            <category android:name="android.intent.category.DEFAULT" />
            <category android:name="android.intent.category.BROWSABLE" />
            <data android:scheme="@string/fb_login_protocol_scheme" />
        </intent-filter>
    </activity>
    
    <!-- Google Sign-in configuration -->
    <meta-data
        android:name="com.google.android.gms.version"
        android:value="@integer/google_play_services_version" />
  </application>
</manifest>
```

## Troubleshooting

### Common Issues with Google Sign-In:

1. **API Exception Error Code 10**: Usually indicates missing or incorrect Web Client ID configuration. Make sure you've:
   - Updated `web_client_id.xml` with the correct Web Client ID
   - Enabled Google Sign-In in Firebase Authentication
   - Configured OAuth consent screen correctly

2. **SHA-1 Certificate Issues**: Make sure the SHA-1 fingerprint of your debug key is added to your Firebase project.

### Common Issues with Facebook Sign-In:

1. **MissingPluginException**: Indicates the Facebook plugin is not properly integrated. Make sure:
   - All necessary string resources are correctly defined
   - AndroidManifest.xml is properly configured
   - The package has been added to pubspec.yaml and packages have been retrieved (flutter pub get)

2. **Invalid KeyHash**: Ensure you've added the correct key hash to your Facebook app configuration. 