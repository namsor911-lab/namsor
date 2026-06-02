import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:accounting/models/transaction.dart';

const String currencySymbol = '₭';

const List<String> months = [
  'ມັງກອນ', 'ກຸມພາ', 'ມີນາ', 'ເມສາ', 'ພຶດສະພາ', 'ມິຖຸນາ',
  'ກໍລະກົດ', 'ສິງຫາ', 'ກັນຍາ', 'ຕຸລາ', 'ພະຈິກ', 'ທັນວາ',
];

const List<String> monthsShort = [
  'ມ.ກ', 'ກ.ພ', 'ມ.ນ', 'ມ.ສ', 'ພ.ສ', 'ມ.ຖ',
  'ກ.ກ', 'ສ.ຫ', 'ກ.ຍ', 'ຕ.ລ', 'ພ.ຈ', 'ທ.ວ',
];

const List<Map<String, dynamic>> quarters = [
  {'name': 'Q1', 'months': [1, 2, 3], 'color': Color(0xFF58A6FF)},
  {'name': 'Q2', 'months': [4, 5, 6], 'color': Color(0xFF3FB950)},
  {'name': 'Q3', 'months': [7, 8, 9], 'color': Color(0xFFD29922)},
  {'name': 'Q4', 'months': [10, 11, 12], 'color': Color(0xFFBC8CFF)},
];

const List<String> signatureRoles = [
  'ຜູ້ອຳນວຍການ',
  'ຫົວໜ້າເຂື່ອນ',
  'ບັນຊີ-ການເງິນ',
  'ຜູ້ສະຫຼຸບ',
];

const List<String> budgetSignatureRoles = [
  'ຜູ້ຮັບຜິດຊອບ',
  'ຜູ້ອຳນວຍການ',
  'ຫົວໜ້າເຂື່ອນ',
  'ຜູ້ອະນຸມັດ',
];

const List<String> budgetCategories = [
  'ອຸປະກອນ',
  'ວັດສະດຸ',
  'ເຄື່ອງຈັກ',
  'ອາຫານ',
  'ນ້ຳມັນ',
  'ອື່ນໆ',
];

String formatMoney(double amount) {
  return NumberFormat('#,###', 'lo').format(amount);
}

String formatMoneyWithSign(double amount) {
  if (amount < 0) {
    return '−${formatMoney(amount.abs())}';
  }
  return formatMoney(amount);
}

String formatMoneyWithCurrency(double amount) {
  return '${formatMoney(amount)} $currencySymbol';
}

String formatMoneyWithSignAndCurrency(double amount) {
  if (amount < 0) {
    return '−${formatMoney(amount.abs())} $currencySymbol';
  }
  return '${formatMoney(amount)} $currencySymbol';
}

double getOpeningBalance(List<Transaction> transactions, int year, int month) {
  final boundary = DateTime(year, month, 1);
  return transactions
      .where((t) => t.date.isBefore(boundary))
      .fold(0.0, (sum, t) => sum + (t.income - t.expense));
}

double getTotalBalance(List<Transaction> transactions) {
  return transactions.fold(0.0, (sum, t) => sum + (t.income - t.expense));
}

List<Transaction> recalculateBalances(List<Transaction> transactions) {
  final sorted = [...transactions]..sort((a, b) => a.date.compareTo(b.date));
  double cumulative = 0.0;
  return sorted
      .map((t) {
        cumulative += t.income - t.expense;
        return t.copyWith(balance: cumulative);
      })
      .toList();
}
