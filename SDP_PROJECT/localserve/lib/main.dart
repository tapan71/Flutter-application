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
    // Premium Modern Design System Palette
    const primaryNavy = Color(0xFF0F172A); // Deep Midnight Slate
    const primaryBlue = Color(0xFF1E40AF); // Deep Royal Blue
    const electricIndigo = Color(0xFF2563EB); // Vibrant Electric Indigo
    const accentCyan = Color(0xFF0EA5E9); // Bright Cyan
    const surfaceBg = Color(0xFFF8FAFC); // Slate Soft Clean Background
    const surfaceWhite = Colors.white;
    const borderSlate = Color(0xFFE2E8F0); // Subtle modern divider

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => DatabaseService()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'LocalServe - Smart On-Demand Home Services',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: surfaceBg,
          colorScheme: ColorScheme.fromSeed(
            seedColor: primaryBlue,
            primary: primaryBlue,
            secondary: electricIndigo,
            tertiary: accentCyan,
            surface: surfaceWhite,
            brightness: Brightness.light,
          ),
          fontFamily: 'Roboto',
          appBarTheme: const AppBarTheme(
            centerTitle: false,
            elevation: 0,
            backgroundColor: surfaceWhite,
            foregroundColor: primaryNavy,
            surfaceTintColor: Colors.transparent,
            titleTextStyle: TextStyle(
              color: primaryNavy,
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
            iconTheme: IconThemeData(color: primaryNavy),
          ),
          cardTheme: CardThemeData(
            elevation: 0,
            color: surfaceWhite,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: borderSlate, width: 1.2),
            ),
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: const Color(0xFFF8FAFC),
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: borderSlate, width: 1.2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: borderSlate, width: 1.2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: electricIndigo, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.2),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 2),
            ),
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
            labelStyle: const TextStyle(color: Color(0xFF475569), fontSize: 14, fontWeight: FontWeight.w500),
            prefixIconColor: const Color(0xFF64748B),
            suffixIconColor: const Color(0xFF64748B),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              elevation: 2,
              shadowColor: primaryBlue.withValues(alpha: 0.35),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          filledButtonTheme: FilledButtonThemeData(
            style: FilledButton.styleFrom(
              backgroundColor: electricIndigo,
              foregroundColor: Colors.white,
              elevation: 1,
              shadowColor: electricIndigo.withValues(alpha: 0.3),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ),
          outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
              foregroundColor: primaryBlue,
              side: const BorderSide(color: borderSlate, width: 1.4),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          chipTheme: ChipThemeData(
            backgroundColor: const Color(0xFFF1F5F9),
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: borderSlate, width: 1),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          ),
          dialogTheme: DialogThemeData(
            backgroundColor: surfaceWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: borderSlate, width: 1),
            ),
            elevation: 10,
          ),
          bottomSheetTheme: const BottomSheetThemeData(
            backgroundColor: surfaceWhite,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            elevation: 12,
          ),
          snackBarTheme: SnackBarThemeData(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            backgroundColor: primaryNavy,
            contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
          ),
          floatingActionButtonTheme: FloatingActionButtonThemeData(
            backgroundColor: electricIndigo,
            foregroundColor: Colors.white,
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
        home: const AuthWrapper(),
      ),
    );
  }
}