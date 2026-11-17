import 'package:flutter/cupertino.dart';

class POSActions {
  static void printBill() {
    debugPrint("🧾 PRINT BILL");
  }

  static void printToken() {
    debugPrint("🎫 PRINT TOKEN");
  }

  static void newOrder() {
    debugPrint("➕ NEW ORDER");
  }

  static void search() {
    debugPrint("🔍 SEARCH FOCUS");
  }

  static void save() {
    debugPrint("💾 SAVE / PAYMENT");
  }

  static void escape() {
    debugPrint("❌ ESC PRESSED");
  }

  static void fullscreen() {
    debugPrint("🖥 FULLSCREEN TOGGLE");
  }

  static void delete() {
    debugPrint("🗑 DELETE ITEM");
  }
}