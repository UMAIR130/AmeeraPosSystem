import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/order_model.dart';
import 'OrderDetail.dart';

class Orderlist extends StatelessWidget {
  final String hotelName;


  const Orderlist({super.key, required this.hotelName,});

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
        //  final orders = box.values.toList();
          final orders = box.values.where((o) => o.status != "paid").toList();
          if (orders.isEmpty) {
            return const Center(child: Text("No Orders Found"));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: MediaQuery
                  .of(context)
                  .size
                  .width ~/ 260, // responsive
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.25,
            ),
            itemBuilder: (context, index) {
              final order = orders[index];

              Color statusColor;

              // 🔥 Example Status Logic
              if (order.orderType == "Dine-In") {
                statusColor = Colors.orange;
              } else if (order.orderType == "Takeaway") {
                statusColor = Colors.blue;
              } else if (order.orderType == "Delivery") {
                statusColor = Colors.brown;
              } else {
                statusColor = Colors.green;
              }

              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        /// 🔥 ORDER NUMBER TOP BAR
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: statusColor, // dynamic color
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
                                fontSize: 16,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ),

                        /// 🔽 CARD BODY
                        /// 🔽 CARD BODY
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

                              const SizedBox(height: 6),

                              /// Floor + Table + Time
                              if (order.orderType == "Delivery")
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [

                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [

                                        Expanded(
                                          child: Text(
                                            "👤 ${order.customerName ?? ''}",
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),

                                        const SizedBox(width: 10),

                                        Text(
                                          "📞 ${order.customerPhone ?? ''}",
                                          style: const TextStyle(
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 5),

                                    Text(
                                      "${(order.timestamp.hour > 12 ? order.timestamp.hour - 12 : order.timestamp.hour == 0 ? 12 : order.timestamp.hour)}:"
                                          "${order.timestamp.minute.toString().padLeft(2, '0')} "
                                          "${order.timestamp.hour >= 12 ? 'PM' : 'AM'}",
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text("Floor: ${order.floorNumber ?? '-'}"),
                                    Text("Table: ${order.tableNumber ?? '-'}"),
                                    Text(
                                      "${(order.timestamp.hour > 12 ? order.timestamp.hour - 12 : order.timestamp.hour == 0 ? 12 : order.timestamp.hour)}:"
                                          "${order.timestamp.minute.toString().padLeft(2, '0')} "
                                          "${order.timestamp.hour >= 12 ? 'PM' : 'AM'}",
                                    ),
                                  ],
                                ),

                              const SizedBox(height: 8),

                              Row(
                                children: [
                                  Expanded(
                                    child: SizedBox(
                                      height: 36,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: statusColor,
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => OrderDetail(
                                                order: order,
                                                hotelName: hotelName,
                                              ),
                                            ),
                                          );
                                        },
                                        child: const Text(
                                          "View",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 6),

                                  Expanded(
                                    child: SizedBox(
                                      height: 36,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: () async {
                                          bool? confirm = await showDialog(
                                            context: context,
                                            builder: (_) => AlertDialog(
                                              title: const Text("Delete Order"),
                                              content: const Text("Are you sure?"),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context, false),
                                                  child: const Text("Cancel"),
                                                ),
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context, true),
                                                  child: const Text(
                                                    "Delete",
                                                    style: TextStyle(color: Colors.red),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          );

                                          if (confirm == true) {
                                            await order.delete();

                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text("Order deleted"),
                                              ),
                                            );
                                          }
                                        },
                                        child: const Text(
                                          "Delete",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                          ),
                                        ),
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




                ),
              );
            },
          );
        },
      ),
    );
  }
}