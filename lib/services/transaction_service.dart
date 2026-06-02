import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;

import '../models/transaction.dart';

class TransactionService {
  static final _col = FirebaseFirestore.instance.collection('transactions');

  static Stream<List<Transaction>> stream() {
    return _col.orderBy('date').snapshots().map(
          (snap) => snap.docs.map((d) => Transaction.fromJson(_fix(d))).toList(),
        );
  }

  static Future<void> add(Transaction t) async {
    await _col.doc(t.id).set(t.toJson());
  }

  static Future<void> update(Transaction t) async {
    await _col.doc(t.id).set(t.toJson());
  }

  static Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  static Future<void> deleteAll() async {
    final snap = await _col.get();
    final batch = FirebaseFirestore.instance.batch();
    for (final d in snap.docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  static Map<String, dynamic> _fix(DocumentSnapshot d) {
    final data = d.data() as Map<String, dynamic>;
    if (data['date'] is Timestamp) {
      data['date'] = (data['date'] as Timestamp).toDate().toIso8601String();
    }
    data['id'] = d.id;
    return data;
  }
}
