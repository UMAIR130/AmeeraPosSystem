import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'POSActions.dart';

class POSShortcuts extends StatelessWidget {
  final Widget child;

  const POSShortcuts({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{

        // 🧾 BILL PRINT
        const SingleActivator(LogicalKeyboardKey.keyP, control: true):
        const PrintBillIntent(),

        // 🧾 TOKEN PRINT
        const SingleActivator(LogicalKeyboardKey.keyT, control: true):
        const PrintTokenIntent(),

        // ➕ NEW ORDER
        const SingleActivator(LogicalKeyboardKey.keyN, control: true):
        const NewOrderIntent(),

        // 🔍 SEARCH
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
        const SearchIntent(),

        // 💾 SAVE / PAY
        const SingleActivator(LogicalKeyboardKey.keyS, control: true):
        const SaveIntent(),

        // ❌ ESC (BACK / CLOSE)
        const SingleActivator(LogicalKeyboardKey.escape):
        const EscapeIntent(),

        // 🖥 FULL SCREEN
        const SingleActivator(LogicalKeyboardKey.f11):
        const FullscreenIntent(),

        // 🗑 DELETE
        const SingleActivator(LogicalKeyboardKey.delete):
        const DeleteIntent(),
      },

      child: Actions(
        actions: <Type, Action<Intent>>{

          PrintBillIntent: CallbackAction<PrintBillIntent>(
            onInvoke: (_) => POSActions.printBill(),
          ),

          PrintTokenIntent: CallbackAction<PrintTokenIntent>(
            onInvoke: (_) => POSActions.printToken(),
          ),

          NewOrderIntent: CallbackAction<NewOrderIntent>(
            onInvoke: (_) => POSActions.newOrder(),
          ),

          SearchIntent: CallbackAction<SearchIntent>(
            onInvoke: (_) => POSActions.search(),
          ),

          SaveIntent: CallbackAction<SaveIntent>(
            onInvoke: (_) => POSActions.save(),
          ),

          EscapeIntent: CallbackAction<EscapeIntent>(
            onInvoke: (_) => POSActions.escape(),
          ),

          FullscreenIntent: CallbackAction<FullscreenIntent>(
            onInvoke: (_) => POSActions.fullscreen(),
          ),

          DeleteIntent: CallbackAction<DeleteIntent>(
            onInvoke: (_) => POSActions.delete(),
          ),
        },

        child: child,
      ),
    );
  }











}

class PrintBillIntent extends Intent {
  const PrintBillIntent();
}

class PrintTokenIntent extends Intent {
  const PrintTokenIntent();
}

class NewOrderIntent extends Intent {
  const NewOrderIntent();
}

class SearchIntent extends Intent {
  const SearchIntent();
}

class SaveIntent extends Intent {
  const SaveIntent();
}

class EscapeIntent extends Intent {
  const EscapeIntent();
}

class FullscreenIntent extends Intent {
  const FullscreenIntent();
}

class DeleteIntent extends Intent {
  const DeleteIntent();
}

