import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/budget_plan_item.dart';

class BudgetPlanService {
  static final _col = FirebaseFirestore.instance.collection('budgetPlans');

  static Stream<List<BudgetPlanItem>> streamByMonth(String monthKey) {
    return _col
        .where('monthKey', isEqualTo: monthKey)
        .orderBy('itemName')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => BudgetPlanItem.fromJson({'id': d.id, ...d.data()}))
            .toList());
  }

  static Future<void> save(BudgetPlanItem item) async {
    await _col.doc(item.id).set(item.toJson());
  }

  static Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }

  static Future<void> updateSig(String monthKey, String field, String? signatureUrl) async {
    final query = await _col.where('monthKey', isEqualTo: monthKey).get();
    final batch = FirebaseFirestore.instance.batch();
    for (final doc in query.docs) {
      batch.update(doc.reference, {field: signatureUrl});
    }
    await batch.commit();
  }
}
