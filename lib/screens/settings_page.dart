import 'package:flutter/material.dart';

import 'package:accounting/models/models.dart';

class SettingsPage extends StatefulWidget {
  final List<Transaction> transactions;
  final AuthResult currentUser;

  const SettingsPage({
    super.key,
    required this.transactions,
    required this.currentUser,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _darkMode = false;
  bool _compactMode = false;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Manage application preferences and display settings.', style: TextStyle(fontSize: 14, color: Color(0xFF8B949E))),
        const SizedBox(height: 24),
        Card(
          child: Column(children: [
            SwitchListTile(
              title: const Text('Dark mode'),
              subtitle: const Text('Use a darker theme for easier night-time viewing.'),
              value: _darkMode,
              onChanged: (value) => setState(() => _darkMode = value),
            ),
            const Divider(height: 1),
            SwitchListTile(
              title: const Text('Compact layout'),
              subtitle: const Text('Reduce spacing to show more data on the screen.'),
              value: _compactMode,
              onChanged: (value) => setState(() => _compactMode = value),
            ),
          ]),
        ),
        const SizedBox(height: 20),
        Card(
          child: Column(children: [
            ListTile(title: const Text('App version'), subtitle: const Text('1.0.0')),
            const Divider(height: 1),
            ListTile(title: const Text('Support email'), subtitle: const Text('support@example.com')),
          ]),
        ),
      ]),
    );
  }
}
