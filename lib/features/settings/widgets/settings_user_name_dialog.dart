import 'package:flutter/material.dart';

Future<String?> showSettingsUserNameDialog({
  required BuildContext context,
  required String? currentName,
}) async {
  return showDialog<String?>(
    context: context,
    builder: (_) => SettingsUserNameDialog(currentName: currentName),
  );
}

class SettingsUserNameDialog extends StatefulWidget {
  const SettingsUserNameDialog({super.key, required this.currentName});

  final String? currentName;

  @override
  State<SettingsUserNameDialog> createState() => _SettingsUserNameDialogState();
}

class _SettingsUserNameDialogState extends State<SettingsUserNameDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentName ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _closeWith(String? value) {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Your Name'),
      content: TextField(
        key: const ValueKey<String>('settings-user-name-field'),
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: const InputDecoration(
          labelText: 'Display name',
          hintText: 'e.g. Mahesh',
        ),
        maxLength: 40,
        onSubmitted: _closeWith,
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () {
            _closeWith(null);
          },
          child: const Text('Cancel'),
        ),
        if ((widget.currentName ?? '').isNotEmpty)
          TextButton(
            onPressed: () {
              _closeWith('');
            },
            child: const Text('Clear'),
          ),
        FilledButton(
          onPressed: () {
            _closeWith(_controller.text);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
