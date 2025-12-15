import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CashCount {
  final String timestamp;
  final String date;  // Date key for grouping (dd/MM/yyyy)
  final String userName;  // User who counted (e.g., "SAVIO")
  final List<int> branchUsdQty;  // Branch/Safe USD: 100, 50, 20, 10, 5, 1
  final List<int> branchLbpQty;  // Branch/Safe LBP: 100k, 50k, 20k, 10k, 5k, 1k
  final List<int> usdQty;  // User drawer USD: 100, 50, 20, 10, 5, 1
  final List<int> lbpQty;  // User drawer LBP: 100k, 50k, 20k, 10k, 5k, 1k
  final double usdTotal;
  final int lbpTotal;
  final double tajUsd;
  final int tajLbp;
  final String usdTest;
  final String lbpTest;

  CashCount({
    required this.timestamp,
    required this.date,
    this.userName = '',
    List<int>? branchUsdQty,
    List<int>? branchLbpQty,
    required this.usdQty,
    required this.lbpQty,
    required this.usdTotal,
    required this.lbpTotal,
    required this.tajUsd,
    required this.tajLbp,
    required this.usdTest,
    required this.lbpTest,
  }) : branchUsdQty = branchUsdQty ?? [0, 0, 0, 0, 0, 0],
       branchLbpQty = branchLbpQty ?? [0, 0, 0, 0, 0, 0];

  // Calculate branch totals
  int get branchUsdTotal {
    const multipliers = [100, 50, 20, 10, 5, 1];
    int total = 0;
    for (int i = 0; i < branchUsdQty.length && i < multipliers.length; i++) {
      total += branchUsdQty[i] * multipliers[i];
    }
    return total;
  }

  int get branchLbpTotal {
    const multipliers = [100000, 50000, 20000, 10000, 5000, 1000];
    int total = 0;
    for (int i = 0; i < branchLbpQty.length && i < multipliers.length; i++) {
      total += branchLbpQty[i] * multipliers[i];
    }
    return total;
  }

  Map<String, dynamic> toJson() => {
    'timestamp': timestamp,
    'date': date,
    'userName': userName,
    'branchUsdQty': branchUsdQty,
    'branchLbpQty': branchLbpQty,
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
    userName: json['userName'] ?? '',
    branchUsdQty: json['branchUsdQty'] != null ? List<int>.from(json['branchUsdQty']) : null,
    branchLbpQty: json['branchLbpQty'] != null ? List<int>.from(json['branchLbpQty']) : null,
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
