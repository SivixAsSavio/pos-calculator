import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/exchange_rates.dart';
import '../services/transaction_service.dart';
import 'transactions_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Selected mode: 0 = Pay LBP (89,500), 1 = Get USD (89,500), 2 = Charge LBP (89,750)
  int _selectedMode = 0;
  
  final _inputController = TextEditingController();
  String _result = '';
  int _pendingCount = 0;
  
  final _numberFormat = NumberFormat('#,###');
  final _currencyFormat = NumberFormat('#,##0.00');

  @override
  void initState() {
    super.initState();
    _loadPendingCount();
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
    super.dispose();
  }

  void _calculate() {
    final input = _inputController.text.replaceAll(',', '');
    if (input.isEmpty) {
      setState(() => _result = '');
      return;
    }
    
    switch (_selectedMode) {
      case 0: // Pay LBP -> USD to LBP (89,500)
        final usd = double.tryParse(input);
        if (usd == null) {
          setState(() => _result = 'Invalid');
          return;
        }
        final lbp = ExchangeRates.usdToLbpSellUsd(usd);
        setState(() => _result = 'LBP ${_numberFormat.format(lbp)}');
        break;
      case 1: // Get USD <- LBP to USD (89,500)
        final lbp = int.tryParse(input);
        if (lbp == null) {
          setState(() => _result = 'Invalid');
          return;
        }
        final usd = ExchangeRates.lbpToUsdBuyUsd(lbp);
        setState(() => _result = 'USD ${_currencyFormat.format(usd)}');
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
        usd = double.parse(input);
        lbp = ExchangeRates.usdToLbpSellUsd(usd);
        type = TransactionType.sellUsd;
        break;
      case 1:
        lbp = int.parse(input);
        usd = ExchangeRates.lbpToUsdBuyUsd(lbp);
        type = TransactionType.buyUsd;
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
    
    // Clear input after saving
    _inputController.clear();
    setState(() => _result = '');
    
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
  }

  @override
  Widget build(BuildContext context) {
    final modeColor = _getModeColor(_selectedMode);
    
    return Scaffold(
      backgroundColor: const Color(0xFF1a1a1a),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            children: [
              // Compact Header
              Row(
                children: [
                  Text(
                    'POS',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[400],
                    ),
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
              _buildVerticalModeButton(0, 'Pay LBP', '89,500', 'Customer receives LBP', Colors.orange),
              const SizedBox(height: 6),
              _buildVerticalModeButton(1, 'Get USD', '89,500', 'Customer pays LBP → USD', Colors.green),
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
                      _selectedMode == 1 ? 'LBP' : '\$',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                        ],
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: _selectedMode == 1 ? 'LBP amount' : 'USD amount',
                          hintStyle: TextStyle(color: Colors.grey[700], fontSize: 18),
                          border: InputBorder.none,
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
                    if (_inputController.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
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
              
              const Spacer(),
              
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
      case 0: return Colors.orange;
      case 1: return Colors.green;
      case 2: return Colors.blue;
      default: return Colors.grey;
    }
  }

  String _getModeLabel(int mode) {
    switch (mode) {
      case 0: return 'Customer receives LBP (Rate: 89,500)';
      case 1: return 'Customer pays LBP → Gets USD (Rate: 89,500)';
      case 2: return 'Customer pays LBP for USD account (Rate: 89,750)';
      default: return '';
    }
  }

  String _getShortModeLabel(int mode) {
    switch (mode) {
      case 0: return 'Pay customer LBP';
      case 1: return 'Customer pays LBP';
      case 2: return 'Charge LBP (89,750)';
      default: return '';
    }
  }
}
