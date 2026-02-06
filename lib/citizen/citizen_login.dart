import 'package:flutter/material.dart';
import '../main.dart';

class CitizenLoginPage extends StatelessWidget {
  const CitizenLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthPage(role: "citizen");
  }
}
