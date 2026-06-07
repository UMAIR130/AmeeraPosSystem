import 'dart:io';

import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/RoomHistory.dart';

class Roomhistory extends StatefulWidget {
  final String hotelName;

  const Roomhistory({super.key, required this.hotelName});

  @override
  State<Roomhistory> createState() => _RoomhistoryState();
}

class _RoomhistoryState extends State<Roomhistory> {
  late Box<RoomHistory> historyBox;

  List<RoomHistory> allHistory = [];
  List<RoomHistory> filteredHistory = [];

  final TextEditingController searchController = TextEditingController();

  DateTime? selectedDate;

  Map<String, dynamic>? hotelInfo;


  @override
  void initState() {
    super.initState();
    historyBox = Hive.box<RoomHistory>('roomHistory');

    selectedDate = DateTime.now();

    loadData();
    loadHotelInfo(); // 🔥 IMPORTANT

  }

  void loadData() {
    allHistory = historyBox.values.toList().reversed.toList();
    //filteredHistory = allHistory;
    applyFilters();

    setState(() {});
  }

  Future<void> loadHotelInfo() async {
    final ref = FirebaseDatabase.instance.ref(
      "Restaurant/${widget.hotelName}/Users",
    );

    final snapshot = await ref.get();

    if (snapshot.exists) {
      final data = snapshot.value as Map;

      for (var entry in data.entries) {
        final user = Map<String, dynamic>.from(entry.value);

        // 🔥 prefer owner OR address wali entry
        if (user.containsKey('address') || user['role'] == 'owner') {
          hotelInfo = user;
          break;
        }
      }
    }

    setState(() {});
  }

  // ================= PHONE SEARCH =================


  void searchByPhone(String value) {
    applyFilters(search: value);
  }
  // ================= DATE FILTER =================
  void filterByDate(DateTime date) {
    setState(() {
      selectedDate = date;
    });
    applyFilters();
  }

