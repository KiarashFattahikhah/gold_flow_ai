import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:gold_trading/screens/home_screen.dart';

// import 'auth/auth_gate.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const GoldSignalApp());
}

class GoldSignalApp extends StatelessWidget {
  const GoldSignalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gold Signal Dashboard',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const HomeScreen(),
    );
  }
}