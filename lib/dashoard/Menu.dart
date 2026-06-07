import 'dart:convert';
import 'dart:io';
import 'package:esc_pos_printer/esc_pos_printer.dart';
import 'package:esc_pos_utils/esc_pos_utils.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_reorderable_grid_view/widgets/reorderable_builder.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/gestures.dart';
import 'package:image_picker/image_picker.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:reorderables/reorderables.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';


import 'package:flutter/services.dart';



import '../models/order_model.dart';

class Menu extends StatefulWidget {
  final String hotelName;


  const Menu({super.key, required this.hotelName});

  @override
  State<Menu> createState() => _Menu();
}






// ================= SCROLL BEHAVIOR =================
class MyCustomScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices =>
      {
        PointerDeviceKind.mouse,
        PointerDeviceKind.touch,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}

class _Menu extends State<Menu> {
  List<String> categories = [];
  Map<String, List<Map>> menuItems = {};
  String selectedCategory = "";
  String selectedCartItem = "";

  String orderType = "Dine In";

  List<Map<String, dynamic>> cart = [];
  double total = 0;

  double discount = 0;
  double servicePercent = 8;
  double subTotal = 0;
  double grandTotal = 0;


  String customerName = "";
  String customerPhone = "";

  String hotelName = "";
  String address = "";
  String phone = "";

  final TextEditingController discountController = TextEditingController(
    text: "0",
  );
  late bool isDesktop = MediaQuery
      .of(context)
      .size
      .width > 1000;

  bool serviceEnabled = true;
  bool taxEnabled = false;

  TextEditingController serviceController = TextEditingController(text: "8");

  TextEditingController taxController = TextEditingController(text: "5");

  final ScrollController cartScrollController = ScrollController();
  final ScrollController categoryScrollController = ScrollController();
  String selectedOrderType = "Dine In"; // default value

  @override
  void initState() {
    super.initState();
    loadMenu();
    loadSwitchStates();
    loadHotelInfo();
    loadSavedHotelInfo(); // offline data

    loadSettings();


  }






  Future<void> loadSavedHotelInfo() async {
    final prefs = await SharedPreferences.getInstance();

    hotelName =
        prefs.getString("${widget.hotelName}_hotelName") ??
            widget.hotelName;

    address =
        prefs.getString("${widget.hotelName}_address") ?? "";

    phone =
        prefs.getString("${widget.hotelName}_phone") ?? "";

    if (mounted) {
      setState(() {});
    }
  }
  Future<void> loadHotelInfo() async {
    final prefs = await SharedPreferences.getInstance();

    // ================= LOAD SAVED DATA FIRST =================
    hotelName = prefs.getString("${widget.hotelName}_hotelName") ??
        widget.hotelName;

    address = prefs.getString("${widget.hotelName}_address") ?? "";

    phone = prefs.getString("${widget.hotelName}_phone") ?? "";

    if (mounted) {
      setState(() {});
    }

    try {
      final ref = FirebaseDatabase.instance.ref(
        "Restaurant/${widget.hotelName}/Users",
      );

      final snapshot = await ref.get();

      if (snapshot.exists) {
        final usersMap =
        Map<String, dynamic>.from(snapshot.value as Map);

        String tempHotelName = hotelName;
        String tempAddress = address;
        String tempPhone = phone;

        usersMap.forEach((key, value) {
          final data = Map<String, dynamic>.from(value);

          tempHotelName =
              data["HotelName"]?.toString() ?? tempHotelName;

          tempAddress =
              data["address"]?.toString() ?? tempAddress;

          tempPhone =
              data["phone"]?.toString() ?? tempPhone;
        });

        hotelName = tempHotelName;
        address = tempAddress;
        phone = tempPhone;

        // ================= SAVE TO SHAREDPREFERENCES =================
        await prefs.setString(
          "${widget.hotelName}_hotelName",
          hotelName,
        );

        await prefs.setString(
          "${widget.hotelName}_address",
          address,
        );

        await prefs.setString(
          "${widget.hotelName}_phone",
          phone,
        );

        print("HOTEL SAVED: $hotelName");
        print("ADDRESS SAVED: $address");
        print("PHONE SAVED: $phone");

        if (mounted) {
          setState(() {});
        }
      }
    } catch (e) {
      print("Firebase Error: $e");

      // Offline mode - SharedPreferences data already loaded above
      print("Using Offline Saved Data");
      print("Hotel: $hotelName");
      print("Address: $address");
      print("Phone: $phone");
    }
  }  // Future<void> loadHotelInfo() async {



