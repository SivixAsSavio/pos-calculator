import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/exchange_rates.dart';
import '../services/transaction_service.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  List<Transaction> _transactions = [];
  bool _showExported = false;
  final _numberFormat = NumberFormat('#,###');
  final _currencyFormat = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    final transactions = await TransactionService.getTransactions();
    setState(() {
      _transactions = transactions;
    });
  }

  List<Transaction> get _filteredTransactions {
    if (_showExported) {
      return _transactions;
    }
    return _transactions.where((t) => !t.isExported).toList();
  }

  Future<void> _exportToCsv() async {
    try {
      final csv = TransactionService.exportToCsv(_filteredTransactions);
      
      // Get downloads folder
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('${directory.path}/transactions_$timestamp.csv');
      await file.writeAsString(csv);
      
      // Mark all as exported
      for (var t in _filteredTransactions) {
        if (!t.isExported) {
          await TransactionService.markAsExported(t.id);
        }
      }
      
      await _loadTransactions();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported to: ${file.path}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Copy Path',
              textColor: Colors.white,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: file.path));
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _copyAllToClipboard() async {
    final buffer = StringBuffer();
    buffer.writeln('=== Transaction Summary ===\n');
    
    final changes = TransactionService.calculateDrawerChanges(_filteredTransactions);
    buffer.writeln('Drawer Changes:');
    buffer.writeln('USD: ${changes['usd']! >= 0 ? '+' : ''}${_currencyFormat.format(changes['usd'])}');
    buffer.writeln('LBP: ${changes['lbp']! >= 0 ? '+' : ''}${_numberFormat.format(changes['lbp'])}');
    buffer.writeln('\n=== Transactions ===\n');
    
    for (var t in _filteredTransactions) {
      buffer.writeln('${DateFormat('yyyy-MM-dd HH:mm').format(t.timestamp)}');
      buffer.writeln('Type: ${t.typeLabel}');
      buffer.writeln('USD: ${_currencyFormat.format(t.usdAmount)}');
      buffer.writeln('LBP: ${_numberFormat.format(t.lbpAmount)}');
      buffer.writeln('Rate: ${_numberFormat.format(t.rate)}');
      buffer.writeln('---');
    }
    
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Copied to clipboard!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteTransaction(String id) async {
    await TransactionService.deleteTransaction(id);
    await _loadTransactions();
  }

  Future<void> _clearAllTransactions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Transactions?'),
        content: const Text('This will permanently delete all transactions. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      await TransactionService.clearAllTransactions();
      await _loadTransactions();
    }
  }

  Widget _buildCompactGroupCard({
    required String title,
    required Color color,
    required int count,
    required double usd,
    required int lbp,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                child: Text('$count', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('\$${_currencyFormat.format(usd)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          Text('LBP ${_numberFormat.format(lbp)}', style: TextStyle(fontSize: 12, color: Colors.grey[400])),
        ],
      ),
    );
  }

  // Calculate totals by rate group
  Map<String, dynamic> _calculateGroupedTotals() {
    // 89,500 rate transactions (sellUsd + buyUsd)
    double usd89500 = 0;
    int lbp89500 = 0;
    int count89500 = 0;
    
    // 89,750 rate transactions (sellLbp)
    double usd89750 = 0;
    int lbp89750 = 0;
    int count89750 = 0;
    
    for (var t in _filteredTransactions) {
      if (t.type == TransactionType.sellUsd || t.type == TransactionType.buyUsd) {
        usd89500 += t.usdAmount;
        lbp89500 += t.lbpAmount;
        count89500++;
      } else if (t.type == TransactionType.sellLbp) {
        usd89750 += t.usdAmount;
        lbp89750 += t.lbpAmount;
        count89750++;
      }
    }
    
    return {
      'usd89500': usd89500,
      'lbp89500': lbp89500,
      'count89500': count89500,
      'usd89750': usd89750,
      'lbp89750': lbp89750,
      'count89750': count89750,
    };
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _calculateGroupedTotals();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: Icon(_showExported ? Icons.visibility : Icons.visibility_off),
            tooltip: _showExported ? 'Hide Exported' : 'Show Exported',
            onPressed: () {
              setState(() => _showExported = !_showExported);
            },
          ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy All',
            onPressed: _filteredTransactions.isNotEmpty ? _copyAllToClipboard : null,
          ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export CSV',
            onPressed: _filteredTransactions.isNotEmpty ? _exportToCsv : null,
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            tooltip: 'Clear All',
            onPressed: _transactions.isNotEmpty ? _clearAllTransactions : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // Summary Cards - Side by Side
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: Row(
              children: [
                // 89,500 Rate Group (Pay LBP + Get USD)
                Expanded(
                  child: grouped['count89500'] > 0
                      ? _buildCompactGroupCard(
                          title: '89,500',
                          color: Colors.orange,
                          count: grouped['count89500'],
                          usd: grouped['usd89500'],
                          lbp: grouped['lbp89500'],
                        )
                      : Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('89,500\nNo transactions', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ),
                ),
                const SizedBox(width: 8),
                // 89,750 Rate Group (Charge LBP)
                Expanded(
                  child: grouped['count89750'] > 0
                      ? _buildCompactGroupCard(
                          title: '89,750',
                          color: Colors.blue,
                          count: grouped['count89750'],
                          usd: grouped['usd89750'],
                          lbp: grouped['lbp89750'],
                        )
                      : Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('89,750\nNo transactions', style: TextStyle(fontSize: 10, color: Colors.grey)),
                        ),
                ),
              ],
            ),
          ),
          
          // Transaction List
          Expanded(
            child: _filteredTransactions.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No transactions yet',
                          style: TextStyle(color: Colors.grey, fontSize: 18),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final t = _filteredTransactions[_filteredTransactions.length - 1 - index];
                      return _buildTransactionCard(t);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Transaction t) {
    Color typeColor;
    
    switch (t.type) {
      case TransactionType.sellUsd:
        typeColor = Colors.orange;
        break;
      case TransactionType.buyUsd:
        typeColor = Colors.green;
        break;
      case TransactionType.sellLbp:
        typeColor = Colors.blue;
        break;
      case TransactionType.buyLbp:
        typeColor = Colors.purple;
        break;
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2a2a2a),
        borderRadius: BorderRadius.circular(6),
        border: Border(left: BorderSide(color: typeColor, width: 3)),
      ),
      child: Row(
        children: [
          // Time
          SizedBox(
            width: 42,
            child: Text(
              DateFormat('HH:mm').format(t.timestamp),
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ),
          // USD
          Expanded(
            child: Text(
              '\$${_currencyFormat.format(t.usdAmount)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ),
          // Arrow
          Icon(Icons.arrow_forward, size: 12, color: Colors.grey[600]),
          const SizedBox(width: 8),
          // LBP
          Expanded(
            child: Text(
              'LBP ${_numberFormat.format(t.lbpAmount)}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          // Exported badge
          if (t.isExported)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.3), borderRadius: BorderRadius.circular(3)),
              child: const Text('✓', style: TextStyle(fontSize: 10, color: Colors.green)),
            ),
          // Delete
          GestureDetector(
            onTap: () => _deleteTransaction(t.id),
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Icon(Icons.close, size: 16, color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }

  // Keep old method for reference but unused
  Widget _buildTransactionCardOld(Transaction t) {
    Color typeColor;
    
    // Empty fallback
    return const SizedBox();
  }
}
