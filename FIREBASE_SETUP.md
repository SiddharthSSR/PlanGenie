# Firebase Configuration Setup

This project uses Firebase for backend services. For security reasons, Firebase API keys and configuration are **not** committed to the repository.

## For New Developers

To set up Firebase in your local development environment:

### 1. Get Firebase Project Access

Contact the project maintainer to get access to the Firebase project: `plan-genie-hackathon`

### 2. Install Firebase CLI

```bash
npm install -g firebase-tools
firebase login
```

### 3. Set Up Flutter Firebase Configuration

Navigate to the Flutter app directory:

```bash
cd flutter-app
```

Install FlutterFire CLI if you haven't already:

```bash
dart pub global activate flutterfire_cli
```

Generate your Firebase configuration:

```bash
flutterfire configure --project=plan-genie-hackathon
```

This will:
- Create `lib/firebase_options.dart` with your API keys (overwriting the placeholder values committed to the repo)
- Set up platform-specific configuration files (if needed)

### 4. Alternative Manual Setup

If you can't run FlutterFire CLI, you can manually create the configuration:

1. Copy the template file:
   ```bash
   cp lib/firebase_options.dart.template lib/firebase_options.dart
   ```

2. Get your Firebase configuration from the Firebase Console:
   - Go to [Firebase Console](https://console.firebase.google.com/)
   - Select the `plan-genie-hackathon` project
   - Go to Project Settings > General
   - Scroll down to "Your apps" section
   - Copy the config values for each platform

3. Replace the placeholder values in `firebase_options.dart` (look for `REPLACE_WITH_*`).

## Security Notes

- **NEVER** commit `firebase_options.dart` to Git
- **NEVER** share API keys in chat, email, or documentation
- The `.gitignore` file is configured to prevent accidental commits
- If you accidentally commit sensitive data, immediately rotate your API keys in Firebase Console

## Files Excluded from Git

The following Firebase-related files are excluded from version control:

- `flutter-app/lib/firebase_options.dart` - Contains API keys
- `flutter-app/android/app/google-services.json` - Android config
- `flutter-app/ios/Runner/GoogleService-Info.plist` - iOS config
- Any `**/serviceAccountKey.json` or `**/firebase-adminsdk-*.json` files

## Testing Your Setup

After setting up Firebase, run the Flutter app to ensure everything works:

```bash
cd flutter-app
flutter pub get
flutter run
```

If you see Firebase-related errors, double-check your configuration files.

## Troubleshooting

### "Firebase project not found" error
- Ensure you have access to the `plan-genie-hackathon` project
- Check that your Firebase CLI is authenticated: `firebase projects:list`

### "Missing google-services.json" error (Android)
- Run `flutterfire configure` again
- Or manually download from Firebase Console > Project Settings > Your apps > Android app

### "Missing GoogleService-Info.plist" error (iOS)
- Run `flutterfire configure` again  
- Or manually download from Firebase Console > Project Settings > Your apps > iOS app
