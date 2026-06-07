import 'package:demoproject/dashoard/Menu.dart';
import 'package:demoproject/dashoard/RoomData.dart';
import 'package:demoproject/dashoard/RoomHistory.dart';
import 'package:demoproject/inventory/InventoryScreen.dart';
import 'package:demoproject/inventory/RecipeScreen.dart';
import 'package:demoproject/ownerdashboard/OrderHistory.dart';
import 'package:demoproject/dashoard/UploadMenuPage.dart';
import 'package:flutter/material.dart';
import 'OrderList.dart';

class Dashboard extends StatefulWidget {
  final String hotelName;

  const Dashboard({super.key, required this.hotelName});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) {
    bool isDesktop = MediaQuery.of(context).size.width > 800;

    return Scaffold(
      // appBar: AppBar(
      //   title: const Text("Dashboard", style: TextStyle(color: Colors.white)),
      //   backgroundColor: Colors.green,
      // ),

      body: TabBarView(
        controller: _tabController,
        children: [
          Menu(hotelName: widget.hotelName),
          Orderlist(hotelName: widget.hotelName,),
          UploadMenuPage(hotelName: widget.hotelName),
          RoomData(hotelName: widget.hotelName),
          Roomhistory(hotelName: widget.hotelName),
        //  Inventoryscreen(hotelName: widget.hotelName),
         // Recipescreen(hotelName: widget.hotelName),

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
              Tab(icon: Icon(Icons.menu), text: "Menu"),
              Tab(icon: Icon(Icons.point_of_sale), text: "Order List"),
              Tab(icon: Icon(Icons.upload), text: "Upload Menu"),
              Tab(icon: Icon(Icons.family_restroom_outlined), text: "Room Booking"),
              Tab(icon: Icon(Icons.bathroom_outlined), text: "Room History"),
            //  Tab(icon: Icon(Icons.bathroom_outlined), text: "I"),
             // Tab(icon: Icon(Icons.bathroom_outlined), text: "R"),

            ],
          ),
        ),
      ),
    );
  }


}
