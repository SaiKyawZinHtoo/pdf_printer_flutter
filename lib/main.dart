import 'package:flutter/material.dart';
import 'create_screen.dart'; // Import the CreateScreen

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: CreateScreen(), // Set CreateScreen as the home screen
    );
  }
}
