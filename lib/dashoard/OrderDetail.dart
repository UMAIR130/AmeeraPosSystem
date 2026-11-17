import 'dart:convert';
import 'dart:io';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../inventory/models/InventoryHistory.dart';
import '../inventory/models/InventoryItem.dart';
import '../inventory/models/MenuRecipe.dart';
import '../inventory/models/TokenHistory.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/order_model.dart';
import 'package:http/http.dart' as http;

class OrderDetail extends StatefulWidget {
  final Order order;
  final String hotelName;

  const OrderDetail({super.key, required this.order, required this.hotelName});

  @override
  State<OrderDetail> createState() => _OrderDetailState();
}

class _OrderDetailState extends State<OrderDetail> {
  List<Map<String, dynamic>> menuItems = [];
  List<Map<String, dynamic>> filteredItems = [];
  bool isLoadingMenu = true;
  late String menuCacheKey = "${widget.hotelName}_menu_cache";
  double subTotal = 0;
  double serviceCharge = 0;
  double discount = 0;
  double grandTotal = 0;
  int lastPrintedCount = 0;
  String savedHotelName = "";
  String savedAddress = "";
  String savedPhone = "";
  int? expandedIndex;

  bool isProcessing = false;



  final TextEditingController discountController = TextEditingController();
  final TextEditingController searchController = TextEditingController();

  // ===== PAYMENT SYSTEM =====
  String selectedPayment = "";
  TextEditingController receivedController = TextEditingController();
  double returnedAmount = 0;

  String selectedPaymentMethod = "Cash"; // Cash / Card / JazzCash

  bool serviceEnabled = true; // user enable/disable
  TextEditingController serviceController = TextEditingController(text: "8");

  bool taxEnabled = false;
  TextEditingController taxController = TextEditingController(text: "0");
  double taxAmount = 0;

  bool isFullScreen = false;
  FocusNode _focusNode = FocusNode();

  bool discountPercentageEnabled =
  false; // true agar % discount enable karna ho
  bool discountEnabled = true; // agar default enable rakhna hai
  @override
  void initState() {
    super.initState();
    calculateBill();
    loadMenu();


    loadSavedHotelInfo(); // offline load

    loadHotelInfo();

    loadSettings();
    filteredItems = [];
    _focusNode.requestFocus();



 //   startAutoSync();



  }

  void toggleFullScreen() {
    setState(() {
      isFullScreen = !isFullScreen;
    });

    if (isFullScreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersive);
    } else {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
  }


