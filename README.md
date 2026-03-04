# Instagram Clone

A completely Responsive Instagram App- Works on Android, iOS & Web! 

## Features
- Responsive Instagram UI
- Email & Password Authentication
- Share Posts with Caption
- Display Posts with Caption
- Like & Comment on Posts
- Search Users
- Follow Users
- Display User Posts, Followers & Following
- EVERYTHING REAL TIME
- Sign Out


## Installation
After cloning this repository, migrate to ```instagram-flutter-clone``` folder. Then, follow the following steps:
- Create Firebase Project
- Enable Authentication
- Make Firestore Rules
- Create Android, iOS & Web Apps
- Take Web FirebaseOptions and put it in main function in main.dart file replacing my keys (My keys wont work as I deleted my project)
Then run the following commands to run your app:
```bash
  flutter pub get
  open -a simulator (to get iOS Simulator)
  flutter run
  flutter run -d chrome --web-renderer html (to see the best output)
```

## Tech Used
**Server**: Firebase Auth, Firebase Storage, Firebase Firestore

**Client**: Flutter, Provider
    
## Feedback

If you have any feedback, please reach out to me at namanrivaan@gmail.com

## Supabase Migration

This branch replaces Firebase with Supabase for auth, database, and storage.

### Feature Mapping
- Auth: Firebase Auth → Supabase Auth (`email/password`)
- Database: Firestore collections → Postgres tables (`users`, `posts`, `comments`)
- Storage: Firebase Storage buckets → Supabase Storage buckets (`profilePics`, `posts`)
- Streams: Firestore `snapshots()` → Realtime via `client.from(...).stream()`

### Code Changes Summary
- Initialize Supabase with `flutter_dotenv` in `lib/main.dart` and replace Firebase auth stream with `Supabase.instance.client.auth.onAuthStateChange`.
- Replace Firestore reads/writes with Supabase queries in:
  - `lib/resources/auth_methods.dart` (signup, login, signout, get user)
  - `lib/resources/firestore_methods.dart` (upload post, like/unlike, comment, delete, follow)
  - `lib/resources/storage_methods.dart` (upload to Supabase Storage)
  - UI screens: `feed_screen.dart`, `comments_screen.dart`, `search_screen.dart`, `profile_screen.dart`, `post_card.dart`
- Remove Firebase packages and platform configs; add `supabase_flutter` and `flutter_dotenv` in `pubspec.yaml`.
- Add `.env` support and template: `.env.example`.
- Add SQL migrations and policies under `supabase/migrations/0001_init.sql`.

### Environment Variables
Create `.env` from the template and set keys:

```
cp .env.example .env
```

Fill in:

```
SUPABASE_URL_DEV=https://YOUR-PROJECT-REF.supabase.co
SUPABASE_ANON_KEY_DEV=YOUR-ANON-PUBLISHABLE-KEY
SUPABASE_URL_PROD=https://YOUR-PROJECT-REF.supabase.co
SUPABASE_ANON_KEY_PROD=YOUR-PROD-ANON-KEY
ENV=dev
```

Keys are obtained from Dashboard → Settings → API (`Project URL`, `anon` public key). Keep the `service_role` key only for server environments; do not put it in the app.

### Supabase Project Setup (Dashboard)
1. Create project: https://database.new
2. Get URL and anon key: Settings → API.
3. Storage buckets: go to Storage → Create `posts` and `profilePics` buckets (Public: On).
4. Database schema and policies: open SQL Editor and paste the contents of `supabase/migrations/0001_init.sql`; click Run.
5. Authentication: Settings → Auth → turn on Email/Password. Optionally enable OAuth providers and add redirect URLs later.

### Local Run
```
flutter pub get
flutter run
```

If building Android, ensure `android/app/src/main/AndroidManifest.xml` includes:
```
<uses-permission android:name="android.permission.INTERNET" />
```

### Testing Plan
- Manual:
  - Sign up, sign in, sign out
  - Create post with image, verify appears in feed and profile grid
  - Like/unlike a post (double-tap and heart button)
  - Add comments and verify they stream live
  - Follow/unfollow users and verify counters update
  - Search users by prefix
  - Profile photo upload on sign up
- Automated (suggested):
  - Unit test `AuthMethods.signUpUser` and `loginUser` with a Supabase test project
  - Integration test for `FireStoreMethods.uploadPost` mocking storage
  - Widget tests for `PostCard` interactions using a fake Supabase client

### Deployment
- Web: set `ENV=prod` in `.env` and ensure `.env` is bundled (already listed in `pubspec.yaml` assets).
- Mobile: set `ENV=prod` and rebuild.

### Risks and Rollback
- Policies currently allow authenticated users to update likes and follow arrays broadly. Tighten RLS later by moving likes/follows to join tables (`post_likes`, `user_follows`) and updating code.
- If any Supabase issue occurs, revert env to Firebase-compatible branch and restore Firebase packages and platform configs.

### Suggested Commit Outline (you will run git yourself)
- chore: add supabase_flutter and flutter_dotenv; remove firebase deps
- feat: initialize Supabase and auth state stream
- refactor: migrate models to Map
- feat: migrate AuthMethods to Supabase
- feat: migrate FireStoreMethods to Supabase tables
- feat: migrate StorageMethods to Supabase Storage
- feat: update feed/search/profile/comments screens to Supabase
- chore: add SQL migrations and .env example
- chore(android/ios): remove Firebase configs; add INTERNET permission
