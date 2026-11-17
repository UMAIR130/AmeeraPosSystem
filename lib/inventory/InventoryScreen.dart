import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/order_model.dart';
import 'models/InventoryHistory.dart';
import 'models/InventoryItem.dart';

class Inventoryscreen extends StatefulWidget {
  const Inventoryscreen({super.key, required String hotelName});

  @override
  State<Inventoryscreen> createState() => _InventoryscreenState();
}

class _InventoryscreenState extends State<Inventoryscreen> {


  String selectedFilter = "Today";

  DateTimeRange? customRange;

  final List<String> filters = [
    "Today",
    "Yesterday",
    "This Week",
    "This Month",
    "Custom",
  ];


  final TextEditingController itemController = TextEditingController();
  final TextEditingController stockController = TextEditingController();
  final TextEditingController unitController = TextEditingController();

  String selectedType = "RawMaterial";

  @override
  void dispose() {
    itemController.dispose();
    stockController.dispose();
    unitController.dispose();
    super.dispose();
  }

  // ================= BASE CONVERTER =================
  double convertToBase(double qty, String unit) {
    switch (unit.toLowerCase()) {
      case "kg":
        return qty * 1000;
      case "g":
        return qty;
      case "l":
        return qty * 1000;
      case "ml":
        return qty;
      default:
        return qty;
    }
  }