  void createNewOrder() {
    widget.order.items.clear();

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("New Order Started")),
    );
  }
  @override
  void dispose() {
    serviceController.dispose();
    taxController.dispose();
    _focusNode.dispose();

    super.dispose();
  }
  Future<void> deductInventory(Order order) async {
    // ✅ Already deducted? Stop here.
    if (order.inventoryDeducted == true) {
      print("Inventory already deducted for Order ${order.orderNumber}");
      return;
    }

    final historyBox = Hive.box<InventoryHistory>('inventory_history');
    final inventoryBox = Hive.box<InventoryItem>('inventory');
    final recipeBox = Hive.box<MenuRecipe>('recipes');

    for (var orderItem in order.items) {

      /// ================= 1. CHECK RECIPE =================
      final recipeList = recipeBox.values
          .where((r) => match(r.menuName, orderItem.name))
          .toList();

      if (recipeList.isNotEmpty) {

        final recipe = recipeList.first;

        for (var ingredient in recipe.ingredients) {

          final inventoryList = inventoryBox.values
              .where((i) => match(i.itemName, ingredient.inventoryName))
              .toList();

          if (inventoryList.isEmpty) continue;

          final inventory = inventoryList.first;

          double deductQty = ingredient.qty * orderItem.qty;

          // Deduct Stock
          inventory.stock -= deductQty;
          await inventory.save();

          // Prevent duplicate history
          final alreadyExists = historyBox.values.any(
                (h) =>
            h.orderNo == order.orderNumber &&
                h.itemName == inventory.itemName &&
                h.type == "USED" &&
                h.qty == deductQty,
          );

          if (!alreadyExists) {
            await historyBox.add(
              InventoryHistory(
                itemName: inventory.itemName,
                qty: deductQty,
                unit: inventory.unit,
                type: "USED",
                date: DateTime.now(),
                orderNo: order.orderNumber,
              ),
            );

            print("History Length After Save = ${historyBox.length}");
          }
        }

        continue;
      }

      /// ================= 2. DIRECT ITEM =================
      final inventoryList = inventoryBox.values
          .where((i) => match(i.itemName, orderItem.name))
          .toList();

      if (inventoryList.isEmpty) continue;

      final inventory = inventoryList.first;

      if (inventory.itemType == "Drink" ||
          inventory.itemType == "ReadyMade" ||
          inventory.itemType == "RawMaterial") {

        double deductQty = orderItem.qty.toDouble();

        // Deduct Stock
        inventory.stock -= deductQty;
        await inventory.save();

        // Prevent duplicate history
        final alreadyExists = historyBox.values.any(
              (h) =>
          h.orderNo == order.orderNumber &&
              h.itemName == inventory.itemName &&
              h.type == "USED" &&
              h.qty == deductQty,
        );

        if (!alreadyExists) {
          await historyBox.add(
            InventoryHistory(
              itemName: inventory.itemName,
              qty: deductQty,
              unit: inventory.unit,
              type: "USED",
              date: DateTime.now(),
              orderNo: order.orderNumber,
            ),
          );
        }
      }
    }

    // ✅ Mark as deducted ONLY after everything succeeds
    order.inventoryDeducted = true;
    await order.save();

    print("Inventory Deducted Successfully : ${order.orderNumber}");
  }









  bool match(String a, String b) {
    return a.trim().toLowerCase() == b.trim().toLowerCase();
  }

  Future<void> saveSettings() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('servicePercent', serviceController.text);
    await prefs.setString('taxPercent', taxController.text);

    await prefs.setBool('serviceEnabled', serviceEnabled);
    await prefs.setBool('taxEnabled', taxEnabled);
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      serviceController.text =
          prefs.getString('servicePercent') ?? '';

      taxController.text =
          prefs.getString('taxPercent') ?? '';

      serviceEnabled =
          prefs.getBool('serviceEnabled') ?? false;

      taxEnabled =
          prefs.getBool('taxEnabled') ?? false;
    });

    calculateBill();
  }


  Future<void> loadSavedHotelInfo() async {
    final prefs = await SharedPreferences.getInstance();

    savedHotelName =
        prefs.getString("${widget.hotelName}_hotelName") ??
            widget.hotelName;

    savedAddress =
        prefs.getString("${widget.hotelName}_address") ?? "";

    savedPhone =
        prefs.getString("${widget.hotelName}_phone") ?? "";
  }

  Future<void> loadHotelInfo() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final ref = FirebaseDatabase.instance.ref(
        "Restaurant/${widget.hotelName}/Users",
      );

      final snapshot = await ref.get();

      if (snapshot.exists) {
        final usersMap =
        Map<String, dynamic>.from(snapshot.value as Map);


        for (var user in usersMap.values) {
          final data = Map<String, dynamic>.from(user);

          if ((data["address"] ?? "")
              .toString()
              .isNotEmpty) {
            savedHotelName =
                data["HotelName"]?.toString() ?? widget.hotelName;

            savedAddress =
                data["address"]?.toString() ?? "";

            savedPhone =
                data["phone"]?.toString() ?? "";

            break;
          }
        }

        await prefs.setString(
          "${widget.hotelName}_hotelName",
          savedHotelName,
        );

        await prefs.setString(
          "${widget.hotelName}_address",
          savedAddress,
        );

        await prefs.setString(
          "${widget.hotelName}_phone",
          savedPhone,
        );
      }
    } catch (e) {
      debugPrint("Hotel Load Error: $e");
    }
  }

  // 🔥 ADD THESE TWO FUNCTIONS INSIDE _OrderDetailState

  void editFloor() async {
    TextEditingController controller = TextEditingController(
      text: widget.order.floorNumber?.toString() ?? "",
    );

    final result = await showDialog<String>(
      context: context,
      builder: (_) =>
          AlertDialog(
            title: const Text("Edit Floor"),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: "Enter Floor Number"),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text("Save"),
              ),
            ],
          ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        widget.order.floorNumber = int.tryParse(result);
        widget.order.save();
      });
    }
  }

  void editTable() async {
    TextEditingController controller = TextEditingController(
      text: widget.order.tableNumber?.toString() ?? "",
    );

    final result = await showDialog<String>(
      context: context,
      builder: (_) =>
          AlertDialog(
            title: const Text("Edit Table"),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: "Enter Table Number"),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text("Save"),
              ),
            ],
          ),
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        widget.order.tableNumber = int.tryParse(result);
        widget.order.save();
      });
    }
  }

  // ---------------- LOAD MENU ----------------
  Future<void> loadMenu() async {
    setState(() => isLoadingMenu = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // 🔥 CACHE KEY
      String cacheKey = "${widget.hotelName}_menus";

      // 🔴 1. LOAD FROM CACHE FIRST (INSTANT OFFLINE SUPPORT)
      String? localData = prefs.getString(cacheKey);

      if (localData != null) {
        try {
          final cached = List<Map<String, dynamic>>.from(
            json.decode(localData),
          );

          setState(() {
            menuItems = cached;
            filteredItems = List.from(menuItems);
          });
        } catch (e) {
          print("Cache parse error: $e");
        }
      }

      Map<String, dynamic> data = {};

      // 🔵 2. FETCH FROM FIREBASE / HTTP
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
        final url = Uri.parse(
          "https://adsadmobandfacebook-default-rtdb.firebaseio.com/Restaurant/${widget
              .hotelName}/MenuItems.json",
        );

        final res = await http.get(url);

        if (res.statusCode == 200 && res.body != "null") {
          data = Map<String, dynamic>.from(json.decode(res.body));
        }
      } else {
        final ref = FirebaseDatabase.instance.ref(
          "Restaurant/${widget.hotelName}/MenuItems",
        );

        final snapshot = await ref.get();

        if (snapshot.exists) {
          data = Map<String, dynamic>.from(snapshot.value as Map);
        }
      }

      // 🔥 3. PROCESS + CACHE SAVE
      if (data.isNotEmpty) {
        List<Map<String, dynamic>> itemsList = [];

        data.forEach((categoryKey, categoryValue) {
          if (categoryValue is Map) {
            categoryValue.forEach((itemKey, itemValue) {
              final itemMap = Map<String, dynamic>.from(itemValue);



              // itemsList.add({
              //   "name": itemMap["name"] ?? "",
              //   "price": double.tryParse(itemMap["price"]?.toString() ?? "0") ?? 0,
              //
              //   // 🔥 THIS IS MISSING (MAIN FIX)
              //   "items": itemMap["items"] ?? [],
              //
              // });

              itemsList.add({
                "name": itemMap["name"] ?? "",
                "price": double.tryParse(itemMap["price"]?.toString() ?? "0") ?? 0,
                "items": itemMap["items"] ?? [],

                // 🔥 ADD THIS LINE
                "tokenCategory": itemMap["tokenCategory"] ?? "Kitchen",
              });

            });
          }
        });

        // 🔥 SAVE TO CACHE
        await prefs.setString(cacheKey, json.encode(itemsList));

        setState(() {
          menuItems = itemsList;
          filteredItems = List.from(menuItems);
        });
      }
    } catch (e) {
      debugPrint("Error fetching menu: $e");
    } finally {
      setState(() => isLoadingMenu = false);
    }
  }

  // ---------------- BILL CALCULATION ----------------
  void calculateBill() {
    subTotal = 0;

    // ===== Calculate Subtotal =====
    for (var item in widget.order.items) {
      subTotal += item.price * item.qty;
    }

    // ===== Service =====
    double servicePercent = double.tryParse(serviceController.text) ?? 0;
    serviceCharge =
    serviceEnabled ? subTotal * (servicePercent / 100) : 0;

    // ===== Tax =====
    double taxPercent = double.tryParse(taxController.text) ?? 0;
    taxAmount =
    taxEnabled ? subTotal * (taxPercent / 100) : 0;

    // ===== Gross Total (Subtotal + Service + Tax) =====
    double grossTotal = subTotal + serviceCharge + taxAmount;

    // ===== Discount (Apply after Service & Tax) =====
    double discountPercent = double.tryParse(discountController.text) ?? 0;
    discount = discountEnabled
        ? grossTotal * (discountPercent / 100)
        : 0;

    // ===== Grand Total =====
    grandTotal = grossTotal - discount;

    // ===== Save in Hive =====
    widget.order.subTotal = subTotal;
    widget.order.service = serviceCharge;
    widget.order.tax = taxAmount;
    widget.order.discount = discount;
    widget.order.grandTotal = grandTotal;

    widget.order.save();

    setState(() {});
  }
  void removeItem(int index) {
    setState(() {
      widget.order.items.removeAt(index);
      calculateBill();
    });
  }

  void increaseQty(int index) {
    setState(() {
      widget.order.items[index].qty++;
      calculateBill();
      widget.order.save();
    });
  }

  void decreaseQty(int index) {
    setState(() {
      if (widget.order.items[index].qty > 1) {
        widget.order.items[index].qty--;
        calculateBill();
        widget.order.save();
      }
    });
  }

  // ---------------- SEARCH ----------------
  void searchMenu(String query) {
    final lowerQuery = query.toLowerCase();

    setState(() {
      filteredItems = [...menuItems];

      filteredItems.sort((a, b) {
        final aMatch = a["name"]
            .toString()
            .toLowerCase()
            .startsWith(lowerQuery);

        final bMatch = b["name"]
            .toString()
            .toLowerCase()
            .startsWith(lowerQuery);

        if (aMatch && !bMatch) return -1;
        if (!aMatch && bMatch) return 1;
        return 0;
      });

      filteredItems = filteredItems.where((item) {
        return item["name"]
            .toString()
            .toLowerCase()
            .contains(lowerQuery);
      }).toList();
    });
  }

  // ---------------- ADD ITEM ----------------
  void addItem(Map<String, dynamic> item) {
    setState(() {
      final raw = item["items"];

      List<Map<String, dynamic>> dealItems = [];

      if (raw is List) {
        dealItems = raw
            .where((e) => e != null)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      final newItem = OrderItem(
        name: item["name"] ?? "",
        qty: 1,
        price: (item["price"] ?? 0).toDouble(),

        // 🔥 IMPORTANT FIX
        tokenCategory: item["tokenCategory"] ?? "Kitchen",

        items: dealItems.isEmpty ? null : dealItems,
      );

      widget.order.items.add(newItem);

      widget.order.save(); // 🔥 MUST
      calculateBill();
    });
  }
  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKey: (event) {
          if (event is! RawKeyDownEvent) return;

          final ctrl = event.isControlPressed;
          final key = event.logicalKey;

          // 🖨️ PRINT TOKEN
          if (ctrl && key == LogicalKeyboardKey.keyP) {
            printToken();
          }

          // 🧾 PRINT BILL
          else if (ctrl && key == LogicalKeyboardKey.keyB) {
            printReceipt(
              order: widget.order,
              status: widget.order.status ?? "UNPAID",
            );
          }

          // ➕ NEW ORDER
          else if (ctrl && key == LogicalKeyboardKey.keyN) {
            createNewOrder(); // apna function
          }

          // ❌ ESC (cancel / close dialog)
          else if (key == LogicalKeyboardKey.escape) {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          }

          // 🖥️ F11 FULLSCREEN TOGGLE
          else if (key == LogicalKeyboardKey.f11) {
            toggleFullScreen();
          }
        },


    child:  Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.orange,
          width: 7,
        )
      ),
      child: Scaffold(
        backgroundColor: const Color(0xfff4f6f9),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          title: Text(
            "ORDER #${widget.order.orderId}",
            style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  "Items: ${widget.order.items.length}",
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        ),

        body: Row(
          children: [
          // ================= LEFT SIDE =================
          Expanded(
          flex: 3,
          child: Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ================= ORDER INFO CARD =================
                // ================= ORDER INFO CARD =================
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 🔥 HOTEL NAME CENTER
                      Center(
                        child: Text(
                          widget.hotelName,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),


                      const SizedBox(height: 8),

                      Column(
                        children: [

                          Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: widget.order.orderType == "Dine In"
                                    ? Colors.green.shade100
                                    : widget.order.orderType == "Take Away"
                                    ? Colors.orange.shade100
                                    : Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                widget.order.orderType,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: widget.order.orderType == "Dine In"
                                      ? Colors.green.shade800
                                      : widget.order.orderType == "Take Away"
                                      ? Colors.orange.shade800
                                      : Colors.blue.shade800,
                                ),
                              ),
                            ),
                          ),

                          if (widget.order.orderType == "Delivery") ...[
                            const SizedBox(height: 8),

                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: Colors.blue.shade100),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [

                                  // 👤 CUSTOMER LABEL + EDIT BUTTON
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        "CUSTOMER DETAILS",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),

                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () {
                                          editCustomerDetails(); // 🔥 function bana lena
                                        },
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 6),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "Name: ${widget.order.customerName ?? ''}",
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          "Phone: ${widget.order.customerPhone ?? ''}",
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          "Address: ${widget.order.customerAddress ?? ''}",
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const Divider(height: 20),

                                  // 🚴 RIDER LABEL + EDIT BUTTON
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        "RIDER DETAILS",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),

                                      IconButton(
                                        icon: const Icon(Icons.edit, color: Colors.blue),
                                        onPressed: () {
                                          editRiderDetails(); // 🔥 function bana lena
                                        },
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 6),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          "Name: ${widget.order.riderName ?? 'Not Assigned'}",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          "Phone: ${widget.order.riderPhone ?? ''}",
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],



                        ],
                      ),


                      const SizedBox(height: 20),

                      // 🔥 FLOOR & TABLE EDITABLE
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Floor: ${widget.order.floorNumber ?? "-"}",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: editFloor,
                              ),
                            ],
                          ),

                          Row(
                            children: [
                              Text(
                                "Table: ${widget.order.tableNumber ?? "-"}",
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit, size: 18),
                                onPressed: editTable,
                              ),
                            ],
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // 🔥 DATE & TIME
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Date: ${widget.order.timestamp.day}-${widget.order
                                .timestamp.month}-${widget.order.timestamp.year}",
                            style: const TextStyle(fontSize: 14),
                          ),
                          Text(
                            "Time: ${((widget.order.timestamp.hour % 12 == 0) ? 12 : widget.order.timestamp.hour % 12).toString().padLeft(2, '0')}:${widget.order.timestamp.minute.toString().padLeft(2, '0')} ${widget.order.timestamp.hour >= 12 ? 'PM' : 'AM'}",
                            style: const TextStyle(fontSize: 14),
                          ),



                        ],
                      ),
                    ],
                  ),
                ),
                // ====== HEADER WITH ADD BUTTON ======
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "ORDER ITEMS",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.yellow,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () =>
                          showDialog(
                            context: context,
                            builder: (_) => menuDialog(),
                          ),
                      icon: const Icon(Icons.add),
                      label: const Text("Add"),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // ====== ITEM LIST ======
                Expanded(
                  child: widget.order.items.isEmpty
                      ? const Center(
                    child: Text(
                      "No Items Added",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                      : ListView.builder(
                    itemCount: widget.order.items.length,
                    itemBuilder: (context, index) {
                      final item = widget.order.items[index];

                      final dealList = (item.items is List)
                          ? List<Map<String, dynamic>>.from(
                          (item.items as List)
                              .where((e) => e != null)
                              .map((e) => Map<String, dynamic>.from(e))
                      )
                          : <Map<String, dynamic>>[];

                      final isDeal =
                          item.items != null &&
                              item.items is List &&
                              (item.items as List).isNotEmpty;
                      final isExpanded = expandedIndex == index;

                      return Column(
                        children: [
                          // ================= MAIN ITEM =================
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.grey.shade200,
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // NAME TAP AREA
                                Expanded(
                                  child: InkWell(
                                    onTap: () {
                                      if (isDeal) {
                                        setState(() {
                                          expandedIndex =
                                          isExpanded ? null : index;
                                        });
                                      }
                                    },
                                    child: Row(
                                      children: [
                                        Text(
                                          item.name,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (isDeal)
                                          const Icon(Icons.arrow_drop_down),
                                      ],
                                    ),
                                  ),
                                ),

                                IconButton(
                                  icon: const Icon(Icons.remove_circle,
                                      color: Colors.red),
                                  onPressed: () => decreaseQty(index),
                                ),

                                Container(
                                  width: 40,
                                  alignment: Alignment.center,
                                  child: Text(
                                    "${item.qty}",
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),

                                IconButton(
                                  icon: const Icon(Icons.add_circle,
                                      color: Colors.green),
                                  onPressed: () => increaseQty(index),
                                ),

                                const SizedBox(width: 10),

                                Text(
                                  "Rs ${(item.price * item.qty).toStringAsFixed(0)}",
                                ),

                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => removeItem(index),
                                ),
                              ],
                            ),
                          ),

                          // ================= DEAL SUB ITEMS =================
                          if (isDeal && isExpanded)
                            Padding(
                              padding: const EdgeInsets.only(left: 25, bottom: 10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: dealList.map((d) {
                                  return Text("• ${d["name"]} x${d["qty"]}");
                                }).toList(),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                )
              ],
            ),
          ),
        ),

        // ================= RIGHT SIDE =================
        Container(
          width: 350,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(left: BorderSide(color: Colors.grey, width: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "BILL SUMMARY",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 20),

              // Subtotal
              rowItem("Sub Total", subTotal),

              const SizedBox(height: 10),

              // Service Charge Toggle + % Input
              Row(
                children: [
              Expanded(
              child: Row(
              children: [
                Switch(
                value: serviceEnabled,
                onChanged: (v) {
                  setState(() {
                    serviceEnabled = v;
                    calculateBill();
                  });

                  saveSettings();
                },
              ),
              const Text("Service Charge"),
            ],
          ),
        ),
        SizedBox(
            width: 60,
            child: TextField(
                controller: serviceController,
                enabled: serviceEnabled,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                ),
              onChanged: (_) {
                calculateBill();
                saveSettings();
              },
        ),
      ),
      const SizedBox(width: 4),
      const Text("%"),
      ],
      ),

      // TAX Toggle
      Row(
      children: [
      Expanded(
      child: Row(
      children: [
      Switch(
      value: taxEnabled,
      onChanged: (v) {
      setState(() {
      taxEnabled = v;
      calculateBill();
      });

      saveSettings();

      },
      ),
      const Text("Tax"),
      ],
      ),
      ),
      SizedBox(
      width: 60,
      child: TextField(
      controller: taxController,
      enabled: taxEnabled,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
      isDense: true,
      border: OutlineInputBorder(),
      contentPadding: EdgeInsets.symmetric(
      horizontal: 6,
      vertical: 4,
      ),
      ),
      onChanged: (_) {
      calculateBill();
      saveSettings();
      },
      ),
      ),
      const SizedBox(width: 4),
      const Text("%"),
      ],
      ),

      const SizedBox(height: 10),

      rowItem("Tax (${taxController.text}%)", taxAmount),

      const SizedBox(height: 10),

      // Show calculated service charge
      rowItem("Service (${serviceController.text}%)", serviceCharge),

      const SizedBox(height: 15),

      // Discount
      TextField(
      controller: discountController,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
      labelText: "Discount",
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      ),
      ),
      onChanged: (_) => calculateBill(),
      ),

      const Spacer(),

      // Total
      Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
      color: Colors.green.shade600,
      borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
      const Text(
      "TOTAL",
      style: TextStyle(
      color: Colors.white,
      fontSize: 18,
      fontWeight: FontWeight.bold,
      ),
      ),
      Text(
      "Rs ${grandTotal.toStringAsFixed(2)}",
      style: const TextStyle(
      color: Colors.white,
      fontSize: 20,
      fontWeight: FontWeight.bold,
      ),
      ),
      ],
      ),
      ),

      const SizedBox(height: 15),

      // PAY BUTTON
      SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
      style: ElevatedButton.styleFrom(
      backgroundColor: Colors.black,
      shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      ),
      ),
      onPressed: () {
      showPaymentDialog();
      },
      child: const Text(
      "PAY NOW",
      style: TextStyle(fontSize: 16),
      ),
      ),
      ),

      const SizedBox(height: 10),

      // 🖨️ PRINT BUTTON
      SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
      icon: const Icon(Icons.print),
      label: const Text("PRINT Token",style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
      backgroundColor: Colors.blue,
      shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      ),
      ),
      onPressed: () async {

      // await printCategoryTokens();
      await printToken();
      }
      ),
      ),

      const SizedBox(height: 10),


      SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
      icon: const Icon(Icons.print),
      label: const Text("PRINT BILL",style: TextStyle(color: Colors.white),),
      style: ElevatedButton.styleFrom(
      backgroundColor: Colors.blue,
      shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      ),
      ),

      onPressed: () async {
      if (widget.order.items.isEmpty) return;


      await printReceipt(
      order: widget.order,
      status: widget.order.status ?? "UNPAID",
      );
      },
      ),
      ),
      ],
      ),
      ),
      ]
      ,
      )
      ,
      ),
    )
    );
  }


  Widget rowItem(String title, double value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            "Rs ${value.toStringAsFixed(2)}",
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }




  Widget menuDialog() {
    return StatefulBuilder(
      builder: (context, dialogSetState) {
        return AlertDialog(
          title: TextField(
            controller: searchController,
            decoration: const InputDecoration(
              labelText: "Search Item",
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
            onChanged: (query) {
              dialogSetState(() {
                filteredItems = menuItems.where((item) {
                  return item["name"]
                      .toString()
                      .toLowerCase()
                      .contains(query.toLowerCase());
                }).toList();
              });
            },
          ),

          content: SizedBox(
            width: 800,
            height: 400,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 10,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 2,
              ),
              itemCount: filteredItems.length,
              itemBuilder: (context, index) {
                final item = filteredItems[index];

                return InkWell(
                  onTap: () {
                    print("ITEM: $item"); // 🔥 DEBUG IMPORTANT
                    addItem(item);
                    Navigator.pop(context);
                  },
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade200,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(item["name"]),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  void showPaymentDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Select Payment Method"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // ===== CASH =====
              ListTile(
                title: const Text("Cash"),
                onTap: () {
                  Navigator.pop(context); // close method select
                  showCashDialog(); // Cash dialog will handle received & returned
                },
              ),

              // ===== JAZZCASH =====
              ListTile(
                title: const Text("JazzCash"),
                onTap: () async {
                  await _markOrderPaid("JazzCash");
                },
              ),

              // ===== EASYPaisa =====
              ListTile(
                title: const Text("Easypaisa"),
                onTap: () async {
                  await _markOrderPaid("Easypaisa");
                },
              ),

              // ===== BANK =====
              ListTile(
                title: const Text("Bank Account"),
                onTap: () async {
                  await _markOrderPaid("Bank Account");
                },
              ),
            ],
          ),
        );
      },
    );
  }

// ===== HELPER FUNCTION FOR NON-CASH PAYMENTS =====
  Future<void> _markOrderPaid(String paymentMethod) async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {
      final historyBox = Hive.box<Order>('orders_history');



      widget.order.status = "paid";
      widget.order.paymentMethod = paymentMethod;
      widget.order.receivedAmount = widget.order.grandTotal;
      widget.order.returnedAmount = 0;
      widget.order.timestamp = DateTime.now();

      await widget.order.save();

      // Inventory
      await deductInventory(widget.order);

      final orderForHistory = Order(
        hotelName: widget.hotelName,
        orderId: widget.order.orderId,
        orderNumber: widget.order.orderNumber,
        orderType: widget.order.orderType,
        tableNumber: widget.order.tableNumber,
        floorNumber: widget.order.floorNumber,
        items: widget.order.items
            .map(
              (e) => OrderItem(
            name: e.name,
            qty: e.qty,
            price: e.price,
            items: e.items,
            tokenCategory: e.tokenCategory,
          ),
        )
            .toList(),
        subTotal: widget.order.subTotal,
        service: widget.order.service,
        discount: widget.order.discount,
        grandTotal: widget.order.grandTotal,
        tax: widget.order.tax,
        status: widget.order.status,
        paymentMethod: widget.order.paymentMethod,
        receivedAmount: widget.order.receivedAmount,
        returnedAmount: widget.order.returnedAmount,
        timestamp: widget.order.timestamp,
        inventoryDeducted: widget.order.inventoryDeducted,
        firebaseSynced: false,
      );

      // Save in history
      await historyBox.add(orderForHistory);

      try {
         uploadSalesSummary(orderForHistory, widget.hotelName);

        orderForHistory.firebaseSynced = true;
        await orderForHistory.save();
      } catch (e) {
        orderForHistory.firebaseSynced = false;
        await orderForHistory.save();
      }

// 🖨️ Print after sync/offline check
      try {
        await printReceipt(
          order: widget.order,
          status: "PAID",
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "Order saved successfully. Printer failed: $e",
              ),
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
        Navigator.pop(context);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Paid via $paymentMethod"),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }// ===== CASH DIALOG =====
  void showCashDialog() {
    receivedController.clear();
    returnedAmount = 0;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Text(
            "Cash Payment",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 🔹 TOTAL BILL (BIG & HIGHLIGHTED)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "Total: Rs ${widget.order.grandTotal.toStringAsFixed(0)}",
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // 🔹 RECEIVED INPUT (BIGGER)
                  TextField(
                    controller: receivedController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                      labelText: "Received Amount",
                      labelStyle: const TextStyle(fontSize: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      prefixIcon: const Icon(Icons.money),
                    ),
                    onChanged: (value) {
                      double received = double.tryParse(value) ?? 0;
                      setStateDialog(() {
                        returnedAmount = received - widget.order.grandTotal;
                      });
                    },
                  ),

                  const SizedBox(height: 15),

                  // 🔹 RETURN AMOUNT (BIG + COLOR)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: returnedAmount >= 0
                          ? Colors.blue.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      "Return: Rs ${returnedAmount > 0 ? returnedAmount
                          .toStringAsFixed(0) : "0"}",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: returnedAmount >= 0 ? Colors.blue : Colors.red,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),

          // 🔹 ACTION BUTTONS (PRO STYLE)
          actionsPadding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 10),
          actions: [
            SizedBox(
              width: 100,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
            ),
            SizedBox(
              width: 120,
              height: 45,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isProcessing
                    ? null
                    : () async {

                  if (isProcessing) return;

                  setState(() {
                    isProcessing = true;
                  });

                  try {
                    double received =
                        double.tryParse(receivedController.text) ?? 0;

                    widget.order.status = "paid";
                    widget.order.paymentMethod = "Cash";
                    widget.order.receivedAmount = received;
                    widget.order.returnedAmount =
                        received - widget.order.grandTotal;
                    widget.order.timestamp = DateTime.now();

                    final historyBox = Hive.box<Order>('orders_history');

                    // Already processed?
                    final alreadyExists = historyBox.values.any(
                          (o) => o.orderId == widget.order.orderId,
                    );

                    if (alreadyExists) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text("Order already processed"),
                          ),
                        );
                      }
                      return;
                    }

                    await widget.order.save();

                    // Deduct inventory
                    await deductInventory(widget.order);

                    // Create history
                    final orderForHistory = Order(
                      hotelName: widget.hotelName,
                      orderId: widget.order.orderId,
                      orderNumber: widget.order.orderNumber,
                      orderType: widget.order.orderType,
                      tableNumber: widget.order.tableNumber,
                      floorNumber: widget.order.floorNumber,
                      items: widget.order.items
                          .map((e) => OrderItem(
                        name: e.name,
                        qty: e.qty,
                        price: e.price,
                        items: e.items != null
                            ? List<Map<String, dynamic>>.from(
                          (e.items as List<dynamic>)
                              .map((d) => Map<String, dynamic>.from(d)),
                        )
                            : null,
                      ))
                          .toList(),
                      subTotal: widget.order.subTotal,
                      service: widget.order.service,
                      discount: widget.order.discount,
                      grandTotal: widget.order.grandTotal,
                      tax: widget.order.tax,
                      status: widget.order.status,
                      paymentMethod: widget.order.paymentMethod,
                      receivedAmount: widget.order.receivedAmount,
                      returnedAmount: widget.order.returnedAmount,
                      timestamp: widget.order.timestamp,
                      inventoryDeducted: widget.order.inventoryDeducted,
                      firebaseSynced: true, // <-- reserve immediately
                    );

                    await historyBox.add(orderForHistory);

                    // Sync

                    try {
                       uploadSalesSummary(
                        orderForHistory,
                        widget.hotelName,
                      );

                      orderForHistory.firebaseSynced = true;
                      await orderForHistory.save();
                    } catch (e) {
                      orderForHistory.firebaseSynced = false;
                      await orderForHistory.save();
                    }
                    // Print
                    try {
                      await printReceipt(
                        order: widget.order,
                        status: "PAID",
                      );
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              "Order saved successfully. Printer failed: $e",
                            ),
                          ),
                        );
                      }
                    }

                    // Close dialog LAST
                    if (mounted) {
                      Navigator.pop(context);
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Order Paid"),
                        ),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() {
                        isProcessing = false;
                      });
                    }
                  }
                },
                child: isProcessing
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
                    : const Text(
                  "Confirm",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }


  Widget infoTile(String title, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }


  Future<void> printReceipt({
    String status = "UNPAID",
    required Order order,
  })




  async {
    String hotelName = savedHotelName.isNotEmpty
        ? savedHotelName
        : widget.hotelName;

    String address = savedAddress;

    String phone = savedPhone;

    await printLanRaw(
      widget.order.items.map((e) {
        return {
          "name": e.name,
          "qty": e.qty,
          "price": e.price,
          "items": e.items == null
              ? null
              : e.items!.map((d) {
            return {
              "name": d["name"],
              "qty": d["qty"],
            };
          }).toList(),
        };
      }).toList(),

      hotelName,
      widget.order.orderType,
      widget.order.subTotal,
      widget.order.grandTotal,

      serviceEnabled,
      taxEnabled,

      serviceController.text,
      taxController.text,
      discountController.text,

      address,
      phone,
      status,
    );
  }

  Future<void> printLanRaw(List<Map<String, dynamic>> cart,
      String hotelName,
      String selectedOrderType,
      double subTotal,
      double grandTotal,
      bool serviceEnabled,
      bool taxEnabled,
      String servicePercent,
      String taxPercent,
      String discountPercent,
      String address,
      String phone,
      String status,)
  async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    List<int> bytes = [];

    // 🔹 Header
    bytes += generator.text(
      hotelName,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );


    if (address
        .trim()
        .isNotEmpty) {
      bytes += generator.text(
        address.trim(),
        styles: const PosStyles(
          align: PosAlign.center,
        ),
      );
    }


    if (phone.isNotEmpty) {
      bytes += generator.text(
        "Ph: $phone",
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    bytes += generator.hr();

    bytes += generator.text(
      "ORDER #${widget.order.orderId}",
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );

    bytes += generator.text(
      "Order Type: $selectedOrderType",
      styles: const PosStyles(align: PosAlign.center),
    );



if (selectedOrderType == "Delivery") {
  bytes += generator.hr();

  bytes += generator.text(
    "Customer: ${widget.order.customerName ?? ''}",
    styles: const PosStyles(align: PosAlign.left),
  );

  bytes += generator.text(
    "Phone: ${widget.order.customerPhone ?? ''}",
    styles: const PosStyles(align: PosAlign.left),
  );

  bytes += generator.text(
    "Address: ${widget.order.customerAddress ?? ''}",
    styles: const PosStyles(align: PosAlign.left),
  );

  bytes += generator.feed(1);

  bytes += generator.text(
    "Rider: ${widget.order.riderName ?? ''}",
    styles: const PosStyles(align: PosAlign.left),
  );

  bytes += generator.text(
    "Rider Phone: ${widget.order.riderPhone ?? ''}",
    styles: const PosStyles(align: PosAlign.left),
  );

  bytes += generator.hr();
}




























    final now = DateTime.now();
    int hour = now.hour;
    String period = "AM";

    if (hour >= 12) {
      period = "PM";
      if (hour > 12) hour -= 12;
    } else if (hour == 0) {
      hour = 12;
    }

    bytes += generator.text(
      "${now.day}-${now.month}-${now.year} $hour:${now.minute
          .toString()
          .padLeft(2, '0')} $period",
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.text(
      status,
      styles: PosStyles(
        align: PosAlign.center,
        bold: true,
        reverse: status == "PAID",
      ),
    );

    bytes += generator.hr();

    final Map<String, Map<String, dynamic>> groupedItems = {};


    for (var item in cart) {
      String name = item["name"].toString();

      if (groupedItems.containsKey(name)) {
        groupedItems[name]!["qty"] += item["qty"] as int;
      } else {
        groupedItems[name] = {
          "name": name,
          "qty": item["qty"],
          "price": item["price"],
        };
      }
    }


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

// 1️⃣ FIRST: GROUP NORMAL ITEMS + COMBINE QTY + MERGE DEAL ITEMS
    Map<String, Map<String, dynamic>> grouped = {};

    for (var item in cart) {
      final name = item["name"]?.toString() ?? "";
      final qty = (item["qty"] ?? 1);

      if (grouped.containsKey(name)) {
        grouped[name]!["qty"] += qty;
      } else {
        grouped[name] = {
          "name": name,
          "qty": qty,
          "price": item["price"] ?? 0,
          "items": item["items"], // 👈 deal items bhi store
        };
      }
    }
    for (var item in grouped.values) {

      final name = item["name"];
      final qty = item["qty"];
      final price = (item["price"] ?? 0) * qty;

      // ================= MAIN ITEM =================
      bytes += generator.row([
        PosColumn(
          text: name.toString(),
          width: 7,
          styles: const PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: "$qty",
          width: 2,
          styles: const PosStyles(align: PosAlign.center),
        ),
        PosColumn(
          text: "${price.toInt()}",
          width: 3,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);

      // ================= DEAL ITEMS =================
      final rawDeal = item["items"];

      List<Map<String, dynamic>> dealItems = [];

      if (rawDeal is List) {
        dealItems = rawDeal
            .where((e) => e != null)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }

      if (rawDeal is String) {
        try {
          final decoded = jsonDecode(rawDeal);
          if (decoded is List) {
            dealItems = decoded
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          }
        } catch (_) {}
      }

      // 🔥 IMPORTANT FIX: DEAL ITEMS PRINT WITH MULTIPLY QTY
      for (var d in dealItems) {
        final dName = d["name"] ?? "";
        final dQty = (d["qty"] ?? 1) * qty; // 👈 MAIN FIX

        bytes += generator.row([
          PosColumn(
            text: "   • $dName",
            width: 7,
            styles: const PosStyles(align: PosAlign.left),
          ),
          PosColumn(
            text: "$dQty",
            width: 2,
            styles: const PosStyles(align: PosAlign.center),
          ),
          PosColumn(text: "", width: 3),
        ]);
      }
    }










    // for (var item in groupedItems.values) {
    //   bytes += generator.row([
    //     PosColumn(
    //       text: item["name"].toString(),
    //       width: 7,
    //       styles: PosStyles(align: PosAlign.left),
    //     ),
    //     PosColumn(
    //       text: "${item["qty"]}",
    //       width: 2,
    //       styles: PosStyles(align: PosAlign.center),
    //     ),
    //     PosColumn(
    //       text: "${(item["price"] * item["qty"]).toInt()}",
    //       width: 3,
    //       styles: PosStyles(align: PosAlign.right),
    //     ),
    //   ]);
    // }

    bytes += generator.hr();

    double serviceAmount = serviceEnabled
        ? subTotal * ((double.tryParse(servicePercent) ?? 0) / 100)
        : 0;

    double taxAmount = taxEnabled
        ? subTotal * ((double.tryParse(taxPercent) ?? 0) / 100)
        : 0;

    double discountAmount = (double.tryParse(discountPercent) ?? 0) > 0
        ? subTotal * ((double.parse(discountPercent)) / 100)
        : 0;

    bytes += generator.row([
      PosColumn(text: "Sub Total", width: 6),
      PosColumn(
        text: "Rs ${subTotal.toInt()}",
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    if (serviceEnabled) {
      bytes += generator.row([
        PosColumn(text: "Service ($servicePercent%)", width: 6),
        PosColumn(
          text: "Rs ${serviceAmount.toInt()}",
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    if (taxEnabled) {
      bytes += generator.row([
        PosColumn(text: "Tax ($taxPercent%)", width: 6),
        PosColumn(
          text: "Rs ${taxAmount.toInt()}",
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    if ((double.tryParse(discountPercent) ?? 0) > 0) {
      bytes += generator.row([
        PosColumn(text: "Discount ($discountPercent%)", width: 6),
        PosColumn(
          text: "- Rs ${discountAmount.toInt()}",
          width: 6,
          styles: const PosStyles(align: PosAlign.right),
        ),
      ]);
    }


    bytes += generator.hr();

// 👇 YAHAN ADD KARO
    String paymentMethod = "";
    String receivedText = "0";
    String changeText = "0";

    if (status == "PAID") {
      paymentMethod = widget.order.paymentMethod ?? "Cash";
      receivedText =
          (widget.order.receivedAmount ?? 0).toStringAsFixed(0);
      changeText =
          (widget.order.returnedAmount ?? 0).toStringAsFixed(0);
    }


    bytes += generator.row([
      PosColumn(
        text: "Received",
        width: 6,
      ),
      PosColumn(
        text: "Rs $receivedText",
        width: 6,
        styles: const PosStyles(
          align: PosAlign.right,
        ),
      ),
    ]);
    bytes += generator.row([
      PosColumn(
        text: "Change",
        width: 6,
      ),
      PosColumn(
        text: "Rs $changeText",
        width: 6,
        styles: const PosStyles(
          align: PosAlign.right,
        ),
      ),
    ]);
    if (status == "PAID") {
      bytes += generator.row([
        PosColumn(
          text: "Payment",
          width: 6,
        ),
        PosColumn(
          text: paymentMethod,
          width: 6,
          styles: const PosStyles(
            align: PosAlign.right,
          ),
        ),
      ]);
    }

    bytes += generator.hr();

    bytes += generator.text(
      "TOTAL: Rs ${grandTotal.toInt()}",
      styles: const PosStyles(
        bold: true,
        align: PosAlign.right,
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

    // 🔥 PRINT WITH FULL ERROR HANDLING
    await _sendToPrinter(bytes);
  }


  Future<void> _sendToPrinter(List<int> bytes) async {



    try {
      final prefs = await SharedPreferences.getInstance();
      String ip = prefs.getString("printer_ip") ?? "";

      // 🔥 OFFLINE SAFE FALLBACK IP
      if (ip.isEmpty) {
        ip = "192.168.0.142"; // default printer IP
        _showSnack("⚠️ Using default printer IP");
      }

      Socket socket;

      try {
        socket = await Socket.connect(
          ip,
          9100,
          timeout: const Duration(seconds: 2),
        );
      } catch (e) {
        _showSnack("❌ Printer not connected");
        return;
      }

      try {





        socket.add(bytes);
        await socket.flush();
        await Future.delayed(const Duration(milliseconds: 100));
        socket.destroy();

        _showSnack("✅ Printed successfully");
      } catch (e) {
        _showSnack("❌ Print failed");
      }
    } catch (e) {
      _showSnack("❌ Unexpected error");
    }
  }

  Future<String> getPrinterIp() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("printer_ip") ?? "192.168.0.142";
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> printDrinksToken()

  async {
    final drinksItems = widget.order.items.where((item) {
      return [
        "Pepsi",
        "7up",
        "Coke",
        "Juice",
        "Tea",
        "Coffee"
      ].contains(item.name);
    }).toList();

    if (drinksItems.isEmpty) return;
  }

  Future<void> printToken() async {
    for (var item in widget.order.items) {
      print("DEBUG ITEM => ${item.name}");
      print("TOKEN CATEGORY => ${item
          .tokenCategory}");
    }

    if (widget.order.items.length <= widget.order.lastPrintedCount) {
      _showSnack("No New Items");
      return;
    }

    final newItems = widget.order.items.sublist(widget.order.lastPrintedCount);

    Map<String, List<OrderItem>> groupedItems = {};

    for (var item in newItems) {

      // 🔥 FIX: DIRECT FIELD USE
      String category = item.tokenCategory ?? "Kitchen";

      groupedItems.putIfAbsent(category, () => []);
      groupedItems[category]!.add(item);
    }

    for (var entry in groupedItems.entries) {
      await printSingleCategoryToken(entry.key, entry.value);
    }

    widget.order.lastPrintedCount = widget.order.items.length;
    await widget.order.save();

    _showSnack("Token Printed");
  }

  Future<void> printSingleCategoryToken(
      String category,
      List<OrderItem> items,
      ) async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    List<int> bytes = [];

    final now = DateTime.now();

    String orderType =
    (widget.order.orderType ?? "DINE IN").toUpperCase();

    // 🔥 HEADER
    bytes += generator.text(
      orderType,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );

    bytes += generator.text(
      category.toUpperCase(),
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
      ),
    );

    bytes += generator.text(
      "ORDER #${widget.order.orderId}",
      styles: const PosStyles(
        align: PosAlign.center,
      ),
    );

    bytes += generator.hr();

    // 🔥 TABLE INFO
    bytes += generator.row([
      PosColumn(
        text: "Floor: ${widget.order.floorNumber ?? "-"}",
        width: 6,
      ),
      PosColumn(
        text: "Table: ${widget.order.tableNumber ?? "-"}",
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    // 🔥 TIME FORMAT (12-hour AM/PM FIX)
    int hour = now.hour;
    String period = "AM";

    if (hour >= 12) {
      period = "PM";
      if (hour > 12) hour -= 12;
    }

    if (hour == 0) {
      hour = 12;
    }

    String time =
        "$hour:${now.minute.toString().padLeft(2, '0')} $period";

    bytes += generator.row([
      PosColumn(
        text: "${now.day}/${now.month}/${now.year}",
        width: 6,
      ),
      PosColumn(
        text: time,
        width: 6,
        styles: const PosStyles(align: PosAlign.right),
      ),
    ]);

    bytes += generator.hr();

    // 🔥 ITEM HEADER
    bytes += generator.row([
      PosColumn(
        text: "Item",
        width: 3,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: "Qty",
        width: 9,
        styles: const PosStyles(
          bold: true,
          align: PosAlign.right,
        ),
      ),
    ]);

    bytes += generator.hr();

    // 🔥 ITEMS
    for (var item in items) {
      bytes += generator.row([
        PosColumn(
          text: item.name,
          width: 8,
          styles: const PosStyles(
            align: PosAlign.left,
          ),
        ),
        PosColumn(
          text: "${item.qty}",
          width: 4,
          styles: const PosStyles(
            bold: true,
            align: PosAlign.right,
          ),
        ),
      ]);
    }

    bytes += generator.hr();

    // 🔥 TOTAL
    int totalQty = items.fold(0, (sum, item) => sum + item.qty);

    bytes += generator.row([
      PosColumn(
        text: "TOTAL",
        width: 8,
        styles: const PosStyles(bold: true),
      ),
      PosColumn(
        text: "$totalQty",
        width: 4,
        styles: const PosStyles(
          align: PosAlign.right,
          bold: true,
        ),
      ),
    ]);

    bytes += generator.feed(1);
    bytes += generator.cut();

    try {
      await _sendToPrinter(bytes);
    } catch (e) {
      print("Printer error but ignored: $e");
    }

    await saveTokenHistory(category, items);
  }






  Future<void> saveTokenHistory(String category,
      List<OrderItem> items,)
  async {
    final box =
    await Hive.openBox<TokenHistory>("tokenHistory");

    await box.add(
      TokenHistory(
        orderId: widget.order.orderId,
        orderNumber: widget.order.orderId,
        orderType: widget.order.orderType ?? "DINE IN",
        category: category,
        dateTime: DateTime.now().toString(),


        tableNumber: widget.order.tableNumber ?? 0,
        floorNumber: widget.order.floorNumber ?? 0,
        items: items.map((e) =>
        "${e.qty} x ${e.name}").toList(),
      ),
    );
  }

  void editCustomerDetails() {
    TextEditingController nameController =
    TextEditingController(text: widget.order.customerName ?? "");
    TextEditingController phoneController =
    TextEditingController(text: widget.order.customerPhone ?? "");
    TextEditingController addressController =
    TextEditingController(text: widget.order.customerAddress ?? "");

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Customer Details"),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: "Phone"),
              ),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: "Address"),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),

            ElevatedButton(
              onPressed: () {
                setState(() {
                  widget.order.customerName = nameController.text;
                  widget.order.customerPhone = phoneController.text;
                  widget.order.customerAddress = addressController.text;
                });

                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }

  void editRiderDetails() {
    TextEditingController nameController =
    TextEditingController(text: widget.order.riderName ?? "");
    TextEditingController phoneController =
    TextEditingController(text: widget.order.riderPhone ?? "");

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Edit Rider Details"),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Rider Name"),
              ),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: "Rider Phone"),
              ),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),

            ElevatedButton(
              onPressed: () {
                setState(() {
                  widget.order.riderName = nameController.text;
                  widget.order.riderPhone = phoneController.text;
                });

                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );
  }}



Future<void> uploadSalesSummary(Order order, String hotelName) async {
  try {
    final db = FirebaseDatabase.instance.ref();

    final now = DateTime.now();

    final day =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final month =
        "${now.year}-${now.month.toString().padLeft(2, '0')}";

    // Daily Summary
    await db
        .child("Restaurant/$hotelName/Sales/Daily/$day")
        .update({
      "sale": ServerValue.increment(order.grandTotal),
      "service": ServerValue.increment(order.service),
      "tax": ServerValue.increment(order.tax),
      "orders": ServerValue.increment(1),
    });

    // Monthly Summary
    await db
        .child("Restaurant/$hotelName/Sales/Monthly/$month")
        .update({
      "sale": ServerValue.increment(order.grandTotal),
      "service": ServerValue.increment(order.service),
      "tax": ServerValue.increment(order.tax),
      "orders": ServerValue.increment(1),
    });

    debugPrint("✅ Sales Summary Uploaded");
  } catch (e) {
    debugPrint("❌ uploadSalesSummary Error: $e");
    rethrow;
  }
}

