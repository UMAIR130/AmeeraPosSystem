import 'package:hive/hive.dart';
import 'RecipeIngredient.dart';
import 'RecipeIngredient.dart';

part 'MenuRecipe.g.dart';

@HiveType(typeId: 22)
class MenuRecipe extends HiveObject {

  @HiveField(0)
  String menuName;

  @HiveField(1)
  List<RecipeIngredient> ingredients;

  MenuRecipe({
    required this.menuName,
    required this.ingredients,
  });
}