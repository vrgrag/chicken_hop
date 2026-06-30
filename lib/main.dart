import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/loading_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF8FD16F),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const ChickenHopApp());
}

class ChickenHopApp extends StatelessWidget {
  const ChickenHopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chicken Hop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFC93C),
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
      ),
      home: const LoadingScreen(),
    );
  }
}
