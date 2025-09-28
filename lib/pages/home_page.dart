import 'package:flutter/material.dart';
import 'package:hecate/pages/add_entry_page.dart';
import 'package:hecate/pages/settings_page.dart';
import 'package:hecate/services/firebase_service.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

import '../models/period_entry.dart';
import '../widgets/period_calendar.dart';

class HomePage extends StatelessWidget {
  HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthService>(context, listen: false);
    final fs = Provider.of<FirestoreService>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Period Predictor'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, SettingsPage.routeName),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => auth.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<List<PeriodEntry>>(
        stream: fs.periodStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final list = snapshot.data ?? [];
          return PeriodCalendar(entries: list);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => AddEntryPage())),
        child: const Icon(Icons.add),
      ),
    );
  }
}
