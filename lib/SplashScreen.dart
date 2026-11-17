import 'dart:async';
import 'package:flutter/material.dart';
import 'package:demoproject/login/login.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dashoard/Dashboard.dart';
import 'dashoard/Menu.dart';
import 'ownerdashboard/OwnerDashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  bool userLoggedIn = false; // replace with SharedPreferences/Firebase

  @override
  void initState() {
    super.initState();
    _start();
  }

  void _start() async {
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final prefs = await SharedPreferences.getInstance();
    final isLoggedIn = prefs.getBool("isLoggedIn") ?? false;
    final role = prefs.getString("role");
    final hotelName = prefs.getString("hotelName") ?? "";

    Widget nextScreen = const Login();

    if (isLoggedIn && role != null) {
      nextScreen = (role == 'owner')
          ? Ownerdashboard(hotelName: hotelName)
          : Dashboard(hotelName: hotelName);
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => nextScreen),
    );
  }







  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111827),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // LOGO
            Container(
              height: 120,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
              ),
              child: Padding(
                padding: const EdgeInsets.all(15),
                child: Image.asset(
                  "assets/images/logo.png",
                  fit: BoxFit.contain,
                ),
              ),
            ),

            const SizedBox(height: 25),

            const Text(
              "My Restaurant POS",
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              "Restaurant Management System",
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),

            const SizedBox(height: 40),

            const CircularProgressIndicator(),

            const SizedBox(height: 15),

            const Text(
              "Loading...",
              style: TextStyle(color: Colors.white70),
            ),


            const Text(
              "version 1.44",
              style: TextStyle(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}