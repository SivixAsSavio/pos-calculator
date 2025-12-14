import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../services/cash_count_service.dart';

class CashCountHistoryScreen extends StatefulWidget {
  const CashCountHistoryScreen({super.key});

  @override
  State<CashCountHistoryScreen> createState() => _CashCountHistoryScreenState();
}

class _CashCountHistoryScreenState extends State<CashCountHistoryScreen> {
  List<CashCount> _counts = [];
  Set<DateTime> _datesWithCounts = {};
  DateTime _selectedDate = DateTime.now();
  final _numberFormat = NumberFormat('#,###');
  final _currencyFormat = NumberFormat('#,##0.00');
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _loadDatesAndCounts();
  }

  Future<void> _loadDatesAndCounts() async {
    final dates = await CashCountService.getDatesWithCounts();
    final dateStr = _dateFormat.format(_selectedDate);
    final counts = await CashCountService.getCashCountsByDate(dateStr);
    setState(() {
      _datesWithCounts = dates;
      _counts = counts.reversed.toList(); // Most recent first
    });
  }

  Future<void> _loadCountsForDate(DateTime date) async {
    final dateStr = _dateFormat.format(date);
    final counts = await CashCountService.getCashCountsByDate(dateStr);
    setState(() {
      _selectedDate = date;
      _counts = counts.reversed.toList();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.orange,
              surface: Color(0xFF2a2a2a),
            ),
            dialogBackgroundColor: const Color(0xFF1a1a1a),
          ),
          child: child!,
        );
      },
      selectableDayPredicate: (date) {
        // Allow today + any day that has counts
        final today = DateTime.now();
        if (date.year == today.year && date.month == today.month && date.day == today.day) {
          return true;
        }
        return _datesWithCounts.any((d) => d.year == date.year && d.month == date.month && d.day == date.day);
      },
    );
    if (picked != null) {
      _loadCountsForDate(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = _selectedDate.year == DateTime.now().year &&
        _selectedDate.month == DateTime.now().month &&
        _selectedDate.day == DateTime.now().day;
    
    return RawKeyboardListener(
      focusNode: FocusNode()..requestFocus(),
      onKey: (event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
              event.logicalKey == LogicalKeyboardKey.escape) {
            Navigator.pop(context);
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1a1a1a),
        appBar: AppBar(
          backgroundColor: const Color(0xFF2a2a2a),
          title: const Text('Cash Count History', style: TextStyle(fontSize: 16)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            // Calendar button
            IconButton(
              icon: const Icon(Icons.calendar_today, color: Colors.orange),
              tooltip: 'Pick date',
              onPressed: _pickDate,
            ),
          ],
        ),
        body: Column(
          children: [
            // Date header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: const Color(0xFF2a2a2a),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Previous day button
                  IconButton(
                    icon: const Icon(Icons.chevron_left, color: Colors.grey),
                    onPressed: () {
                      final prevDay = _selectedDate.subtract(const Duration(days: 1));
                      if (_datesWithCounts.any((d) => d.year == prevDay.year && d.month == prevDay.month && d.day == prevDay.day)) {
                        _loadCountsForDate(prevDay);
                      }
                    },
                  ),
                  GestureDetector(
                    onTap: _pickDate,
                    child: Text(
                      isToday ? 'Today - ${_dateFormat.format(_selectedDate)}' : _dateFormat.format(_selectedDate),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  // Next day button
                  IconButton(
                    icon: Icon(Icons.chevron_right, color: isToday ? Colors.grey[800] : Colors.grey),
                    onPressed: isToday ? null : () {
                      final nextDay = _selectedDate.add(const Duration(days: 1));
                      final today = DateTime.now();
                      if (nextDay.year == today.year && nextDay.month == today.month && nextDay.day == today.day) {
                        _loadCountsForDate(nextDay);
                      } else if (_datesWithCounts.any((d) => d.year == nextDay.year && d.month == nextDay.month && d.day == nextDay.day)) {
                        _loadCountsForDate(nextDay);
                      }
                    },
                  ),
                ],
              ),
            ),
            // Counts list
            Expanded(
              child: _counts.isEmpty
                  ? Center(
                      child: Text(
                        isToday ? 'No cash counts saved today' : 'No cash counts for this date',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _counts.length,
                      padding: const EdgeInsets.all(12),
                      itemBuilder: (context, index) {
                        final count = _counts[index];
                        return Card(
                          color: const Color(0xFF2a2a2a),
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header with time only (date is shown in header)
                                Text(
                                  count.timestamp.contains(' ') ? count.timestamp.split(' ')[1] : count.timestamp,
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // USD and LBP side by side
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // USD Column
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('USD', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Total: \$${_currencyFormat.format(count.usdTotal)}',
                                              style: const TextStyle(color: Colors.white, fontSize: 12),
                                            ),
                                            Text(
                                              'TAJ: \$${_currencyFormat.format(count.tajUsd)}',
                                              style: TextStyle(color: Colors.grey[400], fontSize: 11),
                                            ),
                                            Text(
                                              'Test: ${count.usdTest.isEmpty ? "-" : count.usdTest}',
                                              style: TextStyle(
                                                color: count.usdTest == 'OK ✓' ? Colors.green : (count.usdTest.startsWith('-') ? Colors.red : Colors.orange),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    // LBP Column
                                    Expanded(
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text('LBP', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Total: ${_numberFormat.format(count.lbpTotal)}',
                                              style: const TextStyle(color: Colors.white, fontSize: 12),
                                            ),
                                            Text(
                                              'TAJ: ${_numberFormat.format(count.tajLbp)}',
                                              style: TextStyle(color: Colors.grey[400], fontSize: 11),
                                            ),
                                            Text(
                                              'Test: ${count.lbpTest.isEmpty ? "-" : count.lbpTest}',
                                              style: TextStyle(
                                                color: count.lbpTest == 'OK ✓' ? Colors.green : (count.lbpTest.startsWith('-') ? Colors.red : Colors.orange),
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
