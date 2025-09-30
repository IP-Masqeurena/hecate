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
  DateTime? endDate;
  bool _submitting = false;

  void _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (result != null && mounted) setState(() => selectedDate = result);
  }

  void _submit() async {
    final fs = Provider.of<FirestoreService>(context, listen: false);

    final entry = PeriodEntry(
      startDate: selectedDate,
      endDate: endDate ?? selectedDate,
      type: 'menstruation',
    );

    if (!mounted) return;
    setState(() => _submitting = true);

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
      if (mounted) setState(() => _submitting = false);
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
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              'This entry will be recorded as "Menstruation".',
              style: TextStyle(fontSize: 14),
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
                  if (d != null && mounted) setState(() => endDate = d);
                },
              ),
              if (endDate != null)
                IconButton(icon: const Icon(Icons.clear), onPressed: () {
                  if (mounted) setState(() => endDate = null);
                }),
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
