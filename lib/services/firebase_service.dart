import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/period_entry.dart';
class FirestoreService extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String? _uid;

  // NOTE: we no longer call notifyListeners() here.
  void setUser(String uid) {
    _uid = uid;
    // don't notifyListeners() here to avoid marking widgets dirty during build
  }

  CollectionReference<Map<String, dynamic>> get _periodsRef {
    if (_uid == null) {
      throw Exception('User not set in FirestoreService');
    }
    return _db.collection('users').doc(_uid).collection('periods');
  }

  /// Returns a stream of PeriodEntry. If _uid is not set, return an empty stream immediately.
  Stream<List<PeriodEntry>> periodStream() {
    if (_uid == null) {
      // Safe: return an immediately completed stream with an empty list
      return Stream<List<PeriodEntry>>.value(<PeriodEntry>[]);
    }
    return _periodsRef.orderBy('startDate', descending: true).snapshots().map((snap) {
      return snap.docs.map((d) => PeriodEntry.fromMap(d.data(), id: d.id)).toList();
    });
  }

  Future<void> addOrUpdateEntry(PeriodEntry e, {bool overwrite = false}) async {
    if (_uid == null) throw Exception('User not set in FirestoreService');
    final q = await _periodsRef
        .where('startDate', isEqualTo: Timestamp.fromDate(e.startDate))
        .limit(1)
        .get();
    if (q.docs.isNotEmpty) {
      final existingId = q.docs.first.id;
      if (!overwrite) {
        throw Exception('conflict'); // caller should prompt user
      } else {
        await _periodsRef.doc(existingId).set(e.toMap());
        return;
      }
    }
    await _periodsRef.add(e.toMap());
  }

  Future<void> forceOverwriteStartDate(DateTime startDate, PeriodEntry e) async {
    if (_uid == null) throw Exception('User not set in FirestoreService');
    final q = await _periodsRef.where('startDate', isEqualTo: Timestamp.fromDate(startDate)).get();
    if (q.docs.isNotEmpty) {
      await _periodsRef.doc(q.docs.first.id).set(e.toMap());
    } else {
      await _periodsRef.add(e.toMap());
    }
  }

  Future<void> deleteEntry(String id) async {
    if (_uid == null) throw Exception('User not set in FirestoreService');
    await _periodsRef.doc(id).delete();
  }
}