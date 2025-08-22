import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'game_screen.dart';

void main() {
  // Wrap the entire application in a ProviderScope to make Riverpod providers
  // available throughout the widget tree.
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wizard Battle',
      debugShowCheckedModeBanner: false, // Optional: removes the debug banner
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      // The home screen of the app is our GameScreen.
      home: const GameScreen(),
    );
  }
}
