import 'package:hive/hive.dart';

part 'order_model.g.dart';

@HiveType(typeId: 1)
class OrderItem extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  int qty;

  @HiveField(2)
  double price;

  // 🆕 DEAL / SUB ITEMS SUPPORT

  @HiveField(3)
  List<Map<String, dynamic>>? items;
 // List<Map>? items;


  @HiveField(4)
  String? tokenCategory;

  OrderItem({
    required this.name,
    required this.qty,
    required this.price,
    this.items,
    this.tokenCategory,

  });
}

@HiveType(typeId: 13)
class Order extends HiveObject {
  @HiveField(0)
  String orderId;

  @HiveField(1)
  String orderType;

  @HiveField(2)
  int? tableNumber;

  @HiveField(3)
  int? floorNumber;

  @HiveField(4)
  List<OrderItem> items;

  @HiveField(5)
  double subTotal;

  @HiveField(6)
  double service;

  @HiveField(7)
  double discount;

  @HiveField(8)
  double grandTotal;

  @HiveField(9)
  DateTime timestamp;

  @HiveField(10)
  String status;

  @HiveField(11)
  String? paymentMethod;

  @HiveField(12)
  double? receivedAmount;

  @HiveField(13)
  double? returnedAmount;

  @HiveField(14)
  double tax;

  @HiveField(15)
  int lastPrintedCount;

  @HiveField(16)
  String? orderNumber;

  @HiveField(17)
  String? customerName;

  @HiveField(18)
  String? customerPhone;

  // 🆕 DELIVERY FIELDS
  @HiveField(19)
  String? customerAddress;

  @HiveField(20)
  String? riderName;

  @HiveField(21)
  String? riderPhone;

  @HiveField(22)
  bool inventoryDeducted;


  @HiveField(23)
  bool firebaseSynced;


  @HiveField(24)
  String hotelName;

  Order({
    required this.orderId,
    required this.orderType,
    this.tableNumber,
    this.floorNumber,
    required this.items,
    required this.subTotal,
    required this.service,
    required this.discount,
    required this.grandTotal,
    required this.timestamp,
    this.status = "pending",
    this.paymentMethod,
    this.receivedAmount,
    this.returnedAmount,
    this.tax = 0,
    this.lastPrintedCount = 0,
    this.orderNumber,
    this.customerName,
    this.customerPhone,
    this.customerAddress,
    this.riderName,
    this.riderPhone,
    this.inventoryDeducted = false,
    this.firebaseSynced = false,
    required this.hotelName,
  });
}