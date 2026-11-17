import 'package:demoproject/dashoard/ExpenseSheet.dart';
import 'package:demoproject/dashoard/Menu.dart';
import 'package:demoproject/dashoard/RoomData.dart';
import 'package:demoproject/dashoard/RoomHistory.dart';
import 'package:demoproject/inventory/InventoryScreen.dart';
import 'package:demoproject/inventory/RecipeScreen.dart';
import 'package:demoproject/ownerdashboard/OrderHistory.dart';
import 'package:demoproject/dashoard/UploadMenuPage.dart';
import 'package:flutter/material.dart';
import '../service/sync_service.dart';
import 'OrderDetail.dart';
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
    _tabController = TabController(length: 8, vsync: this);


  }

















  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
          Expensesheet(hotelName: widget.hotelName),
          Inventoryscreen(hotelName: widget.hotelName),
          Recipescreen(hotelName: widget.hotelName),
       //   OrderHistory(hotelName: widget.hotelName),
       //   Tokencategories(hotelName: widget.hotelName),

        ],
      ),

      // ✅ Tabs always at bottom (Desktop + Mobile)
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white70,

            // 🔥 RED BORDER ADDED
            border: Border.all(
              color: Colors.black12,
              width: 1,
            ),
          ),

          child: Theme(
            data: Theme.of(context).copyWith(
              splashColor: Colors.red.withOpacity(0.2),
              highlightColor: Colors.red.withOpacity(0.1),
            ),

            child: TabBar(
              controller: _tabController,

              indicatorColor: Colors.deepOrange,
              indicatorWeight: 3,

              labelColor: Colors.black,
              unselectedLabelColor: Colors.black,

              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),

              unselectedLabelStyle: const TextStyle(
                fontSize: 11,
              ),

              overlayColor: MaterialStateProperty.resolveWith<Color?>(
                    (states) {
                  if (states.contains(MaterialState.hovered)) {
                    return Colors.green.withOpacity(0.15);
                  }
                  if (states.contains(MaterialState.pressed)) {
                    return Colors.green.withOpacity(0.25);
                  }
                  return null;
                },
              ),

              tabs: const [
                Tab(icon: Icon(Icons.restaurant_menu, size: 40,color: Colors.deepOrange,), text: "Menu"),
                Tab(icon: Icon(Icons.receipt_long, size: 40,color:Colors.deepOrange), text: "Orders List"),
                Tab(icon: Icon(Icons.cloud_upload, size: 40,color:Colors.deepOrange), text: "Upload Menu"),
                Tab(icon: Icon(Icons.hotel, size: 40,color:Colors.deepOrange), text: "Room Data"),
                Tab(icon: Icon(Icons.history, size: 40,color:Colors.deepOrange), text: "Room History"),
                Tab(icon: Icon(Icons.payments, size: 40,color:Colors.deepOrange), text: "Expense"),
                Tab(icon: Icon(Icons.inventory, size: 40,color:Colors.deepOrange), text: "Inventory"),
                Tab(icon: Icon(Icons.payments, size: 40,color:Colors.deepOrange), text: "Recipe"),
         //       Tab(icon: Icon(Icons.payments, size: 40,color:Colors.deepOrange), text: "Order History"),
              ],
            ),
          ),
        ),      ),


    );
  }


}
