import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../home_page.dart';
import 'government_dashboard.dart';
import 'manage_issues.dart';

class GovernmentDrawer extends StatelessWidget {
  const GovernmentDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: const Text(
              "Government Portal",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            accountEmail: Text(user?.email ?? "No Email"),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.account_balance, size: 40, color: Colors.green),
            ),
            decoration: const BoxDecoration(color: Colors.green),
            otherAccountsPictures: [
              Chip(
                label: const Text(
                  "Government",
                  style: TextStyle(fontSize: 10, color: Colors.white),
                ),
                backgroundColor: Colors.green.shade900,
              ),
            ],
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text("Dashboard"),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const GovernmentDashboard()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment),
            title: const Text("All Issues"),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ManageIssuesPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_add),
            title: const Text("Assign Issue"),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ManageIssuesPage()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.analytics),
            title: const Text("Analytics"),
            onTap: () {
              // Placeholder
              Navigator.pop(context);
            },
          ),
          const Spacer(),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text("Logout", style: TextStyle(color: Colors.red)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const HomePage()),
                  (route) => false,
                );
              }
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
