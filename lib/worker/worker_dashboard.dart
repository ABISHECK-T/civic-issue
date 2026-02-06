import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'worker_action_page.dart';
import '../home_page.dart';

class WorkerDashboard extends StatelessWidget {
  const WorkerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Worker Dashboard"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
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
        ],
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection("users").doc(user?.uid).get(),
        builder: (context, userSnapshot) {
          if (!userSnapshot.hasData) return const Center(child: CircularProgressIndicator());
          
          final workerData = userSnapshot.data!.data() as Map<String, dynamic>;
          final String domain = workerData["domain"] ?? "Others";

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.orange.shade100,
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Welcome, ${workerData["name"]}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text("Domain: $domain", style: TextStyle(color: Colors.orange.shade900)),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection("issues")
                      .where("department", isEqualTo: _getDeptFromDomain(domain))
                      .orderBy("createdAt", descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text("No tasks assigned to your domain."));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var doc = snapshot.data!.docs[index];
                        var data = doc.data() as Map<String, dynamic>;

                        return Card(
                          elevation: 3,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(16),
                            title: Text(data["category"] ?? "Unknown", style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text("Address: ${data["address"] ?? "N/A"}", maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                _buildStatusBadge(data["status"]),
                              ],
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => WorkerActionPage(complaintId: doc.id, complaintData: data),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _getDeptFromDomain(String domain) {
    // Maps the worker domain to the department string used in government assignment
    switch (domain) {
      case "Roads": return "Roads & Infrastructure";
      case "Sanitation": return "Sanitation & Waste";
      case "Electricity": return "Electricity & Lighting";
      case "Drainage": return "Water & Sewage";
      case "Public Safety": return "Public Safety";
      case "Parks & Recreation": return "Parks & Recreation";
      default: return "Others";
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case "Resolved": color = Colors.green; break;
      case "In Progress": color = Colors.blue; break;
      case "Assigned": color = Colors.orange; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4), border: Border.all(color: color, width: 0.5)),
      child: Text(status, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
