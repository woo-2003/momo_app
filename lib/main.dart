import 'package:flutter/material.dart';
import 'package:momo_app/core/theme.dart';
import 'package:momo_app/presentation/screens/login_screen.dart';

void main() {
  runApp(const MomoApp());
}

class MomoApp extends StatelessWidget {
  const MomoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'momo',
      debugShowCheckedModeBanner: false,
      theme: MomoTheme.light,
      home: const LoginScreen(),
    );
  }
}
