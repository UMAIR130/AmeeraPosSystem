import 'package:hive/hive.dart';

part 'InventoryItem.g.dart';

@HiveType(typeId: 20)
class InventoryItem extends HiveObject {

  @HiveField(0)
  String itemName;

  // Current Remaining Stock
  @HiveField(1)
  double stock;

  @HiveField(2)
  String unit;

  @HiveField(3)
  DateTime createdAt;

  // Total Added Stock
  @HiveField(4)
  double totalAddedStock;

  // RawMaterial, Drink, ReadyMade
  @HiveField(5)
  String itemType;

  InventoryItem({
    required this.itemName,
    required this.stock,
    required this.unit,
    required this.createdAt,
    required this.totalAddedStock,
    required this.itemType,
  });

  double get usedStock {
    return totalAddedStock - stock;
  }
}