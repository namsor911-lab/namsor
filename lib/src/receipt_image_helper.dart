import 'package:flutter/material.dart';

// Web-safe fallback for receipt images.
Widget buildReceiptImage(String path, Widget placeholder) {
  return Image.network(
    path,
    width: 250,
    height: 350,
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) => placeholder,
  );
}
