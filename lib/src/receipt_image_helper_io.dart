import 'dart:io';
import 'package:flutter/material.dart';

// Native platform implementation for receipt images using dart:io File.
Widget buildReceiptImage(String path, Widget placeholder) {
  return Image.file(
    File(path),
    width: 250,
    height: 350,
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) => placeholder,
  );
}
