import 'package:flutter/material.dart';
import '../main.dart';

class GovernmentLoginPage extends StatelessWidget {
  const GovernmentLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthPage(role: "government");
  }
}
