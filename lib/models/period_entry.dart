import 'package:cloud_firestore/cloud_firestore.dart';

enum BleedStatus { start, still, stop }

class PeriodEntry {
  final String? id;
  final DateTime startDate;
  final DateTime endDate; // for single-day start= endDate if unknown
  final BleedStatus status; // status at the given date entry - typically start/still/stop

  PeriodEntry({
    this.id,
    required this.startDate,
    required this.endDate,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'status': status.name,
    };
  }

  factory PeriodEntry.fromMap(Map<String, dynamic> map, {String? id}) {
    return PeriodEntry(
      id: id,
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      status: BleedStatus.values.firstWhere((e) => e.name == (map['status'] ?? 'start')),
    );
  }
}
