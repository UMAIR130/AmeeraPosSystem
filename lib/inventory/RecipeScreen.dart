import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'models/InventoryItem.dart';
import 'models/MenuRecipe.dart';
import 'models/RecipeIngredient.dart';

class Recipescreen extends StatefulWidget {
  const Recipescreen({super.key, required String hotelName});

  @override
  State<Recipescreen> createState() => _RecipescreenState();
}

class _RecipescreenState extends State<Recipescreen> {
  final menuController = TextEditingController();

  List<RecipeIngredient> ingredients = [];

  Future<void> saveRecipe() async {
    if (menuController.text.trim().isEmpty || ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Enter menu name and ingredients"),
        ),
      );
      return;
    }

    final recipeBox = Hive.box<MenuRecipe>('recipes');

    await recipeBox.add(
      MenuRecipe(
        menuName: menuController.text.trim(),
        ingredients: List.from(ingredients),
      ),
    );

    menuController.clear();

    setState(() {
      ingredients.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Recipe Saved Successfully"),
      ),
    );
  }

  void addIngredientDialog() {
    final qtyController = TextEditingController();

    String? selectedItem;
    String selectedUnit = "";

    final inventoryBox = Hive.box<InventoryItem>('inventory');

    showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: const Text("Add Ingredient"),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedItem,
                    decoration: const InputDecoration(
                      labelText: "Select Ingredient",
                      border: OutlineInputBorder(),
                    ),
                    items: inventoryBox.values.map((item) {
                      return DropdownMenuItem(
                        value: item.itemName,
                        child: Text(item.itemName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setDialogState(() {
                        selectedItem = value;

                        final inventory =
                        inventoryBox.values.firstWhere(
                              (e) => e.itemName == value,
                        );

                        selectedUnit = inventory.unit;
                      });
                    },
                  ),

                  const SizedBox(height: 15),

                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: "Used Quantity",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  if (selectedUnit.isNotEmpty)
                    Text(
                      "Unit: $selectedUnit",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () {
                Navigator.pop(context);
              },
            ),
            ElevatedButton(
              child: const Text("Add"),
              onPressed: () {
                if (selectedItem == null ||
                    qtyController.text.trim().isEmpty) {
                  return;
                }

                setState(() {
                  ingredients.add(
                    RecipeIngredient(
                      inventoryName: selectedItem!,
                      qty: double.tryParse(
                        qtyController.text,
                      ) ??
                          0,
                      unit: selectedUnit,
                    ),
                  );
                });

                Navigator.pop(context);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final recipeBox = Hive.box<MenuRecipe>('recipes');

    return Scaffold(
      appBar: AppBar(
        title: const Text("Menu Recipes"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              showAddRecipeDialog();
            },
          ),
        ],
      ),

      body: ValueListenableBuilder(
        valueListenable: recipeBox.listenable(),
        builder: (
            context,
            Box<MenuRecipe> box,
            _,
            ) {
          if (box.isEmpty) {
            return const Center(
              child: Text("No Recipes Found"),
            );
          }

          return ListView.builder(
            itemCount: box.length,
            itemBuilder: (context, index) {

              final recipe = box.getAt(index)!;

              return Card(
                margin: const EdgeInsets.all(8),
                child: ExpansionTile(
                  title: Text(
                    recipe.menuName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  subtitle: Text(
                    "${recipe.ingredients.length} Ingredients",
                  ),

                  children: recipe.ingredients.map((e) {
                    return ListTile(
                      title: Text(e.inventoryName),
                      subtitle: Text(
                        "${e.qty} ${e.unit}",
                      ),
                    );
                  }).toList(),

                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete,
                      color: Colors.red,
                    ),
                    onPressed: () async {
                      await box.deleteAt(index);
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }


  void showAddRecipeDialog() {
    menuController.clear();
    ingredients.clear();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Add Recipe"),

              content: SizedBox(
                width: 500,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      TextField(
                        controller: menuController,
                        decoration: const InputDecoration(
                          labelText: "Menu Item Name",
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 15),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            addIngredientDialog();
                          },
                          icon: const Icon(Icons.add),
                          label: const Text(
                            "Add Ingredient",
                          ),
                        ),
                      ),

                      const SizedBox(height: 15),

                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          itemCount: ingredients.length,
                          itemBuilder: (context, index) {

                            final item =
                            ingredients[index];

                            return ListTile(
                              title: Text(
                                item.inventoryName,
                              ),
                              subtitle: Text(
                                "${item.qty} ${item.unit}",
                              ),
                              trailing: IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  setDialogState(() {
                                    ingredients.removeAt(
                                      index,
                                    );
                                  });
                                },
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              actions: [

                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),

                ElevatedButton(
                  onPressed: () async {

                    if (menuController.text.trim().isEmpty ||
                        ingredients.isEmpty) {
                      return;
                    }

                    final recipeBox =
                    Hive.box<MenuRecipe>('recipes');

                    await recipeBox.add(
                      MenuRecipe(
                        menuName:
                        menuController.text.trim(),
                        ingredients:
                        List.from(ingredients),
                      ),
                    );

                    Navigator.pop(context);

                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          "Recipe Saved",
                        ),
                      ),
                    );
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}