import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GridGlance',
      theme: ThemeData(brightness: Brightness.dark, primarySwatch: Colors.red),
      home: HomeScreen(),
    );
  }
}
