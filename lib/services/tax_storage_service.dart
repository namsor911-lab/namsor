import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tax_record.dart';

class TaxRecordService {
  static final _col = FirebaseFirestore.instance.collection('taxRecords');

  static Stream<List<TaxRecord>> stream() {
    return _col.orderBy('taxYear').snapshots().map((snap) {
      return snap.docs
          .map((d) => TaxRecord.fromJson({'id': d.id, ...d.data()}))
          .toList();
    });
  }

  static Future<void> add(TaxRecord record) async {
    await _col.doc(record.id).set(record.toJson());
  }

  static Future<void> update(TaxRecord record) async {
    await _col.doc(record.id).set(record.toJson());
  }

  static Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
