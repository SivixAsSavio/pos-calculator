import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CashCount {
  final String timestamp;
  final String date;  // Date key for grouping (dd/MM/yyyy)
  final List<int> usdQty;  // 100, 50, 20, 10, 5, 1
  final List<int> lbpQty;  // 100k, 50k, 20k, 10k, 5k, 1k
  final double usdTotal;
  final int lbpTotal;
  final double tajUsd;
  final int tajLbp;
  final String usdTest;
  final String lbpTest;

  CashCount({
    required this.timestamp,
    required this.date,
    required this.usdQty,
    required this.lbpQty,
    required this.usdTotal,
    required this.lbpTotal,
    required this.tajUsd,
    required this.tajLbp,
    required this.usdTest,
    required this.lbpTest,
  });

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'date': date,
    'usdQty': usdQty,
    'lbpQty': lbpQty,
    'usdTotal': usdTotal,
    'lbpTotal': lbpTotal,
    'tajUsd': tajUsd,
    'tajLbp': tajLbp,
    'usdTest': usdTest,
    'lbpTest': lbpTest,
  };

  factory CashCount.fromJson(Map<String, dynamic> json) => CashCount(
    timestamp: json['timestamp'],
    date: json['date'] ?? json['timestamp'].toString().split(' ')[0],  // Fallback for old data
    usdQty: List<int>.from(json['usdQty']),
    lbpQty: List<int>.from(json['lbpQty']),
    usdTotal: json['usdTotal'].toDouble(),
    lbpTotal: json['lbpTotal'],
    tajUsd: json['tajUsd'].toDouble(),
    tajLbp: json['tajLbp'],
    usdTest: json['usdTest'],
    lbpTest: json['lbpTest'],
  );
}

class CashCountService {
  static const _key = 'cash_counts';

  static Future<List<CashCount>> getCashCounts() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_key) ?? [];
    return data.map((e) => CashCount.fromJson(jsonDecode(e))).toList();
  }

  static Future<List<CashCount>> getCashCountsByDate(String date) async {
    final all = await getCashCounts();
    return all.where((c) => c.date == date).toList();
  }

  static Future<Set<DateTime>> getDatesWithCounts() async {
    final all = await getCashCounts();
    final dates = <DateTime>{};
    for (final count in all) {
      try {
        final parts = count.date.split('/');
        if (parts.length == 3) {
          dates.add(DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0])));
        }
      } catch (_) {}
    }
    return dates;
  }

  static Future<void> saveCashCount(CashCount count) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_key) ?? [];
    data.add(jsonEncode(count.toJson()));
    await prefs.setStringList(_key, data);
  }
}
