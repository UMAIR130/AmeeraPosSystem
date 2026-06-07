// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'MenuRecipe.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MenuRecipeAdapter extends TypeAdapter<MenuRecipe> {
  @override
  final int typeId = 22;

  @override
  MenuRecipe read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MenuRecipe(
      menuName: fields[0] as String,
      ingredients: (fields[1] as List).cast<RecipeIngredient>(),
    );
  }

  @override
  void write(BinaryWriter writer, MenuRecipe obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.menuName)
      ..writeByte(1)
      ..write(obj.ingredients);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MenuRecipeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
