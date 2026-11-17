import 'dart:io';

import 'package:demoproject/models/RoomHistory.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/RoomBooking.dart';

class RoomData extends StatefulWidget {
  final String hotelName;

  const RoomData({super.key, required this.hotelName});

  @override
  State<RoomData> createState() => _RoomDataState();
}

class _RoomDataState extends State<RoomData> {
  late Box<RoomBooking> roomBox;
  Map<String, dynamic>? hotelInfo;
  late Box<RoomHistory> historyBox;

  @override
  void initState() {
    super.initState();
    roomBox = Hive.box<RoomBooking>('roomsBox');
    historyBox = Hive.box<RoomHistory>('roomHistory'); // ✅ ADD THIS

    loadHotelInfo();
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

  // 🔥 ADD ROOM
  void _addRoomDialog() {
    final roomController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Room"),
        content: TextField(
          controller: roomController,
          decoration: const InputDecoration(
            labelText: "Room Number",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              if (roomController.text.trim().isEmpty) return;

              final room = RoomBooking(
                roomName: roomController.text.trim(),
                status: "available",
              );

              roomBox.add(room);
              setState(() {});
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  // 🔥 DELETE ROOM
  void _deleteRoom(int index) {
    roomBox.deleteAt(index);
    setState(() {});
  }

  // 🔥 CUSTOMER FORM
  void _openCustomerForm(RoomBooking room) {
    final name = TextEditingController();
    final phone = TextEditingController();
    final cnic = TextEditingController();
    final address = TextEditingController();
    final carNumber = TextEditingController();
    final advance = TextEditingController();
    final rent = TextEditingController();

    DateTime? checkInDate;
    DateTime? checkOutDate;

    int totalDays = 1;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setStateDialog) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(18),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔥 HEADER
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Colors.green, Colors.teal],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      "Room ${room.roomName} Booking",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ================= CUSTOMER =================
                  const Text(
                    "👤 Customer Details",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(child: _input(name, "Name", Icons.person)),
                      const SizedBox(width: 10),
                      Expanded(child: _input(phone, "Phone", Icons.phone)),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(child: _input(cnic, "CNIC", Icons.badge)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _input(
                          carNumber,
                          "Car No",
                          Icons.directions_car,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  _input(address, "Address", Icons.home),

                  const SizedBox(height: 18),

                  // ================= STAY =================
                  const Text(
                    "📅 Stay Details",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today),

                          label: Text(
                            checkInDate == null
                                ? "Check In"
                                : "${checkInDate!.day}/${checkInDate!.month}/${checkInDate!.year}",
                          ),

                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,

                              initialDate: DateTime.now(),

                              firstDate: DateTime.now(),

                              lastDate: DateTime(2035),
                            );

                            if (picked != null) {
                              setStateDialog(() {
                                checkInDate = picked;

                                if (checkOutDate != null) {
                                  totalDays = checkOutDate!
                                      .difference(checkInDate!)
                                      .inDays;

                                  if (totalDays <= 0) {
                                    totalDays = 1;
                                  }
                                }
                              });
                            }
                          },
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.event),

                          label: Text(
                            checkOutDate == null
                                ? "Check Out"
                                : "${checkOutDate!.day}/${checkOutDate!.month}/${checkOutDate!.year}",
                          ),

                          onPressed: () async {
                            if (checkInDate == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Please select Check In first"),
                                ),
                              );

                              return;
                            }

                            final picked = await showDatePicker(
                              context: context,

                              initialDate: checkInDate!,

                              firstDate: checkInDate!,

                              lastDate: DateTime(2035),
                            );

                            if (picked != null) {
                              setStateDialog(() {
                                checkOutDate = picked;

                                totalDays = checkOutDate!
                                    .difference(checkInDate!)
                                    .inDays;

                                if (totalDays <= 0) {
                                  totalDays = 1;
                                }
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  Container(
                    width: double.infinity,

                    padding: const EdgeInsets.all(12),

                    decoration: BoxDecoration(
                      color: Colors.green.shade50,

                      borderRadius: BorderRadius.circular(10),
                    ),

                    child: Text(
                      "Stay : $totalDays Day(s)",

                      textAlign: TextAlign.center,

                      style: const TextStyle(
                        fontWeight: FontWeight.bold,

                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ================= PAYMENT =================
                  const Text(
                    "💰 Payment Details",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 10),

                  Row(
                    children: [
                      Expanded(child: _input(rent, "Room Rent", Icons.money)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _input(advance, "Advance", Icons.payments),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ================= BUTTONS =================
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Cancel"),
                        ),
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.check),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            // ✅ Check Dates
                            if (checkInDate == null || checkOutDate == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    "Please select Check In & Check Out dates",
                                  ),
                                ),
                              );

                              return;
                            }

                            int baseRent = int.tryParse(rent.text) ?? 0;

                            // Total Rent = Room Rent × Total Days
                            int finalRent = baseRent * totalDays;

                            room.customerName = name.text.trim();
                            room.customerPhone = phone.text.trim();
                            room.cnic = cnic.text.trim();
                            room.address = address.text.trim();
                            room.carNumber = carNumber.text.trim();
                            room.advance = int.tryParse(advance.text) ?? 0;
                            room.rent = finalRent;
                            room.dailyRent = baseRent;
                            room.stayType = "$totalDays Day(s)";



                            room.checkIn = checkInDate!.toIso8601String();
                            room.checkOut = checkOutDate!.toIso8601String();

                            room.status = "occupied";
                            room.save();

                            setState(() {});
                            Navigator.pop(context);
                          },
                          label: const Text(
                            "Save Booking",
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🔥 COMMON INPUT WIDGET
  Widget _input(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      keyboardType: label == "Rent" || label == "Advance"
          ? TextInputType.number
          : null,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showRoomDetails(RoomBooking room) {
    int total = room.rent ?? 0;
    int advance = room.advance ?? 0;
    int remaining = total - advance;


    int refund = 0;

    if (remaining < 0) {
      refund = remaining.abs();
      remaining = 0;
    }

    DateTime? startTime;

    try {
      if (room.checkIn != null && room.checkIn!.isNotEmpty) {
        startTime = DateTime.tryParse(room.checkIn!)?.toLocal();
      }
    } catch (_) {
      startTime = null;
    }


    DateTime? checkoutTime;

    if (room.checkOut != null && room.checkOut!.isNotEmpty) {
      checkoutTime = DateTime.tryParse(room.checkOut!)?.toLocal();
    }

    String format(DateTime? dt) {
      if (dt == null) return "-";

      int hour = dt.hour;
      String period = "AM";

      if (hour >= 12) {
        period = "PM";
        if (hour > 12) hour = hour - 12;
      }

      if (hour == 0) {
        hour = 12;
      }

      return "${dt.day.toString().padLeft(2, '0')}-"
          "${dt.month.toString().padLeft(2, '0')}-"
          "${dt.year}  "
          "${hour.toString().padLeft(2, '0')}:"
          "${dt.minute.toString().padLeft(2, '0')} $period";
    }

    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔥 HEADER
// 🔥 HEADER
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [

                      Expanded(
                        child: Text(
                          "Room ${room.roomName} Details",
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      Tooltip(
                        message: "Edit Booking",
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            Navigator.pop(context);
                            showEditBookingDialog(room);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.edit,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                        ),
                      ),

                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // 🔥 CUSTOMER + STAY ROW
                LayoutBuilder(
                  builder: (context, constraints) {
                    bool isSmall = constraints.maxWidth < 400;

                    return isSmall
                        ? Column(
                            children: [
                              _customerCard(room),
                              const SizedBox(height: 12),
                              _stayCard(room, startTime, checkoutTime, format),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(child: _customerCard(room)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _stayCard(
                                  room,
                                  startTime,
                                  checkoutTime,
                                  format,
                                ),
                              ),
                            ],
                          );
                  },
                ),

                const SizedBox(height: 18),

                // 🔥 BILLING
                _sectionTitle("💰 Billing Details"),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.orange.shade100),
                  ),
                  child: Column(
                    children: [
                      _billLine("Rent", total),
                      _billLine("Advance", advance),

                      if (refund > 0)
                        _billLine(
                          "Refund",
                          refund,
                          isGreen: true,
                        )
                      else
                        _billLine(
                          "Remaining",
                          remaining,
                          isRed: true,
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 22),

                // 🔥 BUTTONS
                Row(
                  children: [
                    // CANCEL
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.close, size: 20),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                            side: BorderSide(color: Colors.grey.shade400),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          label: const Text(
                            "Cancel",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // EDIT

                    // PRINT
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.print, size: 20),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () async {
                            await printRoomBill(room, total.toDouble());
                          },
                          label: const Text(
                            "Print",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // CHECKOUT
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child:

                        ElevatedButton.icon(
                          icon: const Icon(Icons.check_circle, size: 20),

                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),

                          onPressed: () async {
                            int rent = room.rent ?? 0;
                            int advance = room.advance ?? 0;
                            int remaining = rent - advance;

                            final TextEditingController remainingController =
                            TextEditingController(
                              text: remaining.toString(),
                            );

                            // ⭐ IMPORTANT: direct await without microtask
                            await Future.delayed(
                              const Duration(milliseconds: 50),
                            );

                            if (!context.mounted) return;

                            await showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (dialogContext) {
                                return AlertDialog(
                                  title: const Text("Remaining Payment"),

                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade50,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Text(
                                          "Remaining Amount: Rs $remaining",
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 15),

                                      TextField(
                                        controller: remainingController,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: "Received Amount",
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  actions: [

                                    SizedBox(
                                      width: 120,
                                      height: 42,
                                      child: OutlinedButton(
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(color: Colors.red),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: () {
                                          Navigator.pop(dialogContext);
                                        },
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.close, color: Colors.red, size: 18),
                                            SizedBox(width: 6),
                                            Text(
                                              "Cancel",
                                              style: TextStyle(
                                                color: Colors.red,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: 140,
                                      height: 42,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green.shade700,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: () async {

                                          int paid =
                                              int.tryParse(
                                                remainingController.text,
                                              ) ??
                                                  0;

                                          // int finalRemaining = remaining - paid;
                                          //
                                          // int refund = 0;
                                          //
                                          // if (finalRemaining < 0) {
                                          //   refund = finalRemaining.abs();
                                          //   finalRemaining = 0;
                                          // }


                                          int finalAdvance = advance + paid;
                                          int finalRemaining = rent - finalAdvance;

                                          int refund = 0;

                                          if (finalRemaining < 0) {
                                            refund = finalRemaining.abs();
                                            finalRemaining = 0;
                                          }

                                          DateTime now = DateTime.now();




                                          final history = RoomHistory(
                                            roomName: room.roomName,
                                            customerName: room.customerName,
                                            phone: room.customerPhone,
                                            cnic: room.cnic,
                                            carNumber: room.carNumber,
                                            address: room.address,
                                            rent: rent,
                                            advance: finalAdvance,
                                            remaining: finalRemaining,
                                            checkIn: room.checkIn,
                                            checkOut: now.toIso8601String(),
                                            refund: refund,
                                          );

                                          await historyBox.add(history);

                                          room.status = "available";
                                          room.customerName = null;
                                          room.customerPhone = null;
                                          room.cnic = null;
                                          room.address = null;
                                          room.carNumber = null;
                                          room.advance = 0;
                                          room.rent = 0;
                                          room.checkIn = null;
                                          room.checkOut = null;
                                          room.dailyRent = 0;
                                          room.stayType = null;

                                          await room.save();

                                          setState(() {});

                                          Navigator.pop(dialogContext);
                                          Navigator.pop(context);

                                        },
                                        child: const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.logout, color: Colors.white, size: 18),
                                            SizedBox(width: 6),
                                            Text(
                                              "Checkout",
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                  ],                                );
                              },
                            );
                          },

                          label: const Text(
                            "Checkout",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
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
        ),
      ),
    );
  }

  // ================= HELPERS =================
  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _infoText(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "$label:",
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          ),
          Flexible(
            child: Text(
              value ?? "-",
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _billLine(
      String label,
      int value, {
        bool isRed = false,
        bool isGreen = false,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            "Rs $value",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isGreen
                  ? Colors.green
                  : (isRed ? Colors.red : Colors.black),
            ),
          ),
        ],
      ),
    );
  }
  Widget _customerCard(RoomBooking room) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("👤 Customer Information"),
          _infoText("Name", room.customerName),
          _infoText("Phone", room.customerPhone),
          _infoText("CNIC", room.cnic),
          _infoText("Car", room.carNumber),
          _infoText("Address", room.address),
        ],
      ),
    );
  }

  Widget _stayCard(
    RoomBooking room,
    DateTime? startTime,
    DateTime? checkoutTime,
    String Function(DateTime?) format,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle("⏰ Stay Details"),
          _infoText("Check In", format(startTime)),
          _infoText("Check Out", format(checkoutTime)),
          _infoText("Stay Type", room.stayType),
        ],
      ),
    );
  }

  Future<void> printRoomBill(RoomBooking room, double grandTotal) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    List<int> bytes = [];

    // ================= TIME CALCULATION =================
    DateTime? startTime;

    try {
      if (room.checkIn != null && room.checkIn!.isNotEmpty) {
        startTime = DateTime.tryParse(room.checkIn!)?.toLocal();
      }
    } catch (_) {
      startTime = null;
    }

    DateTime? checkoutTime;

    try {
      if (room.checkOut != null && room.checkOut!.isNotEmpty) {
        checkoutTime = DateTime.tryParse(room.checkOut!)?.toLocal();
      }
    } catch (_) {
      checkoutTime = null;
    }

    // ================= AM/PM FORMAT =================
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

    // ================= TITLE =================
    bytes += generator.text(
      "ROOM INVOICE",
      styles: PosStyles(align: PosAlign.center, bold: true),
    );

    bytes += generator.hr();

    // ================= ROOM INFO =================
    bytes += generator.row([
      PosColumn(text: "Room No:", width: 4, styles: PosStyles(bold: true)),
      PosColumn(text: room.roomName, width: 8),
    ]);

    bytes += generator.row([
      PosColumn(
        text: "Customer Name:",
        width: 4,
        styles: PosStyles(bold: true),
      ),
      PosColumn(text: room.customerName ?? '', width: 8),
    ]);

    bytes += generator.row([
      PosColumn(text: "Phone:", width: 4, styles: PosStyles(bold: true)),
      PosColumn(text: room.customerPhone ?? '', width: 8),
    ]);

    bytes += generator.row([
      PosColumn(text: "CNIC:", width: 4, styles: PosStyles(bold: true)),
      PosColumn(text: room.cnic ?? '', width: 8),
    ]);

    bytes += generator.row([
      PosColumn(text: "Car Number:", width: 4, styles: PosStyles(bold: true)),
      PosColumn(text: room.carNumber ?? '', width: 8),
    ]);

    bytes += generator.row([
      PosColumn(text: "Address:", width: 4, styles: PosStyles(bold: true)),
      PosColumn(
        text: room.address?.isNotEmpty == true ? room.address! : "N/A",
        width: 8,
      ),
    ]);

    // ================= STAY DETAILS =================
    bytes += generator.hr();

    bytes += generator.text(
      "Stay Details",
      styles: PosStyles(align: PosAlign.center, bold: true),
    );

    bytes += generator.hr();

    bytes += generator.row([
      PosColumn(
        text: "Stay Duration:",
        width: 4,
        styles: PosStyles(bold: true),
      ),
      PosColumn(text: room.stayType ?? '', width: 8),
    ]);

    bytes += generator.row([
      PosColumn(text: "Check In:", width: 4, styles: PosStyles(bold: true)),
      PosColumn(text: format(startTime), width: 8),
    ]);

    bytes += generator.row([
      PosColumn(text: "Check Out:", width: 4, styles: PosStyles(bold: true)),
      PosColumn(text: format(checkoutTime), width: 8),
    ]);

    bytes += generator.hr();

    // ================= BILL =================
    int rent = room.rent ?? 0;
    int advance = room.advance ?? 0;
    int remaining = rent - advance;

    bytes += generator.row([
      PosColumn(text: "Rent", width: 6),
      PosColumn(
        text: "Rs $rent",
        width: 6,
        styles: PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += generator.row([
      PosColumn(text: "Advance", width: 6),
      PosColumn(
        text: "Rs $advance",
        width: 6,
        styles: PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += generator.row([
      PosColumn(text: "Remaining", width: 6, styles: PosStyles(bold: true)),
      PosColumn(
        text: "Rs $remaining",
        width: 6,
        styles: PosStyles(align: PosAlign.right, bold: true),
      ),
    ]);

    bytes += generator.hr();

    // ================= TOTAL =================
    bytes += generator.text(
      "TOTAL: Rs ${grandTotal.toInt()}",
      styles: PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );

    bytes += generator.feed(1);
    bytes += generator.hr(ch: '=');

    // ================= FOOTER =================
    bytes += generator.text(
      "Thank You For Visiting",
      styles: PosStyles(align: PosAlign.center, bold: true),
    );

    bytes += generator.text(
      "Developed By Umair Imtiaz 0348-9031338",
      styles: PosStyles(align: PosAlign.center),
    );

    bytes += generator.feed(2);
    bytes += generator.cut();

    // ================= PRINT =================
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

      print("✅ Professional Room Bill Printed");
    } catch (e) {
      print("❌ Print Error: $e");
    }
  }

  Future<String> getPrinterIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("printer_ip") ?? "192.168.0.142";
  }

  @override
  Widget build(BuildContext context) {
    final rooms = roomBox.values.toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("Room Booking - ${widget.hotelName}"),
        backgroundColor: Colors.green,
        leading: IconButton(
          icon: const Icon(Icons.add),
          onPressed: _addRoomDialog,
        ),
      ),

      body: GridView.builder(
        padding: const EdgeInsets.all(10),
        itemCount: rooms.length,
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1,
        ),
        itemBuilder: (context, index) {
          final room = rooms[index];

          return GestureDetector(
            onTap: () {
              if (room.status == "available") {
                _openCustomerForm(room);
              } else {
                _showRoomDetails(room);
              }
            },

            // 🔥 LONG PRESS WITH CONFIRM DIALOG
            onLongPress: () {
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Delete Room"),
                  content: const Text(
                    "Are you sure you want to delete this room?",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("No"),
                    ),
                    TextButton(
                      onPressed: () {
                        _deleteRoom(index);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        "Yes",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              );
            },

            child: Container(
              decoration: BoxDecoration(
                color: room.status == "available" ? Colors.green : Colors.red,
                borderRadius: BorderRadius.circular(12),
              ),

              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    room.roomName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 50,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    room.status == "available" ? "Available" : "Booked",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void showEditBookingDialog(RoomBooking room) {
    final name = TextEditingController(text: room.customerName ?? "");

    final phone = TextEditingController(text: room.customerPhone ?? "");

    final cnic = TextEditingController(text: room.cnic ?? "");

    final address = TextEditingController(text: room.address ?? "");

    final carNumber = TextEditingController(text: room.carNumber ?? "");

    final advance = TextEditingController(text: (room.advance ?? 0).toString());

    final rent = TextEditingController(text: (room.rent ?? 0).toString());





    DateTime checkInDate =
        DateTime.tryParse(room.checkIn ?? "") ??
            DateTime.now();

    DateTime checkOutDate =
        DateTime.tryParse(room.checkOut ?? "") ??
            checkInDate.add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text("Edit Booking"),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SizedBox(
                width: 500,

                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _input(name, "Customer Name", Icons.person),

                      const SizedBox(height: 10),

                      _input(phone, "Phone", Icons.phone),

                      const SizedBox(height: 10),

                      _input(cnic, "CNIC", Icons.badge),

                      const SizedBox(height: 10),

                      _input(address, "Address", Icons.home),

                      const SizedBox(height: 10),

                      _input(carNumber, "Car No", Icons.directions_car),

                      const SizedBox(height: 15),

                      Row(
                        children: [
                          Expanded(
                            child: _input(rent, "Room Rent", Icons.money),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: _input(advance, "Advance", Icons.payments),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // ================= CHECK IN =================
                      OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          "Check In : "
                          "${checkInDate.day}/${checkInDate.month}/${checkInDate.year}",
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: checkInDate,
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2035),
                          );

                          if (picked != null) {
                            setStateDialog(() {
                              checkInDate = picked;

                              // Agar checkout pehle ho gaya to usko bhi update karo
                              if (checkOutDate.isBefore(checkInDate)) {
                                checkOutDate = checkInDate.add(
                                  const Duration(days: 1),
                                );
                              }

                              // Stay Days
                              int days = checkOutDate
                                  .difference(checkInDate)
                                  .inDays;

                              if (days <= 0) days = 1;

                              // Auto Rent
                              int totalRent = (int.tryParse(room.rent.toString()) ?? 0) * days;

                              rent.text = totalRent.toString();
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 10),

                      // ================= CHECK OUT =================
                      OutlinedButton.icon(
                        icon: const Icon(Icons.event),
                        label: Text(
                          "Check Out : "
                          "${checkOutDate.day}/${checkOutDate.month}/${checkOutDate.year}",
                        ),
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: checkOutDate,
                            firstDate: checkInDate,
                            lastDate: DateTime(2035),
                          );

                          if (picked != null) {
                            setStateDialog(() {
                              checkOutDate = picked;

                              int days = checkOutDate
                                  .difference(checkInDate)
                                  .inDays;

                              if (days <= 0) days = 1;

                              int totalRent = (room.dailyRent ?? 0) * days;

                              rent.text = totalRent.toString();
                            });
                          }
                        },
                      ),

                      const SizedBox(height: 15),

                      Builder(
                        builder: (_) {
                          int days = checkOutDate
                              .difference(checkInDate)
                              .inDays;

                          if (days <= 0) days = 1;

                          int totalRent = int.tryParse(rent.text) ?? 0;

                          int adv = int.tryParse(advance.text) ?? 0;

                          int remaining = totalRent - adv;

                          return Card(
                            color: Colors.green.shade50,
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  Text(
                                    "Stay : $days Day(s)",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),

                                  const SizedBox(height: 5),

                                  Text("Total Rent : Rs $totalRent"),

                                  Text(
                                    "Remaining : Rs $remaining",
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: const Text("Cancel"),
                            ),
                          ),

                          const SizedBox(width: 10),

                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.save),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                              ),
                              onPressed: () async {
                                int totalRent = int.tryParse(rent.text) ?? 0;

                                int adv = int.tryParse(advance.text) ?? 0;

                                int days = checkOutDate
                                    .difference(checkInDate)
                                    .inDays;

                                if (days <= 0) days = 1;

                                room.customerName = name.text.trim();
                                room.customerPhone = phone.text.trim();
                                room.cnic = cnic.text.trim();
                                room.address = address.text.trim();
                                room.carNumber = carNumber.text.trim();

                                room.rent = totalRent;
                                room.advance = adv;

                                room.checkIn = checkInDate.toIso8601String();

                                room.checkOut = checkOutDate.toIso8601String();

                                room.stayType = "$days Day(s)";

                                await room.save();

                                if (mounted) {
                                  Navigator.pop(context);

                                  setState(() {});

                                  Future.delayed(
                                    const Duration(milliseconds: 100),
                                        () {
                                      _showRoomDetails(room);
                                    },
                                  );

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        "Booking Updated Successfully",
                                      ),
                                    ),
                                  );
                                }
                              },
                              label: const Text(
                                "Update Booking",
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
