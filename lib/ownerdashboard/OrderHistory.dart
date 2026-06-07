import 'dart:io';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/order_model.dart';

class OrderHistory extends StatefulWidget {
  final String hotelName;

  const OrderHistory({super.key, required this.hotelName});

  @override
  State<OrderHistory> createState() => _OrderHistoryState();
}


String formatNumber(double value) {
  if (value % 1 == 0) {
    return value.toInt().toString(); // no .00
  } else {
    return value.toStringAsFixed(2); // keep decimals
  }
}

class _OrderHistoryState extends State<OrderHistory> {
  DateTime? selectedDate;

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Order>('orders_history');

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Order History"),
        centerTitle: true,
        elevation: 0,
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<Order> box, _) {
          List<Order> allPaidOrders =
          box.values.where((o) => o.status == "paid").toList();

          // Filter by selected date
          List<Order> filteredOrders = selectedDate != null
              ? allPaidOrders
              .where((o) =>
          o.timestamp.year == selectedDate!.year &&
              o.timestamp.month == selectedDate!.month &&
              o.timestamp.day == selectedDate!.day)
              .toList()
              : allPaidOrders;

          // --- CALCULATE SUMMARY ---
          double dailySale = 0,
              monthlySale = 0,
              dailyService = 0,
              monthlyService = 0,
              dailyTax = 0,
              monthlyTax = 0;

          DateTime now = DateTime.now();

          for (var o in allPaidOrders) {
            // Daily totals
            if (selectedDate != null) {
              if (o.timestamp.year == selectedDate!.year &&
                  o.timestamp.month == selectedDate!.month &&
                  o.timestamp.day == selectedDate!.day) {
                dailySale += o.grandTotal;
                dailyService += o.service;
                dailyTax += o.tax;
              }
            } else {
              if (o.timestamp.year == now.year &&
                  o.timestamp.month == now.month &&
                  o.timestamp.day == now.day) {
                dailySale += o.grandTotal;
                dailyService += o.service;
                dailyTax += o.tax;
              }
            }

            // Monthly totals
            if (selectedDate != null) {
              if (o.timestamp.year == selectedDate!.year &&
                  o.timestamp.month == selectedDate!.month) {
                monthlySale += o.grandTotal;
                monthlyService += o.service;
                monthlyTax += o.tax;
              }
            } else {
              if (o.timestamp.year == now.year && o.timestamp.month == now.month) {
                monthlySale += o.grandTotal;
                monthlyService += o.service;
                monthlyTax += o.tax;
              }
            }
          }

          return Column(
            children: [
              // ===== TOP SUMMARY =====
              Container(
                padding: const EdgeInsets.all(12),
                color: Colors.white,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // LEFT SIDE - Monthly
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _summaryBox("This Month Sale", monthlySale, color: Colors.blue.shade700),
                        const SizedBox(width: 10), // <-- gap between boxes
                        _summaryBox("This Month Service", monthlyService, color: Colors.orange.shade700),
                        const SizedBox(width: 10), // <-- gap between boxes
                        _summaryBox("This Month Tax", monthlyTax, color: Colors.red.shade700),
                      ],
                    ),
                    // CENTER - Date Picker
                    ElevatedButton.icon(
                      icon: const Icon(Icons.date_range),
                      label: Text(selectedDate != null
                          ? DateFormat('dd-MM-yyyy').format(selectedDate!)
                          : "Select Date"),
                      onPressed: () async {
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null) {
                          setState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                    ),


                    ElevatedButton.icon(
                      icon: Icon(Icons.bar_chart),
                      label: Text("Report"),
                      onPressed: () async {

                        // 🔹 STEP 1: DATE PICKER
                        DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );

                        if (picked == null) return; // cancel

                        // 🔹 STEP 2: FILTER ORDERS
                        final box = Hive.box<Order>('orders_history');

                        List<Order> allPaidOrders =
                        box.values.where((o) => o.status == "paid").toList();

                        List<Order> filteredOrders = allPaidOrders.where((o) =>
                        o.timestamp.year == picked.year &&
                            o.timestamp.month == picked.month &&
                            o.timestamp.day == picked.day).toList();

                        // 🔹 STEP 3: SHOW REPORT
                        _showDailyReport(filteredOrders, selectedDate);                      },
                    ),

                    // RIGHT SIDE - Daily
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _summaryBox("Daily Sale", dailySale, color: Colors.blue),
                        const SizedBox(width: 10), // <-- gap between boxes
                        _summaryBox("Daily Service", dailyService,
                            color: Colors.orange),
                        const SizedBox(width: 10), // <-- gap between boxes
                        _summaryBox("Daily Tax", dailyTax, color: Colors.red),
                      ],
                    ),



                  ],
                ),
              ),
              const SizedBox(height: 10),
              // ===== ORDER GRID =====
              Expanded(
                child: filteredOrders.isEmpty
                    ? const Center(child: Text("No History Found"))
                    : GridView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: filteredOrders.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: MediaQuery.of(context).size.width ~/ 200,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: 0.95,
                  ),
                  itemBuilder: (context, index) {
                    final order = filteredOrders[index];
                    final displayNumber = 1001 + index;
                    return _orderCard(order, displayNumber);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryBox(String title, double value, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 4),
          Text("Rs ${formatNumber(value)}",
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.green)),
        ],
      ),
    );
  }

  Widget _orderCard(Order order, int displayNumber) {
    Color statusColor = Colors.green;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              /// 🔥 TOP BAR
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8), // chhota kiya
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Center(
                  child: Text(
                    "ORDER #$displayNumber",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14, // chhota font
                    ),
                  ),
                ),
              ),

              /// 🔽 BODY
              Padding(
                padding: const EdgeInsets.all(8), // padding kam ki
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    /// Order Type
                    Text(
                      order.orderType,
                      style: const TextStyle(
                        fontSize: 13, // chhota font
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),

                    const SizedBox(height: 6), // chhota spacing

                    /// Floor & Table
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (order.floorNumber != null)
                          Text("Floor: ${order.floorNumber}", style: const TextStyle(fontSize: 11)),
                        if (order.tableNumber != null)
                          Text("Table: ${order.tableNumber}", style: const TextStyle(fontSize: 11)),
                      ],
                    ),

                    const SizedBox(height: 6),

                    /// Payment Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // chhota badge
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        order.paymentMethod ?? "-",
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ),

                    const SizedBox(height: 6),

                    /// Date Time
                    Text(
                      "${order.timestamp.day}-${order.timestamp.month}-${order.timestamp.year} "
                          "${order.timestamp.hour}:${order.timestamp.minute.toString().padLeft(2, '0')}",
                      style: const TextStyle(fontSize: 10, color: Colors.grey),
                    ),

                    const SizedBox(height: 8),

                    /// 🔥 BUTTON
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: statusColor,
                          padding: const EdgeInsets.symmetric(vertical: 8), // chhota button
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () {
                          _showInvoiceDialog(
                            context,
                            order,
                            displayNumber,
                            widget.hotelName,
                          );
                        },
                        child: const Text(
                          "View Invoice",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: 12, // chhota text
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }  Widget _summaryRow(String title, double value,
      {bool bold = false, bool red = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style:
              TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          Text(
            "Rs ${formatNumber(value)}",
            style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                color: red ? Colors.red : Colors.black),
          ),
        ],
      ),
    );
  }
  void _showInvoiceDialog(
      BuildContext context,
      Order order,
      int displayNumber,
      String hotelName,
      ) {
    // Safe percentage calculations
    final servicePercent = order.subTotal > 0 ? (order.service / order.subTotal) * 100 : 0;
    final taxPercent = order.subTotal > 0 ? (order.tax / order.subTotal) * 100 : 0;
    final discountPercent = order.subTotal > 0 ? (order.discount / order.subTotal) * 100 : 0;

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            padding: const EdgeInsets.all(20),
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Hotel Name
                  Center(
                    child: Text(
                      hotelName,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      "INVOICE #$displayNumber",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                  const Divider(height: 30),

                  // Floor & Table
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (order.floorNumber != null) Text("Floor: ${order.floorNumber}"),
                      if (order.tableNumber != null) Text("Table: ${order.tableNumber}"),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Date & Time
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Date: ${order.timestamp.day}-${order.timestamp.month}-${order.timestamp.year}",
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        "Time: ${order.timestamp.hour}:${order.timestamp.minute.toString().padLeft(2, '0')}",
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                  const Divider(height: 30),

                  // Items Table
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text(
                              "Item Name",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 60,
                          child: Text(
                            "Qty",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: Text(
                              "Price",
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(),

                  // Items List
                  ...order.items.map((item) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 4,
                      ),
                      child: Row(
                        children: [

                          // Item Name
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),

                          // Qty
                          SizedBox(
                            width: 60,
                            child: Text(
                              "${item.qty}",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),

                          // Price
                          SizedBox(
                            width: 100,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 4),
                              child: Text(
                                "Rs ${formatNumber(item.price * item.qty)}",
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                  const Divider(height: 30),

                  // Billing Summary
                  _summaryRow("Subtotal", order.subTotal),

                  if (order.service > 0)
                    _summaryRow("Service (${servicePercent.toStringAsFixed(2)}%)", order.service),

                  if (order.tax > 0)
                    _summaryRow("Tax (${taxPercent.toStringAsFixed(2)}%)", order.tax),

                  if (order.discount > 0)
                    _summaryRow("Discount (${discountPercent.toStringAsFixed(2)}%)", order.discount),



                  if (order.receivedAmount != null)
                    _summaryRow(
                      "Received Amount",
                      order.receivedAmount!,
                    ),



                  if (order.paymentMethod != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        "Payment Method: ${order.paymentMethod}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),


                  const SizedBox(height: 6),
                  _summaryRow("Grand Total", order.grandTotal, bold: true),

                  if (order.paymentMethod == "Cash" &&
                      order.returnedAmount != null &&
                      order.returnedAmount! > 0)
                    _summaryRow("Return", order.returnedAmount!, bold: true, red: true),

                  const SizedBox(height: 20),

                  // Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        onPressed: () async {

                          String hotel = hotelName;
                          String address = "";
                          String phone = "";

                          final ref = FirebaseDatabase.instance.ref(
                            "Restaurant/$hotelName/Users",
                          );

                          final snapshot = await ref.get();

                          if (snapshot.exists) {
                            final usersMap =
                            Map<String, dynamic>.from(snapshot.value as Map);

                            for (var user in usersMap.values) {
                              final data = Map<String, dynamic>.from(user);

                              if ((data["HotelName"] ?? "")
                                  .toString()
                                  .isNotEmpty) {
                                hotel = data["HotelName"].toString();
                              }

                              if ((data["address"] ?? "")
                                  .toString()
                                  .isNotEmpty) {
                                address = data["address"].toString();
                              }

                              if ((data["phone"] ?? "")
                                  .toString()
                                  .isNotEmpty) {
                                phone = data["phone"].toString();
                              }
                            }
                          }

                          print("Hotel: $hotel");
                          print("Address: $address");
                          print("Phone: $phone");

                          final cart = order.items.map((e) => {
                            "name": e.name,
                            "qty": e.qty,
                            "price": e.price,
                          }).toList();

                          await printLanRaw(
                            cart,
                            hotel, // Firebase se actual hotel name
                            order.orderType,
                            order.subTotal,
                            order.service,
                            order.tax,
                            order.discount,
                            order.grandTotal,
                            address,
                            phone,
                            order.orderId,
                            order.paymentMethod ?? "",
                            order.receivedAmount ?? 0,
                            order.returnedAmount ?? 0,
                          );
                        },
                        child: const Text("Print"),
                      ),
                      const SizedBox(width: 20),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "Close",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }



  Future<void> printLanRaw(
      List<Map<String, dynamic>> cart,
      String hotelName,
      String selectedOrderType,
      double subTotal,
      double service,
      double tax,
      double discount,
      double grandTotal,
      String address,
      String phone,
      String orderId,
      String paymentMethod,
      double receivedAmount,
      double changeAmount,
      ) async {
    // 🧮 Dynamic percentage calculations
    final servicePercent = subTotal > 0 ? (service / subTotal) * 100 : 0;
    final taxPercent = subTotal > 0 ? (tax / subTotal) * 100 : 0;
    final discountPercent = subTotal > 0 ? (discount / subTotal) * 100 : 0;

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];

    // 🖨️ HEADER
    bytes += generator.text(
      hotelName,
      styles: PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );

    if (address.isNotEmpty)
      bytes += generator.text(address, styles: PosStyles(align: PosAlign.center));

    if (phone.isNotEmpty)
      bytes += generator.text("Ph: $phone", styles: PosStyles(align: PosAlign.center));

    bytes += generator.hr();


    bytes += generator.text(
      "Order No: $orderId",
      styles: PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );


    // 📋 Order Type & Time
    bytes += generator.text("Order Type: $selectedOrderType",
        styles: PosStyles(align: PosAlign.center));

    final now = DateTime.now();
    String hr = now.hour > 12 ? "${now.hour - 12}" : "${now.hour}";
    String period = now.hour >= 12 ? "PM" : "AM";
    String minute = now.minute.toString().padLeft(2, "0");

    bytes += generator.text(
      "${now.day}-${now.month}-${now.year} $hr:$minute $period",
      styles: PosStyles(align: PosAlign.center),
    );

    bytes += generator.hr();

    // 🛒 ITEMS HEADER
    // bytes += generator.row([
    //   PosColumn(text: "#", width: 1, styles: PosStyles(bold: true)),
    //   PosColumn(text: "Item Name", width: 6, styles: PosStyles(bold: true)),
    //   PosColumn(text: "Qty", width: 2, styles: PosStyles(bold: true)),
    //   PosColumn(text: "Price", width: 3, styles: PosStyles(bold: true, align: PosAlign.right)),
    // ]);



    bytes += generator.row([
      PosColumn(
        text: "ITEM",
        width: 7,
        styles: PosStyles(
          bold: true,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: "QTY",
        width: 2,
        styles: PosStyles(
          bold: true,
          align: PosAlign.center,
        ),
      ),
      PosColumn(
        text: "PRICE",
        width: 3,
        styles: PosStyles(
          bold: true,
          align: PosAlign.right,
        ),
      ),
    ]);


    bytes += generator.hr();

    // 🧾 ITEMS
    for (var item in cart) {
      bytes += generator.row([
        PosColumn(
          text: item["name"].toString(),
          width: 7,
          styles: PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: "${item["qty"]}",
          width: 2,
          styles: PosStyles(align: PosAlign.center),
        ),
        PosColumn(
          text: "${(item["price"] * item["qty"]).toInt()}",
          width: 3,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr();

    // 💰 BILL SUMMARY
    // Subtotal
    bytes += generator.row([
      PosColumn(text: "Subtotal", width: 6),
      PosColumn(
          text: "Rs ${formatNumber(subTotal)}",
          width: 6,
          styles: PosStyles(align: PosAlign.right)),
    ]);

    // Service (dynamic %)
    if (service > 0) {
      bytes += generator.row([
        PosColumn(
            text: "Service (${servicePercent.toStringAsFixed(2)}%)", width: 6),
        PosColumn(
            text: "Rs ${formatNumber(service)}",
            width: 6,
            styles: PosStyles(align: PosAlign.right)),
      ]);
    }

    // Tax (dynamic %)
    if (tax > 0) {
      bytes += generator.row([
        PosColumn(text: "Tax (${taxPercent.toStringAsFixed(2)}%)", width: 6),
        PosColumn(
            text: "Rs ${formatNumber(tax)}",
            width: 6,
            styles: PosStyles(align: PosAlign.right)),
      ]);
    }

    // Discount (dynamic %)
    if (discount > 0) {
      bytes += generator.row([
        PosColumn(
            text: "Discount (${discountPercent.toStringAsFixed(2)}%)", width: 6),
        PosColumn(
            text: "- Rs ${formatNumber(discount)}",
            width: 6,
            styles: PosStyles(align: PosAlign.right)),
      ]);
    }



    bytes += generator.hr();

    bytes += generator.row([
      PosColumn(text: "Payment", width: 6),
      PosColumn(
        text: paymentMethod,
        width: 6,
        styles: PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += generator.row([
      PosColumn(text: "Received", width: 6),
      PosColumn(
        text: "Rs ${formatNumber(receivedAmount)}",
        width: 6,
        styles: PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += generator.row([
      PosColumn(text: "Change", width: 6),
      PosColumn(
        text: "Rs ${formatNumber(changeAmount)}",
        width: 6,
        styles: PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += generator.hr();


    // 🏁 FINAL TOTAL
    bytes += generator.text(
      "Grand Total: Rs ${formatNumber(grandTotal)}",
      styles: PosStyles(
        bold: true,
        align: PosAlign.center,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );
    bytes += generator.feed(1);


    bytes += generator.text(
      "Software Developed By",
      styles: PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );

    bytes += generator.text(
      "Umair Imtiaz",
      styles: PosStyles(
        align: PosAlign.center,
      ),
    );

    bytes += generator.text(
      "0348-9031338",
      styles: PosStyles(
        align: PosAlign.center,
      ),
    );

    bytes += generator.feed(2);
    bytes += generator.cut();

    // 📡 SEND TO PRINTER
    try {
      // Socket socket = await Socket.connect('192.168.0.142', 9100,
      //     timeout: const Duration(seconds: 10));

      String ip = await getPrinterIp();

      Socket socket = await Socket.connect(ip, 9100, timeout: Duration(seconds: 10));
      socket.add(bytes);
      await socket.flush();
      socket.destroy();
      print("✅ Printed successfully via LAN TCP!");
    } catch (e) {
      print("❌ TCP Print failed: $e");
    }
  }


  void _showDailyReport(List<Order> orders, DateTime? selectedDate) async {
    Map<String, int> itemQty = {};
    Map<String, double> itemTotal = {};

    double grandTotal = 0;

    // 🔥 Calculate report
    for (var order in orders) {
      grandTotal += order.grandTotal;

      for (var item in order.items) {
        itemQty[item.name] = (itemQty[item.name] ?? 0) + item.qty;
        itemTotal[item.name] =
            (itemTotal[item.name] ?? 0) + (item.price * item.qty);
      }
    }

    // 🔥 HOTEL INFO
    String address = "";
    String phone = "";
    String hotel = widget.hotelName;

    final ref = FirebaseDatabase.instance
        .ref("Restaurant/${widget.hotelName}/Users");

    final snapshot = await ref.get();

    if (snapshot.exists) {
      final usersMap = Map<String, dynamic>.from(snapshot.value as Map);
      final firstUser = usersMap.values.first;
      final data = Map<String, dynamic>.from(firstUser);

      hotel = data["HotelName"] ?? widget.hotelName;
      address = data["address"] ?? "";
      phone = data["phone"] ?? "";
    }

    // ✅ FIXED DATE (IMPORTANT)
    final reportDate = selectedDate ?? DateTime.now();

    String dateTime =
        "${reportDate.day}-${reportDate.month}-${reportDate.year} "
        "${reportDate.hour.toString().padLeft(2, '0')}:"
        "${reportDate.minute.toString().padLeft(2, '0')}";

    // 🔥 DIALOG
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child:

          Container(
            padding: const EdgeInsets.all(20),
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // 🔥 HOTEL NAME
                Text(
                  hotel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),

                if (address.isNotEmpty)
                  Text(address,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12)),

                if (phone.isNotEmpty)
                  Text("Ph: $phone",
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12)),

                const SizedBox(height: 5),

                // ✅ FIXED DATE (NO BUG NOW)
                Text(
                  dateTime,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),

                const Divider(),

                const Text(
                  "Daily Sale Report",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                const Divider(),

                // 🔹 HEADER
                // 🔹 HEADER
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  color: Colors.grey.shade200,
                  child: Row(
                    children: const [
                      Expanded(
                        flex: 7,
                        child: Text(
                          "Item",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(
                        width: 50,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            "Qty",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      SizedBox(width: 20),
                      SizedBox(
                        width: 90,
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            "Price",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

// 🔹 ITEMS
                SizedBox(
                  height: 300,
                  child: ListView.separated(
                    itemCount: itemQty.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final name = itemQty.keys.elementAt(index);

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 4,
                        ),
                        child: Row(
                          children: [

                            // Item Name
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),

                            // Qty
                            SizedBox(
                              width: 50,
                              child: Text(
                                "${itemQty[name]}",
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                            // Price
                            SizedBox(
                              width: 90,
                              child: Text(
                                "Rs ${formatNumber(itemTotal[name] ?? 0)}",
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),

                const Divider(),

                // 🔹 ITEMS


                const Divider(),

                // 🔥 TOTAL
                Text(
                  "TOTAL: Rs ${formatNumber(grandTotal)}",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 15),

                // 🔥 BUTTONS
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.print),
                      label: const Text("Print"),
                      onPressed: () {
                        if (selectedDate == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Please select a date first"),
                            ),
                          );
                          return;
                        }

                        _printDailyReport(
                          itemQty,
                          itemTotal,
                          grandTotal,
                          selectedDate!,
                        );
                      },
                    ),
                    const SizedBox(width: 15),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("Close",
                          style: TextStyle(color: Colors.white)),
                    ),
                  ],
                )
              ],
            ),
          ),
        );
      },
    );
  }

  List<Order> getFilteredOrders(
      List<Order> allOrders,
      DateTime? selectedDate,
      String type, // "daily" "weekly" "monthly"
      ) {
    DateTime now = selectedDate ?? DateTime.now();

    if (type == "daily") {
      return allOrders.where((o) =>
      o.timestamp.year == now.year &&
          o.timestamp.month == now.month &&
          o.timestamp.day == now.day).toList();
    }

    if (type == "weekly") {
      DateTime startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));

      return allOrders.where((o) =>
      o.timestamp.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
          o.timestamp.isBefore(endOfWeek.add(const Duration(days: 1))))
          .toList();
    }

    if (type == "monthly") {
      return allOrders.where((o) =>
      o.timestamp.year == now.year &&
          o.timestamp.month == now.month).toList();
    }

    return allOrders;
  }

  Future<void> _printDailyReport(
      Map<String, int> qty,
      Map<String, double> total,
      double grandTotal,
      DateTime reportDate,
      ) async {


    final info = await getHotelInfo();

    String hotelName = info["hotel"]!;
    String address = info["address"]!;
    String phone = info["phone"]!;

    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);
    List<int> bytes = [];
    // 🏨 HOTEL HEADER
    bytes += generator.text(
      hotelName,
      styles: PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );

    if (address.isNotEmpty) {
      bytes += generator.text(
        address,
        styles: PosStyles(align: PosAlign.center),
      );
    }

    if (phone.isNotEmpty) {
      bytes += generator.text(
        "Ph: $phone",
        styles: PosStyles(align: PosAlign.center),
      );
    }

    bytes += generator.hr();



    final now = reportDate;

    int hour = now.hour;
    String period = hour >= 12 ? "PM" : "AM";
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;

    String minute = now.minute.toString().padLeft(2, '0');

    bytes += generator.text(
      "${now.day}-${now.month}-${now.year} $hour:$minute $period",
      styles: PosStyles(align: PosAlign.center),
    );

    bytes += generator.hr();




    bytes += generator.text("DAILY SALE REPORT",
        styles: PosStyles(
            align: PosAlign.center,
            bold: true,
            height: PosTextSize.size2));

    bytes += generator.hr();

    // Header
    bytes += generator.row([
      PosColumn(
        text: "ITEM",
        width: 7,
        styles: PosStyles(
          bold: true,
          align: PosAlign.left,
        ),
      ),
      PosColumn(
        text: "QTY",
        width: 2,
        styles: PosStyles(
          bold: true,
          align: PosAlign.center,
        ),
      ),
      PosColumn(
        text: "PRICE",
        width: 3,
        styles: PosStyles(
          bold: true,
          align: PosAlign.right,
        ),
      ),
    ]);


    bytes += generator.hr();

    // Items
    qty.keys.forEach((name) {
      bytes += generator.row([
        PosColumn(
          text: name,
          width: 7,
          styles: PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: "${qty[name]}",
          width: 2,
          styles: PosStyles(align: PosAlign.center),
        ),
        PosColumn(
          text: "${formatNumber(total[name] ?? 0)}",
          width: 3,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
    });

    bytes += generator.hr();

    bytes += generator.text(
      "TOTAL: Rs ${formatNumber(grandTotal)}",
      styles: PosStyles(
          bold: true,
          align: PosAlign.center,
          height: PosTextSize.size2),
    );




    bytes += generator.hr();




    bytes += generator.feed(2);
    bytes += generator.cut();

    try {
    //  Socket socket = await Socket.connect('192.168.0.142', 9100);
      String ip = await getPrinterIp();

      Socket socket = await Socket.connect(ip, 9100, timeout: Duration(seconds: 10));

      socket.add(bytes);
      await socket.flush();
      socket.destroy();
    } catch (e) {
      print("Print Error: $e");
    }
  }





  Future<String> getPrinterIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("printer_ip") ?? "192.168.0.142";
  }

  Future<Map<String, String>> getHotelInfo() async {
    String address = "";
    String phone = "";
    String hotel = widget.hotelName;

    final ref =
    FirebaseDatabase.instance.ref("Restaurant/$hotel/Users");
    final snapshot = await ref.get();

    if (snapshot.exists) {
      final usersMap =
      Map<String, dynamic>.from(snapshot.value as Map);
      final firstUser = usersMap.values.first;
      final data = Map<String, dynamic>.from(firstUser);

      hotel = data["HotelName"] ?? hotel;
      address = data["address"] ?? "";
      phone = data["phone"] ?? "";
    }

    return {
      "hotel": hotel,
      "address": address,
      "phone": phone,
    };
  }
}