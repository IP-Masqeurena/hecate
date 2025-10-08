import 'package:flutter/material.dart';
import 'package:hecate/services/auth_service.dart';
import 'package:provider/provider.dart';
import '../main.dart';

class SettingsPage extends StatelessWidget {
  static const routeName = '/settings';
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final themeModel = Provider.of<ThemeModel>(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text('Dark mode'),
            value: themeModel.mode == ThemeMode.dark,
            onChanged: (_) => themeModel.toggle(),
          ),
          ListTile(
            title: const Text('Logout'),
            onTap: () async {
              await auth.signOut();
              if (!context.mounted) return;
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
    );
  }
}
