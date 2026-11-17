import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../login/login.dart';

class OwnerSale extends StatefulWidget {
  final String hotelName;

  const OwnerSale({super.key, required this.hotelName});

  @override
  State<OwnerSale> createState() => _OwnerSaleState();
}

class _OwnerSaleState extends State<OwnerSale> {
  final DatabaseReference db = FirebaseDatabase.instance.ref();
   StreamSubscription<DatabaseEvent>? selectedDateSub;

  bool isOnline = true;
  bool isLoading = true;

  late StreamSubscription<DatabaseEvent> dailySub;
  late StreamSubscription<DatabaseEvent> monthlySub;
  late StreamSubscription<List<ConnectivityResult>> internetSub;

  DateTime selectedDate = DateTime.now();

  double todaySale = 0;
  int todayOrders = 0;
  double todayService = 0;
  double todayTax = 0;

  double monthSale = 0;
  int monthOrders = 0;
  double monthService = 0;
  double monthTax = 0;

  double selectedSale = 0;
  int selectedOrders = 0;
  double selectedService = 0;
  double selectedTax = 0;

  @override
  Future<void> loadDashboard() async {
    setState(() {
      isLoading = true;
    });

    await Future.wait([loadTodaySale(), loadMonthlySale(), loadSelectedDate()]);

    setState(() {
      isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();

    listenTodaySale();
    listenSelectedDate();
    listenMonthlySale();

    internetSub = Connectivity()
        .onConnectivityChanged
        .listen((result) {
      if (!mounted) return;

      setState(() {
        isOnline = !result.contains(ConnectivityResult.none);
      });
    });

    loadDashboard();
  }


  void listenSelectedDate() {
    selectedDateSub?.cancel();

    final date = DateFormat("yyyy-MM-dd").format(selectedDate);

    selectedDateSub = db
        .child("Restaurant")
        .child(widget.hotelName)
        .child("Sales")
        .child("Daily")
        .child(date)
        .onValue
        .listen((event) {
      if (!mounted) return;

      if (event.snapshot.exists) {
        final data = Map<String, dynamic>.from(
          event.snapshot.value as Map,
        );

        setState(() {
          selectedSale = (data["sale"] ?? 0).toDouble();
          selectedOrders = data["orders"] ?? 0;
          selectedService = (data["service"] ?? 0).toDouble();
          selectedTax = (data["tax"] ?? 0).toDouble();
        });
      } else {
        setState(() {
          selectedSale = 0;
          selectedOrders = 0;
          selectedService = 0;
          selectedTax = 0;
        });
      }
    });
  }

  @override
  void dispose() {
    dailySub.cancel();
    monthlySub.cancel();
    selectedDateSub?.cancel();
    internetSub.cancel();
    super.dispose();
  }

  Future<void> loadTodaySale() async {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final snapshot = await db
        .child("Restaurant")
        .child(widget.hotelName)
        .child("Sales")
        .child("Daily")
        .child(today)
        .get();

    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);

      todaySale = (data["sale"] ?? 0).toDouble();
      todayOrders = data["orders"] ?? 0;
      todayService = (data["service"] ?? 0).toDouble();
      todayTax = (data["tax"] ?? 0).toDouble();
    }
  }

  Future<void> loadMonthlySale() async {
    final month = DateFormat("yyyy-MM").format(DateTime.now());

    final snapshot = await db
        .child("Restaurant")
        .child(widget.hotelName)
        .child("Sales")
        .child("Monthly")
        .child(month)
        .get();

    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);