  // ================= COMBINED FILTER =================
  void applyFilters({String search = ""}) {

    filteredHistory = allHistory.where((e) {

      // 🔥 PHONE MATCH
      bool phoneMatch = (e.phone ?? "")
          .toLowerCase()
          .contains(search.toLowerCase());

      // 🔥 CNIC MATCH
      bool cnicMatch = (e.cnic ?? "")
          .toLowerCase()
          .contains(search.toLowerCase());

      // 🔥 BOTH SEARCH
      bool searchMatch = phoneMatch || cnicMatch;

      // 🔥 DATE MATCH
      bool dateMatch = true;

      if (selectedDate != null && e.checkIn != null) {

        DateTime dt =
            DateTime.tryParse(e.checkIn!) ?? DateTime.now();

        dateMatch =
            dt.year == selectedDate!.year &&
                dt.month == selectedDate!.month &&
                dt.day == selectedDate!.day;
      }

      return searchMatch && dateMatch;

    }).toList();

    setState(() {});
  }
  // ================= FORMAT FIX =================
  String formatDateTime(String? value) {
    if (value == null || value.isEmpty) return "-";

    try {
      DateTime dt = DateTime.parse(value).toLocal();

      int hour = dt.hour;
      String ampm = "AM";

      if (hour >= 12) {
        ampm = "PM";
        if (hour > 12) hour = hour - 12;
      }
      if (hour == 0) hour = 12;

      return "${dt.day.toString().padLeft(2, '0')}-"
          "${dt.month.toString().padLeft(2, '0')}-"
          "${dt.year}  "
          "${hour.toString().padLeft(2, '0')}:"
          "${dt.minute.toString().padLeft(2, '0')} $ampm";
    } catch (e) {
      return value;
    }
  }
  // ================= DATE PICKER =================
  Future<void> pickDate() async {
    DateTime? date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (date != null) {
      filterByDate(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Room History"),
        backgroundColor: Colors.green,
      ),

      body: Column(
        children: [

          // ================= TOP CONTROLS =================
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [

                // SEARCH
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: searchController,
                      keyboardType: TextInputType.phone,
                      onChanged: searchByPhone,
                      decoration: InputDecoration(
                        hintText: "Search phone...",
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                        prefixIcon: const Icon(Icons.search, size: 18),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // DATE
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    onPressed: pickDate,
                    icon: const Icon(Icons.date_range, size: 18),
                    label: const Text("Date"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ================= LIST =================
          Expanded(
            child: filteredHistory.isEmpty
                ? const Center(child: Text("No History Found"))
                : GridView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: filteredHistory.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 8, // ⭐ 8 items per row
                crossAxisSpacing: 6,
                mainAxisSpacing: 6,
                childAspectRatio: 0.75, // small compact cards
              ),

                itemBuilder: (context, index) {
                  final item = filteredHistory[index];

                  bool isHighlighted = false;

                  String search = searchController.text.toLowerCase();

                  if (search.isNotEmpty) {

                    if ((item.phone ?? "")
                        .toLowerCase()
                        .contains(search)) {
                      isHighlighted = true;
                    }

                    if ((item.cnic ?? "")
                        .toLowerCase()
                        .contains(search)) {
                      isHighlighted = true;
                    }
                  }




                  return Container(
                    decoration: BoxDecoration(
                      color: isHighlighted
                          ? Colors.orange.shade200
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 3,
                          spreadRadius: 1,
                        )
                      ],
                    ),

                    padding: const EdgeInsets.all(6),

                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [

                        // 🏠 ROOM NUMBER (BIG TEXT ONLY)
                        Container(
                          width: double.infinity,
                          height: 155,
                          decoration: BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              item.roomName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 50, // ⭐ BIG SIZE
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        // 👇 BIG VIEW BUTTON
                        SizedBox(
                          width: double.infinity,
                          height: 35,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onPressed: () {
                              _showHistoryDialog(item);
                            },
                            child: const Text(
                              "View Details",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
            ),
          ),
        ],
      ),
    );
  }

  void _showHistoryDialog(item) {
    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            width: 450,
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // 🔥 HEADER
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "Room ${item.roomName}",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // CUSTOMER
                  const Text("👤 Customer Information",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

                  const SizedBox(height: 10),

                  _row("Name", item.customerName),
                  _row("Phone", item.phone),
                  _row("CNIC", item.cnic),
                  _row("Car Number", item.carNumber),
                  _row("Address", item.address),

                  const Divider(),

                  // PAYMENT
                  const Text("💰 Payment Details",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

                  const SizedBox(height: 10),

                  _row("Rent", item.rent.toString()),
                  _row("Advance", item.advance.toString()),
                  _row("Remaining", item.remaining.toString()),

                  const Divider(),

                  // TIME
                  const Text("⏰ Stay Details",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),

                  const SizedBox(height: 10),

                  _row("Check In", formatDateTime(item.checkIn)),
                  _row("Check Out", formatDateTime(item.checkOut)),

                  const SizedBox(height: 20),

                  // 🔥 BUTTONS (UPDATED)
                  Row(
                    children: [

                      // PRINT BUTTON
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.print),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                          onPressed: () async {
                            await printHistoryBill(item);
                          },
                          label: const Text("Print",
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),

                      const SizedBox(width: 10),

                      // CLOSE
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text("Close"),
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

  Widget _row(String title, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              "$title:",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value ?? "-"),
          ),
        ],
      ),
    );
  }




  Future<void> printHistoryBill(item) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    List<int> bytes = [];

    // ================= FORMAT FUNCTION =================
    String format(DateTime? dt) {
      if (dt == null) return "-";

      int hour = dt.hour;
      String period = "AM";

      if (hour >= 12) {
        period = "PM";
        if (hour > 12) hour -= 12;
      }

      if (hour == 0) hour = 12;

      return "${dt.day.toString().padLeft(2, '0')}-"
          "${dt.month.toString().padLeft(2, '0')}-"
          "${dt.year} "
          "${hour.toString().padLeft(2, '0')}:"
          "${dt.minute.toString().padLeft(2, '0')} $period";
    }

    DateTime? checkIn = DateTime.tryParse(item.checkIn ?? "")?.toLocal();
    DateTime? checkOut = DateTime.tryParse(item.checkOut ?? "")?.toLocal();

    // ================= HEADER =================
    bytes += generator.text(
      hotelInfo?['HotelName'] ?? 'HOTEL',
      styles: PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );

    bytes += generator.text(
      hotelInfo?['address'] ?? '',
      styles: PosStyles(align: PosAlign.center),
    );

    bytes += generator.text(
      "Phone: ${hotelInfo?['phone'] ?? ''}",
      styles: PosStyles(align: PosAlign.center),
    );

    bytes += generator.hr();

    // TITLE
    bytes += generator.text(
      "ROOM HISTORY BILL",
      styles: PosStyles(align: PosAlign.center, bold: true),
    );

    bytes += generator.hr();

    // ROOM INFO
    bytes += generator.row([
      PosColumn(text: "Room:", width: 4, styles: PosStyles(bold: true)),
      PosColumn(text: item.roomName, width: 8),
    ]);

    bytes += generator.row([
      PosColumn(text: "Name:", width: 4, styles: PosStyles(bold: true)),
      PosColumn(text: item.customerName ?? '', width: 8),
    ]);

    bytes += generator.row([
      PosColumn(text: "Phone:", width: 4, styles: PosStyles(bold: true)),
      PosColumn(text: item.phone ?? '', width: 8),
    ]);

    bytes += generator.row([
      PosColumn(text: "CNIC:", width: 4, styles: PosStyles(bold: true)),
      PosColumn(text: item.cnic ?? '', width: 8),
    ]);

    bytes += generator.row([
      PosColumn(text: "Car:", width: 4, styles: PosStyles(bold: true)),
      PosColumn(text: item.carNumber ?? '', width: 8),
    ]);

    bytes += generator.row([
      PosColumn(text: "Address:", width: 4, styles: PosStyles(bold: true)),
      PosColumn(text: item.address ?? '', width: 8),
    ]);

    bytes += generator.hr();

    // TIME
    bytes += generator.row([
      PosColumn(text: "Check In:", width: 4, styles: PosStyles(bold: true)),
      PosColumn(text: format(checkIn), width: 8),
    ]);

    bytes += generator.row([
      PosColumn(text: "Check Out:", width: 4, styles: PosStyles(bold: true)),
      PosColumn(text: format(checkOut), width: 8),
    ]);

    bytes += generator.hr();

    // BILL
    bytes += generator.row([
      PosColumn(text: "Rent", width: 6),
      PosColumn(
          text: "Rs ${item.rent}",
          width: 6,
          styles: PosStyles(align: PosAlign.right)),
    ]);

    bytes += generator.row([
      PosColumn(text: "Advance", width: 6),
      PosColumn(
          text: "Rs ${item.advance}",
          width: 6,
          styles: PosStyles(align: PosAlign.right)),
    ]);

    bytes += generator.row([
      PosColumn(text: "Remaining", width: 6, styles: PosStyles(bold: true)),
      PosColumn(
          text: "Rs ${item.remaining}",
          width: 6,
          styles: PosStyles(align: PosAlign.right, bold: true)),
    ]);

    bytes += generator.hr();

    bytes += generator.text(
      "TOTAL: Rs ${item.rent}",
      styles: PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
      ),
    );

    bytes += generator.feed(1);
    bytes += generator.hr(ch: '=');

    bytes += generator.text(
      "Thank You",
      styles: PosStyles(align: PosAlign.center),
    );

    bytes += generator.feed(2);
    bytes += generator.cut();

    // PRINT
    try {
      String ip = await getPrinterIp();

      Socket socket = await Socket.connect(
        ip,
        9100,
        timeout: const Duration(seconds: 10),
      );

      socket.add(bytes);
      await socket.flush();
      socket.destroy();

      print("✅ History Printed");
    } catch (e) {
      print("❌ Print Error: $e");
    }
  }



  Future<String> getPrinterIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("printer_ip") ?? "192.168.0.142";
  }
}