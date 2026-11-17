import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../inventory/models/TokenHistory.dart';

class TokenHistoryScreen extends StatefulWidget {
  const TokenHistoryScreen({super.key});

  @override
  State<TokenHistoryScreen> createState() => _TokenHistoryScreenState();
}

class _TokenHistoryScreenState extends State<TokenHistoryScreen> {
  String selectedFilter = "Daily";
  DateTime? selectedDate;

  String searchQuery = "";

  Box<TokenHistory> get box => Hive.box<TokenHistory>('tokenHistory');

  List<TokenHistory> get allData => box.values.toList();

  // ===== FILTER + SEARCH LOGIC =====
  List<TokenHistory> get filteredData {
    DateTime now = DateTime.now();

    return allData.where((item) {
      DateTime date = DateTime.parse(item.dateTime);

      // ===== DATE FILTER =====
      bool dateMatch = true;

      if (selectedDate != null) {
        dateMatch = date.year == selectedDate!.year &&
            date.month == selectedDate!.month &&
            date.day == selectedDate!.day;
      } else if (selectedFilter == "Daily") {
        dateMatch = date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      } else {
        dateMatch = date.year == now.year &&
            date.month == now.month;
      }

      // ===== SEARCH FILTER =====
      bool searchMatch =
          item.orderNumber.toString().contains(searchQuery.trim()) ||
              item.orderId.toLowerCase().contains(searchQuery.toLowerCase().trim());

      return dateMatch && searchMatch;
    }).toList();
  }

  int get totalOrders => filteredData.length;

  // ===== DATE PICKER =====
  Future<void> pickDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        selectedFilter = "";
      });
    }
  }

  // ===== DETAIL DIALOG =====
  void showDetails(TokenHistory item) {
    DateTime date = DateTime.parse(item.dateTime);

    String formattedDate =
        "${date.day.toString().padLeft(2, '0')}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.year}";

    String formattedTime =
        "${(date.hour % 12 == 0 ? 12 : date.hour % 12).toString().padLeft(2, '0')}:"
        "${date.minute.toString().padLeft(2, '0')} "
        "${date.hour >= 12 ? 'PM' : 'AM'}";

    showDialog(
      context: context,
      builder: (_) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ===== HEADER =====
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Order #${item.orderNumber}",
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    )
                  ],
                ),

                const Divider(),

                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ===== ORDER INFO =====
                        _buildSectionTitle("Order Info"),
                        _buildRow(Icons.confirmation_number, "Order ID", item.orderId),
                        _buildRow(Icons.category, "Type", item.orderType),
                        _buildRow(Icons.label, "Category", item.category),

                        const SizedBox(height: 10),

                        // ===== LOCATION =====
                        _buildSectionTitle("Location"),
                        _buildRow(Icons.table_bar, "Table", item.tableNumber.toString()),
                        _buildRow(Icons.apartment, "Floor", item.floorNumber.toString()),

                        const SizedBox(height: 10),

                        // ===== DATE TIME =====
                        _buildSectionTitle("Date & Time"),
                        _buildRow(Icons.calendar_today, "Date", formattedDate),
                        _buildRow(Icons.access_time, "Time", formattedTime),

                        const SizedBox(height: 10),

                        // ===== ITEMS TABLE =====
                        _buildSectionTitle("Items"),

                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            children: [
                              // HEADER
                              Row(
                                children: const [
                                  Expanded(
                                    flex: 3,
                                    child: Text(
                                      "Item",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      "Qty",
                                      textAlign: TextAlign.right,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const Divider(),

                              // ITEMS
                              ...item.items.map((e) {
                                String name = "";
                                String qty = "1";

                                String raw = e.toString().trim();

// ===== REMOVE 1x / 1 x / 1X =====
                                raw = raw.replaceAll(
                                  RegExp(r'^\s*\d+\s*[xX]\s*'),
                                  '',
                                );

                                if (raw.contains(":")) {
                                  final parts = raw.split(":");
                                  name = parts[0].trim();
                                  qty = parts.length > 1 ? parts[1].trim() : "1";
                                } else if (raw.contains("-")) {
                                  final parts = raw.split("-");
                                  name = parts[0].trim();
                                  qty = parts.length > 1 ? parts[1].trim() : "1";
                                } else {
                                  name = raw.trim();
                                }

                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Text(name),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          qty,
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }



  // ===== HIGHLIGHT TEXT FUNCTION =====
  TextSpan highlight(String text) {
    String query = searchQuery.trim();

    if (query.isEmpty) {
      return TextSpan(text: text);
    }

    String lowerText = text.toLowerCase();
    String lowerQuery = query.toLowerCase();

    if (!lowerText.contains(lowerQuery)) {
      return TextSpan(text: text);
    }

    int start = lowerText.indexOf(lowerQuery);
    int end = start + lowerQuery.length;

    return TextSpan(
      children: [
        TextSpan(text: text.substring(0, start)),
        TextSpan(
          text: text.substring(start, end),
          style: const TextStyle(
            backgroundColor: Colors.yellow,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        TextSpan(text: text.substring(end)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Token History")),

      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<TokenHistory> box, _) {
          final data = filteredData;

          return Column(
            children: [
              // ===== SEARCH BAR =====
              Padding(
                padding: const EdgeInsets.all(10),
                child: TextField(
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Search by Order Number / ID",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),

              // ===== FILTER ROW =====
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ChoiceChip(
                          label: const Text("Daily"),
                          selected: selectedFilter == "Daily",
                          onSelected: (_) {
                            setState(() {
                              selectedFilter = "Daily";
                              selectedDate = null;
                            });
                          },
                        ),
                        ChoiceChip(
                          label: const Text("Monthly"),
                          selected: selectedFilter == "Monthly",
                          onSelected: (_) {
                            setState(() {
                              selectedFilter = "Monthly";
                              selectedDate = null;
                            });
                          },
                        ),
                        ElevatedButton(
                          onPressed: pickDate,
                          child: const Text("Select Date"),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    if (selectedDate != null)
                      Text(
                        "Selected Date: ${selectedDate!.day}-${selectedDate!.month}-${selectedDate!.year}",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),

                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "Total Orders: $totalOrders",
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(),

              // ===== LIST =====
              Expanded(
                child: data.isEmpty
                    ? const Center(child: Text("No Data Found"))
                    : ListView.builder(
                  itemCount: data.length,
                  itemBuilder: (context, index) {
                    final item = data[index];

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      child: ListTile(
                        title: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: Colors.black, // ✅ FULL TEXT BLACK
                              fontSize: 16,
                            ),
                            children: [
                              highlight("Order #${item.orderNumber}"),
                            ],
                          ),
                        ),
                        subtitle: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: Colors.black, // ✅ BLACK
                            ),
                            children: [
                              highlight(item.category),
                            ],
                          ),
                        ),
                        trailing: ElevatedButton(
                          onPressed: () => showDetails(item),
                          child: const Text("View"),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }


  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Widget _buildRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 8),
          Text(
            "$label: ",
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}