      monthSale = (data["sale"] ?? 0).toDouble();
      monthOrders = data["orders"] ?? 0;
      monthService = (data["service"] ?? 0).toDouble();
      monthTax = (data["tax"] ?? 0).toDouble();
    }
  }

  Future<void> loadSelectedDate() async {
    final date = DateFormat("yyyy-MM-dd").format(selectedDate);

    final snapshot = await db
        .child("Restaurant")
        .child(widget.hotelName)
        .child("Sales")
        .child("Daily")
        .child(date)
        .get();

    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);

      selectedSale = (data["sale"] ?? 0).toDouble();
      selectedOrders = data["orders"] ?? 0;
      selectedService = (data["service"] ?? 0).toDouble();
      selectedTax = (data["tax"] ?? 0).toDouble();
    } else {
      selectedSale = 0;
      selectedOrders = 0;
      selectedService = 0;
      selectedTax = 0;
    }
  }

  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      selectedDate = picked;

      listenSelectedDate();

      setState(() {});
    }
  }
  Future<void> logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text("Logout"),
            content: const Text("Are you sure you want to logout?"),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text("Logout"),
              ),
            ],
          ),
    );

    if (shouldLogout != true) return;

    // Firebase Logout
    await FirebaseAuth.instance.signOut();

    // Clear Saved Session
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("uid");
    await prefs.remove("hotelName");
    await prefs.remove("role");
    await prefs.setBool("isLoggedIn", false);

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const Login()),
          (route) => false,
    );
  }

  Widget buildCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      margin: const EdgeInsets.all(5),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: const [
          BoxShadow(
            blurRadius: 8,
            color: Colors.black12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: color.withOpacity(.15),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
        ],
      ),
    );
  }

  Widget detailTile(String title, String value, IconData icon) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.orange.shade100,
        child: Icon(icon, color: Colors.orange),
      ),
      title: Text(title),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sales Report"),
        centerTitle: true,
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await logout();
            },
          ),
        ],
      ),


      body: Column(
        children: [
          if (!isOnline)
            Container(
              width: double.infinity,
              color: Colors.red,
              padding: const EdgeInsets.all(8),
              child: const Center(
                child: Text(
                  "❌ No Internet Connection",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          Expanded(
            child: RefreshIndicator(
              onRefresh: loadDashboard,
              child: isLoading
                  ? const Center(
                child: CircularProgressIndicator(),
              )
                  : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: buildCard(
                          title: "Today's Sale",
                          value: "Rs ${todaySale.toStringAsFixed(0)}",
                          icon: Icons.attach_money,
                          color: Colors.green,
                        ),
                      ),
                      Expanded(
                        child: buildCard(
                          title: "Today's Orders",
                          value: todayOrders.toString(),
                          icon: Icons.shopping_bag,
                          color: Colors.green,
                        ),
                      ),
                      Expanded(
                        child: buildCard(
                          title: "This Month Orders",
                          value: "$monthOrders",
                          icon: Icons.shopping_bag,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: buildCard(
                          title: "This Month Sale",
                          value: "Rs ${monthSale.toStringAsFixed(0)}",
                          icon: Icons.calendar_month,
                          color: Colors.blue,
                        ),
                      ),
                      Expanded(
                        child: buildCard(
                          title: "This Month Service",
                          value: "Rs ${monthService.toStringAsFixed(0)}",
                          icon: Icons.room_service,
                          color: Colors.orange,
                        ),
                      ),
                      Expanded(
                        child: buildCard(
                          title: "This Month Tax",
                          value: "Rs ${monthTax.toStringAsFixed(0)}",
                          icon: Icons.receipt_long,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        DateFormat("dd MMM yyyy")
                            .format(selectedDate),
                      ),
                      onPressed: pickDate,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Card(
                    elevation: 5,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: 10),

                        const Text(
                          "Selected Date Report",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),

                        const Divider(),

                        detailTile(
                          "Sale",
                          "Rs ${selectedSale.toStringAsFixed(0)}",
                          Icons.attach_money,
                        ),

                        detailTile(
                          "Orders",
                          "$selectedOrders",
                          Icons.shopping_cart,
                        ),

                        detailTile(
                          "Service",
                          "Rs ${selectedService.toStringAsFixed(0)}",
                          Icons.room_service,
                        ),

                        detailTile(
                          "Tax",
                          "Rs ${selectedTax.toStringAsFixed(0)}",
                          Icons.receipt_long,
                        ),

                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),

    );
  }

  void listenTodaySale() {
    final today = DateFormat("yyyy-MM-dd").format(DateTime.now());

    dailySub = db
        .child("Restaurant")
        .child(widget.hotelName)
        .child("Sales")
        .child("Daily")
        .child(today)
        .onValue
        .listen((event) {
      if (!mounted) return;

      if (event.snapshot.exists) {
        final data = Map<String, dynamic>.from(
          event.snapshot.value as Map,
        );

        setState(() {
          todaySale = (data["sale"] ?? 0).toDouble();
          todayOrders = data["orders"] ?? 0;
          todayService = (data["service"] ?? 0).toDouble();
          todayTax = (data["tax"] ?? 0).toDouble();
        });
      } else {
        setState(() {
          todaySale = 0;
          todayOrders = 0;
          todayService = 0;
          todayTax = 0;
        });
      }
    });
  }


  void listenMonthlySale() {
    final month = DateFormat("yyyy-MM").format(DateTime.now());

    monthlySub = db
        .child("Restaurant")
        .child(widget.hotelName)
        .child("Sales")
        .child("Monthly")
        .child(month)
        .onValue
        .listen((event) {
      if (!mounted) return;

      if (event.snapshot.exists) {
        final data = Map<String, dynamic>.from(
          event.snapshot.value as Map,
        );

        setState(() {
          monthSale = (data["sale"] ?? 0).toDouble();
          monthOrders = data["orders"] ?? 0;
          monthService = (data["service"] ?? 0).toDouble();
          monthTax = (data["tax"] ?? 0).toDouble();
          monthService = (data["service"] ?? 0).toDouble();
          monthTax = (data["tax"] ?? 0).toDouble();
        });
      } else {
        setState(() {
          monthSale = 0;
          monthOrders = 0;
          monthService = 0;
          monthTax = 0;
        });
      }
    });
  }
}