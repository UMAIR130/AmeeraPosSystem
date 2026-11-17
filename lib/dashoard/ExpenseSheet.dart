import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Expensesheet extends StatefulWidget {
  const Expensesheet({super.key, required String hotelName});

  @override
  State<Expensesheet> createState() => _ExpensesheetState();
}

class _ExpensesheetState extends State<Expensesheet> {
  List<Map<String, dynamic>> expenses = [];

  bool showMonthly = false;

  @override
  void initState() {
    super.initState();
    loadExpenses();
  }

  // ================= LOAD =================
  Future<void> loadExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString("expenses");

    if (data != null) {
      expenses = List<Map<String, dynamic>>.from(jsonDecode(data));
      setState(() {});
    }
  }

  // ================= SAVE =================
  Future<void> saveExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("expenses", jsonEncode(expenses));
  }

  // ================= FILTER TODAY =================
  List<Map<String, dynamic>> getTodayExpenses() {
    final now = DateTime.now();

    return expenses.where((e) {
      final date = DateTime.parse(e["date"]);
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }).toList();
  }

  // ================= FILTER MONTH =================
  List<Map<String, dynamic>> getMonthlyExpenses() {
    final now = DateTime.now();

    return expenses.where((e) {
      final date = DateTime.parse(e["date"]);
      return date.year == now.year &&
          date.month == now.month;
    }).toList();
  }

  // ================= TOTAL =================
  double getTotal(List<Map<String, dynamic>> list) {
    return list.fold(
      0,
          (sum, item) => sum + ((item["amount"] ?? 0) as num),
    );
  }

  // ================= ADD EXPENSE =================
  void addExpenseDialog() {
    final nameController = TextEditingController();
    final titleController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Add Expense"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(labelText: "Title"),
              ),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "Name"),
              ),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Amount"),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                if (amountController.text.isEmpty) return;

                expenses.add({
                  "title": titleController.text,
                  "name": nameController.text,
                  "amount": double.tryParse(amountController.text) ?? 0,
                  "date": DateTime.now().toIso8601String(),
                });

                await saveExpenses();
                setState(() {});

                Navigator.pop(context);
              },
              child: const Text("Add"),
            ),
          ],
        );
      },
    );
  }

  // ================= DELETE =================
  void deleteExpense(Map<String, dynamic> item) async {
    expenses.remove(item);
    await saveExpenses();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final todayList = getTodayExpenses();
    final monthlyList = getMonthlyExpenses();

    final currentList = showMonthly ? monthlyList : todayList;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Expenses"),

        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: addExpenseDialog,
          ),

          IconButton(
            icon: Icon(
              showMonthly ? Icons.today : Icons.calendar_month,
            ),
            onPressed: () {
              setState(() {
                showMonthly = !showMonthly;
              });
            },
          ),
        ],
      ),

      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.blue.shade50,
            child: Text(
              showMonthly
                  ? "Monthly Total: Rs ${getTotal(monthlyList).toStringAsFixed(0)}"
                  : "Today Total: Rs ${getTotal(todayList).toStringAsFixed(0)}",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          Expanded(
            child: currentList.isEmpty
                ? const Center(child: Text("No Expenses"))
                : ListView.builder(
              itemCount: currentList.length,
              itemBuilder: (context, index) {
                final e = currentList[index];

                return Card(
                  child: ListTile(
                    title: Text(e["title"] ?? ""),
                    subtitle: Text("By: ${e["name"] ?? ""}"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Rs ${e["amount"]}"),
                        // IconButton(
                        //   icon: const Icon(Icons.delete,
                        //       color: Colors.red),
                        //   onPressed: () => deleteExpense(e),
                        // ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}