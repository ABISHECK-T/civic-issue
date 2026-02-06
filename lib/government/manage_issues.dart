import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'government_drawer.dart';

class ManageIssuesPage extends StatelessWidget {
  const ManageIssuesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Issues")),
      drawer: const GovernmentDrawer(),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection("issues")
            .orderBy("createdAt", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              var doc = snapshot.data!.docs[index];
              return ListTile(
                title: Text(doc["category"]),
                subtitle: Text("Status: ${doc["status"]}"),
                trailing: DropdownButton<String>(
                  value: doc["status"],
                  items: ["Pending", "In Progress", "Resolved"].map((String status) {
                    return DropdownMenuItem<String>(
                      value: status,
                      child: Text(status),
                    );
                  }).toList(),
                  onChanged: (String? newStatus) async {
                    if (newStatus == null) return;

                    // Ensure user is signed in
                    final user = FirebaseAuth.instance.currentUser;
                    if (user == null) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("You must be signed in to change status."),
                      ));
                      return;
                    }

                    try {
                      // Verify role from users collection
                      final userDoc = await FirebaseFirestore.instance.collection("users").doc(user.uid).get();
                      final role = userDoc.exists ? (userDoc.data()?['role'] ?? '') : '';
                      if (role != 'government') {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text("Access denied: Government role required."),
                        ));
                        return;
                      }

                      await FirebaseFirestore.instance.collection("issues").doc(doc.id).update({"status": newStatus});
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text("Status updated."),
                      ));
                    } on FirebaseException catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("Failed to update status: ${e.message}"),
                      ));
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text("Error: ${e.toString()}"),
                      ));
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
