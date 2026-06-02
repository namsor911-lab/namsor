import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'package:accounting/auth_page.dart';
import 'package:accounting/models/models.dart';
import 'package:accounting/screens/main_screen.dart';
import 'package:accounting/services/services.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'namsor hydropower — dam project',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF3FB950),
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        fontFamily: 'IBM Plex Sans Thai',
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF3FB950),
          surface: Color(0xFF161B22),
          onSurface: Color(0xFFE6EDF3),
          secondary: Color(0xFFF85149),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF161B22),
          elevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1C2128),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF30363D)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: Color(0xFF58A6FF)),
          ),
        ),
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: FirebaseAuthService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D1117),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF3FB950)),
            ),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return AuthPage(onAuthenticated: (_) {});
        }

        return MainScreen(
          currentUser: AuthResult(
            success: true,
            message: '',
            uid: user.uid,
            email: user.email ?? '',
            name: user.displayName ?? user.email ?? '',
          ),
          onLogout: () async {
            await FirebaseAuthService.logout();
          },
        );
      },
    );
  }
}
