# WealthWise - Setup Instructions

## Firestore Indexes

The app requires certain Firestore indexes to function properly. You need to create the following composite indexes:

### 1. Saving Goals Index
There's an error related to the saving goals query. Create the index by visiting:
```
https://console.firebase.google.com/v1/r/project/wealthwise-f96a5/firestore/indexes?create_composite=ClRwcm9qZWN0cy93ZWFsdGh3aXNlLWY5NmE1L2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbkdyb3Vwcy9zYXZpbmdHb2Fscy9pbmRleGVzL18QARoKCgZ1c2VySWQQARoPCgtjcmVhdGVkRGF0ZRACGgwKCF9fbmFtZV9fEAI
```

This index is for:
- Collection: `savingGoals`
- Fields indexed:
  - `userId` (Ascending)
  - `createdDate` (Descending)
  - `__name__` (Descending)

### 2. Transactions Index
There's another error related to transactions queries. Create the index by visiting:
```
https://console.firebase.google.com/v1/r/project/wealthwise-f96a5/firestore/indexes?create_composite=ClVwcm9qZWN0cy93ZWFsdGh3aXNlLWY5NmE1L2RhdGFiYXNlcy8oZGVmYXVsdCkvY29sbGVjdGlvbkdyb3Vwcy90cmFuc2FjdGlvbnMvaW5kZXhlcy9fEAEaCgoGdXNlcklkEAEaCAoEZGF0ZRABGgwKCF9fbmFtZV9fEAE
```

This index is for:
- Collection: `transactions`
- Fields indexed:
  - `userId` (Ascending)
  - `date` (Ascending)
  - `__name__` (Ascending)

## Facebook Login Setup

If you want to use Facebook login, you need to:
1. Register an app at [Facebook Developers Console](https://developers.facebook.com)
2. Update the Facebook App ID and Client Token in `android/app/src/main/res/values/strings.xml`
3. Add the Facebook login product to your Facebook app
4. Add your SHA-1 fingerprint to the Facebook app's Android settings

## Google Sign-In Setup

For Google Sign-In to work properly:
1. Make sure you've added your app's SHA-1 fingerprint to the Firebase Console
2. Verify that the web client ID is correctly configured in the Google Sign-In setup

## Common Issues

If you're still having trouble with the app:

1. For Fluent UI localization errors:
   - The app should now include the necessary Fluent UI localization delegates

2. For layout overflow issues:
   - The app has been redesigned to avoid layout overflow problems

3. For Facebook login errors:
   - Make sure you've replaced the placeholder Facebook App ID in the strings.xml file
   - The error "Invalid application ID" means you need to register a real Facebook app 