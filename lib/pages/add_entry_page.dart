import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hecate/services/firebase_service.dart';
import 'package:provider/provider.dart';
import '../models/period_entry.dart';

class AddEntryPage extends StatefulWidget {
  const AddEntryPage({super.key});

  @override
  State<AddEntryPage> createState() => _AddEntryPageState();
}

class _AddEntryPageState extends State<AddEntryPage> {
  DateTime selectedDate = DateTime.now();
  BleedStatus selectedStatus = BleedStatus.start;
  DateTime? endDate;
  bool _submitting = false;

  void _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (result != null) setState(() { selectedDate = result; });
  }

  void _submit() async {
    final fs = Provider.of<FirestoreService>(context, listen: false);
    // Validation: 'still' only possible if previous entry was start or still
    if (selectedStatus == BleedStatus.still) {
      // fetch most recent entry to check
      final snap = await fs.periodStream().first;
      if (snap.isEmpty) {
        _showError('Cannot mark "Still bleeding" without a previous Start/Still record.');
        return;
      }
      final last = snap.first; // already ordered desc in service
      if (!(last.status == BleedStatus.start || last.status == BleedStatus.still)) {
        _showError('Cannot mark "Still bleeding" unless previous record was Start or Still.');
        return;
      }
    }

    final entry = PeriodEntry(
      startDate: selectedDate,
      endDate: endDate ?? selectedDate,
      status: selectedStatus,
    );

    setState(() { _submitting = true; });

    try {
      await fs.addOrUpdateEntry(entry);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (ex) {
      if (ex.toString().contains('conflict')) {
        final overwrite = await _confirmOverwrite();
        if (overwrite == true) {
          await fs.forceOverwriteStartDate(selectedDate, entry);
          if (!mounted) return;
          Navigator.of(context).pop();
        }
      } else {
        _showError('Failed to save: $ex');
      }
    } finally {
      if (mounted) setState(() { _submitting = false; });
    }
  }

  Future<bool?> _confirmOverwrite() {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Conflict found'),
        content: const Text('An entry for that start date already exists. Overwrite?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Overwrite')),
        ],
      ),
    );
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final statuses = ['Start bleeding', 'Still bleeding', 'Stop bleeding'];
    return Scaffold(
      appBar: AppBar(title: const Text('Add entry')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          ListTile(
            title: const Text('Selected date'),
            subtitle: Text('${selectedDate.toLocal()}'.split(' ')[0]),
            trailing: IconButton(icon: const Icon(Icons.calendar_today), onPressed: _pickDate),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 120,
            child: CupertinoPicker.builder(
              itemExtent: 32,
              onSelectedItemChanged: (i) => setState(() => selectedStatus = BleedStatus.values[i]),
              childCount: statuses.length,
              itemBuilder: (context, i) => Center(child: Text(statuses[i])),
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            title: const Text('Optional end date (if set, will be saved)'),
            subtitle: Text(endDate != null ? '${endDate!.toLocal()}'.split(' ')[0] : 'Not set'),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final d = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (d != null) setState(() => endDate = d);
                },
              ),
              if (endDate != null)
                IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => endDate = null)),
            ]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting ? const CircularProgressIndicator() : const Text('Save'),
          ),
        ]),
      ),
    );
  }
}
