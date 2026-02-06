import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'citizen_drawer.dart';

const List<String> issueCategories = [
  "Pothole",
  "Broken Streetlight",
  "Overflowing Garbage Bin",
  "Drainage Blockage",
  "Unsafe Public Space",
  "Damaged Infrastructure",
];

class ReportIssuePage extends StatefulWidget {
  const ReportIssuePage({super.key});

  @override
  State<ReportIssuePage> createState() => _ReportIssuePageState();
}

class _ReportIssuePageState extends State<ReportIssuePage> {
  final descCtrl = TextEditingController();
  final areaCtrl = TextEditingController();
  final addressCtrl = TextEditingController();
  String category = "Pothole";
  bool isSubmitting = false;
  bool isGettingLocation = false;
  File? _image;
  Position? _currentPosition;
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
                if (pickedFile != null) {
                  setState(() => _image = File(pickedFile.path));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () async {
                Navigator.pop(context);
                final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera);
                if (pickedFile != null) {
                  setState(() => _image = File(pickedFile.path));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    setState(() => isGettingLocation = true);

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location services are disabled.")),
          );
        }
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Location permissions are denied.")),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permissions are permanently denied.")),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition();
      setState(() => _currentPosition = position);

      // Reverse geocoding to get address
      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks[0];
          setState(() {
            addressCtrl.text = "${place.street}, ${place.subLocality}, ${place.locality}, ${place.postalCode}";
            areaCtrl.text = place.subLocality ?? place.locality ?? "";
          });
        }
      } catch (e) {
        debugPrint("Error in reverse geocoding: $e");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error getting location: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => isGettingLocation = false);
    }
  }

  Future<void> submitIssue() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("No internet connection.")),
        );
      }
      return;
    }

    if (descCtrl.text.isEmpty || areaCtrl.text.isEmpty || addressCtrl.text.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please fill all fields")),
        );
      }
      return;
    }

    setState(() => isSubmitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      String? imageUrl;

      if (_image != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child("issue_images/${DateTime.now().millisecondsSinceEpoch}.jpg");
        await storageRef.putFile(_image!);
        imageUrl = await storageRef.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection("issues").add({
        "userId": user!.uid,
        "category": category,
        "area": areaCtrl.text.trim(),
        "address": addressCtrl.text.trim(),
        "description": descCtrl.text.trim(),
        "status": "Pending",
        "remarks": "",
        "imageUrl": imageUrl,
        "latitude": _currentPosition?.latitude,
        "longitude": _currentPosition?.longitude,
        "createdAt": FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Issue reported successfully!")),
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
      if (mounted) setState(() => isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Report Issue")),
      drawer: const CitizenDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(
                  labelText: "Issue Category",
                  border: OutlineInputBorder(),
                ),
                items: issueCategories.map((String val) {
                  return DropdownMenuItem<String>(
                    value: val,
                    child: Text(val),
                  );
                }).toList(),
                onChanged: (v) => setState(() => category = v!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: areaCtrl,
                decoration: const InputDecoration(
                  labelText: "Area / Ward",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: addressCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: "Full Address of the Issue",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descCtrl,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: "Issue Description",
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image),
                      label: const Text("Pick Photo"),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: isGettingLocation ? null : _getCurrentLocation,
                      icon: isGettingLocation 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.location_on),
                      label: Text(isGettingLocation ? "Locating..." : "Get Location"),
                    ),
                  ),
                ],
              ),
              if (_image != null) ...[
                const SizedBox(height: 10),
                Image.file(_image!, height: 150),
              ],
              if (_currentPosition != null) ...[
                const SizedBox(height: 10),
                Card(
                  color: Colors.blue.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.map, color: Colors.blue),
                    title: const Text("View on OpenStreetMap"),
                    subtitle: Text("Lat: ${_currentPosition!.latitude}, Lng: ${_currentPosition!.longitude}"),
                    trailing: const Icon(Icons.open_in_new, size: 20),
                    onTap: () async {
                      final url = Uri.parse(
                          'https://www.openstreetmap.org/?mlat=${_currentPosition!.latitude}&mlon=${_currentPosition!.longitude}#map=17/${_currentPosition!.latitude}/${_currentPosition!.longitude}');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                  ),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSubmitting ? null : submitIssue,
                  child: isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Submit Issue", style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
