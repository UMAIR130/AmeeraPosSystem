import 'package:demoproject/inventory/InventoryScreen.dart';
import 'package:demoproject/inventory/RecipeScreen.dart';
import 'package:demoproject/ownerdashboard/AddStaff.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../dashoard/OrderList.dart';
import 'OrderHistory.dart';

class Ownerdashboard extends StatefulWidget {
  final String hotelName;

  const Ownerdashboard({super.key, required this.hotelName});

  @override
  State<Ownerdashboard> createState() => _OwnerdashboardState();
}

class _OwnerdashboardState extends State<Ownerdashboard> with SingleTickerProviderStateMixin{

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(
      // appBar: AppBar(
      //   title: const Text("Dashboard", style: TextStyle(color: Colors.white)),
      //   backgroundColor: Colors.green,
      // ),

      body: TabBarView(
        controller: _tabController,
        children: [


          OrderHistory(hotelName: widget.hotelName),
          AddStaff(hotelName: widget.hotelName),
          Inventoryscreen(hotelName: widget.hotelName),
          Recipescreen(hotelName: widget.hotelName),
        ],
      ),

      // ✅ Tabs always at bottom (Desktop + Mobile)
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: Colors.green,
          child: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.white,
            tabs: const [
              Tab(icon: Icon(Icons.point_of_sale), text: "Order History"),
              Tab(icon: Icon(Icons.people), text: "Add Staff"),
              Tab(icon: Icon(Icons.people), text: "Inventory"),
              Tab(icon: Icon(Icons.people), text: "Recipe"),
             // Tab(icon: Icon(Icons.list), text: "Show Menu"),
            ],
          ),
        ),
      ),
    );  }
}
