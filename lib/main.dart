import 'dart:io';

import 'package:demoproject/SplashScreen.dart';
import 'package:demoproject/inventory/models/TokenHistory.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'firebase_options.dart'; // auto generated
import 'inventory/models/InventoryHistory.dart';
import 'inventory/models/InventoryItem.dart';
import 'inventory/models/MenuRecipe.dart';
import 'inventory/models/RecipeIngredient.dart';
import 'login/login.dart';
import 'models/RoomBooking.dart';
import 'models/RoomHistory.dart';
import 'models/order_model.dart';


// 🔥 SSL OVERRIDE (FOR TESTING ONLY)
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔥 APPLY SSL OVERRIDE FIRST
  HttpOverrides.global = MyHttpOverrides();

  // Firebase initialize
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,

  );
  FirebaseDatabase.instance.setPersistenceEnabled(true);
  // Hive initialize
  await Hive.initFlutter();
  //
  // final appDir = await getApplicationSupportDirectory();
  //
  // await Hive.initFlutter(appDir.path);
  //
  // print("Hive Path : ${appDir.path}");

  // Hive adapters register
  Hive.registerAdapter(OrderItemAdapter());
  Hive.registerAdapter(OrderAdapter());
  Hive.registerAdapter(RoomBookingAdapter());
  Hive.registerAdapter(RoomHistoryAdapter());

  
  Hive.registerAdapter(InventoryItemAdapter());
  Hive.registerAdapter(RecipeIngredientAdapter());
  Hive.registerAdapter(MenuRecipeAdapter());
  Hive.registerAdapter(TokenHistoryAdapter());
  Hive.registerAdapter(InventoryHistoryAdapter());




  // Open boxes
  await Hive.openBox<Order>('orders');
  await Hive.openBox<Order>('orders_history');
  await Hive.openBox<RoomBooking>('roomsBox');
  await Hive.openBox<RoomHistory>('roomHistory');
  await Hive.openBox<InventoryItem>('inventory');
  await Hive.openBox<MenuRecipe>('recipes');
  await Hive.openBox<TokenHistory>('tokenHistory');
  await Hive.openBox('token_categories');
  Hive.openBox<InventoryHistory>('inventory_history');



  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const SplashScreen(),
    );
  }
}