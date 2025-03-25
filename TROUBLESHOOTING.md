# WealthWise App Troubleshooting Guide

## Common Issues and Solutions

### 1. FluentUI Localization Issues
If you see "No FluentLocalizations found" errors in the logs:
- Ensure you have the proper localization delegates in your MaterialApp
- Make sure flutter_localizations package is added to your pubspec.yaml

### 2. RenderFlex Overflow Issues
If you see "A RenderFlex overflowed by X pixels" errors:
- Wrap content in SingleChildScrollView where appropriate
- Use Expanded widgets within Row/Column to prevent overflow
- Set shrinkWrap: true and physics: ClampingScrollPhysics() on nested ListViews
- For the current overflow of 99437 pixels, check the ExpensesScreen implementation

### 3. Firestore Index Errors
The queries require composite indexes to be created in Firebase:

#### For savingGoals Collection:
Visit: https://console.firebase.google.com/v1/r/project/wealthwise-f96a5/firestore/indexes?create_composite=ClRwcm9qZWN0cy93ZWFsdGh3aXNlLWY5NmE1L2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbkdyb3Vwcy9zYXZpbmdHb2Fscy9pbmRleGVzL18QARoKCgZ1c2VySWQQARoPCgtjcmVhdGVkRGF0ZRACGgwKCF9fbmFtZV9fEAI

This creates an index on:
- Collection: savingGoals
- Fields: userId (Ascending), createdDate (Descending), __name__ (Descending)

#### For transactions Collection:
Visit: https://console.firebase.google.com/v1/r/project/wealthwise-f96a5/firestore/indexes?create_composite=ClVwcm9qZWN0cy93ZWFsdGh3aXNlLWY5NmE1L2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbkdyb3Vwcy90cmFuc2FjdGlvbnMvaW5kZXhlcy9fEAEaCgoGdXNlcklkEAEaCAoEZGF0ZRABGgwKCF9fbmFtZV9fEAE

This creates an index on:
- Collection: transactions
- Fields: userId (Ascending), date (Ascending), __name__ (Ascending)

### 4. Facebook Authentication Errors
If you see "Error validating application. Invalid application ID" in the logs:
- You need to create a real Facebook app in the Facebook Developer Console
- Update the following values in `android/app/src/main/res/values/strings.xml`:
  - `facebook_app_id`: Your actual Facebook App ID
  - `fb_login_protocol_scheme`: "fb" followed by your App ID
  - `facebook_client_token`: Your actual client token

### 5. OnBackInvokedCallback Warning
If you see "OnBackInvokedCallback is not enabled for the application" warning:
- Make sure you have `android:enableOnBackInvokedCallback="true"` in the `<application>` tag of your `AndroidManifest.xml` file

### 6. Missing Asset Files
If you see errors about missing assets:
- Ensure you have all required assets in the `assets` directory
- Check that the assets are correctly declared in `pubspec.yaml`
- For the specific "card_pattern.png" error, make sure this file is in the "assets/images/" directory

## Performance Optimization
- For long lists, consider using ListView.builder instead of Column with many children
- Use lazy loading for images and data
- Consider pagination for large data sets

## Debugging Tips
- Check the Flutter Dev Tools for widget layout issues
- Use "flutter clean" followed by "flutter pub get" to resolve dependency issues
- For Firestore queries, always create the required indexes before querying 