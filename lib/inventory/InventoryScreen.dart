import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/InventoryItem.dart';


class Inventoryscreen extends StatefulWidget {
  const Inventoryscreen({super.key, required String hotelName});

  @override
  State<Inventoryscreen> createState() => _InventoryscreenState();
}

class _InventoryscreenState extends State<Inventoryscreen> {
  final TextEditingController itemController =
  TextEditingController();

  final TextEditingController stockController =
  TextEditingController();


  final TextEditingController unitController =
  TextEditingController();

  String selectedType = "RawMaterial";



  @override
  void dispose() {
    itemController.dispose();
    stockController.dispose();
    unitController.dispose();
    super.dispose();
  }


  String formatStock(double value, String unit) {
    if (unit.toLowerCase() == "piece") {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }


  Future<void> saveItem() async {
    if (itemController.text.trim().isEmpty ||
        stockController.text.trim().isEmpty ||
        unitController.text.trim().isEmpty) {
      return;
    }

    final box = Hive.box<InventoryItem>('inventory');






    await box.add(
      InventoryItem(
        itemName: itemController.text.trim(),
        stock: double.tryParse(stockController.text) ?? 0,
        totalAddedStock:
        double.tryParse(stockController.text) ?? 0,
        unit: unitController.text.trim(),
        createdAt: DateTime.now(),
        itemType: selectedType,
      ),
    );



    itemController.clear();
    stockController.clear();
    unitController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Item Added Successfully"),
      ),
    );
  }
  Future<void> deleteItem(int index) async {
    final box = Hive.box<InventoryItem>('inventory');
    await box.deleteAt(index);
  }

  @override
  Widget build(BuildContext context) {

    final box = Hive.box<InventoryItem>('inventory');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Kitchen Inventory"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              _showAddInventoryDialog();
            },
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          children: [

            const Text(
              "Current Stock",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: ValueListenableBuilder(
                valueListenable: box.listenable(),
                builder: (context, Box<InventoryItem> box, _) {

                  if (box.isEmpty) {
                    return const Center(
                      child: Text(
                        "No Inventory Found",
                        style: TextStyle(fontSize: 16),
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: box.length,
                    itemBuilder: (context, index) {

                      final item = box.getAt(index);

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.inventory_2),
                          ),

                          title: Text(
                            item!.itemName,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              Text(
                          "In Stock: ${formatStock(item.totalAddedStock, item.unit)} ${item.unit}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                ),
                              ),

                              Text(
                                "Used: ${formatStock(item.usedStock, item.unit)} ${item.unit}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),

                              Text(
                                "Remaining: ${formatStock(item.stock, item.unit)} ${item.unit}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),


                              Text(
                                "Type: ${item.itemType}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),

                              const SizedBox(height: 5),

                              Text(
                                "Added On: "
                                    "${item.createdAt.day}-${item.createdAt.month}-${item.createdAt.year} "
                                    "${item.createdAt.hour > 12 ? item.createdAt.hour - 12 : (item.createdAt.hour == 0 ? 12 : item.createdAt.hour)}:"
                                    "${item.createdAt.minute.toString().padLeft(2, '0')} "
                                    "${item.createdAt.hour >= 12 ? "PM" : "AM"}",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [

                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                onPressed: () {
                                  showEditDialog(
                                    index,
                                    item,
                                  );
                                },
                              ),

                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  showDeleteDialog(index);
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }


  Future<void> showDeleteDialog(int index) async {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delete Item"),
          content: const Text(
            "Are you sure you want to delete this inventory item?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () async {
                await deleteItem(index);

                if (mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text("Delete"),
            ),
          ],
        );
      },
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
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    TextField(
                      controller: itemController,
                      decoration: const InputDecoration(
                        labelText: "Item Name",
                        hintText: "Chicken",
                      ),
                    ),

                    const SizedBox(height: 10),

                    TextField(
                      controller: stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Stock",
                        hintText: "10",
                      ),
                    ),

                    const SizedBox(height: 10),

                TextField(
                  controller: unitController,




                  decoration: const InputDecoration(
                    labelText: "Unit",
                    hintText: "Kg, Gram, Litre, Piece, Half Kg, ML etc",
                  ),
                ),






                    const SizedBox(height: 10),

                    DropdownButtonFormField<String>(
                      value: selectedType,
                      decoration: const InputDecoration(
                        labelText: "Item Type",
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "RawMaterial",
                          child: Text("Raw Material"),
                        ),
                        DropdownMenuItem(
                          value: "Drink",
                          child: Text("Drink"),
                        ),
                        DropdownMenuItem(
                          value: "ReadyMade",
                          child: Text("Ready Made"),
                        ),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          selectedType = value!;
                        });
                      },
                    ),



















                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await saveItem();
                    if (mounted) {
                      Navigator.pop(context);
                    }
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
  Future<void> showEditDialog(
      int index,
      InventoryItem item,
      ) async {

    itemController.text = item.itemName;
    stockController.text = item.stock.toString();
    unitController.text = item.unit;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Edit Inventory"),

              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    TextField(
                      controller: itemController,
                      decoration: const InputDecoration(
                        labelText: "Item Name",
                      ),
                    ),

                    const SizedBox(height: 10),

                    TextField(
                      controller: stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Stock",
                      ),
                    ),

                    const SizedBox(height: 10),



                    TextField(
                      controller: unitController,
                      decoration: const InputDecoration(
                        labelText: "Unit",
                        hintText: "Kg, Gram, Litre, Piece, ML etc",
                      ),
                    ),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),

                ElevatedButton(
                  onPressed: () async {

                    item.itemName =
                        itemController.text.trim();

                    item.stock =
                        double.tryParse(
                          stockController.text,
                        ) ??
                            0;
                    item.unit = unitController.text.trim();

                    await item.save();

                    if (mounted) {
                      Navigator.pop(context);
                    }
                  },
                  child: const Text("Update"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}