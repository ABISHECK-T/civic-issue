import 'package:flutter/material.dart';
import '../main.dart';

class WorkerLoginPage extends StatelessWidget {
  const WorkerLoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AuthPage(role: "worker");
  }
}
