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
  final TextEditingController menuController = TextEditingController();

  /// TEMP DRAFT (advanced clean state)
  String recipeName = "";
  List<RecipeIngredient> ingredients = [];

  @override
  void dispose() {
    menuController.dispose();
    super.dispose();
  }

  // ---------------- SAVE RECIPE ----------------
  Future<void> saveRecipe() async {
    if (recipeName.trim().isEmpty || ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter name & ingredients")),
      );
      return;
    }

    final box = Hive.box<MenuRecipe>('recipes');

    await box.add(
      MenuRecipe(
        menuName: recipeName.trim(),
        ingredients: List.from(ingredients),
      ),
    );

    setState(() {
      recipeName = "";
      ingredients.clear();
      menuController.clear();
    });

    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Recipe Saved")),
    );
  }

  // ---------------- ADD INGREDIENT ----------------
  double convertToBase(double qty, String unit) {
    switch (unit) {
      case "kg":
        return qty * 1000; // grams
      case "g":
        return qty;

      case "l":
        return qty * 1000; // ml
      case "ml":
        return qty;

      case "pc":
        return qty;

      default:
        return qty;
    }
  }
  Widget _qtyChip(String value, TextEditingController controller, Function setStateDialog) {
    return ActionChip(
      label: Text(value),
      onPressed: () {
        setStateDialog(() {
          controller.text = value;
        });
      },
    );
  }
  void addIngredientDialog() {
    final qtyController = TextEditingController();

    String? selectedItem;
    String selectedUnit = "g"; // default unit

    final inventoryBox = Hive.box<InventoryItem>('inventory');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Add Ingredient"),

              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  /// 🔍 Select Ingredient
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: selectedItem,
                    decoration: const InputDecoration(
                      labelText: "Ingredient",
                      border: OutlineInputBorder(),
                    ),
                    items: inventoryBox.values.map((item) {
                      return DropdownMenuItem(
                        value: item.itemName,
                        child: Text(item.itemName),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setStateDialog(() {
                        selectedItem = value;
                      });
                    },
                  ),

                  const SizedBox(height: 15),

                  /// ⚡ UNIT SELECT (IMPORTANT FIX)
                  DropdownButtonFormField<String>(
                    value: selectedUnit,
                    decoration: const InputDecoration(
                      labelText: "Unit",
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: "g", child: Text("Gram (g)")),
                      DropdownMenuItem(value: "kg", child: Text("Kilogram (kg)")),
                      DropdownMenuItem(value: "ml", child: Text("Milliliter (ml)")),
                      DropdownMenuItem(value: "l", child: Text("Liter (l)")),
                      DropdownMenuItem(
                        value: "pc",
                        child: Text("Piece (pc)"),
                      ),

                    ],
                    onChanged: (value) {
                      setStateDialog(() {
                        selectedUnit = value!;
                      });
                    },
                  ),

                  const SizedBox(height: 15),

                  /// ✍️ Quantity Input
                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Quantity",
                      hintText: "Enter quantity",
                      suffixText: selectedUnit,
                      border: const OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 10),

                  /// 📦 INFO BOX
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Will be stored in base unit (g/ml)",
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),

              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),

                ElevatedButton(
                  onPressed: () {
                    if (selectedItem == null ||
                        qtyController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Select item and quantity"),
                        ),
                      );
                      return;
                    }

                    final baseQty = convertToBase(
                      double.tryParse(qtyController.text) ?? 0,
                      selectedUnit,
                    );

                    setState(() {
                      ingredients.add(
                        RecipeIngredient(
                          inventoryName: selectedItem!,
                          qty: baseQty, // 🔥 STORED IN BASE UNIT
                          unit: selectedUnit,
                        ),
                      );
                    });

                    Navigator.pop(context);
                  },
                  child: const Text("Add"),
                ),
              ],
            );
          },
        );
      },
    );
  }  // ---------------- MAIN DIALOG ----------------
  void showAddRecipeDialog() {
    menuController.clear();
    ingredients.clear();
    recipeName = "";

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
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
                          labelText: "Menu Name",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (v) {
                          recipeName = v;
                        },
                      ),

                      const SizedBox(height: 15),

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: addIngredientDialog,
                          icon: const Icon(Icons.add),
                          label: const Text("Add Ingredient"),
                        ),
                      ),

                      const SizedBox(height: 15),

                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          itemCount: ingredients.length,
                          itemBuilder: (context, index) {
                            final item = ingredients[index];

                            return ListTile(
                              title: Text(item.inventoryName),
                              subtitle: Text("${item.qty} ${item.unit}"),
                              trailing: SizedBox(
                                width: 70,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [

                                    GestureDetector(
                                      onTap: () {
                                        editIngredientDialog(index);
                                      },
                                      child: const Icon(
                                        Icons.edit,
                                        color: Colors.blue,
                                        size: 22,
                                      ),
                                    ),

                                    GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          ingredients.removeAt(index);
                                        });

                                        setStateDialog(() {});
                                      },
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                        size: 22,
                                      ),
                                    ),

                                  ],
                                ),
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
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),

                ElevatedButton(
                  onPressed: saveRecipe,
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }





  void editIngredientDialog(int index) {

    final qtyController = TextEditingController(
      text: ingredients[index].qty.toString(),
    );

    String selectedItem = ingredients[index].inventoryName;
    String selectedUnit = ingredients[index].unit;

    final inventoryBox = Hive.box<InventoryItem>('inventory');

    showDialog(
      context: context,
      builder: (context) {

        return StatefulBuilder(
          builder: (context, setStateDialog) {

            return AlertDialog(

              title: const Text("Edit Ingredient"),

              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  DropdownButtonFormField<String>(
                    value: selectedItem,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: "Ingredient",
                      border: OutlineInputBorder(),
                    ),
                    items: inventoryBox.values.map((item) {

                      return DropdownMenuItem(
                        value: item.itemName,
                        child: Text(item.itemName),
                      );

                    }).toList(),
                    onChanged: (v) {

                      setStateDialog(() {

                        selectedItem = v!;

                        final inv = inventoryBox.values.firstWhere(
                              (e) => e.itemName == v,
                        );

                        selectedUnit = inv.unit;

                      });

                    },
                  ),

                  const SizedBox(height: 15),

                  TextField(
                    controller: qtyController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "Quantity",
                      suffixText: selectedUnit,
                      border: const OutlineInputBorder(),
                    ),
                  ),

                ],
              ),

              actions: [

                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("Cancel"),
                ),

                ElevatedButton(

                  onPressed: () {

                    ingredients[index] = RecipeIngredient(

                      inventoryName: selectedItem,

                      qty: convertToBase(
                        double.parse(qtyController.text),
                        selectedUnit,
                      ),

                      unit: selectedUnit,

                    );

                    setState(() {});
                    Navigator.pop(context);

                  },

                  child: const Text("Update"),

                ),

              ],

            );

          },
        );

      },
    );
  }






  // ---------------- UI ----------------
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
            onPressed: showAddRecipeDialog,
          ),
        ],
      ),

      body: ValueListenableBuilder(
        valueListenable: recipeBox.listenable(),
        builder: (context, Box<MenuRecipe> box, _) {
          if (box.isEmpty) {
            return const Center(child: Text("No Recipes Found"));
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
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),

                  subtitle: Text(
                    "${recipe.ingredients.length} Ingredients",
                  ),

                  children: recipe.ingredients.map((e) {
                    return ListTile(
                      title: Text(e.inventoryName),
                      subtitle: Text("${e.qty} ${e.unit}"),
                    );
                  }).toList(),

                  trailing: SizedBox(
                    width: 90,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        IconButton(
                          tooltip: "Edit",
                          icon: const Icon(
                            Icons.edit,
                            color: Colors.blue,
                          ),
                          onPressed: () {

                            showEditRecipeDialog(recipe, index);

                          },
                        ),

                        IconButton(
                          tooltip: "Delete",
                          icon: const Icon(
                            Icons.delete,
                            color: Colors.red,
                          ),
                          onPressed: () async {

                            await box.deleteAt(index);

                          },
                        ),

                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

void showEditRecipeDialog(MenuRecipe recipe, int recipeIndex) {

menuController.text = recipe.menuName;

recipeName = recipe.menuName;

ingredients = recipe.ingredients
.map(
(e) => RecipeIngredient(
inventoryName: e.inventoryName,
qty: e.qty,
unit: e.unit,
),
)
.toList();

showDialog(
context: context,
builder: (context) {

return StatefulBuilder(

builder: (context, setStateDialog) {

return AlertDialog(

title: const Text("Edit Recipe"),

content: SizedBox(
width: 500,

child: SingleChildScrollView(

child: Column(

mainAxisSize: MainAxisSize.min,

children: [

TextField(
controller: menuController,
decoration: const InputDecoration(
labelText: "Menu Name",
border: OutlineInputBorder(),
),
onChanged: (v) {
recipeName = v;
},
),

const SizedBox(height: 15),

SizedBox(
width: double.infinity,
child: ElevatedButton.icon(
onPressed: addIngredientDialog,
icon: const Icon(Icons.add),
label: const Text("Add Ingredient"),
),
),

const SizedBox(height: 15),

SizedBox(
height: 250,
child: ListView.builder(
itemCount: ingredients.length,
itemBuilder: (context, index) {

final item = ingredients[index];

return Card(
margin: const EdgeInsets.symmetric(vertical: 4),

child: ListTile(

leading: const Icon(
Icons.restaurant_menu,
color: Colors.green,
),

title: Text(
item.inventoryName,
style: const TextStyle(
fontWeight: FontWeight.bold,
),
),

subtitle: Text(
"${item.qty} ${item.unit}",
),

trailing: SizedBox(
width: 90,
child: Row(
mainAxisSize: MainAxisSize.min,
children: [

IconButton(
icon: const Icon(
Icons.edit,
color: Colors.blue,
),
onPressed: () async {

editIngredientDialog(index);

setStateDialog(() {});

},
),

IconButton(
icon: const Icon(
Icons.delete,
color: Colors.red,
),
onPressed: () {

ingredients.removeAt(index);

setStateDialog(() {});

},
),

],
),
),

),

);

},
),
),

const SizedBox(height: 15),
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

        if (recipeName.trim().isEmpty ||
            ingredients.isEmpty) {

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Enter menu name & ingredients",
              ),
            ),
          );

          return;
        }

        final recipeBox =
        Hive.box<MenuRecipe>('recipes');

        final updatedRecipe = MenuRecipe(

          menuName: recipeName.trim(),

          ingredients: List.from(ingredients),

        );

        await recipeBox.putAt(
          recipeIndex,
          updatedRecipe,
        );

        if (mounted) {

          Navigator.pop(context);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Recipe Updated Successfully",
              ),
            ),
          );

          setState(() {});

        }

      },

      child: const Text("Update"),

    ),

  ],

);

},

);

},

);

}

}