import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanchita/features/settings/widgets/settings_user_name_dialog.dart';

void main() {
  testWidgets('focused user name dialog can save without framework errors', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: _UserNameDialogHost()));

    await tester.tap(find.text('Edit name'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey<String>('settings-user-name-field')),
      'Mahesh',
    );
    await tester.pump();

    expect(FocusManager.instance.primaryFocus, isNotNull);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Saved: Mahesh'), findsOneWidget);
  });
}

class _UserNameDialogHost extends StatefulWidget {
  const _UserNameDialogHost();

  @override
  State<_UserNameDialogHost> createState() => _UserNameDialogHostState();
}

class _UserNameDialogHostState extends State<_UserNameDialogHost> {
  String? savedName;

  Future<void> _openDialog() async {
    final result = await showSettingsUserNameDialog(
      context: context,
      currentName: savedName,
    );

    if (!mounted || result == null) {
      return;
    }

    setState(() {
      savedName = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          TextButton(onPressed: _openDialog, child: const Text('Edit name')),
          Text('Saved: ${savedName ?? ''}'),
        ],
      ),
    );
  }
}
