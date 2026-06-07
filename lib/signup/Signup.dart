import 'package:demoproject/login/login.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:demoproject/firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class Signup extends StatefulWidget {
  const Signup({super.key});

  @override
  State<Signup> createState() => _SignupState();
}

class _SignupState extends State<Signup> {
  final formkey = GlobalKey<FormState>();

  final TextEditingController fullname = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController phone = TextEditingController();
  final TextEditingController hotelName = TextEditingController();
  final TextEditingController address = TextEditingController();
  final TextEditingController passsword = TextEditingController();

  late DatabaseReference restaurantRef;

  bool isLoading = false;
  bool firebaseReady = false;

  @override
  void initState() {
    super.initState();
    initFirebase();
  }

  Future<void> initFirebase() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
      restaurantRef = FirebaseDatabase.instanceFor(
        app: Firebase.app(),
        databaseURL:
        'https://adsadmobandfacebook-default-rtdb.firebaseio.com/',
      ).ref('Restaurant');
    } else {
      restaurantRef = FirebaseDatabase.instance.ref('Restaurant');
    }

    setState(() {
      firebaseReady = true;
    });
  }

  String safeKey(String input) {
    return input.trim().replaceAll(" ", "_");
  }

  Future<void> registerUser() async {
    if (!formkey.currentState!.validate()) return;

    if (isLoading) return;

    setState(() => isLoading = true);

    try {
      // 🔐 Firebase Auth
      UserCredential userCredential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.text.trim(),
        password: passsword.text.trim(),
      );

      final uid = userCredential.user!.uid;
      final hotel = safeKey(hotelName.text);

      // ✅ USER DATA
      final userData = {
        "owner": fullname.text.trim(),
        "email": email.text.trim(),
        "phone": phone.text.trim(),
        "HotelName": hotel,
        "address": address.text.trim(),
        "uid": uid,
        "role": "owner",
        "createdAt": DateTime.now().toIso8601String(),
      };

      // 🌐 WEB / WINDOWS
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
        final url = Uri.parse(
            'https://adsadmobandfacebook-default-rtdb.firebaseio.com/Restaurant/$hotel/Users/$uid.json');

        final response =
        await http.put(url, body: json.encode(userData));

        if (response.statusCode != 200) {
          throw Exception("Upload Failed");
        }
      }
      // 📱 MOBILE
      else {
        await restaurantRef
            .child(hotel)
            .child("Users")
            .child(uid)
            .set(userData);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Signup Successful")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Login()),
      );

      // clear
      fullname.clear();
      email.clear();
      phone.clear();
      hotelName.clear();
      address.clear();
      passsword.clear();
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Auth Error")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Signup", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        child: Container(
          padding: const EdgeInsets.all(16),
          width: double.infinity,
          alignment: Alignment.center,
          child: Form(
            key: formkey,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Icon(Icons.lock_outline, size: 80),
                ),
                const Text(
                  "Create Account",
                  style: TextStyle(fontSize: 25),
                ),

                _buildTextField(fullname, "Full Name"),
                _buildTextField(email, "Email"),
                _buildTextField(phone, "Phone"),
                _buildTextField(hotelName, "Hotel Name"),
                _buildTextField(address, "Address"),
                _buildTextField(passsword, "Password", obscure: true),

                const SizedBox(height: 15),

                isLoading
                    ? const CircularProgressIndicator()
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildButton("Signup", registerUser),
                    const SizedBox(width: 20),
                    _buildButton("Login", () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const Login()),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {bool obscure = false}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        child: TextFormField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          validator: (value) =>
          value == null || value.isEmpty ? "Enter $label" : null,
        ),
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.35,
      height: 50,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
        ),
        child: Text(text),
      ),
    );
  }
}