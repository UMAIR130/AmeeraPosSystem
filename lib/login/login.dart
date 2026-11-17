import 'dart:convert';
import 'package:demoproject/dashoard/Dashboard.dart';
import 'package:demoproject/ownerdashboard/OwnerDashboard.dart';
import 'package:demoproject/signup/Signup.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> {
  final formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool isPasswordVisible = false;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      checkAutoLogin();
    });
  }




  // ================= GET USER DATA =================
  Future<Map<String, dynamic>> getUserData(String uid) async {
    Map<String, dynamic> userData = {};

    DatabaseReference ref =
    FirebaseDatabase.instance.ref('Restaurant');

    final snapshot = await ref.get();

    if (snapshot.exists) {
      Map data = snapshot.value as Map;

      data.forEach((hotelKey, hotelValue) {
        Map users = hotelValue['Users'] ?? {};

        if (users.containsKey(uid)) {
          userData = Map<String, dynamic>.from(users[uid]);
          userData['hotelName'] = hotelKey;
        }
      });
    }

    return userData;
  }

  // ================= AUTO LOGIN =================
  Future<void> checkAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();

    final isLoggedIn = prefs.getBool("isLoggedIn") ?? false;
    final role = prefs.getString("role");
    final hotelName = prefs.getString("hotelName") ?? "";

    if (!isLoggedIn || role == null || role.isEmpty) return;

    if (!mounted) return;

    Future.microtask(() {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => role == 'owner'
              ? Ownerdashboard(hotelName: hotelName)
              : Dashboard(hotelName: hotelName),
        ),
      );
    });
  }










  // ================= LOGIN =================
  Future<void> loginUser() async {
    if (isLoading) return; // prevent double click
    if (!formKey.currentState!.validate()) return;

    setState(() => isLoading = true);

    final prefs = await SharedPreferences.getInstance();

    try {
      // AUTH LOGIN
      UserCredential userCredential =
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      final uid = userCredential.user!.uid;

      // GET USER DATA
      Map<String, dynamic> userData = await getUserData(uid);

      if (userData.isEmpty) {
        throw Exception("User not found in database");
      }

      String hotelName = userData['hotelName'] ?? '';
      String role = userData['role'] ?? '';

      if (hotelName.isEmpty || role.isEmpty) {
        throw Exception("Invalid user data");
      }

      // SAVE SESSION
      await prefs.setString('uid', uid);
      await prefs.setString('hotelName', hotelName);
      await prefs.setString('role', role);
      await prefs.setBool('isLoggedIn', true);

      await prefs.reload();

      if (!mounted) return;

      // NAVIGATION
      if (role == 'owner') {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => Ownerdashboard(hotelName: hotelName),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => Dashboard(hotelName: hotelName),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Login", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: formKey,
            child: Column(
              children: [
                const Icon(Icons.lock, size: 80),
                const Text("Login", style: TextStyle(fontSize: 25)),

                _buildField(emailController, "Email"),

                _buildField(
                  passwordController,
                  "Password",
                  obscure: !isPasswordVisible,
                  suffix: IconButton(
                    icon: Icon(isPasswordVisible
                        ? Icons.visibility
                        : Icons.visibility_off),
                    onPressed: () {
                      setState(() {
                        isPasswordVisible = !isPasswordVisible;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 20),

                isLoading
                    ? const CircularProgressIndicator()
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildButton("Login", loginUser),
                    const SizedBox(width: 20),
                    _buildButton("Signup", () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const Signup(),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ),
      )
    );
  }

  Widget _buildField(
      TextEditingController controller,
      String label, {
        bool obscure = false,
        Widget? suffix,
      }) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextFormField(
        controller: controller,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: suffix,
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return "Enter $label";
          }
          return null;
        },
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      child: Text(text),
    );
  }
}