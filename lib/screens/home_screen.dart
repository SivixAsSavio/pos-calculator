import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/exchange_rates.dart';
import '../services/transaction_service.dart';
import '../services/cash_count_service.dart';
import '../services/branch_settings_service.dart';
import 'transactions_screen.dart';
import 'cash_count_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Selected mode: 0 = Pay LBP (89,500), 1 = Get USD (89,500), 2 = Charge LBP (89,750)
  int _selectedMode = 0;
  
  final _inputController = TextEditingController();
  final _inputFocusNode = FocusNode();
  String _result = '';
  int _pendingCount = 0;
  
  // Undo support - persistent history (5 steps)
  List<Map<String, dynamic>> _undoHistory = [];
  int _undoIndex = -1;
  
  // TAJ stored values for Cash Count
  double _tajUsd = 0;
  int _tajLbp = 0;
  
  // Cash Count stored values (persist between dialogs)
  late List<int> _usdQty;  // 100, 50, 20, 10, 5, 1
  late List<int> _lbpQty;  // 100k, 50k, 20k, 10k, 5k, 1k
  
  final _numberFormat = NumberFormat('#,###');
  final _currencyFormat = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _usdQty = <int>[0, 0, 0, 0, 0, 0];
    _lbpQty = <int>[0, 0, 0, 0, 0, 0];
    _loadPendingCount();
    _loadUndoHistory();
  }
  
  Future<void> _loadUndoHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('undo_history') ?? [];
    setState(() {
      _undoHistory = data.map((e) => Map<String, dynamic>.from(jsonDecode(e))).toList();
      _undoIndex = _undoHistory.length - 1;
    });
  }
  
  Future<void> _saveToUndoHistory(String input, String result, int mode) async {
    if (input.isEmpty) return;
    
    final entry = {
      'input': input,
      'result': result,
      'mode': mode,
    };
    
    _undoHistory.add(entry);
    // Keep only last 5
    if (_undoHistory.length > 5) {
      _undoHistory.removeAt(0);
    }
    _undoIndex = _undoHistory.length - 1;
    
    // Persist
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('undo_history', _undoHistory.map((e) => jsonEncode(e)).toList());
  }
  
  void _undo() {
    if (_undoHistory.isEmpty) return;
    
    if (_undoIndex >= 0) {
      final entry = _undoHistory[_undoIndex];
      _inputController.text = entry['input'];
      setState(() {
        _selectedMode = entry['mode'];
        _result = entry['result'];
      });
      _undoIndex--;
    }
  }

  Future<void> _loadPendingCount() async {
    final transactions = await TransactionService.getTransactions();
    setState(() {
      _pendingCount = transactions.where((t) => !t.isExported).length;
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _calculate() {
    final input = _inputController.text.replaceAll(',', '');
    if (input.isEmpty) {
      setState(() => _result = '');
      return;
    }
    
    switch (_selectedMode) {
      case 0: // Get USD <- LBP to USD (89,500)
        final lbp = int.tryParse(input);
        if (lbp == null) {
          setState(() => _result = 'Invalid');
          return;
        }
        final usd = ExchangeRates.lbpToUsdBuyUsd(lbp);
        setState(() => _result = 'USD ${_currencyFormat.format(usd)}');
        break;
      case 1: // Pay LBP -> USD to LBP (89,500)
        final usd = double.tryParse(input);
        if (usd == null) {
          setState(() => _result = 'Invalid');
          return;
        }
        final lbp = ExchangeRates.usdToLbpSellUsd(usd);
        setState(() => _result = 'LBP ${_numberFormat.format(lbp)}');
        break;
      case 2: // Charge LBP (89,750) - Customer pays LBP for USD account
        final usd = double.tryParse(input);
        if (usd == null) {
          setState(() => _result = 'Invalid');
          return;
        }
        final lbp = ExchangeRates.usdToLbpSellLbp(usd);
        setState(() => _result = 'LBP ${_numberFormat.format(lbp)}');
        break;
    }
  }

  Future<void> _saveTransaction() async {
    final input = _inputController.text.replaceAll(',', '');
    if (input.isEmpty || _result.isEmpty || _result == 'Invalid') return;
    
    TransactionType type;
    double usd;
    int lbp;
    
    switch (_selectedMode) {
      case 0:
        lbp = int.parse(input);
        usd = ExchangeRates.lbpToUsdBuyUsd(lbp);
        type = TransactionType.buyUsd;
        break;
      case 1:
        usd = double.parse(input);
        lbp = ExchangeRates.usdToLbpSellUsd(usd);
        type = TransactionType.sellUsd;
        break;
      case 2:
        usd = double.parse(input);
        lbp = ExchangeRates.usdToLbpSellLbp(usd);
        type = TransactionType.sellLbp;
        break;
      default:
        return;
    }
    
    final transaction = Transaction(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      timestamp: DateTime.now(),
      type: type,
      usdAmount: usd,
      lbpAmount: lbp,
    );
    
    await TransactionService.saveTransaction(transaction);
    await _loadPendingCount();
    
    // Save to undo history before clearing
    await _saveToUndoHistory(_inputController.text, _result, _selectedMode);
    
    // Clear input after saving
    _inputController.clear();
    setState(() => _result = '');
    _inputFocusNode.requestFocus();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✓ Saved'),
          backgroundColor: Colors.green,
          duration: Duration(milliseconds: 800),
        ),
      );
    }
  }

  void _onModeChanged(int mode) {
    setState(() {
      _selectedMode = mode;
      _result = '';
    });
    _inputController.clear();
    _inputFocusNode.requestFocus();
  }

  void _showChangeCalculatorDialog() {
    final lbpAmountController = TextEditingController();
    final usdPaidController = TextEditingController();
    final usdGiveController = TextEditingController();
    String usdEquivalent = '';
    String changeUsd = '';
    String changeLbp = '';
    double changeAmount = 0;
    String remainingLbp = '';
    // For when customer is short and pays remaining in LBP
    double shortAmount = 0;
    String shortLbpAtChargeRate = '';
    
    // Auto-populate from calculator if in Get USD mode (mode 0)
    if (_selectedMode == 0 && _inputController.text.isNotEmpty) {
      lbpAmountController.text = _inputController.text;
    }
    
    void calculate() {
      final lbpAmount = int.tryParse(lbpAmountController.text.replaceAll(',', '')) ?? 0;
      final usdPaid = double.tryParse(usdPaidController.text.replaceAll(',', '')) ?? 0;
      final usdGive = double.tryParse(usdGiveController.text.replaceAll(',', '')) ?? 0;
      
      if (lbpAmount > 0) {
        final usdValue = lbpAmount / ExchangeRates.sellUsdRate;
        usdEquivalent = '\$${_currencyFormat.format(usdValue)}';
        
        if (usdPaid > 0) {
          final change = usdPaid - usdValue;
          changeAmount = change;
          if (change >= 0) {
            changeUsd = '\$${_currencyFormat.format(change)}';
            changeLbp = '${_numberFormat.format((change * ExchangeRates.sellUsdRate).round())} LBP';
            shortAmount = 0;
            shortLbpAtChargeRate = '';
            
            // Calculate remaining after USD given
            if (usdGive > 0 && usdGive < change) {
              final remaining = change - usdGive;
              remainingLbp = '${_numberFormat.format((remaining * ExchangeRates.sellUsdRate).round())} LBP';
            } else {
              remainingLbp = '';
            }
          } else {
            // Customer is SHORT - needs to pay more
            shortAmount = -change;
            changeUsd = 'Short \$${_currencyFormat.format(shortAmount)}';
            // Calculate what they owe in LBP at CHARGE rate (89,750)
            final lbpOwed = (shortAmount * ExchangeRates.sellLbpRate).round();
            shortLbpAtChargeRate = '${_numberFormat.format(lbpOwed)} LBP';
            changeLbp = '';
            remainingLbp = '';
          }
        } else {
          changeUsd = '';
          changeLbp = '';
          remainingLbp = '';
          shortAmount = 0;
          shortLbpAtChargeRate = '';
        }
      } else {
        usdEquivalent = '';
        changeUsd = '';
        changeLbp = '';
        remainingLbp = '';
        shortAmount = 0;
        shortLbpAtChargeRate = '';
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Calculate initial values if pre-populated
          if (lbpAmountController.text.isNotEmpty && usdEquivalent.isEmpty) {
            calculate();
          }
          
          return AlertDialog(
            backgroundColor: const Color(0xFF2a2a2a),
            title: Row(
              children: [
                const Icon(Icons.currency_exchange, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Exchange Calculator',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
            content: SizedBox(
              width: 320,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer pays USD for LBP amount',
                      style: TextStyle(color: Colors.grey[500], fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    // LBP Amount input
                    Text('Amount in LBP:', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: lbpAmountController,
                      autofocus: lbpAmountController.text.isEmpty,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        _ThousandsSeparatorInputFormatter(),
                      ],
                      decoration: InputDecoration(
                        hintText: 'e.g. 1,650,000',
                        hintStyle: TextStyle(color: Colors.grey[700]),
                        filled: true,
                        fillColor: const Color(0xFF1a1a1a),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (_) {
                        calculate();
                        setDialogState(() {});
                      },
                    ),
                    // Show USD equivalent
                    if (usdEquivalent.isNotEmpty) ...[  
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Equals:', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                            Text(
                              usdEquivalent,
                              style: const TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    // USD Paid input
                    Text('Customer Pays (USD):', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                    const SizedBox(height: 4),
                    TextField(
                      controller: usdPaidController,
                      autofocus: lbpAmountController.text.isNotEmpty,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                        _ThousandsSeparatorInputFormatter(),
                      ],
                      decoration: InputDecoration(
                        hintText: 'e.g. 20',
                        hintStyle: TextStyle(color: Colors.grey[700]),
                        filled: true,
                        fillColor: const Color(0xFF1a1a1a),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (_) {
                        calculate();
                        setDialogState(() {});
                      },
                    ),
                    // Show change or short amount
                    if (changeUsd.isNotEmpty) ...[  
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: shortAmount > 0 
                              ? Colors.red.withOpacity(0.15) 
                              : Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: shortAmount > 0 
                                ? Colors.red.withOpacity(0.3) 
                                : Colors.orange.withOpacity(0.3)
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              shortAmount > 0 ? 'CUSTOMER OWES' : 'CHANGE TO GIVE',
                              style: TextStyle(
                                color: shortAmount > 0 ? Colors.red : Colors.orange, 
                                fontSize: 11, 
                                fontWeight: FontWeight.bold
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              changeUsd,
                              style: TextStyle(
                                color: shortAmount > 0 ? Colors.red : Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (changeLbp.isNotEmpty) ...[  
                              const SizedBox(height: 2),
                              Text(
                                changeLbp,
                                style: const TextStyle(color: Colors.blue, fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                            ],
                            // Show LBP amount at charge rate when customer is short
                            if (shortAmount > 0 && shortLbpAtChargeRate.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Customer pays in LBP (at 89,750):',
                                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      shortLbpAtChargeRate,
                                      style: const TextStyle(color: Colors.blue, fontSize: 18, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    // USD I Give section (when change > 0)
                    if (changeAmount > 0 && !changeUsd.contains('Need')) ...[  
                      const SizedBox(height: 12),
                      Text('USD I Give:', style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                      const SizedBox(height: 4),
                      TextField(
                        controller: usdGiveController,
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                        ],
                        decoration: InputDecoration(
                          hintText: 'e.g. 20 (if you don\'t have exact change)',
                          hintStyle: TextStyle(color: Colors.grey[700], fontSize: 12),
                          filled: true,
                          fillColor: const Color(0xFF1a1a1a),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        onChanged: (_) {
                          calculate();
                          setDialogState(() {});
                        },
                      ),
                      // Show remaining in LBP
                      if (remainingLbp.isNotEmpty) ...[  
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue.withOpacity(0.3)),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'REMAINING IN LBP',
                                style: TextStyle(color: Colors.blue, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                remainingLbp,
                                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: Colors.grey)),
              ),
              // Save button - works for both overpay (change) and underpay (short)
              if ((changeAmount > 0 && !changeUsd.contains('Short')) || shortAmount > 0)
                TextButton(
                  onPressed: () async {
                    final lbpAmount = int.tryParse(lbpAmountController.text.replaceAll(',', '')) ?? 0;
                    final usdPaid = double.tryParse(usdPaidController.text.replaceAll(',', '')) ?? 0;
                    
                    if (lbpAmount > 0 && usdPaid > 0) {
                      if (shortAmount > 0) {
                        // Customer is SHORT - paid less USD, will pay remaining in LBP
                        // Save TWO transactions:
                        // 1. Buy USD transaction for the USD received
                        final lbpForUsd = (usdPaid * ExchangeRates.sellUsdRate).round();
                        final t1 = Transaction(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          timestamp: DateTime.now(),
                          type: TransactionType.buyUsd,
                          usdAmount: usdPaid,
                          lbpAmount: lbpForUsd,
                        );
                        await TransactionService.saveTransaction(t1);
                        
                        // 2. Charge LBP transaction for the remaining amount at 89,750
                        final lbpOwed = (shortAmount * ExchangeRates.sellLbpRate).round();
                        final t2 = Transaction(
                          id: (DateTime.now().millisecondsSinceEpoch + 1).toString(),
                          timestamp: DateTime.now(),
                          type: TransactionType.sellLbp,
                          usdAmount: shortAmount,
                          lbpAmount: lbpOwed,
                        );
                        await TransactionService.saveTransaction(t2);
                        
                        await _loadPendingCount();
                        await _saveToUndoHistory(
                          lbpAmountController.text, 
                          'USD ${_currencyFormat.format(usdPaid)} + ${_numberFormat.format(lbpOwed)} LBP', 
                          1
                        );
                        
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✓ Saved: \$${_currencyFormat.format(usdPaid)} + ${_numberFormat.format(lbpOwed)} LBP'),
                            backgroundColor: Colors.green,
                            duration: const Duration(milliseconds: 1200),
                          ),
                        );
                      } else {
                        // Customer OVERPAID - save as single Buy USD transaction
                        final usd = lbpAmount / ExchangeRates.sellUsdRate;
                        final transaction = Transaction(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          timestamp: DateTime.now(),
                          type: TransactionType.buyUsd,
                          usdAmount: usd,
                          lbpAmount: lbpAmount,
                        );
                        await TransactionService.saveTransaction(transaction);
                        await _loadPendingCount();
                        
                        await _saveToUndoHistory(
                          lbpAmountController.text, 
                          'USD ${_currencyFormat.format(usd)}', 
                          1
                        );
                        
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('✓ Exchange saved'),
                            backgroundColor: Colors.green,
                            duration: Duration(milliseconds: 800),
                          ),
                        );
                      }
                    }
                  },
                  child: Text(
                    shortAmount > 0 ? 'Save (USD + LBP)' : 'Save Exchange', 
                    style: const TextStyle(color: Colors.orange)
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  void _showShortcutsHelp() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2a2a2a),
        title: const Text(
          'Keyboard Shortcuts',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _shortcutRow('↑ / ↓', 'Switch mode'),
            _shortcutRow('Enter', 'Save transaction'),
            _shortcutRow('F1', 'Open transactions'),
            _shortcutRow('F2', 'TAJ balance'),
            _shortcutRow('F3', 'Cash count'),
            _shortcutRow('F4', 'Cash count history'),
            _shortcutRow('F5', 'Exchange calculator'),
            _shortcutRow('F6', 'Windows Calculator'),
            _shortcutRow('F8', 'Branch settings (Safe)'),
            _shortcutRow('→ / Ctrl+Z', 'Undo clear'),
            _shortcutRow('Esc', 'Clear input'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
  }

  Widget _shortcutRow(String key, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              key,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            desc,
            style: TextStyle(color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showDrawerBalanceDialog() {
    final usdCountController = TextEditingController();
    final usdPosController = TextEditingController();
    final lbpCountController = TextEditingController();
    final lbpPosController = TextEditingController();
    String usdResult = '';
    String lbpResult = '';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void calculate() {
            // TAJ USD calculation
            final usdCount = double.tryParse(usdCountController.text.replaceAll(',', '')) ?? 0;
            final usdPos = double.tryParse(usdPosController.text.replaceAll(',', '')) ?? 0;
            final actualUsd = usdCount - usdPos;
            
            // TAJ LBP calculation
            final lbpCount = int.tryParse(lbpCountController.text.replaceAll(',', '')) ?? 0;
            final lbpPos = int.tryParse(lbpPosController.text.replaceAll(',', '')) ?? 0;
            final actualLbp = lbpCount - lbpPos;
            
            setDialogState(() {
              usdResult = usdCount > 0 || usdPos != 0 
                  ? 'Actual: \$${_currencyFormat.format(actualUsd)}' 
                  : '';
              lbpResult = lbpCount > 0 || lbpPos != 0 
                  ? 'Actual: ${_numberFormat.format(actualLbp)} LBP' 
                  : '';
            });
          }
          
          return AlertDialog(
            backgroundColor: const Color(0xFF2a2a2a),
            title: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'TAJ Balance',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // TAJ USD Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TAJ USD',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: usdCountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                            _ThousandsSeparatorInputFormatter(),
                          ],
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'USD Count',
                            labelStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                            prefixText: '\$ ',
                            prefixStyle: const TextStyle(color: Colors.green),
                            isDense: true,
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.green),
                            ),
                          ),
                          onChanged: (_) => calculate(),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: usdPosController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[\d.,-]')),
                            _ThousandsSeparatorInputFormatter(),
                          ],
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'POS Balance (- or +)',
                            labelStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                            hintText: 'e.g. -193 or 193',
                            hintStyle: TextStyle(color: Colors.grey[700], fontSize: 12),
                            prefixText: '\$ ',
                            prefixStyle: const TextStyle(color: Colors.orange),
                            isDense: true,
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.orange),
                            ),
                          ),
                          onChanged: (_) => calculate(),
                        ),
                        if (usdResult.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            usdResult,
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // TAJ LBP Section
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TAJ LBP',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: lbpCountController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[\d,]')),
                            _ThousandsSeparatorInputFormatter(),
                          ],
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'LBP Count',
                            labelStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                            prefixText: 'LBP ',
                            prefixStyle: const TextStyle(color: Colors.blue),
                            isDense: true,
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue),
                            ),
                          ),
                          onChanged: (_) => calculate(),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: lbpPosController,
                          keyboardType: const TextInputType.numberWithOptions(signed: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[\d,-]')),
                            _ThousandsSeparatorInputFormatter(),
                          ],
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'POS Balance (- or +)',
                            labelStyle: TextStyle(color: Colors.grey[500], fontSize: 12),
                            hintText: 'e.g. -500,000 or 500,000',
                            hintStyle: TextStyle(color: Colors.grey[700], fontSize: 12),
                            prefixText: 'LBP ',
                            prefixStyle: const TextStyle(color: Colors.orange),
                            isDense: true,
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.orange),
                            ),
                          ),
                          onChanged: (_) => calculate(),
                        ),
                        if (lbpResult.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            lbpResult,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () {
                  // Store TAJ values
                  final usdCount = double.tryParse(usdCountController.text.replaceAll(',', '')) ?? 0;
                  final usdPos = double.tryParse(usdPosController.text.replaceAll(',', '')) ?? 0;
                  final lbpCount = int.tryParse(lbpCountController.text.replaceAll(',', '')) ?? 0;
                  final lbpPos = int.tryParse(lbpPosController.text.replaceAll(',', '')) ?? 0;
                  _tajUsd = usdCount - usdPos;
                  _tajLbp = lbpCount - lbpPos;
                  Navigator.pop(context);
                  _showCashCountDialog();
                },
                child: const Text('→ Cash Count', style: TextStyle(color: Colors.orange)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBranchSettingsDialog() {
    final pinController = TextEditingController();
    bool pinVerified = false;
    String pinError = '';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (!pinVerified) {
            // PIN Entry Screen
            return AlertDialog(
              backgroundColor: const Color(0xFF2a2a2a),
              title: Row(
                children: [
                  const Icon(Icons.lock, color: Colors.orange, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Branch Settings (Safe)',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter PIN to edit Branch (Safe) values',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    style: const TextStyle(color: Colors.white, fontSize: 18, letterSpacing: 8),
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      hintText: '• • • •',
                      hintStyle: TextStyle(color: Colors.grey[600], letterSpacing: 8),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.grey[700]!),
                      ),
                      focusedBorder: const OutlineInputBorder(
                        borderSide: BorderSide(color: Colors.orange),
                      ),
                      errorText: pinError.isNotEmpty ? pinError : null,
                    ),
                    onSubmitted: (value) async {
                      final isValid = await BranchSettingsService.verifyPin(value);
                      if (isValid) {
                        setDialogState(() {
                          pinVerified = true;
                          pinError = '';
                        });
                      } else {
                        setDialogState(() {
                          pinError = 'Incorrect PIN';
                          pinController.clear();
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                TextButton(
                  onPressed: () async {
                    final isValid = await BranchSettingsService.verifyPin(pinController.text);
                    if (isValid) {
                      setDialogState(() {
                        pinVerified = true;
                        pinError = '';
                      });
                    } else {
                      setDialogState(() {
                        pinError = 'Incorrect PIN';
                        pinController.clear();
                      });
                    }
                  },
                  child: const Text('Verify', style: TextStyle(color: Colors.orange)),
                ),
              ],
            );
          }
          
          // Branch Settings Editor
          return FutureBuilder<BranchSettings>(
            future: BranchSettingsService.getSettings(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const AlertDialog(
                  backgroundColor: Color(0xFF2a2a2a),
                  content: Center(child: CircularProgressIndicator()),
                );
              }
              
              final settings = snapshot.data!;
              final usdControllers = List.generate(6, (i) => TextEditingController(
                text: settings.usdQty[i] != 0 ? settings.usdQty[i].toString() : '',
              ));
              final lbpControllers = List.generate(6, (i) => TextEditingController(
                text: settings.lbpQty[i] != 0 ? settings.lbpQty[i].toString() : '',
              ));
              
              final usdUnits = [100, 50, 20, 10, 5, 1];
              final lbpUnits = [100000, 50000, 20000, 10000, 5000, 1000];
              
              int calcUsdTotal() {
                int total = 0;
                for (int i = 0; i < 6; i++) {
                  total += (int.tryParse(usdControllers[i].text) ?? 0) * usdUnits[i];
                }
                return total;
              }
              
              int calcLbpTotal() {
                int total = 0;
                for (int i = 0; i < 6; i++) {
                  total += (int.tryParse(lbpControllers[i].text) ?? 0) * lbpUnits[i];
                }
                return total;
              }
              
              return StatefulBuilder(
                builder: (context, setInnerState) {
                  return AlertDialog(
                    backgroundColor: const Color(0xFF2a2a2a),
                    title: Row(
                      children: [
                        const Icon(Icons.account_balance, color: Colors.orange, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'Branch (Safe) Cash',
                          style: TextStyle(color: Colors.white, fontSize: 16),
                        ),
                        const Spacer(),
                        const Icon(Icons.lock_open, color: Colors.green, size: 16),
                      ],
                    ),
                    content: SizedBox(
                      width: 450,
                      child: SingleChildScrollView(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // USD Section
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'USD (Safe)',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...List.generate(6, (i) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 40,
                                            child: Text(
                                              '\$${usdUnits[i]}',
                                              style: const TextStyle(color: Colors.green, fontSize: 11),
                                            ),
                                          ),
                                          Expanded(
                                            child: SizedBox(
                                              height: 28,
                                              child: TextField(
                                                controller: usdControllers[i],
                                                keyboardType: TextInputType.number,
                                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                                textAlign: TextAlign.center,
                                                decoration: InputDecoration(
                                                  isDense: true,
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                                  enabledBorder: OutlineInputBorder(
                                                    borderSide: BorderSide(color: Colors.grey[700]!),
                                                  ),
                                                  focusedBorder: const OutlineInputBorder(
                                                    borderSide: BorderSide(color: Colors.green),
                                                  ),
                                                ),
                                                onChanged: (_) => setInnerState(() {}),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                                    const Divider(color: Colors.grey, height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Total:', style: TextStyle(color: Colors.white, fontSize: 12)),
                                        Text(
                                          '\$${_numberFormat.format(calcUsdTotal())}',
                                          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // LBP Section
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'LBP (Safe)',
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    ...List.generate(6, (i) => Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 2),
                                      child: Row(
                                        children: [
                                          SizedBox(
                                            width: 50,
                                            child: Text(
                                              '${_numberFormat.format(lbpUnits[i])}',
                                              style: const TextStyle(color: Colors.blue, fontSize: 10),
                                            ),
                                          ),
                                          Expanded(
                                            child: SizedBox(
                                              height: 28,
                                              child: TextField(
                                                controller: lbpControllers[i],
                                                keyboardType: TextInputType.number,
                                                style: const TextStyle(color: Colors.white, fontSize: 12),
                                                textAlign: TextAlign.center,
                                                decoration: InputDecoration(
                                                  isDense: true,
                                                  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                                  enabledBorder: OutlineInputBorder(
                                                    borderSide: BorderSide(color: Colors.grey[700]!),
                                                  ),
                                                  focusedBorder: const OutlineInputBorder(
                                                    borderSide: BorderSide(color: Colors.blue),
                                                  ),
                                                ),
                                                onChanged: (_) => setInnerState(() {}),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )),
                                    const Divider(color: Colors.grey, height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Total:', style: TextStyle(color: Colors.white, fontSize: 12)),
                                        Text(
                                          '${_numberFormat.format(calcLbpTotal())}',
                                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                      ),
                      TextButton(
                        onPressed: () async {
                          final newUsd = List.generate(6, (i) => int.tryParse(usdControllers[i].text) ?? 0);
                          final newLbp = List.generate(6, (i) => int.tryParse(lbpControllers[i].text) ?? 0);
                          
                          await BranchSettingsService.saveSettings(BranchSettings(
                            usdQty: newUsd,
                            lbpQty: newLbp,
                            pin: settings.pin,
                          ));
                          
                          Navigator.pop(context);
                          
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Branch (Safe) values saved!'),
                              backgroundColor: Colors.green,
                              duration: Duration(milliseconds: 800),
                            ),
                          );
                        },
                        child: const Text('Save', style: TextStyle(color: Colors.green)),
                      ),
                    ],
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _showCashCountDialog() async {
    // Ensure lists are initialized (safety for hot reload)
    if (_usdQty.isEmpty) _usdQty = <int>[0, 0, 0, 0, 0, 0];
    if (_lbpQty.isEmpty) _lbpQty = <int>[0, 0, 0, 0, 0, 0];
    
    // Load branch settings
    final branchSettings = await BranchSettingsService.getSettings();
    
    // User name controller (load from prefs)
    final prefs = await SharedPreferences.getInstance();
    final savedUserName = prefs.getString('cash_count_user_name') ?? '';
    final userNameController = TextEditingController(text: savedUserName);
    
    // USD denominations
    final usdUnits = [100.0, 50.0, 20.0, 10.0, 5.0, 1.0];
    final usdControllers = List.generate(6, (i) => TextEditingController(
      text: _usdQty[i] != 0 ? _usdQty[i].toString() : '',
    ));
    final usdFocusNodes = List.generate(6, (_) => FocusNode());
    final usdTajController = TextEditingController(text: _tajUsd != 0 ? _currencyFormat.format(_tajUsd) : '');
    final usdTajFocusNode = FocusNode();
    
    // LBP denominations (no 500, 250)
    final lbpUnits = [100000, 50000, 20000, 10000, 5000, 1000];
    final lbpControllers = List.generate(6, (i) => TextEditingController(
      text: _lbpQty[i] != 0 ? _lbpQty[i].toString() : '',
    ));
    final lbpFocusNodes = List.generate(6, (_) => FocusNode());
    final lbpTajController = TextEditingController(text: _tajLbp != 0 ? _numberFormat.format(_tajLbp) : '');
    final lbpTajFocusNode = FocusNode();
    
    double usdTotal = 0;
    int lbpTotal = 0;
    String usdTest = '';
    String lbpTest = '';
    bool hasInitialized = false;
    
    // Function to store values when dialog closes
    void storeValues() {
      for (int i = 0; i < 6; i++) {
        _usdQty[i] = int.tryParse(usdControllers[i].text) ?? 0;
        _lbpQty[i] = int.tryParse(lbpControllers[i].text) ?? 0;
      }
    }
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          void calculate() {
            // Store values when calculating
            storeValues();
            
            // Calculate USD total (user drawer only)
            usdTotal = 0;
            for (int i = 0; i < usdUnits.length; i++) {
              final qty = int.tryParse(usdControllers[i].text) ?? 0;
              usdTotal += usdUnits[i] * qty;
            }
            
            // Calculate LBP total (user drawer only)
            lbpTotal = 0;
            for (int i = 0; i < lbpUnits.length; i++) {
              final qty = int.tryParse(lbpControllers[i].text) ?? 0;
              lbpTotal += lbpUnits[i] * qty;
            }
            
            // USD Test
            final usdTaj = double.tryParse(usdTajController.text.replaceAll(',', ''));
            if (usdTaj != null) {
              final diff = usdTotal - usdTaj;
              if (diff.abs() < 0.01) {
                usdTest = 'OK ✓';
              } else if (diff < 0) {
                usdTest = '${_currencyFormat.format(diff)}\$';
              } else {
                usdTest = '+${_currencyFormat.format(diff)}\$';
              }
            } else {
              usdTest = '';
            }
            
            // LBP Test
            final lbpTaj = int.tryParse(lbpTajController.text.replaceAll(',', ''));
            if (lbpTaj != null) {
              final diff = lbpTotal - lbpTaj;
              if (diff == 0) {
                lbpTest = 'OK ✓';
              } else if (diff < 0) {
                lbpTest = '${_numberFormat.format(diff)} LBP';
              } else {
                lbpTest = '+${_numberFormat.format(diff)} LBP';
              }
            } else {
              lbpTest = '';
            }
            
            setDialogState(() {});
          }
          
          Widget buildUsdRow(int index) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 50,
                    child: Text(
                      '\$${usdUnits[index].toInt()}',
                      style: const TextStyle(color: Colors.green, fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 28,
                      child: FocusTraversalOrder(
                        order: NumericFocusOrder(index.toDouble()),
                        child: TextField(
                          controller: usdControllers[index],
                          focusNode: usdFocusNodes[index],
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.green),
                            ),
                          ),
                          onChanged: (_) => calculate(),
                          onSubmitted: (_) {
                            // Tab to next USD field, or to USD TAJ
                            if (index < 5) {
                              usdFocusNodes[index + 1].requestFocus();
                            } else {
                              usdTajFocusNode.requestFocus();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 60,
                    child: Text(
                      '\$${_currencyFormat.format(usdUnits[index] * (int.tryParse(usdControllers[index].text) ?? 0))}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }
          
          Widget buildLbpRow(int index) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 55,
                    child: Text(
                      '${_numberFormat.format(lbpUnits[index])}',
                      style: const TextStyle(color: Colors.blue, fontSize: 11),
                    ),
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 28,
                      child: FocusTraversalOrder(
                        order: NumericFocusOrder(index.toDouble()),
                        child: TextField(
                          controller: lbpControllers[index],
                          focusNode: lbpFocusNodes[index],
                          keyboardType: TextInputType.number,
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.grey[700]!),
                            ),
                            focusedBorder: const OutlineInputBorder(
                              borderSide: BorderSide(color: Colors.blue),
                            ),
                          ),
                          onChanged: (_) => calculate(),
                          onSubmitted: (_) {
                            // Tab to next LBP field, or to LBP TAJ
                            if (index < 5) {
                              lbpFocusNodes[index + 1].requestFocus();
                            } else {
                              lbpTajFocusNode.requestFocus();
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 70,
                    child: Text(
                      '${_numberFormat.format(lbpUnits[index] * (int.tryParse(lbpControllers[index].text) ?? 0))}',
                      style: TextStyle(color: Colors.grey[400], fontSize: 11),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            );
          }
          
          // Calculate initial values on first build only
          if (!hasInitialized) {
            hasInitialized = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              calculate();
            });
          }
          
          return AlertDialog(
            backgroundColor: const Color(0xFF2a2a2a),
            title: Row(
              children: [
                const Icon(Icons.calculate, color: Colors.orange, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Cash Count',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const Spacer(),
                // Branch totals indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Branch: \$${_numberFormat.format(branchSettings.usdTotal)} | ${_numberFormat.format(branchSettings.lbpTotal)} LBP',
                    style: const TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // User name input
                    Row(
                      children: [
                        const Icon(Icons.person, color: Colors.orange, size: 18),
                        const SizedBox(width: 8),
                        const Text('Your Name:', style: TextStyle(color: Colors.white, fontSize: 13)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 32,
                            child: TextField(
                              controller: userNameController,
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              textCapitalization: TextCapitalization.characters,
                              decoration: InputDecoration(
                                hintText: 'e.g., SAVIO',
                                hintStyle: TextStyle(color: Colors.grey[600], fontSize: 12),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.grey[700]!),
                                ),
                                focusedBorder: const OutlineInputBorder(
                                  borderSide: BorderSide(color: Colors.orange),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: Colors.grey, height: 1),
                    const SizedBox(height: 12),
                    // Cash count sections
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // USD Section - Tab order 1
                        Expanded(
                          child: FocusTraversalGroup(
                            policy: OrderedTraversalPolicy(),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.green.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'USD (Your Drawer)',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ...List.generate(6, buildUsdRow),
                                const Divider(color: Colors.grey, height: 16),
                                // USD Total section
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Total:', style: TextStyle(color: Colors.white, fontSize: 12)),
                                    Text(
                                      '\$${_currencyFormat.format(usdTotal)}',
                                      style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Text('TAJ:', style: TextStyle(color: Colors.orange, fontSize: 12)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SizedBox(
                                        height: 28,
                                        child: FocusTraversalOrder(
                                          order: const NumericFocusOrder(10),
                                          child: TextField(
                                            controller: usdTajController,
                                            focusNode: usdTajFocusNode,
                                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                            style: const TextStyle(color: Colors.white, fontSize: 12),
                                            decoration: InputDecoration(
                                              isDense: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                              prefixText: '\$ ',
                                              prefixStyle: const TextStyle(color: Colors.orange, fontSize: 12),
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(color: Colors.grey[700]!),
                                              ),
                                              focusedBorder: const OutlineInputBorder(
                                                borderSide: BorderSide(color: Colors.orange),
                                              ),
                                            ),
                                            onChanged: (_) => calculate(),
                                            onSubmitted: (_) {
                                              // After USD TAJ, go to first LBP field
                                              lbpFocusNodes[0].requestFocus();
                                            },
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Test:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    Text(
                                      usdTest.isEmpty ? '-' : usdTest,
                                      style: TextStyle(
                                        color: usdTest == 'OK ✓' ? Colors.green : (usdTest.startsWith('-') ? Colors.red : Colors.orange),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // LBP Section - Tab order 2
                        Expanded(
                          child: FocusTraversalGroup(
                            policy: OrderedTraversalPolicy(),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue.withOpacity(0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'LBP (Your Drawer)',
                                    style: TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  ...List.generate(6, buildLbpRow),
                                  const Divider(color: Colors.grey, height: 16),
                                  // LBP Total section
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text('Total:', style: TextStyle(color: Colors.white, fontSize: 12)),
                                      Text(
                                        '${_numberFormat.format(lbpTotal)}',
                                      style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Text('TAJ:', style: TextStyle(color: Colors.orange, fontSize: 12)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: SizedBox(
                                        height: 28,
                                        child: FocusTraversalOrder(
                                          order: const NumericFocusOrder(10),
                                          child: TextField(
                                            controller: lbpTajController,
                                            focusNode: lbpTajFocusNode,
                                            keyboardType: TextInputType.number,
                                            style: const TextStyle(color: Colors.white, fontSize: 12),
                                            decoration: InputDecoration(
                                              isDense: true,
                                              contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                              enabledBorder: OutlineInputBorder(
                                                borderSide: BorderSide(color: Colors.grey[700]!),
                                              ),
                                              focusedBorder: const OutlineInputBorder(
                                                borderSide: BorderSide(color: Colors.orange),
                                              ),
                                            ),
                                            onChanged: (_) => calculate(),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('Test:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                                    Text(
                                      lbpTest.isEmpty ? '-' : lbpTest,
                                      style: TextStyle(
                                        color: lbpTest == 'OK ✓' ? Colors.green : (lbpTest.startsWith('-') ? Colors.red : Colors.orange),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  storeValues();
                  Navigator.pop(context);
                },
                child: const Text('Close', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () async {
                  storeValues();
                  
                  // Save user name for next time
                  final userName = userNameController.text.trim().toUpperCase();
                  if (userName.isNotEmpty) {
                    await prefs.setString('cash_count_user_name', userName);
                  }
                  
                  // Save cash count to history
                  final now = DateTime.now();
                  final timestamp = '${now.day}/${now.month}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
                  final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
                  
                  final tajUsd = double.tryParse(usdTajController.text.replaceAll(',', '')) ?? 0;
                  final tajLbp = int.tryParse(lbpTajController.text.replaceAll(',', '')) ?? 0;
                  
                  final cashCount = CashCount(
                    timestamp: timestamp,
                    date: dateStr,
                    userName: userName,
                    branchUsdQty: List.from(branchSettings.usdQty),
                    branchLbpQty: List.from(branchSettings.lbpQty),
                    usdQty: List.from(_usdQty),
                    lbpQty: List.from(_lbpQty),
                    usdTotal: usdTotal,
                    lbpTotal: lbpTotal,
                    tajUsd: tajUsd,
                    tajLbp: tajLbp,
                    usdTest: usdTest,
                    lbpTest: lbpTest,
                  );
                  
                  await CashCountService.saveCashCount(cashCount);
                  
                  // Clear stored values after save
                  setState(() {
                    _usdQty = <int>[0, 0, 0, 0, 0, 0];
                    _lbpQty = <int>[0, 0, 0, 0, 0, 0];
                    _tajUsd = 0;
                    _tajLbp = 0;
                  });
                  
                  Navigator.pop(context);
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Cash count saved for ${userName.isNotEmpty ? userName : "user"}!'),
                      backgroundColor: Colors.green,
                      duration: const Duration(milliseconds: 800),
                    ),
                  );
                },
                child: const Text('Save', style: TextStyle(color: Colors.green)),
              ),
              TextButton(
                onPressed: () {
                  storeValues();
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const CashCountHistoryScreen()),
                  );
                },
                child: const Text('History', style: TextStyle(color: Colors.blue)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final modeColor = _getModeColor(_selectedMode);
    
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Column(
              children: [
              // Compact Header
              Row(
                children: [
                  Text(
                    'Cash Calculator',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Help button for shortcuts
                  GestureDetector(
                    onTap: () => _showShortcutsHelp(),
                    child: Icon(
                      Icons.help_outline,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Menu button
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.menu,
                      size: 18,
                      color: Colors.grey[600],
                    ),
                    color: const Color(0xFF2a2a2a),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onSelected: (value) async {
                      switch (value) {
                        case 'transactions':
                          await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                          );
                          _loadPendingCount();
                          break;
                        case 'taj':
                          _showDrawerBalanceDialog();
                          break;
                        case 'cashcount':
                          _showCashCountDialog();
                          break;
                        case 'history':
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const CashCountHistoryScreen()),
                          );
                          break;
                        case 'change':
                          _showChangeCalculatorDialog();
                          break;
                        case 'wincalc':
                          Process.run('calc.exe', []);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'transactions',
                        height: 36,
                        child: Row(
                          children: [
                            Icon(Icons.receipt_long, size: 16, color: Colors.orange),
                            const SizedBox(width: 8),
                            const Text('Transactions', style: TextStyle(color: Colors.white, fontSize: 13)),
                            const SizedBox(width: 8),
                            Text('F1', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'taj',
                        height: 36,
                        child: Row(
                          children: [
                            Icon(Icons.account_balance_wallet, size: 16, color: Colors.orange),
                            const SizedBox(width: 8),
                            const Text('TAJ Balance', style: TextStyle(color: Colors.white, fontSize: 13)),
                            const SizedBox(width: 8),
                            Text('F2', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'cashcount',
                        height: 36,
                        child: Row(
                          children: [
                            Icon(Icons.calculate, size: 16, color: Colors.orange),
                            const SizedBox(width: 8),
                            const Text('Cash Count', style: TextStyle(color: Colors.white, fontSize: 13)),
                            const SizedBox(width: 8),
                            Text('F3', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'history',
                        height: 36,
                        child: Row(
                          children: [
                            Icon(Icons.history, size: 16, color: Colors.blue),
                            const SizedBox(width: 8),
                            const Text('Cash History', style: TextStyle(color: Colors.white, fontSize: 13)),
                            const SizedBox(width: 8),
                            Text('F4', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'change',
                        height: 36,
                        child: Row(
                          children: [
                            Icon(Icons.currency_exchange, size: 16, color: Colors.green),
                            const SizedBox(width: 8),
                            const Text('Exchange', style: TextStyle(color: Colors.white, fontSize: 13)),
                            const SizedBox(width: 8),
                            Text('F5', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'wincalc',
                        height: 36,
                        child: Row(
                          children: [
                            Icon(Icons.calculate_outlined, size: 16, color: Colors.purple),
                            const SizedBox(width: 8),
                            const Text('Win Calculator', style: TextStyle(color: Colors.white, fontSize: 13)),
                            const SizedBox(width: 8),
                            Text('F6', style: TextStyle(color: Colors.grey[600], fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // History badge
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                      );
                      _loadPendingCount();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _pendingCount > 0 
                            ? Colors.orange.withOpacity(0.2)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _pendingCount > 0 ? Colors.orange.withOpacity(0.5) : Colors.transparent,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.receipt_long,
                            size: 14,
                            color: _pendingCount > 0 ? Colors.orange : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$_pendingCount',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: _pendingCount > 0 ? Colors.orange : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 10),
              
              // Vertical Mode Selection
              _buildVerticalModeButton(0, 'Get USD', '89,500', 'Customer pays LBP → USD', Colors.green),
              const SizedBox(height: 6),
              _buildVerticalModeButton(1, 'Pay LBP', '89,500', 'Customer receives LBP', Colors.orange),
              const SizedBox(height: 6),
              _buildVerticalModeButton(2, 'Charge LBP', '89,750', 'USD acc pays in LBP', Colors.blue),
              
              const SizedBox(height: 12),
              
              // Compact Input
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2a2a2a),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF3a3a3a)),
                ),
                child: Row(
                  children: [
                    Text(
                      _selectedMode == 0 ? 'LBP' : '\$',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RawKeyboardListener(
                        focusNode: FocusNode(),
                        onKey: (event) {
                          if (event is RawKeyDownEvent) {
                            if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                              _onModeChanged((_selectedMode - 1 + 3) % 3);
                            } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                              _onModeChanged((_selectedMode + 1) % 3);
                            } else if (event.logicalKey == LogicalKeyboardKey.f6) {
                              // Open Windows Calculator
                              Process.run('calc.exe', []);
                            } else if (event.logicalKey == LogicalKeyboardKey.escape) {
                              // Clear input (will be saved to history on save or when cleared)
                              _inputController.clear();
                              setState(() => _result = '');
                            } else if (event.logicalKey == LogicalKeyboardKey.keyZ &&
                                       (event.isControlPressed)) {
                              // Undo - go back in history
                              _undo();
                            } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                              // Undo with right arrow
                              _undo();
                            } else if (event.logicalKey == LogicalKeyboardKey.f1) {
                              // Open transactions
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const TransactionsScreen()),
                              ).then((_) => _loadPendingCount());
                            } else if (event.logicalKey == LogicalKeyboardKey.f2) {
                              // Open TAJ balance
                              _showDrawerBalanceDialog();
                            } else if (event.logicalKey == LogicalKeyboardKey.f3) {
                              // Open cash count
                              _showCashCountDialog();
                            } else if (event.logicalKey == LogicalKeyboardKey.f4) {
                              // Open cash count history
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const CashCountHistoryScreen()),
                              );
                            } else if (event.logicalKey == LogicalKeyboardKey.f5) {
                              // Open change calculator
                              _showChangeCalculatorDialog();
                            } else if (event.logicalKey == LogicalKeyboardKey.f8) {
                              // Open branch settings (safe cash)
                              _showBranchSettingsDialog();
                            }
                          }
                        },
                        child: TextField(
                          controller: _inputController,
                          focusNode: _inputFocusNode,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
                            _ThousandsSeparatorInputFormatter(),
                          ],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          cursorHeight: 20,
                          decoration: InputDecoration(
                            hintText: _selectedMode == 0 ? 'LBP amount' : 'USD amount',
                            hintStyle: TextStyle(color: Colors.grey[700], fontSize: 16),
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: (_) => _calculate(),
                          onSubmitted: (_) {
                            if (_result.isNotEmpty && _result != 'Invalid') {
                              _saveTransaction();
                            }
                          },
                          autofocus: true,
                        ),
                      ),
                    ),
                    if (_inputController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          // Save to undo history before clearing
                          if (_inputController.text.isNotEmpty && _result.isNotEmpty) {
                            _saveToUndoHistory(_inputController.text, _result, _selectedMode);
                          }
                          _inputController.clear();
                          setState(() => _result = '');
                        },
                        child: Icon(Icons.close, size: 18, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 10),
              
              // Result Display - Compact
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                decoration: BoxDecoration(
                  color: _result.isNotEmpty && _result != 'Invalid'
                      ? modeColor.withOpacity(0.1)
                      : const Color(0xFF2a2a2a),
                  borderRadius: BorderRadius.circular(8),
                  border: Border(
                    left: BorderSide(
                      color: _result.isNotEmpty && _result != 'Invalid' ? modeColor : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _result.isEmpty ? '---' : _result,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: _result.isEmpty || _result == 'Invalid'
                            ? Colors.grey[700]
                            : Colors.white,
                      ),
                    ),
                    if (_result.isNotEmpty && _result != 'Invalid')
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _getShortModeLabel(_selectedMode),
                          style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                        ),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Clear and Save buttons
              Row(
                children: [
                  // Clear Button
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        _inputController.clear();
                        setState(() => _result = '');
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2a2a2a),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF3a3a3a)),
                        ),
                        child: Text(
                          'Clear',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[400],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Save Button
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _result.isNotEmpty && _result != 'Invalid' ? _saveTransaction : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _result.isNotEmpty && _result != 'Invalid'
                              ? Colors.green
                              : Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.save,
                              size: 16,
                              color: _result.isNotEmpty && _result != 'Invalid'
                                  ? Colors.white
                                  : Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Save (Enter)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _result.isNotEmpty && _result != 'Invalid'
                                    ? Colors.white
                                    : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Developer Credit
              Center(
                child: Text(
                  'developed by @savio_atik\n"everything is possible if you know how to code"',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalModeButton(int mode, String label, String rate, String desc, Color color) {
    final isSelected = _selectedMode == mode;
    return GestureDetector(
      onTap: () => _onModeChanged(mode),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : const Color(0xFF252525),
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: isSelected ? color : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : Colors.grey[400],
                    ),
                  ),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? color.withOpacity(0.3) : Colors.grey.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                rate,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : Colors.grey[500],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getModeColor(int mode) {
    switch (mode) {
      case 0: return Colors.green;
      case 1: return Colors.orange;
      case 2: return Colors.blue;
      default: return Colors.grey;
    }
  }

  String _getShortModeLabel(int mode) {
    switch (mode) {
      case 0: return 'Customer pays LBP';
      case 1: return 'Pay customer LBP';
      case 2: return 'Charge LBP (89,750)';
      default: return '';
    }
  }
}

// Custom formatter for thousands separators
class _ThousandsSeparatorInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Handle negative sign
    String prefix = '';
    String text = newValue.text;
    if (text.startsWith('-')) {
      prefix = '-';
      text = text.substring(1);
    }
    
    // Remove existing commas
    text = text.replaceAll(',', '');
    
    if (text.isEmpty) {
      return TextEditingValue(
        text: prefix,
        selection: TextSelection.collapsed(offset: prefix.length),
      );
    }
    
    // Handle decimal part
    String integerPart;
    String decimalPart = '';
    
    if (text.contains('.')) {
      final parts = text.split('.');
      integerPart = parts[0];
      decimalPart = '.${parts.length > 1 ? parts[1] : ''}';
    } else {
      integerPart = text;
    }
    
    // Remove leading zeros except for "0" or "0."
    if (integerPart.length > 1 && integerPart.startsWith('0') && !integerPart.startsWith('0.')) {
      integerPart = integerPart.replaceFirst(RegExp(r'^0+'), '');
      if (integerPart.isEmpty) integerPart = '0';
    }
    
    // Add commas to integer part
    String formatted = '';
    for (int i = 0; i < integerPart.length; i++) {
      if (i > 0 && (integerPart.length - i) % 3 == 0) {
        formatted += ',';
      }
      formatted += integerPart[i];
    }
    
    formatted = prefix + formatted + decimalPart;
    
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