  // ================= FORMAT DISPLAY =================
  String formatStockDetailed(double value, String unit) {
    unit = unit.toLowerCase();

    if (unit == "kg" || unit == "g") {
      return "${value.toStringAsFixed(0)} g\n(${(value / 1000).toStringAsFixed(
          2)} kg)";
    }

    if (unit == "l" || unit == "ml") {
      return "${value.toStringAsFixed(0)} ml\n(${(value / 1000).toStringAsFixed(
          2)} L)";
    }

    return value.toStringAsFixed(2);
  }

  Color getTypeColor(String type) {
    switch (type) {
      case "Drink":
        return Colors.blue;
      case "ReadyMade":
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  // ================= SAVE ITEM =================
  Future<void> saveItem() async {
    if (itemController.text
        .trim()
        .isEmpty ||
        stockController.text
            .trim()
            .isEmpty ||
        unitController.text
            .trim()
            .isEmpty)
      return;

    double stock = double.tryParse(stockController.text) ?? 0;
    String unit = unitController.text.trim();

    double baseStock = convertToBase(stock, unit);

    final box = Hive.box<InventoryItem>('inventory');

    await box.add(
      InventoryItem(
        itemName: itemController.text.trim(),
        stock: baseStock,
        totalAddedStock: baseStock,
        unit: unit,
        createdAt: DateTime.now(),
        itemType: selectedType,
      ),
    );

    itemController.clear();
    stockController.clear();
    unitController.clear();

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Item Added Successfully")));
  }

  // ================= DELETE =================
  Future<void> deleteItem(int index) async {
    final box = Hive.box<InventoryItem>('inventory');
    await box.deleteAt(index);
  }


  double getUsedStockByFilter(InventoryItem item) {
    final historyBox = Hive.box<InventoryHistory>('inventory_history');

    final now = DateTime.now();

    DateTime start;
    DateTime end;

    switch (selectedFilter) {
      case "Today":
        start = DateTime(now.year, now.month, now.day);
        end = start.add(const Duration(days: 1));
        break;

      case "Yesterday":
        start = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 1));
        end = start.add(const Duration(days: 1));
        break;

      case "This Week":
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        end = DateTime(now.year, now.month, now.day)
            .add(const Duration(days: 1));
        break;

      case "This Month":
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 1);
        break;

      case "Custom":
        if (customRange == null) return 0;

        start = DateTime(
          customRange!.start.year,
          customRange!.start.month,
          customRange!.start.day,
        );

        end = DateTime(
          customRange!.end.year,
          customRange!.end.month,
          customRange!.end.day + 1,
        );

        break;

      default:
        return item.usedStock;
    }

    double used = 0;

    for (final h in historyBox.values) {
      print(
          "History => ${h.itemName} | ${h.qty} | ${h.type} | ${h.date}");
      if (h.itemName == item.itemName &&
          h.type == "USED" &&
          h.date.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
          h.date.isBefore(end)) {
        used += h.qty;
      }
    }

    print(
        "Item=${item.itemName} "
            "HistoryUsed=$used "
            "Remaining=${item.stock} "
            "Total=${item.totalAddedStock}"
    );

    return used;
  }






  String getMostUsedItem() {

    final box = Hive.box<InventoryHistory>('inventory_history');

    final Map<String, double> map = {};

    for (final h in box.values) {

      if (h.type != "USED") continue;

      if (!_isHistoryInFilter(h.date)) continue;

      map[h.itemName] = (map[h.itemName] ?? 0) + h.qty;
    }

    if (map.isEmpty) return "-";

    final item = map.entries.reduce((a, b) => a.value > b.value ? a : b);

    final inventoryBox = Hive.box<InventoryItem>('inventory');

    // ✅ Safe search (Bad State error fix)
    final inventoryList = inventoryBox.values
        .where((e) => e.itemName.trim().toLowerCase() ==
        item.key.trim().toLowerCase())
        .toList();

    String qty;

    if (inventoryList.isNotEmpty) {

      final inventory = inventoryList.first;

      if (inventory.unit.toLowerCase() == "kg" ||
          inventory.unit.toLowerCase() == "g") {

        qty =
        "${item.value.toStringAsFixed(0)} g (${(item.value / 1000).toStringAsFixed(2)} kg)";

      } else if (inventory.unit.toLowerCase() == "l" ||
          inventory.unit.toLowerCase() == "ml") {

        qty =
        "${item.value.toStringAsFixed(0)} ml (${(item.value / 1000).toStringAsFixed(2)} L)";

      } else {

        qty = "${item.value.toStringAsFixed(0)} ${inventory.unit}";
      }

    } else {

      // Agar inventory item na mile to bhi app crash nahi hogi
      qty = item.value.toStringAsFixed(0);

    }

    return "${item.key}\n$qty";
  }
  String getBestSellingItem(){

    final box = Hive.box<Order>('orders_history');

    final Map<String,int> map = {};

    for(final order in box.values){

      if(!_isHistoryInFilter(order.timestamp)) continue;

      for(final item in order.items){

        map[item.name]=(map[item.name]??0)+item.qty;

      }

    }

    if(map.isEmpty) return "-";

    final best = map.entries.reduce((a,b)=>a.value>b.value?a:b);

    return "${best.key}\n${best.value}";
  }








  bool _isHistoryInFilter(DateTime date) {
    final now = DateTime.now();

    DateTime start;
    DateTime end;

    switch (selectedFilter) {
      case "Today":
        start = DateTime(now.year, now.month, now.day);
        end = start.add(const Duration(days: 1));
        break;

      case "Yesterday":
        start = DateTime(now.year, now.month, now.day)
            .subtract(const Duration(days: 1));
        end = start.add(const Duration(days: 1));
        break;

      case "This Week":
        start = now.subtract(Duration(days: now.weekday - 1));
        start = DateTime(start.year, start.month, start.day);
        end = DateTime(now.year, now.month, now.day)
            .add(const Duration(days: 1));
        break;

      case "This Month":
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 1);
        break;

      case "Custom":
        if (customRange == null) return false;

        start = DateTime(
          customRange!.start.year,
          customRange!.start.month,
          customRange!.start.day,
        );

        end = DateTime(
          customRange!.end.year,
          customRange!.end.month,
          customRange!.end.day + 1,
        );
        break;

      default:
        return false;
    }

    return date.isAfter(start.subtract(const Duration(milliseconds: 1))) &&
        date.isBefore(end);
  }














  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<InventoryItem>('inventory');

    return Scaffold(
      backgroundColor: const Color(0xfff5f6fa),

      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.green.shade700,
        centerTitle: true,
        title: const Text(
          "Kitchen Inventory",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),

        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.green,
              ),

              onPressed: _showAddInventoryDialog,

              icon: const Icon(Icons.add),

              label: const Text("Add Item"),
            ),
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(15),

        child: ValueListenableBuilder(
          valueListenable: box.listenable(),

          builder: (context, Box<InventoryItem> box, _) {
            final screenWidth = MediaQuery
                .of(context)
                .size
                .width;

            if (box.isEmpty) {
              return const Center(
                child: Text(
                  "No Inventory Found",
                  style: TextStyle(fontSize: 18),
                ),
              );
            }

            return Column(
              children: [


                SizedBox(
                  height: 45,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: filters.length,
                    itemBuilder: (context, index) {
                      final filter = filters[index];

                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(filter),
                          selected: selectedFilter == filter,
                          onSelected: (_) async {
                            if (filter == "Custom") {
                              final picked = await showDateRangePicker(
                                context: context,
                                firstDate: DateTime(2024),
                                lastDate: DateTime.now(),
                              );

                              if (picked != null) {
                                setState(() {
                                  customRange = picked;
                                  selectedFilter = filter;
                                });
                              }
                            } else {
                              setState(() {
                                selectedFilter = filter;
                              });
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 15),


                //---------------- Search ----------------




                const SizedBox(height:15),

                GridView.count(

                  shrinkWrap: true,

                  physics: const NeverScrollableScrollPhysics(),

                  crossAxisCount: 4,

                  childAspectRatio: 3.5,

                  crossAxisSpacing: 10,

                  mainAxisSpacing: 10,

                  children: [

                    // _dashboardCard(
                    //   "Today's Sales",
                    //   "Rs ${getTodaySales().toStringAsFixed(0)}",
                    //   Icons.payments,
                    //   Colors.green,
                    // ),
                    //
                    // _dashboardCard(
                    //   "Today's Orders",
                    //   getTodayOrders().toString(),
                    //   Icons.receipt_long,
                    //   Colors.blue,
                    // ),

                    _dashboardCard(
                      "Most Used",
                      getMostUsedItem(),
                      Icons.local_fire_department,
                      Colors.red,
                    ),

                    _dashboardCard(
                      "Best Seller",
                      getBestSellingItem(),
                      Icons.star,
                      Colors.orange,
                    ),

                  ],

                ),




                const SizedBox(height:10),

                SizedBox(
                  width: 350,

                  child: TextField(
                    decoration: InputDecoration(
                      hintText: "Search Item",

                      prefixIcon: const Icon(Icons.search),

                      filled: true,

                      fillColor: Colors.white,

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height:10),

                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(.15),
                          blurRadius: 8,
                        ),
                      ],
                    ),

                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,

                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,

                        child: DataTable(
                          headingRowHeight: 55,
                          dataRowMinHeight: 50,
                          dataRowMaxHeight: 55,

                          // columnSpacing: 115,
                          // horizontalMargin: 5,


                          columnSpacing: screenWidth * 0.08,
                          horizontalMargin: screenWidth * 0.03,

                          headingRowColor: MaterialStateProperty.all(
                            Colors.green.shade100,
                          ),

                          columns: const [
                            DataColumn(
                              label: Text(
                                "Item Name",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),

                            DataColumn(
                              label: Text(
                                "Type",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),

                            DataColumn(
                              numeric: true,
                              label: Text(
                                "Total",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),

                            DataColumn(
                              numeric: true,
                              label: Text(
                                "Used",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),

                            DataColumn(
                              numeric: true,
                              label: Text(
                                "Remaining",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),

                            DataColumn(
                              label: Text(
                                "Status",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),

                            DataColumn(
                              label: Text(
                                "Action",
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],

                          rows: List.generate(box.length, (index) {
                            final item = box.getAt(index)!;

                            final bool lowStock = item.stock <= 5;

                            return DataRow(
                              cells: [
                                DataCell(
                                  Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 16,
                                        backgroundColor: getTypeColor(
                                          item.itemType,
                                        ).withOpacity(.15),
                                        child: Icon(
                                          item.itemType == "Drink"
                                              ? Icons.local_drink
                                              : item.itemType == "ReadyMade"
                                              ? Icons.fastfood
                                              : Icons.inventory_2,
                                          size: 16,
                                          color: getTypeColor(item.itemType),
                                        ),
                                      ),

                                      const SizedBox(width: 10),

                                      Text(
                                        item.itemName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                //================ TYPE =================
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: getTypeColor(
                                        item.itemType,
                                      ).withOpacity(.12),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      item.itemType,
                                      style: TextStyle(
                                        color: getTypeColor(item.itemType),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),

                                //================ TOTAL =================
                                DataCell(
                                  Text(
                                    formatStockDetailed(
                                      item.totalAddedStock,
                                      item.unit,
                                    ),
                                  ),
                                ),

                                //================ USED =================
                                DataCell(
                                  Text(
                                    formatStockDetailed(


                                      getUsedStockByFilter(item),

                                      item.unit,

                                      //item.usedStock,

                                      // item.totalAddedStock - item.stock,
                                      // item.unit,

                                    ),
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                //================ REMAINING =================
                                DataCell(
                                  Text(
                                    formatStockDetailed(item.stock, item.unit),
                                    style: TextStyle(
                                      color: lowStock
                                          ? Colors.red
                                          : Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                //================ STATUS =================
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: lowStock
                                          ? Colors.red.shade100
                                          : Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      lowStock ? "LOW STOCK" : "AVAILABLE",
                                      style: TextStyle(
                                        color: lowStock
                                            ? Colors.red
                                            : Colors.green,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),

                                //================ ACTION =================
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: "Edit",
                                        icon: const Icon(
                                          Icons.edit,
                                          color: Colors.blue,
                                        ),
                                        onPressed: () =>
                                            showEditDialog(index, item),
                                      ),


                                      IconButton(
                                        tooltip: "Add Stock",
                                        icon: const Icon(
                                          Icons.add_circle,
                                          color: Colors.green,
                                        ),
                                        onPressed: () =>
                                            showAddStockDialog(item),
                                      ),


                                      IconButton(
                                        tooltip: "Delete",
                                        icon: const Icon(
                                          Icons.delete,
                                          color: Colors.red,
                                        ),
                                        onPressed: () =>
                                            showDeleteDialog(index),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          }),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }



  void _showAddInventoryDialog() {
    itemController.clear();
    stockController.clear();
    unitController.clear();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add Inventory"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: itemController,
                    decoration: const InputDecoration(labelText: "Item Name"),
                  ),
                  TextField(
                    controller: stockController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Stock"),
                  ),
                  TextField(
                    controller: unitController,
                    decoration: const InputDecoration(labelText: "Unit"),
                  ),
                  DropdownButtonFormField(
                    value: selectedType,
                    items: const [
                      DropdownMenuItem(
                        value: "RawMaterial",
                        child: Text("Raw Material"),
                      ),
                      DropdownMenuItem(value: "Drink", child: Text("Drink")),
                      DropdownMenuItem(
                        value: "ReadyMade",
                        child: Text("Ready Made"),
                      ),
                    ],
                    onChanged: (v) {
                      setDialogState(() {
                        selectedType = v!;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await saveItem();
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ================= EDIT (FIXED) =================
  void showEditDialog(int index, InventoryItem item) {
    itemController.text = item.itemName;
    stockController.text = item.stock.toString();
    unitController.text = item.unit;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Inventory"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: itemController),
              TextField(controller: unitController),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                item.itemName = itemController.text.trim();
                item.unit = unitController.text.trim();

                await item.save();

                if (mounted) Navigator.pop(context);
              },
              child: const Text("Update"),
            ),
          ],
        );
      },
    );
  }

  void showAddStockDialog(InventoryItem item) {
    final stockController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Add Stock - ${item.itemName}"),
          content: TextField(
            controller: stockController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: "Enter Stock",
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                double qty =
                    double.tryParse(stockController.text) ?? 0;

                double addQty = convertToBase(qty, item.unit);

                item.stock += addQty;
                item.totalAddedStock += addQty;

                await item.save();

                if (mounted) Navigator.pop(context);
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  // ================= DELETE DIALOG =================
  void showDeleteDialog(int index) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Item"),
          content: const Text("Are you sure?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                await deleteItem(index);
                if (mounted) Navigator.pop(context);
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }

  Widget _dashboardCard(

      String title,
      String value,
      IconData icon,
      Color color,

      ){

    return Container(

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(12),

        border: Border.all(color: Colors.grey.shade300),

      ),

      child: Row(

        children: [

          CircleAvatar(

            backgroundColor: color.withOpacity(.15),

            child: Icon(icon,color: color),

          ),

          const SizedBox(width:10),

          Expanded(

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              mainAxisAlignment: MainAxisAlignment.center,

              children: [

                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),

                const SizedBox(height:4),

                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

              ],

            ),

          )

        ],

      ),

    );

  }

}
