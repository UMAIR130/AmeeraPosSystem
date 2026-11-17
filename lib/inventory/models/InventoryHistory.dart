import 'package:hive/hive.dart';

part 'InventoryHistory.g.dart';

@HiveType(typeId: 51)
class InventoryHistory extends HiveObject {

  @HiveField(0)
  String itemName;

  @HiveField(1)
  double qty;

  @HiveField(2)
  String unit;

  @HiveField(3)
  String type; // ADD or USED

  @HiveField(4)
  DateTime date;

  @HiveField(5)
  String? orderNo;

  InventoryHistory({
    required this.itemName,
    required this.qty,
    required this.unit,
    required this.type,
    required this.date,
    this.orderNo,
  });
}