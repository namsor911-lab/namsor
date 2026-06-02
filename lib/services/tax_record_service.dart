import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/profit_tax_record.dart';
import '../models/tax_record.dart';
import '../models/vat_record.dart';

class TaxRecordService {
  static final _empCol = FirebaseFirestore.instance.collection('tax_employees');
  static final _vatCol = FirebaseFirestore.instance.collection('tax_vat');
  static final _profitCol = FirebaseFirestore.instance.collection('tax_profit');

  static Stream<List<TaxRecord>> employeeStream() {
    return _empCol.snapshots().map((snap) => snap.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          return TaxRecord.fromJson(data);
        }).toList());
  }

  static Future<void> addEmployee(TaxRecord record) async {
    await _empCol.doc(record.id).set(record.toJson());
  }

  static Future<void> updateEmployee(TaxRecord record) async {
    await _empCol.doc(record.id).set(record.toJson());
  }

  static Future<void> deleteEmployee(String id) async {
    await _empCol.doc(id).delete();
  }

  static Stream<List<VatRecord>> vatStream() {
    return _vatCol.snapshots().map((snap) => snap.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          return VatRecord.fromJson(data);
        }).toList());
  }

  static Future<void> addVat(VatRecord record) async {
    await _vatCol.doc(record.id).set(record.toJson());
  }

  static Future<void> updateVat(VatRecord record) async {
    await _vatCol.doc(record.id).set(record.toJson());
  }

  static Future<void> deleteVat(String id) async {
    await _vatCol.doc(id).delete();
  }

  static Stream<List<ProfitTaxRecord>> profitStream() {
    return _profitCol.snapshots().map((snap) => snap.docs.map((doc) {
          final data = Map<String, dynamic>.from(doc.data());
          data['id'] = doc.id;
          return ProfitTaxRecord.fromJson(data);
        }).toList());
  }

  static Future<void> addProfit(ProfitTaxRecord record) async {
    await _profitCol.doc(record.id).set(record.toJson());
  }

  static Future<void> updateProfit(ProfitTaxRecord record) async {
    await _profitCol.doc(record.id).set(record.toJson());
  }

  static Future<void> deleteProfit(String id) async {
    await _profitCol.doc(id).delete();
  }
}
