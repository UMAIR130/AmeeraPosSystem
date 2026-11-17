import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../login/login.dart';

class UploadMenuPage extends StatefulWidget {
  final String hotelName;

  const UploadMenuPage({super.key, required this.hotelName});

  @override
  State<UploadMenuPage> createState() => _UploadMenuPageState();
}

class _UploadMenuPageState extends State<UploadMenuPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController categoryController = TextEditingController();

  final TextEditingController tokenCategoryController =
  TextEditingController();






  bool isDeal = false;

  List<Map<String, dynamic>> dealItems = [];

  TextEditingController dealItemNameController = TextEditingController();
  TextEditingController dealItemQtyController = TextEditingController();










  String printerIp = "192.168.0.142";
  TextEditingController ipController = TextEditingController();




  XFile? pickedFile;
  bool loading = false;

  late DatabaseReference dbRef;

  @override
  void initState() {
    super.initState();

    // ✅ Mobile path
    if (!kIsWeb && defaultTargetPlatform != TargetPlatform.windows) {
      dbRef = FirebaseDatabase.instance
          .ref("Restaurant/${widget.hotelName.trim()}/MenuItems");
    }


    _loadPrinterIp();

  }




  // 📸 Pick Image
  Future<void> pickImage() async {
    final picker = ImagePicker();
    pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) setState(() {});
  }

  Future<void> _loadPrinterIp() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      printerIp = prefs.getString("printer_ip") ?? "192.168.0.142";
      ipController.text = printerIp;
    });
  }



  Future<void> _savePrinterIp() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("printer_ip", ipController.text.trim());

    setState(() {
      printerIp = ipController.text.trim();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Printer IP Saved ✅")),
    );
  }


  //
  // Future<String> uploadImageToStorage(XFile file) async {
  //   final storageRef = FirebaseStorage.instance
  //       .ref()
  //       .child(
  //       "Menu_Items_Restaurant/${widget.hotelName}/${DateTime.now().millisecondsSinceEpoch}_${file.name}");
  //
  //   UploadTask uploadTask;
  //
  //   if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
  //     final bytes = await file.readAsBytes();
  //     final extension = file.name.split('.').last.toLowerCase();
  //     final metadata = SettableMetadata(contentType: "image/$extension");
  //     uploadTask = storageRef.putData(bytes, metadata);
  //   } else {
  //     uploadTask = storageRef.putFile(File(file.path));
  //   }
  //
  //   final snapshot = await uploadTask;
  //   return await snapshot.ref.getDownloadURL();
  // }
  //
  //



  Future<String> uploadImageToCloudinary(XFile file) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('https://api.cloudinary.com/v1_1/dprmo6mch/image/upload'),
    );

    request.fields['upload_preset'] = 'menu_upload';

    if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
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

    return data['secure_url']; // 🔥 direct image link
  }



  // 🚀 Upload Menu (FIXED)
  Future<void> uploadMenu() async {
    if (nameController.text.isEmpty ||
        priceController.text.isEmpty ||
        categoryController.text.isEmpty ||
        tokenCategoryController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Fill all fields")),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final hotel = widget.hotelName.trim();
      final category =
      categoryController.text.trim().replaceAll(" ", "_");

      String imageUrl = "";

      if (pickedFile != null) {
        imageUrl = await uploadImageToCloudinary(pickedFile!);
      }

      final data = isDeal
          ? {
        "type": "deal",
        "name": nameController.text.trim(),
        "price": priceController.text.trim(),
        "image": imageUrl,
        "tokenCategory": tokenCategoryController.text.trim(), // 🔥 NEW
        "items": dealItems,
      }
          : {
        "type": "item",
        "name": nameController.text.trim(),
        "price": priceController.text.trim(),
        "image": imageUrl,
        "tokenCategory": tokenCategoryController.text.trim(), // 🔥 NEW
      };

      if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows) {
        final url = Uri.parse(
          "https://adsadmobandfacebook-default-rtdb.firebaseio.com/Restaurant/$hotel/MenuItems/$category.json",
        );

        final res = await http.post(url, body: json.encode(data));

        if (res.statusCode != 200) {
          throw Exception("Upload failed");
        }
      } else {
        await dbRef.child(category).push().set(data);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("✅ Menu Uploaded")),
      );

      // Clear
      nameController.clear();
      priceController.clear();
      categoryController.clear();
      tokenCategoryController.clear(); // 🔥 CLEAR
      pickedFile = null;

      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }

    setState(() => loading = false);

    dealItems.clear();
    isDeal = false;
  }

  // Future<void> logout() async {
  //   await FirebaseAuth.instance.signOut();
  //
  //   final prefs = await SharedPreferences.getInstance();
  //
  //   // Sirf login/session data remove karo
  //   await prefs.remove("email");
  //   await prefs.remove("password");
  //   await prefs.remove("uid");
  //
  //   if (!mounted) return;
  //
  //   Navigator.of(context).pushAndRemoveUntil(
  //     MaterialPageRoute(builder: (_) => const Login()),
  //         (route) => false,
  //   );
  // }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();

    final prefs = await SharedPreferences.getInstance();

    // 🔥 ONLY SESSION RELATED KEYS REMOVE
    await prefs.remove("uid");
    await prefs.remove("role");
    await prefs.remove("hotelName");
    await prefs.setBool("isLoggedIn", false);

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const Login()),
          (route) => false,
    );
  }





  // 🎨 UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      appBar: AppBar(
        title: const Text("Upload Menu"),
        backgroundColor: Colors.green,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: logout,
          ),
        ],
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [

              const SizedBox(height: 20),

              // 🔥 CATEGORY (NOW TOP)
              _buildInput(
                controller: categoryController,
                label: "Category (e.g Fast Food)",
                icon: Icons.category,
              ),

              const SizedBox(height: 15),


              SwitchListTile(
                title: const Text("Is this a Deal?"),
                value: isDeal,
                onChanged: (v) {
                  setState(() {
                    isDeal = v;
                  });
                },
              ),
              const SizedBox(height: 15),

              // 🔥 MENU NAME
              _buildInput(
                controller: nameController,
                label: "Menu Name",
                icon: Icons.fastfood,
              ),

              const SizedBox(height: 15),

              // 🔥 PRICE
              _buildInput(
                controller: priceController,
                label: "Menu Price",
                icon: Icons.attach_money,
                keyboard: TextInputType.number,
              ),
              _buildInput(
                controller: tokenCategoryController,
                label: "Token Category (e.g Kitchen, BBQ, Drinks)",
                icon: Icons.category,
              ),
              const SizedBox(height: 20),

              // 🔥 IMAGE BUTTON
              ElevatedButton.icon(
                onPressed: pickImage,
                icon: const Icon(Icons.image),
                label: const Text("Pick Image"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 12),
                ),
              ),



              if (isDeal) ...[
                const SizedBox(height: 20),

                const Text(
                  "Deal Items",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 10),

                _buildInput(
                  controller: dealItemNameController,
                  label: "Item Name (e.g Pizza)",
                  icon: Icons.fastfood,
                ),

                const SizedBox(height: 10),

                _buildInput(
                  controller: dealItemQtyController,
                  label: "Quantity",
                  icon: Icons.numbers,
                  keyboard: TextInputType.number,
                ),

                const SizedBox(height: 10),

                ElevatedButton(
                  onPressed: () {
                    if (dealItemNameController.text.isEmpty ||
                        dealItemQtyController.text.isEmpty) return;

                    setState(() {
                      dealItems.add({
                        "name": dealItemNameController.text.trim(),
                        "qty": int.parse(dealItemQtyController.text.trim()),
                      });

                      dealItemNameController.clear();
                      dealItemQtyController.clear();
                    });
                  },
                  child: const Text("Add Item"),
                ),

                const SizedBox(height: 10),

                ListView.builder(
                  shrinkWrap: true,
                  itemCount: dealItems.length,
                  itemBuilder: (context, index) {
                    final item = dealItems[index];
                    return ListTile(
                      title: Text(item["name"]),
                      trailing: Text("x${item["qty"]}"),
                    );
                  },
                ),
              ],



              if (pickedFile != null)
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text("Selected: ${pickedFile!.name}"),
                ),

              const SizedBox(height: 20),

              // 🔥 UPLOAD BUTTON
              loading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: uploadMenu,
                  icon: const Icon(Icons.upload),
                  label: const Text("Upload Menu"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // 🔥 PRINTER SECTION
              const Divider(),

              const Text(
                "Printer Settings",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              _buildInput(
                controller: ipController,
                label: "Printer IP Address",
                icon: Icons.print,
              ),

              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 45,
                child: ElevatedButton.icon(
                  onPressed: _savePrinterIp,
                  icon: const Icon(Icons.save),
                  label: const Text("Save Printer IP"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboard = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboard,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }}