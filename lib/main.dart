import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'home_page.dart';
import 'citizen/citizen_dashboard.dart';
import 'government/government_dashboard.dart';
import 'worker/worker_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Citizen Issue Reporting',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.hasData && snapshot.data != null) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection("users").doc(snapshot.data!.uid).get(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (userSnapshot.hasData && userSnapshot.data!.exists) {
                String role = userSnapshot.data!.get("role");
                if (role == "citizen") return const CitizenDashboard();
                if (role == "government") return const GovernmentDashboard();
                if (role == "worker") return const WorkerDashboard();
              }
              // If user exists but doc doesn't or role is invalid, logout
              FirebaseAuth.instance.signOut();
              return const HomePage();
            },
          );
        }
        return const HomePage();
      },
    );
  }
}

class AuthPage extends StatefulWidget {
  final String role;
  const AuthPage({super.key, required this.role});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final nameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final mobileCtrl = TextEditingController();
  final aadhaarCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();
  String? selectedDomain;
  bool isLogin = true;
  bool loading = false;

  final List<String> domains = ["Roads", "Sanitation", "Electricity", "Drainage", "Public Safety", "Parks & Recreation", "Others"];

  Future<void> submit() async {
    if (!isLogin) {
      if (passCtrl.text != confirmCtrl.text) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Passwords do not match")));
        return;
      }
      if (widget.role == "citizen") {
        if (mobileCtrl.text.length < 10) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a valid mobile number")));
          return;
        }
        if (aadhaarCtrl.text.length < 4) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter last 4 digits of Aadhaar")));
          return;
        }
      }
      if (widget.role == "worker" && selectedDomain == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select your domain")));
        return;
      }
    }

    setState(() => loading = true);
    try {
      UserCredential cred;
      if (isLogin) {
        cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailCtrl.text.trim(),
          password: passCtrl.text.trim(),
        );
        
        // Fetch user role from Firestore and navigate to correct dashboard
        final userDoc = await FirebaseFirestore.instance.collection("users").doc(cred.user!.uid).get();
        if (userDoc.exists) {
          final String userRole = userDoc.get("role");
          
          Widget destination;
          if (userRole == "citizen") {
            destination = const CitizenDashboard();
          } else if (userRole == "worker") {
            destination = const WorkerDashboard();
          } else {
            destination = const GovernmentDashboard();
          }

          if (!mounted) return;
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => destination),
            (route) => false,
          );
          return; // Exit after login
        } else {
          await FirebaseAuth.instance.signOut();
          throw FirebaseAuthException(
            code: "user-not-found",
            message: "User profile not found in database.",
          );
        }
      } else {
        cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: emailCtrl.text.trim(),
          password: passCtrl.text.trim(),
        );
        await FirebaseFirestore.instance.collection("users").doc(cred.user!.uid).set({
          "uid": cred.user!.uid,
          "name": nameCtrl.text.trim(),
          "email": cred.user!.email,
          "role": widget.role,
          if (widget.role == "citizen") ...{
            "mobile": mobileCtrl.text.trim(),
            "aadhaarLast4": aadhaarCtrl.text.trim().substring(aadhaarCtrl.text.trim().length - 4),
          },
          if (widget.role == "worker") "domain": selectedDomain,
          "createdAt": FieldValue.serverTimestamp(),
        });
        
        await FirebaseAuth.instance.signOut();
        if (!mounted) return;
        setState(() {
          isLogin = true;
          loading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account created! Please login.")),
        );
        return;
      }

    } on FirebaseAuthException catch (e) {
      String message = e.message ?? "An error occurred";
      switch (e.code) {
        case 'wrong-password':
          message = "Wrong password provided.";
          break;
        case 'user-not-found':
          message = "No user found for that email.";
          break;
        case 'email-already-in-use':
          message = "The account already exists for that email.";
          break;
        case 'weak-password':
          message = "The password provided is too weak.";
          break;
        case 'operation-not-allowed':
          message = "Operation not allowed.";
          break;
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${e.toString()}")));
    }
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("${widget.role[0].toUpperCase()}${widget.role.substring(1)} ${isLogin ? "Login" : "Signup"}")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              if (!isLogin) TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Full Name")),
              TextField(controller: emailCtrl, decoration: const InputDecoration(labelText: "Email")),
              if (!isLogin && widget.role == "citizen") ...[
                TextField(controller: mobileCtrl, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: "Mobile Number")),
                TextField(controller: aadhaarCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Aadhaar (Last 4 digits)")),
              ],
              if (!isLogin && widget.role == "worker") ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedDomain,
                  decoration: const InputDecoration(labelText: "Select Your Domain", border: OutlineInputBorder()),
                  items: domains.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                  onChanged: (v) => setState(() => selectedDomain = v),
                ),
                const SizedBox(height: 10),
              ],
              TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Password")),
              if (!isLogin) TextField(controller: confirmCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Re-enter Password")),
              const SizedBox(height: 20),
              ElevatedButton(onPressed: loading ? null : submit, child: Text(isLogin ? "Login" : "Create Account")),
              TextButton(
                onPressed: () => setState(() => isLogin = !isLogin),
                child: Text(isLogin ? "New user? Create account" : "Already have an account? Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
