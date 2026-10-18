import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'services/theme_service.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'services/local_storage_service.dart';
import 'screens/auth/auth_wrapper.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize local persistent storage
  await LocalStorageService().init();

  // Initialize Firebase safely:
  // On Mobile, it reads from google-services.json automatically.
  // On Web, it initializes using FirebaseOptions.
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: const FirebaseOptions(
          apiKey: 'AIzaSyBblhZ5IKvKvGs9N6v98B-9_nxzLylhzuo',
          appId: '1:709359536387:web:e7360dfaf40316ef6bc136',
          messagingSenderId: '709359536387',
          projectId: 'localserve-project',
          storageBucket: 'localserve-project.firebasestorage.app',
        ),
      );
    } else {
      await Firebase.initializeApp();
    }
  } catch (_) {
    // LocalServe automatically operates in offline/mock demo mode if Firebase is unreachable.
  }

  runApp(const LocalServeApp());
}

class LocalServeApp extends StatelessWidget {
  const LocalServeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => DatabaseService()),
      ],
      child: Consumer<ThemeService>(
        builder: (context, themeService, _) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'LocalServe - Smart On-Demand Home Services',
            themeMode: themeService.themeMode, // Default is ThemeMode.dark
            theme: themeService.lightTheme,
            darkTheme: themeService.darkTheme,
            home: const AuthWrapper(),
          );
        },
      ),
    );
  }
}