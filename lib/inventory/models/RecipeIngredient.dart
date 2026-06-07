import 'package:hive/hive.dart';

part 'RecipeIngredient.g.dart';

@HiveType(typeId: 21)
class RecipeIngredient extends HiveObject {

  @HiveField(0)
  String inventoryName;

  @HiveField(1)
  double qty;

  @HiveField(2)
  String unit;

  RecipeIngredient({
    required this.inventoryName,
    required this.qty,
    required this.unit,
  });
}