  void resetOrderTypeToDineIn() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      selectedOrderType = "Dine In";
      serviceEnabled = true;
    });

    await prefs.setString('orderType', "Dine In");
    await prefs.setBool('serviceEnabled', true);
  }
  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      serviceEnabled = prefs.getBool('serviceEnabled') ?? true;
      selectedOrderType = prefs.getString('orderType') ?? "Dine In";
    });

    calculateTotal();
  }

  void loadSwitchStates() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      serviceEnabled = prefs.getBool('serviceEnabled') ?? true;
      taxEnabled = prefs.getBool('taxEnabled') ?? false;
    });
  }

  @override
  void dispose() {
    cartScrollController.dispose();
    categoryScrollController.dispose(); // 🔥 add this

    saveMenuOrder();

    super.dispose();
  }





  Future<bool> showDeliveryDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();

    bool result = false;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Delivery Details"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: "Customer Name",
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Phone Number",
                ),
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
                customerName = nameController.text.trim();
                customerPhone = phoneController.text.trim();

                result = true;
                Navigator.pop(context);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    return result;
  }









  // ================= FETCH WITH CACHE =================
  Future<void> loadMenu() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // 🔹 Load local cached menu first
    String? localData = prefs.getString("${widget.hotelName}_menu");
    if (localData != null) {
      populateMenu(json.decode(localData));
    }

    try {
      Map<String, dynamic> data = {};

      if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
        final url = Uri.parse(
          "https://adsadmobandfacebook-default-rtdb.firebaseio.com/Restaurant/${widget
              .hotelName}/MenuItems.json",
        );
        final res = await http.get(url);
        if (res.statusCode == 200 && res.body != "null") {
          data = json.decode(res.body);
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

      if (data.isNotEmpty) {
        await prefs.setString("${widget.hotelName}_menu", json.encode(data));
        populateMenu(data);
      }
    } catch (e) {
      debugPrint("Offline mode");
    }
  }

  void populateMenu(Map data) async {
    categories.clear();
    menuItems.clear();

    data.forEach((catKey, catValue) {
      categories.add(catKey);
      menuItems[catKey] = [];

      final itemsMap = Map<String, dynamic>.from(catValue);
      itemsMap.forEach((id, item) {
        menuItems[catKey]!.add(Map<String, dynamic>.from(item));
      });
    });

    // 🔹 LOAD SAVED CATEGORY ORDER
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedCategoryOrder = prefs.getStringList(
      "${widget.hotelName}_category_order",
    );

    if (savedCategoryOrder != null) {
      categories.sort((a, b) =>
          savedCategoryOrder.indexOf(a).compareTo(
              savedCategoryOrder.indexOf(b)));
    }

    // 🔹 Load saved menu item order for selected category
    if (selectedCategory.isEmpty && categories.isNotEmpty) {
      selectedCategory = categories.first;
    }
    await loadMenuOrder(); // 🔹 call here AFTER menuItems populated

    setState(() {});
  }

  // ================= CART =================
  void addToCart(Map item) {
    final index = cart.indexWhere((e) => e["name"] == item["name"]);

    if (index == -1) {
      cart.add({
        "name": item["name"],
        "price": double.parse(item["price"].toString()),
        "qty": 1,
      });
    } else {
      cart[index]["qty"]++;
    }

    selectedCartItem = item["name"];
    calculateTotal();
    setState(() {});

    WidgetsBinding.instance.addPostFrameCallback((_) {
      scrollToCartItem(selectedCartItem);
    });
  }

  void calculateTotal() {
    subTotal = 0;

    // 🔹 Subtotal calculate
    for (var item in cart) {
      subTotal += (item["price"] * item["qty"]);
    }

    // 🔹 Discount %
    double discountPercent = double.tryParse(discountController.text) ?? 0;

    double discountAmount = subTotal * (discountPercent / 100);

    // 🔹 Service %
    double servicePercent = double.tryParse(serviceController.text) ?? 0;

    double serviceAmount = serviceEnabled
        ? subTotal * (servicePercent / 100)
        : 0;

    // 🔹 Tax %
    double taxPercent = double.tryParse(taxController.text) ?? 0;

    double taxAmount = taxEnabled ? subTotal * (taxPercent / 100) : 0;

    // 🔹 Grand Total
    grandTotal = subTotal - discountAmount + serviceAmount + taxAmount;

    setState(() {});
  }

  void scrollToCartItem(String itemName) {
    final index = cart.indexWhere((e) => e["name"] == itemName);
    if (index == -1 || !cartScrollController.hasClients) return;

    cartScrollController.animateTo(
      index * 80,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }


  Widget buildMenuGrid() {
    if (!menuItems.containsKey(selectedCategory)) return Container();
    final items = List<Map<String, dynamic>>.from(menuItems[selectedCategory]!);

    // 🔹 Load saved order on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadMenuOrder();
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isDesktop = constraints.maxWidth > 700;
        int columns = isDesktop ? 7 : 4;

        return ReorderableGridView.builder(
          padding: const EdgeInsets.all(12),
          dragStartDelay: const Duration(milliseconds: 200),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            childAspectRatio: isDesktop ? 0.60 : 0.7,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
          ),
          itemCount: items.length,
          onReorder: (oldIndex, newIndex) async {
            setState(() {
              final movedItem = items.removeAt(oldIndex);
              items.insert(newIndex, movedItem);
              menuItems[selectedCategory] =
              List<Map<String, dynamic>>.from(items);
            });

            // 🔹 Save menu order immediately
            await saveMenuOrder();
          },
          itemBuilder: (context, index) {
            final item = items[index];
            return Card(
              key: ValueKey(item["id"] ?? item["name"]), // fallback if id null
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => addToCart(item),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 6,
                          child: CachedNetworkImage(
                            imageUrl: item["image"],
                            fit: BoxFit.cover,
                            memCacheWidth: 300,
                            memCacheHeight: 300,
                            fadeInDuration: Duration.zero,
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Text(
                              item["name"],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: Text(
                            "Rs ${item["price"]}",
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => _showItemOptions(item),
                        child: const Icon(Icons.more_vert, color: Colors.black),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

// ====================== 🔹 Helper functions ======================

// Load saved menu order for selected category
  Future<void> loadMenuOrder() async {
    if (!menuItems.containsKey(selectedCategory)) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String>? savedOrder = prefs.getStringList(
        "${selectedCategory}_menu_order");
    if (savedOrder != null && savedOrder.isNotEmpty) {
      final currentItems = menuItems[selectedCategory]!;
      currentItems.sort((a, b) {
        int indexA = savedOrder.indexOf(
            a["id"]?.toString() ?? a["name"].toString());
        int indexB = savedOrder.indexOf(
            b["id"]?.toString() ?? b["name"].toString());
        return indexA.compareTo(indexB);
      });
      setState(() {
        menuItems[selectedCategory] = currentItems;
      });
    }
  }

// Save current menu order
  Future<void> saveMenuOrder() async {
    if (!menuItems.containsKey(selectedCategory)) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    List<String> idOrder = menuItems[selectedCategory]!
        .map((e) => e["id"]?.toString() ?? e["name"].toString())
        .toList();
    await prefs.setStringList("${selectedCategory}_menu_order", idOrder);
  }





  // ================= RESPONSIVE =================
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 700;
        return isMobile ? buildMobile() : buildDesktop();
      },
    );
  }

  Widget buildDesktop() {
    return Container(
      color: const Color(0xfff4f6f9), // POS background
      child: Column(
        children: [
          // Modern category bar
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: buildCategories(),
          ),

          const Divider(height: 1),

          Expanded(
            child: Row(
              children: [
                Expanded(
                  flex: 4,
                  child: Container(
                    color: const Color(0xfff4f6f9),
                    child: buildMenuGrid(),
                  ),
                ),

                Container(width: 1, color: Colors.grey.shade300),

                Expanded(flex: 2, child: buildCart()),
              ],
            ),
          ),
        ],
      ),
    );
  }


// 🔹 Helper function: save current order with await


  Widget buildCategories() {
    return SizedBox(
      height: 60, // parent fixed height
      child: Listener(
        onPointerSignal: (pointerSignal) {
          if (pointerSignal is PointerScrollEvent) {
            if (categoryScrollController.hasClients) {
              final newOffset =
                  categoryScrollController.offset +
                      pointerSignal.scrollDelta.dy;
              final maxScroll =
                  categoryScrollController.position.maxScrollExtent;
              final minScroll =
                  categoryScrollController.position.minScrollExtent;
              categoryScrollController.jumpTo(
                newOffset.clamp(minScroll, maxScroll),
              );
            }
          }
        },
        child: SingleChildScrollView(
          controller: categoryScrollController,
          scrollDirection: Axis.horizontal,
          child: ReorderableWrap(
            alignment: WrapAlignment.start,
            spacing: 8,
            runSpacing: 0,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            needsLongPressDraggable: false,
            crossAxisAlignment: WrapCrossAlignment.center,
            // vertical center
            children: categories.map((cat) {
              final selected = cat == selectedCategory;
              return GestureDetector(
                key: ValueKey(cat),
                onTap: () => setState(() => selectedCategory = cat),
                onLongPress: () => _showCategoryOptions(cat),

                child: Container(
                  width: 130,
                  height: 50,
                  // 🔥 fix each category height
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected ? Colors.black : Colors.deepOrangeAccent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    cat,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
            onReorder: (oldIndex, newIndex) {
              final item = categories.removeAt(oldIndex);
              categories.insert(newIndex, item);
              setState(() {});

              // Save order
              SharedPreferences.getInstance().then((prefs) {
                prefs.setStringList(
                  "${widget.hotelName}_category_order",
                  categories,
                );
              });
            },
          ),
        ),
      ),
    );
  }


  // ================= MOBILE =================
  Widget buildMobile() {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.hotelName),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: () {
              // 👉 optional: scroll to cart / open bottom sheet
            },
          ),
        ],
      ),

      body: Column(
        children: [
          // 🔹 Categories (NOW VISIBLE)
          Container(
            height: 55,
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              itemBuilder: (context, i) {
                final cat = categories[i];
                final selected = cat == selectedCategory;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => setState(() => selectedCategory = cat),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected ? Colors.green : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: selected ? Colors.white : Colors.black,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const Divider(height: 1),

          // 🔹 Menu
          Expanded(child: buildMobileMenu()),

          // 🔹 Cart
          SizedBox(
            height: 230,
            child: buildCart(),
          ),
        ],
      ),
    );
  }
  // ================= MENU =================

  Widget buildMenu(int columns) {
    return Column(
      children: [

        // 🔥 SAME DESKTOP CATEGORY BAR
        buildCategories(),

        const Divider(),

        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {

              int columns = 4; // mobile fixed

              return GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  childAspectRatio: 0.65, // 🔥 compact
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                ),
                itemCount: menuItems[selectedCategory]?.length ?? 0,
                itemBuilder: (context, i) {
                  final item = menuItems[selectedCategory]![i];

                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => addToCart(item),
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [

                          // IMAGE
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(10),
                              ),
                              child: CachedNetworkImage(
                                imageUrl: item["image"] ?? "",
                                fit: BoxFit.cover,
                                width: double.infinity,
                                cacheKey: item["image"],
                                placeholder: (_, __) => const Center(
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                errorWidget: (_, __, ___) =>
                                const Icon(Icons.image, size: 30),
                              ),
                            ),
                          ),

                          // NAME
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              item["name"],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),

                          // PRICE
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              "Rs ${item["price"]}",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
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
    );
  }

  // ================= CART =================

  Widget buildCart() {
    bool isMobile = MediaQuery.of(context).size.width < 700;

    return isMobile ? buildMobileCart() : buildDesktopCart();
  }
  Widget buildDesktopCart() {
    double itemHeight = 70; // Approx height per item (Card + padding)

    return Container(
      color: Colors.grey.shade200,
      child: Column(
        children: [
          const SizedBox(height: 4),

          // ================= ORDER TYPE BUTTONS =================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                Expanded(
                  child: _orderButton("Dine In", () async {
                    final prefs = await SharedPreferences.getInstance();

                    setState(() {
                      selectedOrderType = "Dine In";
                      serviceEnabled = true; // ✅ ALWAYS ON
                    });

                    await prefs.setBool('serviceEnabled', true);
                    await prefs.setString('orderType', "Dine In");

                    calculateTotal();
                  }),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _orderButton("Takeaway", () async {
                    final prefs = await SharedPreferences.getInstance();

                    setState(() {
                      selectedOrderType = "Takeaway";
                      serviceEnabled = false; // ❌ AUTO OFF
                    });

                    await prefs.setBool('serviceEnabled', false);
                    await prefs.setString('orderType', "Takeaway");

                    calculateTotal();
                  }),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _orderButton("Delivery", () async {
                    final prefs = await SharedPreferences.getInstance();

                    setState(() {
                      selectedOrderType = "Delivery";
                      serviceEnabled = false; // ❌ mostly OFF
                    });

                    await prefs.setBool('serviceEnabled', false);
                    await prefs.setString('orderType', "Delivery");

                    calculateTotal();
                  }),
                ),
              ],
            ),
          ),

          const Divider(height: 1),







































          Flexible(
            child: ScrollConfiguration(
              behavior: MyCustomScrollBehavior(),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  bool isDesktop = MediaQuery.of(context).size.width > 1000;

                  double itemHeight = isDesktop ? 55 : 70;
                  double minHeight = itemHeight * (isDesktop ? 14 : 10);

                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: minHeight,
                      maxHeight: double.infinity,
                    ),

                    child: ListView.builder(
                      controller: cartScrollController,
                      padding: const EdgeInsets.all(6),
                      itemCount: cart.length,
                      itemBuilder: (context, i) {
                        final item = cart[i];
                        final selected = selectedCartItem == item["name"];

                        return Card(
                          key: ValueKey(item["name"]), // 🔥 IMPORTANT FIX
                          elevation: selected ? 5 : 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: selected
                              ? Colors.yellow.shade200
                              : Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            child: Row(
                              children: [

                                const SizedBox(width: 8),

                                Expanded(
                                  flex: 4,
                                  child: Text(
                                    item["name"],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),

                                const SizedBox(width: 8),

                                // ================= QTY =================
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [

                                      // ➖ MINUS
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            int index = cart.indexWhere(
                                                    (e) => e["name"] == item["name"]);

                                            if (index != -1) {
                                              final updatedItem =
                                              Map<String, dynamic>.from(cart[index]);

                                              int qty = updatedItem["qty"] ?? 1;

                                              if (qty > 1) {
                                                updatedItem["qty"] = qty - 1;
                                                cart[index] = updatedItem;
                                              } else {
                                                cart.removeAt(index);
                                              }

                                              calculateTotal();
                                            }
                                          });
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 4,
                                          ),
                                          child: Icon(Icons.remove, size: 16),
                                        ),
                                      ),

                                      // QTY TEXT
                                      SizedBox(
                                        width: 26,
                                        child: Center(
                                          child: Text(
                                            "${item["qty"]}",
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ),

                                      // ➕ PLUS
                                      InkWell(
                                        onTap: () {
                                          setState(() {
                                            int index = cart.indexWhere(
                                                    (e) => e["name"] == item["name"]);

                                            if (index != -1) {
                                              final updatedItem =
                                              Map<String, dynamic>.from(cart[index]);

                                              updatedItem["qty"] =
                                                  (updatedItem["qty"] ?? 1) + 1;

                                              cart[index] = updatedItem;
                                              calculateTotal();
                                            }
                                          });
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 4,
                                          ),
                                          child: Icon(Icons.add, size: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                const SizedBox(width: 10),

                                SizedBox(
                                  width: 65,
                                  child: Text(
                                    "Rs ${(item["price"] * item["qty"]).toInt()}",
                                    textAlign: TextAlign.right,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 8),

                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      cart.removeAt(i);
                                      calculateTotal();
                                    });
                                  },
                                  child: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ),          const SizedBox(height: 6),

          // ================= BILLING SECTION =================

          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                _billRow("Sub Total", subTotal,bold: true),

                const SizedBox(height: 1),

// ================= SERVICE CHARGE =================
                Row(
                  children: [
                    const Expanded(child: Text("Service %")),

                    Switch(
                      value: serviceEnabled,
                      onChanged: (v) async {
                        final prefs = await SharedPreferences.getInstance();

                        setState(() {
                          serviceEnabled = v;
                        });

                        await prefs.setBool('serviceEnabled', v);

                        calculateTotal();
                      },
                    ),

                    SizedBox(
                      width: 60,
                      height: 32,
                      child: TextField(
                        controller: serviceController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding:
                          EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        ),
                        onChanged: (v) => calculateTotal(),
                      ),
                    ),
                  ],
                ),


                const SizedBox(height: 3),

// ================= TAX =================
                Row(
                  children: [
                    const Expanded(child: Text("Tax %")),

                    Switch(
                      value: taxEnabled,
                      onChanged: (v) async {
                        final prefs = await SharedPreferences.getInstance();

                        setState(() {
                          taxEnabled = v;
                        });

                        await prefs.setBool('taxEnabled', v);

                        calculateTotal();
                      },
                    ),

                    SizedBox(
                      width: 60,
                      height: 32,
                      child: TextField(
                        controller: taxController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding:
                          EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                        ),
                        onChanged: (v) => calculateTotal(),
                      ),
                    ),
                  ],
                ),


                // ================= DISCOUNT =================
                Row(
                  children: [
                    const Expanded(child: Text("Discount %")),

                    SizedBox(
                      width: 60,
                      height: 32,
                      child: TextField(
                        controller: discountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 6, vertical: 6),
                        ),
                        onChanged: (v) => calculateTotal(),
                      ),
                    ),
                  ],
                ),


                const Divider(height: 10),

                _billRow("Grand Total", grandTotal, bold: true),

                const SizedBox(height: 10),

                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 8, horizontal: 12),
                  child: Row(
                    children: [


                      Expanded(
                        child: SizedBox(
                          height: 45,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.print),
                            label: const Text("Print Bill"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {
                              if (cart.isEmpty) return;

                              final box = Hive.box<Order>('orders_history');

                              // 🔹 CALCULATE NEXT ORDER ID STARTING FROM 2001
                              int nextOrderId = 2001;
                              for (var order in box.values) {
                                int id = int.tryParse(order.orderId) ?? 0;
                                if (id >= nextOrderId) nextOrderId = id + 1;
                              }

                              final orderIdStr = nextOrderId.toString(); // ✅ Explicit order number

                              // 🔹 Parse percentages
                              final servicePercent = double.tryParse(serviceController.text) ?? 0;
                              final taxPercent = double.tryParse(taxController.text) ?? 0;
                              final discountInput = double.tryParse(discountController.text) ?? 0;

                              final discountAmount = (subTotal * discountInput) / 100;

                              final order = Order(
                                orderId: orderIdStr, // ✅ Order number explicitly set
                                items: cart.map((e) => OrderItem(
                                  name: e['name'],
                                  qty: e['qty'],
                                  price: e['price'],
                                )).toList(),
                                orderType: selectedOrderType,
                                subTotal: subTotal,
                                grandTotal: grandTotal,
                                service: serviceEnabled ? (subTotal * servicePercent / 100) : 0,
                                tax: taxEnabled ? (subTotal * taxPercent / 100) : 0,
                                discount: discountAmount,
                                status: "paid",
                                paymentMethod: "Cash",
                                receivedAmount: grandTotal,
                                returnedAmount: 0,
                                timestamp: DateTime.now(),
                              );

                              // 🔹 Save order
                              await box.add(order);

                              // 🔹 Fetch hotel info
                              // String hotelName = widget.hotelName;
                              // String address = "";
                              // String phone = "";

                            //  final ref = FirebaseDatabase.instance.ref("Restaurant/${widget.hotelName}/Users");
                            //  final snapshot = await ref.get();

                              // if (snapshot.exists) {
                              //   final usersMap = Map<String, dynamic>.from(snapshot.value as Map);
                              //
                              //   // 🔥 SAFE LOOP (better than .first)
                              //   usersMap.forEach((key, value) {
                              //     final data = Map<String, dynamic>.from(value);
                              //
                              //     // pick correct user (you can refine condition if needed)
                              //     if (address.isEmpty) {
                              //       address = data["address"]?.toString() ?? "";
                              //       phone = data["phone"]?.toString() ?? "";
                              //       hotelName = data["HotelName"]?.toString() ??
                              //           hotelName;
                              //     }
                              //   });
                              //   }

                              // 🔹 Print with correct order number
                              await loadSavedHotelInfo();

                              await printLanRaw(
                                orderIdStr, // ✅ Pass the exact same order number
                                cart,
                                this.hotelName.isEmpty ? widget.hotelName : this.hotelName,


                                selectedOrderType,
                                subTotal,
                                grandTotal,
                                serviceEnabled,
                                taxEnabled,
                                serviceController.text,
                                taxController.text,
                                discountController.text,
                                address,
                                phone,
                              );

                              setState(() {
                                cart.clear();
                                subTotal = 0;
                                grandTotal = 0;
                                discountController.clear();
                              });


                            },
                          ),                        ),
                      ),
                      const SizedBox(width: 12),

                      // 🔹 Manage Order Button
                      Expanded(
                        child: SizedBox(
                          height: 45,
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.list_alt),
                            label: const Text("Manage Order"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade700,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () async {

                              if (selectedOrderType == "Delivery") {
                                bool ok = await showDeliveryDialog();

                                if (!ok) return;
                              }

                              if (cart.isEmpty) return;

                              int? tableNumber;
                              int? floorNumber;

                              // Dine In case
                              if (selectedOrderType == "Dine In") {
                                bool okPressed = false;

                                await showDialog(
                                  context: context,
                                  builder: (_) =>
                                      AlertDialog(
                                        title: const Text(
                                            "Enter Table & Floor Number"),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextField(
                                              keyboardType: TextInputType
                                                  .number,
                                              decoration: const InputDecoration(
                                                  labelText: "Table Number"),
                                              onChanged: (v) =>
                                              tableNumber = int.tryParse(v),
                                            ),
                                            TextField(
                                              keyboardType: TextInputType
                                                  .number,
                                              decoration: const InputDecoration(
                                                  labelText: "Floor Number"),
                                              onChanged: (v) =>
                                              floorNumber = int.tryParse(v),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () {
                                              okPressed = true;
                                              Navigator.pop(context);
                                            },
                                            child: const Text("OK"),
                                          ),
                                        ],
                                      ),
                                );

                                if (!okPressed) return;
                              }

                              // 🔹 Hive box
                              final box = Hive.box<Order>('orders');

                              // 🔹 Calculate next order number starting from 1001
                              int maxOrderId = 1000;
                              for (var order in box.values) {
                                int id = int.tryParse(order.orderId) ?? 0;
                                if (id > maxOrderId) maxOrderId = id;
                              }
                              int nextOrderNumber = maxOrderId + 1;

                              // 🔹 Build order object
                              final order = Order(
                                orderId: nextOrderNumber.toString(),
                                // ✅ 1001, 1002...
                                orderType: selectedOrderType,
                                tableNumber: tableNumber,
                                floorNumber: floorNumber,


                                  customerName:
                                  selectedOrderType == "Delivery"
                                      ? customerName
                                      : null,

                                  customerPhone:
                                  selectedOrderType == "Delivery"
                                      ? customerPhone
                                      : null,



                                items: cart.map((e) =>
                                    OrderItem(
                                      name: e["name"],
                                      qty: e["qty"],
                                      price: e["price"] * 1.0,
                                    )).toList(),
                                subTotal: subTotal,
                                service: selectedOrderType == "Dine In"
                                    ? subTotal * 0.08
                                    : 0.0,
                                discount: double.tryParse(
                                    discountController.text) ?? 0,
                                grandTotal: grandTotal,
                                timestamp: DateTime.now(),
                              );

                              // 🔹 Save to Hive
                              await box.put(order.orderId, order);

                              // 🔹 Clear cart
                              setState(() {
                                cart.clear();
                                calculateTotal();
                              });

                              // 🔹 Show confirmation
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("✅ Order stored with ID: ${order
                                      .orderId}"),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                )


              ],
            ),
          ),


        ],
      ),
    );
  }




  Future<void> printLanRaw(
      String orderId,
      List<Map<String, dynamic>> cart,
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
      )

  async {
    final profile = await CapabilityProfile.load();
    final generator = Generator(PaperSize.mm80, profile);

    List<int> bytes = [];

    // ================= HEADER =================
    bytes += generator.text(
      hotelName,
      styles: const PosStyles(
        align: PosAlign.center,
        bold: true,
        height: PosTextSize.size2,
        width: PosTextSize.size2,
      ),
    );

    if (address.trim().isNotEmpty) {
      bytes += generator.text(
        address,
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    if (phone.trim().isNotEmpty) {
      bytes += generator.text(
        "Ph: $phone",
        styles: const PosStyles(align: PosAlign.center),
      );
    }

    bytes += generator.hr();

    // ================= ORDER INFO =================
    bytes += generator.text(
      "Order No: $orderId",
      styles: const PosStyles(align: PosAlign.center, bold: true),
    );

    bytes += generator.text(
      "Order Type: $selectedOrderType",
      styles: const PosStyles(align: PosAlign.center),
    );

    final now = DateTime.now();
    int hour = now.hour;
    String period = hour >= 12 ? "PM" : "AM";
    if (hour > 12) hour -= 12;
    if (hour == 0) hour = 12;

    bytes += generator.text(
      "${now.day}-${now.month}-${now.year} $hour:${now.minute.toString().padLeft(2, '0')} $period",
      styles: const PosStyles(align: PosAlign.center),
    );

    bytes += generator.hr();

    // ================= HEADER ROW =================
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

// ================= ITEMS =================
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

    // ================= TOTAL =================
    double serviceAmount = serviceEnabled
        ? subTotal * (double.tryParse(servicePercent) ?? 0) / 100
        : 0;

    double taxAmount = taxEnabled
        ? subTotal * (double.tryParse(taxPercent) ?? 0) / 100
        : 0;

    double discountAmount =
    (double.tryParse(discountPercent) ?? 0) > 0
        ? subTotal * (double.tryParse(discountPercent) ?? 0) / 100
        : 0;

    bytes += generator.row([
      PosColumn(
        text: "Subtotal",
        width: 6,
        styles: PosStyles(
          align: PosAlign.left,
          bold: true,
        ),
      ),
      PosColumn(
        text: "Rs ${subTotal.toInt()}",
        width: 6,
        styles: PosStyles(
          align: PosAlign.right,
          bold: true,
        ),
      ),
    ]);

    if (serviceEnabled) {
      bytes += generator.row([
        PosColumn(
          text: "Service (${servicePercent}%)",
          width: 6,
          styles: PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: "Rs ${serviceAmount.toInt()}",
          width: 6,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    if (taxEnabled) {
      bytes += generator.row([
        PosColumn(
          text: "Tax (${taxPercent}%)",
          width: 6,
          styles: PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: "Rs ${taxAmount.toInt()}",
          width: 6,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    if ((double.tryParse(discountPercent) ?? 0) > 0) {
      bytes += generator.row([
        PosColumn(
          text: "Discount (${discountPercent}%)",
          width: 6,
          styles: PosStyles(align: PosAlign.left),
        ),
        PosColumn(
          text: "- Rs ${discountAmount.toInt()}",
          width: 6,
          styles: PosStyles(align: PosAlign.right),
        ),
      ]);
    }

    bytes += generator.hr();

    bytes += generator.text(
      "TOTAL: Rs ${grandTotal.toInt()}",
      styles: const PosStyles(
        align: PosAlign.right,
        bold: true,
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



    bytes += generator.feed(1);
    bytes += generator.cut();


    resetOrderTypeToDineIn();

    // ================= FIXED SOCKET PRINT =================


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

      print("SUCCESS");
    } catch (e) {
      print(e);

    }

  }



  // Future<void> _sendToPrinter(List<int> bytes, BuildContext context) async {
  //   Socket? socket;
  //
  //   try {
  //     String ip = await getPrinterIp();
  //     if (ip.isEmpty) return;
  //
  //     for (int i = 0; i < 3; i++) {
  //       try {
  //         socket = await Socket.connect(
  //           InternetAddress(ip, type: InternetAddressType.IPv4),
  //           9100,
  //           timeout: const Duration(seconds: 5),
  //         );
  //
  //         socket.add(bytes);
  //         await socket.flush();
  //         socket.destroy();
  //
  //         if (context.mounted) {
  //           ScaffoldMessenger.of(context).showSnackBar(
  //             const SnackBar(content: Text("✅ Printed Successfully")),
  //           );
  //         }
  //
  //         return;
  //       } catch (e) {
  //         socket?.destroy();
  //         await Future.delayed(const Duration(milliseconds: 500));
  //       }
  //     }
  //
  //     throw Exception("Printer not reachable");
  //   } catch (e) {
  //     if (context.mounted) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(content: Text("❌ Print error: $e")),
  //       );
  //     }
  //   } finally {
  //     socket?.destroy();
  //   }
  // }



  Future<String> getPrinterIp() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString("printer_ip");
    return (ip == null || ip.isEmpty) ? "192.168.0.142" : ip;
  }

















  Widget _billRow(String title, double value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            "Rs ${value.toInt()}",
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 16 : 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _orderButton(String label, VoidCallback onTap) {
    bool selected = selectedOrderType == label;

    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: selected ? Colors.green : Colors.grey.shade300,
        foregroundColor: selected ? Colors.white : Colors.black,
      ),
      onPressed: onTap,
      child: Text(label),
    );
  }





  Widget buildMobileMenu() {
    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // 👈 FIXED
        childAspectRatio: 0.65,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: menuItems[selectedCategory]?.length ?? 0,
      itemBuilder: (context, i) {
        final item = menuItems[selectedCategory]![i];

        return InkWell(
          onTap: () => addToCart(item),
          child: Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 3,
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(10),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: item["image"] ?? "",
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, __) => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (_, __, ___) => const Icon(Icons.image),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.all(4),
                  child: Text(
                    item["name"],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),

                Text(
                  "Rs ${item["price"]}",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),

                const SizedBox(height: 4),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget buildMobileCart() {
    return Container(
      color: Colors.grey.shade100,
      child: Column(
        children: [

          // 🔹 HEADER
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.black,
            child: Row(
              children: [
                const Icon(Icons.shopping_cart, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                const Text("Cart",
                    style: TextStyle(color: Colors.white, fontSize: 14)),
                const Spacer(),
                Text(
                  "Items: ${cart.length}",
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                )
              ],
            ),
          ),

          // 🔹 CART ITEMS
          Expanded(
            child: ListView.builder(
              itemCount: cart.length,
              itemBuilder: (context, i) {
                final item = cart[i];

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [

                      // 🔹 NAME
                      Expanded(
                        flex: 3,
                        child: Text(
                          item["name"],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),

                      // 🔹 QTY
                      Row(
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                if (item["qty"] > 1) item["qty"]--;
                                calculateTotal();
                              });
                            },
                            child: const Icon(Icons.remove, size: 16),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: Text("${item["qty"]}",
                                style: const TextStyle(fontSize: 12)),
                          ),
                          InkWell(
                            onTap: () {
                              setState(() {
                                item["qty"]++;
                                calculateTotal();
                              });
                            },
                            child: const Icon(Icons.add, size: 16),
                          ),
                        ],
                      ),

                      const SizedBox(width: 6),

                      // 🔹 PRICE
                      SizedBox(
                        width: 60,
                        child: Text(
                          "Rs ${(item["price"] * item["qty"]).toInt()}",
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ),

                      // 🔹 DELETE
                      InkWell(
                        onTap: () {
                          setState(() {
                            cart.removeAt(i);
                            calculateTotal();
                          });
                        },
                        child: const Icon(Icons.delete,
                            size: 16, color: Colors.red),
                      )
                    ],
                  ),
                );
              },
            ),
          ),

          // 🔹 TOTAL BAR
          Container(
            padding: const EdgeInsets.all(10),
            color: Colors.white,
            child: Column(
              children: [

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Total",
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      "Rs ${grandTotal.toInt()}",
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.green),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // 🔹 BUTTON
                Row(
                  children: [

                    // 🔹 SAVE & PRINT
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.print, size: 16),
                          label: const Text("Print", style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            if (cart.isEmpty) return;

                            // 🔥 SAME desktop wala code paste karo yahan
                          },
                        ),
                      ),
                    ),

                    const SizedBox(width: 6),

                    // 🔹 MANAGE ORDER
                    Expanded(
                      child: SizedBox(
                        height: 40,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.list_alt, size: 16),
                          label: const Text("Manage", style: TextStyle(fontSize: 12)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () async {
                            if (cart.isEmpty) return;

                            int? tableNumber;
                            int? floorNumber;

                            if (selectedOrderType == "Dine In") {
                              bool okPressed = false;

                              await showDialog(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text("Table & Floor"),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      TextField(
                                        keyboardType: TextInputType.number,
                                        decoration:
                                        const InputDecoration(labelText: "Table"),
                                        onChanged: (v) =>
                                        tableNumber = int.tryParse(v),
                                      ),
                                      TextField(
                                        keyboardType: TextInputType.number,
                                        decoration:
                                        const InputDecoration(labelText: "Floor"),
                                        onChanged: (v) =>
                                        floorNumber = int.tryParse(v),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        okPressed = true;
                                        Navigator.pop(context);
                                      },
                                      child: const Text("OK"),
                                    ),
                                  ],
                                ),
                              );

                              if (!okPressed) return;
                            }

                            final box = Hive.box<Order>('orders');

                            int maxOrderId = 1000;
                            for (var order in box.values) {
                              int id = int.tryParse(order.orderId) ?? 0;
                              if (id > maxOrderId) maxOrderId = id;
                            }

                            int nextOrderNumber = maxOrderId + 1;

                            final order = Order(
                              orderId: nextOrderNumber.toString(),
                              orderType: selectedOrderType,
                              tableNumber: tableNumber,
                              floorNumber: floorNumber,
                              items: cart.map((e) => OrderItem(
                                name: e["name"],
                                qty: e["qty"],
                                price: e["price"] * 1.0,
                              )).toList(),
                              subTotal: subTotal,
                              service: selectedOrderType == "Dine In"
                                  ? subTotal * 0.08
                                  : 0.0,
                              discount: double.tryParse(discountController.text) ?? 0,
                              grandTotal: grandTotal,
                              timestamp: DateTime.now(),
                            );

                            await box.put(order.orderId, order);

                            setState(() {
                              cart.clear();
                              calculateTotal();
                            });

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("✅ Order stored: ${order.orderId}"),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }






  void _showItemOptions(Map item) {
    showModalBottomSheet(
      context: context,
      builder: (_) =>
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text("Edit Item"),
                onTap: () {
                  Navigator.pop(context);
                  _editItem(item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text("Delete Item"),
                onTap: () {
                  Navigator.pop(context);
                  _deleteItem(item);
                },
              ),
            ],
          ),
    );
  }

  //for items delete/edit
  void _deleteItem(Map item) async {
    String category = selectedCategory;

    double progress = 0.0;

    // 🔥 PROGRESS DIALOG
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Deleting Item"),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // PROGRESS BAR
              LinearProgressIndicator(value: progress),

              const SizedBox(height: 10),

              Text("${(progress * 100).toStringAsFixed(0)} %"),
            ],
          ),
        ),
      ),
    );

    try {
      setState(() {
        progress = 0.2;
      });

      if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
        // 🔥 REST DELETE for Desktop/Web
        final url = Uri.parse(
          "https://adsadmobandfacebook-default-rtdb.firebaseio.com/Restaurant/${widget.hotelName}/MenuItems/$category.json",
        );

        final res = await http.get(url);

        setState(() {
          progress = 0.4;
        });

        if (res.statusCode == 200 && res.body != "null") {
          Map data = json.decode(res.body);
          String? itemKey;

          data.forEach((key, value) {
            if (value["name"] == item["name"]) {
              itemKey = key;
            }
          });

          if (itemKey != null) {
            final deleteUrl = Uri.parse(
              "https://adsadmobandfacebook-default-rtdb.firebaseio.com/Restaurant/${widget.hotelName}/MenuItems/$category/$itemKey.json",
            );

            await http.delete(deleteUrl);
          }
        }

      } else {
        // 🔹 Mobile SDK
        final ref = FirebaseDatabase.instance.ref(
          "Restaurant/${widget.hotelName}/MenuItems/$category",
        );

        final snapshot = await ref.get();

        setState(() {
          progress = 0.6;
        });

        if (snapshot.exists) {
          Map data = Map.from(snapshot.value as Map);
          String? itemKey;

          data.forEach((key, value) {
            if (value["name"] == item["name"]) {
              itemKey = key;
            }
          });

          if (itemKey != null) {
            await ref.child(itemKey!).remove();
          }
        }
      }

      setState(() {
        progress = 1.0;
      });

      await Future.delayed(const Duration(milliseconds: 300));

    } catch (e) {
      debugPrint("Delete error: $e");
    }

    Navigator.pop(context); // close dialog
    loadMenu();
  }

  void _editItem(Map item) {
    final nameController = TextEditingController(text: item["name"]);
    final priceController = TextEditingController(
      text: item["price"].toString(),
    );

    XFile? selectedImage;
    String? uploadedImageUrl;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Edit Item"),

          content: SingleChildScrollView(
            child: Column(
              children: [

                // 🔥 PROGRESS BAR
                if (isUploading)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: LinearProgressIndicator(),
                  ),

                // NAME
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Item Name"),
                ),

                // PRICE
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: "Price"),
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 10),

                // PICK IMAGE BUTTON
                ElevatedButton.icon(
                  icon: const Icon(Icons.image),
                  label: Text(
                    selectedImage == null ? "Pick Image" : "Change Image",
                  ),
                  onPressed: isUploading
                      ? null
                      : () async {
                    XFile? imageFile;

                    if (kIsWeb ||
                        defaultTargetPlatform == TargetPlatform.windows ||
                        defaultTargetPlatform == TargetPlatform.linux ||
                        defaultTargetPlatform == TargetPlatform.macOS) {
                      FilePickerResult? result =
                      await FilePicker.platform.pickFiles(
                        type: FileType.image,
                      );

                      if (result != null &&
                          result.files.single.path != null) {
                        imageFile = XFile(result.files.single.path!);
                      }
                    } else {
                      final picker = ImagePicker();
                      imageFile = await picker.pickImage(
                        source: ImageSource.gallery,
                      );
                    }

                    if (imageFile != null) {
                      setState(() {
                        selectedImage = imageFile;
                      });
                    }
                  },
                ),

                const SizedBox(height: 10),

                // IMAGE PREVIEW
                if (selectedImage != null)
                  SizedBox(
                    height: 150,
                    child: kIsWeb
                        ? Image.network(selectedImage!.path)
                        : Image.file(File(selectedImage!.path)),
                  )
                else
                  SizedBox(
                    height: 150,
                    child: Image.network(item["image"], fit: BoxFit.cover),
                  ),
              ],
            ),
          ),

          actions: [

            // ❌ CANCEL
            TextButton(
              onPressed: isUploading
                  ? null
                  : () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),

            // 🔥 UPDATE BUTTON
            TextButton(
              onPressed: isUploading
                  ? null
                  : () async {
                setState(() {
                  isUploading = true;
                });

                try {
                  String category = selectedCategory;

                  // 🔥 IMAGE UPLOAD (CLOUDINARY)
                  if (selectedImage != null) {
                    uploadedImageUrl =
                    await uploadImageToCloudinary(selectedImage!);

                    debugPrint("✅ New Image URL: $uploadedImageUrl");
                  }

                  // 🔥 DATABASE UPDATE
                  final dbRef = FirebaseDatabase.instance.ref(
                    "Restaurant/${widget.hotelName}/MenuItems/$category",
                  );

                  final snapshot = await dbRef.get();

                  if (snapshot.exists) {
                    Map data = Map.from(snapshot.value as Map);
                    String? itemKey;

                    data.forEach((key, value) {
                      if (value["name"] == item["name"]) {
                        itemKey = key;
                      }
                    });

                    if (itemKey != null) {
                      await dbRef.child(itemKey!).update({
                        "name": nameController.text.trim(),
                        "price": priceController.text.trim(),
                        "image":
                        uploadedImageUrl ?? item["image"],
                      });
                    }
                  }

                  Navigator.pop(context);
                  loadMenu();
                } catch (e) {
                  debugPrint("❌ Edit Item Error: $e");
                }

                setState(() {
                  isUploading = false;
                });
              },
              child: const Text("Update"),
            ),
          ],
        ),
      ),
    );
  }


  Future<String> uploadImageToCloudinary(XFile file) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/dprmo6mch/image/upload'),
    );

    request.fields['upload_preset'] = 'menu_upload';

    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          await file.readAsBytes(),
          filename: file.name,
        ),
      );
    } else {
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path),
      );
    }

    var response = await request.send();
    var resData = await response.stream.bytesToString();
    var data = jsonDecode(resData);

    return data['secure_url'];
  }

  void _showCategoryOptions(String category) {
    showModalBottomSheet(
      context: context,
      builder: (_) =>
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text("Add New Item"),
                onTap: () {
                  Navigator.pop(context);
                  _addNewItem(category); // 🔹 Naya function call
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text("Edit Category"),
                onTap: () {
                  Navigator.pop(context);
                  _editCategory(category);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text("Delete Category"),
                onTap: () {
                  Navigator.pop(context);
                  _deleteCategory(category);
                },
              ),
            ],
          ),
    );
  }

  //for category delete/edit
  void _addNewItem(String category) {
    final nameController = TextEditingController();
    final priceController = TextEditingController();

    XFile? selectedImage;
    String? uploadedImageUrl;

    double progress = 0.0;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Add New Item"),

          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                // NAME
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: "Item Name"),
                ),

                // PRICE
                TextField(
                  controller: priceController,
                  decoration: const InputDecoration(labelText: "Price"),
                  keyboardType: TextInputType.number,
                ),

                const SizedBox(height: 10),

                // PICK IMAGE
                ElevatedButton.icon(
                  icon: const Icon(Icons.image),
                  label: Text(
                    selectedImage == null
                        ? "Pick Image (Optional)"
                        : "Change Image",
                  ),
                  onPressed: () async {
                    XFile? imageFile;

                    if (kIsWeb ||
                        defaultTargetPlatform == TargetPlatform.windows ||
                        defaultTargetPlatform == TargetPlatform.linux ||
                        defaultTargetPlatform == TargetPlatform.macOS) {
                      FilePickerResult? result =
                      await FilePicker.platform.pickFiles(
                        type: FileType.image,
                      );

                      if (result != null &&
                          result.files.single.path != null) {
                        imageFile = XFile(result.files.single.path!);
                      }
                    } else {
                      final picker = ImagePicker();
                      imageFile = await picker.pickImage(
                        source: ImageSource.gallery,
                      );
                    }

                    if (imageFile != null) {
                      setState(() {
                        selectedImage = imageFile;
                      });
                    }
                  },
                ),

                const SizedBox(height: 10),

                // IMAGE PREVIEW
                if (selectedImage != null)
                  SizedBox(
                    height: 150,
                    child: kIsWeb
                        ? Image.network(selectedImage!.path)
                        : Image.file(File(selectedImage!.path)),
                  ),

                const SizedBox(height: 15),

                // PROGRESS BAR
                if (isUploading)
                  Column(
                    children: [
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 5),
                      Text(
                        "${(progress * 100).toStringAsFixed(0)} % uploading...",
                      ),
                    ],
                  ),
              ],
            ),
          ),

          actions: [

            // CANCEL
            TextButton(
              onPressed: isUploading
                  ? null
                  : () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),

            // UPLOAD BUTTON
            TextButton(
              onPressed: isUploading
                  ? null
                  : () async {
                if (nameController.text.trim().isEmpty ||
                    priceController.text.trim().isEmpty) {
                  return;
                }

                setState(() {
                  isUploading = true;
                  progress = 0.1;
                });

                try {
                  uploadedImageUrl = "";

                  // 🔥 OLD FIREBASE STORAGE CODE (COMMENTED)
                  /*
                      if (selectedImage != null) {
                        String fileName =
                            DateTime.now().millisecondsSinceEpoch.toString();

                        Reference ref = FirebaseStorage.instance.ref(
                          "Menu_Items_Restaurant/${widget.hotelName}/$fileName",
                        );

                        UploadTask uploadTask;

                        if (kIsWeb) {
                          final bytes = await selectedImage!.readAsBytes();
                          uploadTask = ref.putData(bytes);
                        } else {
                          uploadTask =
                              ref.putFile(File(selectedImage!.path));
                        }

                        TaskSnapshot snapshot = await uploadTask;
                        uploadedImageUrl =
                            await snapshot.ref.getDownloadURL();
                      }
                      */

                  // 🔥 NEW CLOUDINARY CODE
                  if (selectedImage != null) {
                    uploadedImageUrl =
                    await uploadImageToCloudinary(
                        selectedImage!);
                  }

                  setState(() {
                    progress = 0.8;
                  });

                  // FIREBASE DATABASE SAVE (SAME)
                  final dbRef = FirebaseDatabase.instance.ref(
                    "Restaurant/${widget.hotelName}/MenuItems/$category",
                  );

                  await dbRef.push().set({
                    "name": nameController.text.trim(),
                    "price": priceController.text.trim(),
                    "image": uploadedImageUrl ?? "",
                  });

                  setState(() {
                    progress = 1.0;
                  });

                  Navigator.pop(context);
                  loadMenu();
                } catch (e) {
                  debugPrint("Add Item Error: $e");
                }

                setState(() {
                  isUploading = false;
                });
              },
              child: const Text("Upload & Add"),
            ),
          ],
        ),
      ),
    );
  }


  void _deleteCategory(String category) async {
    double progress = 0.0;
    bool isDeleting = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Deleting Category"),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // 🔥 PROGRESS BAR
              LinearProgressIndicator(value: progress),

              const SizedBox(height: 10),

              Text("${(progress * 100).toStringAsFixed(0)} %"),
            ],
          ),
        ),
      ),
    );

    try {
      setState(() {
        progress = 0.3;
      });

      if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
        // 🔹 REST DELETE for Desktop/Web
        final url = Uri.parse(
          "https://adsadmobandfacebook-default-rtdb.firebaseio.com/Restaurant/${widget.hotelName}/MenuItems/$category.json",
        );

        await http.delete(url);
      } else {
        // 🔹 Mobile SDK
        await FirebaseDatabase.instance
            .ref("Restaurant/${widget.hotelName}/MenuItems/$category")
            .remove();
      }

      setState(() {
        progress = 0.9;
      });

      await Future.delayed(const Duration(milliseconds: 300));

      setState(() {
        progress = 1.0;
      });

    } catch (e) {
      debugPrint("Delete Category Error: $e");
    }

    Navigator.pop(context); // close dialog
    loadMenu();
  }
  // ================= EDIT CATEGORY =================
  void _editCategory(String oldName) {
    final controller = TextEditingController(text: oldName);

    bool isLoading = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Edit Category"),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              // 🔥 PROGRESS BAR
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: LinearProgressIndicator(),
                ),

              TextField(
                controller: controller,
                decoration:
                const InputDecoration(labelText: "Category Name"),
              ),
            ],
          ),

          actions: [

            // ❌ CANCEL
            TextButton(
              onPressed: isLoading
                  ? null
                  : () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),

            // 🔥 SAVE BUTTON
            TextButton(
              onPressed: isLoading
                  ? null
                  : () async {
                String newName = controller.text.trim();
                if (newName.isEmpty) return;

                // 🔥 IMPORTANT FIX (avoid accidental delete)
                if (newName == oldName) {
                  Navigator.pop(context);
                  return;
                }

                setState(() {
                  isLoading = true;
                });

                try {
                  if (kIsWeb ||
                      defaultTargetPlatform ==
                          TargetPlatform.windows ||
                      defaultTargetPlatform ==
                          TargetPlatform.macOS ||
                      defaultTargetPlatform ==
                          TargetPlatform.linux) {
                    // 🔹 Desktop REST API
                    final url = Uri.parse(
                      "https://adsadmobandfacebook-default-rtdb.firebaseio.com/Restaurant/${widget.hotelName}/MenuItems/$oldName.json",
                    );

                    final res = await http.get(url);

                    if (res.statusCode == 200 &&
                        res.body != "null") {
                      final oldData = json.decode(res.body);

                      final newUrl = Uri.parse(
                        "https://adsadmobandfacebook-default-rtdb.firebaseio.com/Restaurant/${widget.hotelName}/MenuItems/$newName.json",
                      );

                      await http.put(
                        newUrl,
                        body: json.encode(oldData),
                      );

                      await http.delete(url);
                    }
                  } else {
                    // 🔹 Mobile SDK
                    final ref = FirebaseDatabase.instance.ref(
                      "Restaurant/${widget.hotelName}/MenuItems",
                    );

                    final snapshot =
                    await ref.child(oldName).get();

                    if (snapshot.exists) {
                      await ref
                          .child(newName)
                          .set(snapshot.value);

                      await ref.child(oldName).remove();
                    }
                  }

                  Navigator.pop(context);
                  loadMenu();
                } catch (e) {
                  debugPrint("Edit Category Error: $e");
                }

                setState(() {
                  isLoading = false;
                });
              },
              child: const Text("Save"),
            ),
          ],
        ),
      ),
    );
  }
  // ================= IMAGE PICK & UPLOAD =================
  Future<String?> pickAndUploadImage(String category) async {
    String? localPath;

    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      // Desktop
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );
      if (result != null && result.files.single.path != null) {
        localPath = result.files.single.path!;
      }
    } else {
      // Mobile
      final picker = ImagePicker();
      XFile? image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) localPath = image.path;
    }

    if (localPath == null) return null;

    // 🔹 Show preview in dialog before upload
    String? uploadedUrl;
    await showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Preview & Upload"),
          content: SizedBox(
            height: 250,
            child: Column(
              children: [
                Expanded(
                  child: localPath!.contains("http") || kIsWeb
                      ? Image.network(localPath!)
                      : Image.file(File(localPath!)),
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      String fileName = DateTime
                          .now()
                          .millisecondsSinceEpoch
                          .toString();
                      Reference ref = FirebaseStorage.instance.ref(
                        "MenuItems/$category/$fileName",
                      );

                      UploadTask uploadTask;
                      if (kIsWeb) {
                        final bytes = await File(localPath!).readAsBytes();
                        uploadTask = ref.putData(bytes);
                      } else {
                        uploadTask = ref.putFile(File(localPath!));
                      }

                      TaskSnapshot snapshot = await uploadTask;
                      uploadedUrl = await snapshot.ref.getDownloadURL();
                    } catch (e) {
                      debugPrint("Upload Error: $e");
                    }

                    Navigator.pop(context);
                  },
                  child: const Text("Upload"),
                ),
              ],
            ),
          ),
        );
      },
    );

    return uploadedUrl;
  }



}