import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exchange_rates.dart';

class TransactionService {
  static const String _transactionsKey = 'transactions';
  static const String _drawerUsdKey = 'drawer_usd';
  static const String _drawerLbpKey = 'drawer_lbp';

  // Save transaction
  static Future<void> saveTransaction(Transaction transaction) async {
    final prefs = await SharedPreferences.getInstance();
    final transactions = await getTransactions();
    transactions.add(transaction);
    
    final jsonList = transactions.map((t) => t.toJson()).toList();
    await prefs.setString(_transactionsKey, jsonEncode(jsonList));
  }

  // Get all transactions
  static Future<List<Transaction>> getTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_transactionsKey);
    
    if (jsonString == null) return [];
    
    final jsonList = jsonDecode(jsonString) as List;
    return jsonList.map((json) => Transaction.fromJson(json)).toList();
  }

  // Delete transaction
  static Future<void> deleteTransaction(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final transactions = await getTransactions();
    transactions.removeWhere((t) => t.id == id);
    
    final jsonList = transactions.map((t) => t.toJson()).toList();
    await prefs.setString(_transactionsKey, jsonEncode(jsonList));
  }

  // Mark transaction as exported
  static Future<void> markAsExported(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final transactions = await getTransactions();
    
    for (var t in transactions) {
      if (t.id == id) {
        t.isExported = true;
        break;
      }
    }
    
    final jsonList = transactions.map((t) => t.toJson()).toList();
    await prefs.setString(_transactionsKey, jsonEncode(jsonList));
  }

  // Clear all transactions
  static Future<void> clearAllTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_transactionsKey);
  }

  // Get drawer balance
  static Future<Map<String, double>> getDrawerBalance() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'usd': prefs.getDouble(_drawerUsdKey) ?? 0.0,
      'lbp': prefs.getDouble(_drawerLbpKey) ?? 0.0,
    };
  }

  // Update drawer balance
  static Future<void> updateDrawerBalance(double usd, double lbp) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_drawerUsdKey, usd);
    await prefs.setDouble(_drawerLbpKey, lbp);
  }

  // Calculate drawer changes from transactions
  static Map<String, double> calculateDrawerChanges(List<Transaction> transactions) {
    double usdChange = 0;
    double lbpChange = 0;

    for (var t in transactions) {
      switch (t.type) {
        case TransactionType.sellUsd:
          // We give LBP, receive nothing (paying customer)
          usdChange += t.usdAmount;  // We keep the USD
          lbpChange -= t.lbpAmount;  // We give out LBP
          break;
        case TransactionType.buyUsd:
          // Customer pays LBP, gets USD
          usdChange -= t.usdAmount;  // We give out USD
          lbpChange += t.lbpAmount;  // We receive LBP
          break;
        case TransactionType.sellLbp:
          // Customer pays LBP for USD account
          usdChange += t.usdAmount;  // We keep USD equivalent
          lbpChange += t.lbpAmount;  // We receive LBP
          break;
        case TransactionType.buyLbp:
          // Customer account is LBP, we pay USD
          usdChange -= t.usdAmount;  // We give out USD
          lbpChange += t.lbpAmount;  // We receive LBP equivalent
          break;
      }
    }

    return {'usd': usdChange, 'lbp': lbpChange};
  }

  // Export transactions to CSV format
  static String exportToCsv(List<Transaction> transactions) {
    final buffer = StringBuffer();
    buffer.writeln('ID,Date,Time,Type,USD Amount,LBP Amount,Rate,Customer,Notes,Exported');
    
    for (var t in transactions) {
      final date = '${t.timestamp.year}-${t.timestamp.month.toString().padLeft(2, '0')}-${t.timestamp.day.toString().padLeft(2, '0')}';
      final time = '${t.timestamp.hour.toString().padLeft(2, '0')}:${t.timestamp.minute.toString().padLeft(2, '0')}';
      buffer.writeln('${t.id},$date,$time,${t.typeLabel},${t.usdAmount},${t.lbpAmount},${t.rate},"${t.customerName ?? ''}","${t.notes ?? ''}",${t.isExported}');
    }
    
    return buffer.toString();
  }
}
