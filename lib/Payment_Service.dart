import 'package:hive/hive.dart';

import 'inventory/models/InventoryItem.dart';
import 'inventory/models/MenuRecipe.dart';

import 'inventory/models/InventoryHistory.dart';
import 'models/order_model.dart';



class Payment_Service {

  static bool isProcessing = false;
  static Future<bool> startProcessing(Order order) async {

    // Agar koi payment already process ho rahi hai
    if (isProcessing) {
      return false;
    }

    isProcessing = true;

    // Agar ye order pehle hi complete ho chuka hai
    if (order.status == "paid") {
      isProcessing = false;
      return false;
    }

    // Check history for duplicate order
    final historyBox = Hive.box<Order>('orders_history');

    final alreadyExists = historyBox.values.any(
          (o) => o.orderId == order.orderId,
    );

    if (alreadyExists) {
      isProcessing = false;
      return false;
    }

    return true;
  }

  static void finishProcessing() {
    isProcessing = false;
  }

}