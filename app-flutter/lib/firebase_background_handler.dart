// Isolate entry point for Firebase background messages.
// Keep this file minimal: only import Firebase so the background isolate
// never loads FirebaseService → ChatScreen → socket_io_client (which was
// causing repeated "Socket error" logs in the background isolate).
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // No FirebaseService import here – notification is shown by the system;
  // when user taps, the app (main isolate) handles it via getInitialMessage / onMessageOpenedApp.
}
