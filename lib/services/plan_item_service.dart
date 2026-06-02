import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/plan_item.dart';

class PlanItemService {
  static final _col = FirebaseFirestore.instance.collection('planItems');

  static Stream<List<PlanItem>> stream() {
    return _col.orderBy('itemName').snapshots().map((snap) {
      return snap.docs
          .map((d) => PlanItem.fromJson({'id': d.id, ...d.data()}))
          .toList();
    });
  }

  static Future<void> add(PlanItem item) async {
    await _col.doc(item.id).set(item.toJson());
  }

  static Future<void> update(PlanItem item) async {
    await _col.doc(item.id).set(item.toJson());
  }

  static Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
