import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/shopping_item.dart';

class ShoppingItemService {
  static final _col = FirebaseFirestore.instance.collection('shoppingItems');

  static Stream<List<ShoppingItem>> stream() {
    return _col.orderBy('itemName').snapshots().map((snap) {
      return snap.docs
          .map((d) => ShoppingItem.fromJson({'id': d.id, ...d.data()}))
          .toList();
    });
  }

  static Future<void> add(ShoppingItem item) async {
    await _col.doc(item.id).set(item.toJson());
  }

  static Future<void> update(ShoppingItem item) async {
    await _col.doc(item.id).set(item.toJson());
  }

  static Future<void> delete(String id) async {
    await _col.doc(id).delete();
  }
}
