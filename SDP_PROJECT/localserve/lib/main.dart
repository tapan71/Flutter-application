import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/local_storage_service.dart';
import 'screens/auth/auth_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local persistent storage
  await LocalStorageService().init();

  // Initialize Firebase safely:
  // On Web, Firebase.initializeApp() requires explicit FirebaseOptions.
  // On Android/iOS, it reads from google-services.json / GoogleService-Info.plist.
  if (!kIsWeb) {
    try {
      await Firebase.initializeApp();
    } catch (_) {
      // Firebase configuration (google-services.json) is not yet added.
      // LocalServe automatically operates in offline/mock demo mode.
    }
  }

  runApp(const LocalServeApp());
}

class LocalServeApp extends StatelessWidget {
  const LocalServeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => DatabaseService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'LocalServe',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 1,
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}