# WealthWise - Financial Management App

A comprehensive Flutter application for personal finance management, including expense tracking, budget planning, and financial insights.

## Features

- **User Authentication**: Email/password, Google Sign-In, and Facebook Sign-In
- **Expense Tracking**: Record and categorize expenses
- **Budget Management**: Set and monitor budget goals
- **Financial Insights**: Visualize spending patterns
- **Savings Goals**: Track progress towards financial goals

## Setup Guide

### 1. Firebase Setup

#### Creating Firestore Indexes
The app requires the following Firestore indexes:

1. **For savingGoals Collection:**
Visit: https://console.firebase.google.com/v1/r/project/wealthwise-f96a5/firestore/indexes?create_composite=ClRwcm9qZWN0cy93ZWFsdGh3aXNlLWY5NmE1L2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbkdyb3Vwcy9zYXZpbmdHb2Fscy9pbmRleGVzL18QARoKCgZ1c2VySWQQARoPCgtjcmVhdGVkRGF0ZRACGgwKCF9fbmFtZV9fEAI

Fields to include:
- userId (Ascending)
- createdDate (Descending)
- __name__ (Descending)

2. **For transactions Collection:**
Visit: https://console.firebase.google.com/v1/r/project/wealthwise-f96a5/firestore/indexes?create_composite=ClVwcm9qZWN0cy93ZWFsdGh3aXNlLWY5NmE1L2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbkdyb3Vwcy90cmFuc2FjdGlvbnMvaW5kZXhlcy9fEAEaCgoGdXNlcklkEAEaCAoEZGF0ZRABGgwKCF9fbmFtZV9fEAE

Fields to include:
- userId (Ascending)
- date (Ascending)
- __name__ (Ascending)

### 2. Facebook Authentication Setup

1. Create a Facebook Developer account at [developers.facebook.com](https://developers.facebook.com/)
2. Create a new app (Consumer app type)
3. Add Facebook Login product to your app
4. Configure the Android platform:
   - Package Name: `com.example.wealth_wise` (or your actual package name)
   - Default Activity Class Name: `com.example.wealth_wise.MainActivity`
   - Generate Key Hashes using your SHA-1 fingerprint
5. Get your App ID and Client Token from the app dashboard
6. Update `android/app/src/main/res/values/strings.xml` with:
   ```xml
   <string name="facebook_app_id">YOUR_ACTUAL_FACEBOOK_APP_ID</string>
   <string name="fb_login_protocol_scheme">fbYOUR_ACTUAL_FACEBOOK_APP_ID</string>
   <string name="facebook_client_token">YOUR_ACTUAL_FACEBOOK_CLIENT_TOKEN</string>
   ```
7. Enable Facebook login in Firebase Authentication console and add your Facebook App ID and Secret

### 3. Troubleshooting

#### Common Issues:

1. **Overflow Errors**: 
   - We've fixed the RenderFlex overflow by wrapping content in SingleChildScrollView
   
2. **Asset Loading Issues**:
   - Make sure all required assets exist in the assets/images directory
   - The file `assets/images/card_pattern.png` is required
   
3. **Firebase Authentication**:
   - Ensure you have the google-services.json file in the android/app directory
   - Check that SHA-1 fingerprint is added to your Firebase project

4. **Back Button Issues**:
   - We've added `android:enableOnBackInvokedCallback="true"` to the AndroidManifest.xml

## Project Structure

```
lib/
├── main.dart                 # App entry point
├── models/                   # Data models
├── providers/                # State management
├── screens/                  # UI screens
│   ├── auth/                 # Authentication screens
│   ├── home/                 # Main app screens
│   └── ...
├── services/                 # Firebase and API services
├── utils/                    # Utility functions
└── widgets/                  # Reusable UI components
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Running the App

```
flutter clean
flutter pub get
flutter run
```
