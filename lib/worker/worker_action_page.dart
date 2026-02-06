import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class WorkerActionPage extends StatefulWidget {
  final String complaintId;
  final Map<String, dynamic> complaintData;

  const WorkerActionPage({
    super.key,
    required this.complaintId,
    required this.complaintData,
  });

  @override
  State<WorkerActionPage> createState() => _WorkerActionPageState();
}

class _WorkerActionPageState extends State<WorkerActionPage> {
  late String currentStatus;
  final workerRemarksCtrl = TextEditingController();
  bool isUpdating = false;

  @override
  void initState() {
    super.initState();
    currentStatus = widget.complaintData["status"] == "Assigned" 
        ? "In Progress" 
        : widget.complaintData["status"];
    workerRemarksCtrl.text = widget.complaintData["workerRemarks"] ?? "";
  }

  Future<void> _updateWork() async {
    setState(() => isUpdating = true);
    try {
      await FirebaseFirestore.instance
          .collection("issues")
          .doc(widget.complaintId)
          .update({
        "status": currentStatus,
        "workerRemarks": workerRemarksCtrl.text.trim(),
        "workerUpdatedAt": FieldValue.serverTimestamp(),
      });

      // Simulate sending email to citizen if completed
      if (currentStatus == "Completed") {
        await _simulateEmailNotification();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(currentStatus == "Completed" 
              ? "Work Completed! Notification sent to citizen." 
              : "Work status updated successfully!"),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isUpdating = false);
    }
  }

  Future<void> _simulateEmailNotification() async {
    // In a real app, this would be a Cloud Function or backend API call
    // We fetch the citizen details to "send" the mail
    final userDoc = await FirebaseFirestore.instance
        .collection("users")
        .doc(widget.complaintData["userId"])
        .get();
    
    if (userDoc.exists) {
      final citizenEmail = userDoc.get("email");
      debugPrint("SIMULATED EMAIL: To: $citizenEmail, Subject: Your Complaint is Resolved, Body: Your issue ${widget.complaintData["category"]} has been marked as Completed by the worker.");
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.complaintData;
    DateTime? expectedDate = (data['expectedCompletion'] as Timestamp?)?.toDate();

    return Scaffold(
      appBar: AppBar(title: const Text("Task Details")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCard("Complaint Information", [
              _buildRow("Category", data["category"]),
              _buildRow("Address", data["address"]),
              _buildRow("Description", data["description"]),
            ]),
            const SizedBox(height: 16),
            _buildCard("Assignment Details", [
              _buildRow("Expected Completion", expectedDate != null ? DateFormat('dd MMM yyyy').format(expectedDate) : "Not Set"),
              _buildRow("Gov Remarks", data["remarks"] ?? "No remarks"),
            ]),
            if (data["imageUrl"] != null) ...[
              const SizedBox(height: 16),
              const Text("Reference Image", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(data["imageUrl"], height: 200, width: double.infinity, fit: BoxFit.cover),
              ),
            ],
            const SizedBox(height: 24),
            const Text("Update Progress", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: currentStatus == "Assigned" ? "In Progress" : currentStatus,
              decoration: const InputDecoration(labelText: "Work Status", border: OutlineInputBorder()),
              items: ["In Progress", "Completed"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: (v) => setState(() => currentStatus = v!),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: workerRemarksCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: "Work Completion Remarks",
                hintText: "Describe the work done...",
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isUpdating ? null : _updateWork,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: isUpdating 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("Submit Work Update", style: TextStyle(fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(String title, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
            const Divider(),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          Expanded(child: Text(value ?? "N/A", style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}
