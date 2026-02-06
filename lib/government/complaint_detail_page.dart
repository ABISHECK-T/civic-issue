import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

class ComplaintDetailPage extends StatefulWidget {
  final String complaintId;
  final Map<String, dynamic> complaintData;

  const ComplaintDetailPage({
    super.key,
    required this.complaintId,
    required this.complaintData,
  });

  @override
  State<ComplaintDetailPage> createState() => _ComplaintDetailPageState();
}

class _ComplaintDetailPageState extends State<ComplaintDetailPage> {
  late String currentStatus;
  final remarksCtrl = TextEditingController();
  final assignedToCtrl = TextEditingController();
  String? selectedDept;
  DateTime? expectedCompletionDate;
  bool isUpdating = false;

  final List<String> departments = [
    "Roads & Infrastructure",
    "Sanitation & Waste",
    "Electricity & Lighting",
    "Water & Sewage",
    "Public Safety",
    "Parks & Recreation",
    "Others"
  ];

  @override
  void initState() {
    super.initState();
    currentStatus = widget.complaintData["status"] ?? "Pending";
    remarksCtrl.text = widget.complaintData["remarks"] ?? "";
    assignedToCtrl.text = widget.complaintData["assignedTo"] ?? "";
    selectedDept = widget.complaintData["department"];
    if (widget.complaintData["expectedCompletion"] != null) {
      expectedCompletionDate = (widget.complaintData["expectedCompletion"] as Timestamp).toDate();
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => expectedCompletionDate = picked);
    }
  }

  Future<void> _updateComplaint({bool isAssigning = false}) async {
    if (isAssigning && (selectedDept == null || assignedToCtrl.text.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select department and assign to a worker/team")),
      );
      return;
    }

    setState(() => isUpdating = true);
    try {
      Map<String, dynamic> updateData = {
        "status": isAssigning ? "Assigned" : currentStatus,
        "remarks": remarksCtrl.text.trim(),
        "department": selectedDept,
        "assignedTo": assignedToCtrl.text.trim(),
        "expectedCompletion": expectedCompletionDate != null ? Timestamp.fromDate(expectedCompletionDate!) : null,
      };

      await FirebaseFirestore.instance
          .collection("issues")
          .doc(widget.complaintId)
          .update(updateData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isAssigning ? "Work Assigned Successfully!" : "Update Saved!")),
        );
        if (isAssigning) setState(() => currentStatus = "Assigned");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.complaintData;
    DateTime? createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    String formattedDateTime = createdAt != null 
        ? DateFormat('dd MMM yyyy, hh:mm a').format(createdAt) 
        : 'N/A';

    return Scaffold(
      appBar: AppBar(title: const Text("Complaint Details")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle("Issue Information"),
            _buildInfoCard([
              _buildDetailRow("Complaint ID", widget.complaintId.substring(0,8).toUpperCase()),
              _buildDetailRow("Category", data["category"] ?? "N/A"),
              _buildDetailRow("Reported On", formattedDateTime),
              _buildDetailRow("Area / Ward", data["area"] ?? "N/A"),
              _buildDetailRow("Address", data["address"] ?? "N/A"),
              const SizedBox(height: 8),
              const Text("Description:", style: TextStyle(fontWeight: FontWeight.bold)),
              Text(data["description"] ?? "No description"),
            ]),

            if (data["imageUrl"] != null) ...[
              const SizedBox(height: 16),
              _buildSectionTitle("Issue Image"),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(data["imageUrl"], height: 200, width: double.infinity, fit: BoxFit.cover),
              ),
            ],

            const SizedBox(height: 16),
            _buildSectionTitle("Citizen Details"),
            FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection("users").doc(data["userId"]).get(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const LinearProgressIndicator();
                final user = snapshot.data!.data() as Map<String, dynamic>;
                return _buildInfoCard([
                  _buildDetailRow("Name", user["name"] ?? "N/A"),
                  _buildDetailRow("Mobile", user["mobile"] ?? "N/A"),
                  _buildDetailRow("Aadhaar", "XXXX-XXXX-${user["aadhaarLast4"] ?? "0000"}"),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => launchUrl(Uri.parse("tel:${user["mobile"]}")),
                    icon: const Icon(Icons.call),
                    label: const Text("Call Citizen"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  ),
                ]);
              },
            ),

            const SizedBox(height: 16),
            _buildSectionTitle("Assign Work"),
            _buildInfoCard([
              DropdownButtonFormField<String>(
                value: selectedDept,
                decoration: const InputDecoration(labelText: "Select Department", border: OutlineInputBorder()),
                items: departments.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (v) => setState(() => selectedDept = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: assignedToCtrl,
                decoration: const InputDecoration(labelText: "Assign to Worker/Team", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(expectedCompletionDate == null 
                  ? "Select Expected Completion Date" 
                  : "Expected Date: ${DateFormat('dd MMM yyyy').format(expectedCompletionDate!)}"),
                trailing: const Icon(Icons.calendar_today),
                onTap: _pickDate,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isUpdating ? null : () => _updateComplaint(isAssigning: true),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  child: const Text("Assign & Update Status"),
                ),
              ),
            ]),

            const SizedBox(height: 16),
            if (data["workerRemarks"] != null) ...[
              _buildSectionTitle("Worker Updates"),
              _buildInfoCard([
                _buildDetailRow("Worker Status", data["status"]),
                _buildDetailRow("Worker Remarks", data["workerRemarks"]),
                if (data["workerUpdatedAt"] != null)
                  _buildDetailRow("Last Updated", DateFormat('dd MMM yyyy, hh:mm a').format((data["workerUpdatedAt"] as Timestamp).toDate())),
              ]),
              const SizedBox(height: 16),
            ],
            _buildSectionTitle("Status Update"),
            _buildInfoCard([
              DropdownButton<String>(
                value: currentStatus,
                isExpanded: true,
                items: ["Pending", "Assigned", "In Progress", "Resolved"].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setState(() => currentStatus = v!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remarksCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Official Remarks", border: OutlineInputBorder(), alignLabelWithHint: true),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isUpdating ? null : () => _updateComplaint(),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                  child: const Text("Save Status & Remarks"),
                ),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
  );

  Widget _buildInfoCard(List<Widget> children) => Card(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children)),
  );

  Widget _buildDetailRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(children: [Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)), Expanded(child: Text(value))]),
  );
}
