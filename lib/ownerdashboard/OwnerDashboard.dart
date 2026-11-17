import 'package:demoproject/inventory/InventoryScreen.dart';
import 'package:demoproject/inventory/RecipeScreen.dart';
import 'package:demoproject/ownerdashboard/AddStaff.dart';
import 'package:demoproject/ownerdashboard/OwnerSale.dart';
import 'package:flutter/material.dart';

import 'OrderHistory.dart';

class Ownerdashboard extends StatefulWidget {
  final String hotelName;

  const Ownerdashboard({
    super.key,
    required this.hotelName,
  });

  @override
  State<Ownerdashboard> createState() => _OwnerdashboardState();
}

class _OwnerdashboardState extends State<Ownerdashboard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool get isMobile =>
      MediaQuery.of(context).size.width < 700;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _tabController = TabController(
      length: isMobile ? 1 : 5,
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Widget> get pages {
    if (isMobile) {
      return [
        OwnerSale(hotelName: widget.hotelName),
    //    AddStaff(hotelName: widget.hotelName),
      ];
    }

    return [
    //  OwnerSale(hotelName: widget.hotelName),
      OrderHistory(hotelName: widget.hotelName),
      AddStaff(hotelName: widget.hotelName),
      Inventoryscreen(hotelName: widget.hotelName),
      Recipescreen(hotelName: widget.hotelName),
    ];
  }

  List<Tab> get tabs {
    if (isMobile) {
      return const [
        Tab(
          icon: Icon(Icons.attach_money),
          text: "Sale",
        ),
        // Tab(
        //   icon: Icon(Icons.history),
        //   text: "Add Staff",
        // ),
      ];
    }

    return const [
      // Tab(
      //   icon: Icon(Icons.attach_money),
      //   text: "Sale",
      // ),
      Tab(
        icon: Icon(Icons.history),
        text: "History",
      ),
      Tab(
        icon: Icon(Icons.people),
        text: "Staff",
      ),
      Tab(
        icon: Icon(Icons.inventory_2),
        text: "Inventory",
      ),
      Tab(
        icon: Icon(Icons.restaurant_menu),
        text: "Recipe",
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: TabBarView(
        controller: _tabController,
        children: pages,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Material(
          color: Colors.green,
          child: TabBar(
            controller: _tabController,
            tabs: tabs,
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
          ),
        ),
      ),
    );
  }
}