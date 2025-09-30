import 'package:cloud_firestore/cloud_firestore.dart';

class PeriodEntry {
  final String? id;
  final DateTime startDate;
  final DateTime endDate; // for single-day start = endDate if unknown
  final String type; // e.g. 'menstruation'. kept as string for flexibility.

  PeriodEntry({
    this.id,
    required this.startDate,
    required this.endDate,
    this.type = 'menstruation',
  });

  Map<String, dynamic> toMap() {
    return {
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'type': type,
    };
  }

  /// Accept legacy 'status' field if present (backwards compatibility).
  factory PeriodEntry.fromMap(Map<String, dynamic> map, {String? id}) {
    final rawType = map['type'] ?? map['status'] ?? 'menstruation';
    final String typeStr = rawType is String ? rawType : rawType.toString();
    return PeriodEntry(
      id: id,
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      type: typeStr,
    );
  }
}