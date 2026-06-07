---
Task ID: 1
Agent: Super Z (Main)
Task: Implement Klasivo Auth Flow UI screens

Work Log:
- Created 10 Dart files for the Auth Flow UI + supporting infrastructure
- Implemented 5 auth screens: Splash, Login, Register, Org Naming, Student Login
- Created GoRouter configuration with auth guards and redirect logic
- Created Riverpod auth_provider.dart with auth state and notifier providers
- Created app_constants.dart with all route paths, Firestore collections, notification types
- Created theme.dart with "Academic Neo-Minimalism" design system
- Created main.dart that wires up Riverpod + GoRouter + theme
- Could not push to GitHub — no authentication token available

Stage Summary:
- All 5 auth screens implemented with full design system compliance
- GoRouter auth guards handle: unauthenticated → login, needs setup → org naming, ready → dashboard
- Auth provider uses authStateProvider (StreamProvider) + needsSetupProvider (FutureProvider) + authNotifierProvider (StateNotifierProvider)
- Files saved to /home/z/my-project/download/klasivo_auth_ui/
- User needs to provide a new GitHub PAT to push changes, or copy files manually
