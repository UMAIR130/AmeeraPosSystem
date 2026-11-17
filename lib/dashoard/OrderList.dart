import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/order_model.dart';
import 'OrderDetail.dart';

class Orderlist extends StatefulWidget {
  final String hotelName;

  const Orderlist({super.key, required this.hotelName});

  @override
  State<Orderlist> createState() => _OrderlistState();
}

class _OrderlistState extends State<Orderlist> {
  Timer? timer;

  @override
  void initState() {
    super.initState();

    timer = Timer.periodic(const Duration(seconds: 30), (_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  String timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time);

    if (diff.inSeconds < 60) {
      return "Just now";
    } else if (diff.inMinutes < 60) {
      return "${diff.inMinutes} min ago";
    } else if (diff.inHours < 24) {
      return "${diff.inHours} hour ago";
    } else {
      return "${diff.inDays} day ago";
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Order>('orders');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Orders"),
        centerTitle: true,
      ),

      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<Order> box, _) {

          final orders = box.values.where((o) => o.status != "paid").toList();

          if (orders.isEmpty) {
            return const Center(child: Text("No Orders Found"));
          }

          // 🔥 RESPONSIVE GRID FIX
          int crossAxisCount =
          (MediaQuery.of(context).size.width / 320).floor();

          if (crossAxisCount < 1) crossAxisCount = 1;

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.7, // 🔥 FIXED (was 1.8)
            ),

            itemBuilder: (context, index) {
              final order = orders[index];

              Color statusColor;

              if (order.orderType == "Dine-In") {
                statusColor = Colors.orange;
              } else if (order.orderType == "Takeaway") {
                statusColor = Colors.blue;
              } else if (order.orderType == "Delivery") {
                statusColor = Colors.brown;
              } else {
                statusColor = Colors.green;
              }

              return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OrderDetail(
                          order: order,
                          hotelName: widget.hotelName,
                        ),
                      ),
                    );
                  },
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),

                // 🔥 SAFE SCROLL INSIDE CARD
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      /// TOP BAR
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(18),
                            topRight: Radius.circular(18),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            "ORDER #${order.orderId}",
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            Text(
                              order.orderType,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            const SizedBox(height: 8),

                            /// DELIVERY UI
                            if (order.orderType == "Delivery")
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [

                                  // 👤 + 📞 SAME ROW
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text("👤 ${order.customerName ?? ''}"),
                                      ),
                                      Expanded(
                                        child: Text(
                                          "📞 ${order.customerPhone ?? ''}",
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 6),

                                  // ⏰ TIME (CENTER)
                                  Center(
                                    child: Text(
                                      timeAgo(order.timestamp),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                ],
                              )

                            /// OTHER ORDERS
                            else
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text("Floor: ${order.floorNumber ?? '-'}"),
                                  Text("Table: ${order.tableNumber ?? '-'}"),
                                  Text(
                                    timeAgo(order.timestamp),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                ],
                              ),

                            const SizedBox(height: 10),

                            /// BUTTONS
                            Row(
                              children: [


                                const SizedBox(width: 8),

                                Expanded(
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                    ),
                                    onPressed: () async {
                                      bool? confirm = await showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (context) {
                                          return AlertDialog(
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            title: const Text("Delete Order"),
                                            content: const Text(
                                              "Are you sure you want to delete this order?",
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(context, false);
                                                },
                                                child: const Text("Cancel"),
                                              ),
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                ),
                                                onPressed: () {
                                                  Navigator.pop(context, true);
                                                },
                                                child: const Text(
                                                  "Delete",
                                                  style: TextStyle(color: Colors.white),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );

                                      if (confirm == true) {
                                        await order.delete();

                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text("Order deleted successfully"),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                    child: const Text(
                                      "Delete",
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ));
            },
          );
        },
      ),
    );
  }}