import 'package:hive/hive.dart';

part 'TokenHistory.g.dart';

@HiveType(typeId: 28)
class TokenHistory extends HiveObject {

  @HiveField(0)
  String orderId;

  @HiveField(1)
  String orderType;

  @HiveField(2)
  String category;

  @HiveField(3)
  String dateTime;

  @HiveField(4)
  int tableNumber;

  @HiveField(5)
  int floorNumber;

  @HiveField(6)
  List<String> items;

  @HiveField(7)
  String orderNumber;

  TokenHistory({
    required this.orderId,
    required this.orderType,
    required this.category,
    required this.dateTime,
    required this.tableNumber,
    required this.floorNumber,
    required this.items,
    required this.orderNumber,
  });
}