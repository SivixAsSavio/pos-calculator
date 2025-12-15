import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A single branch cash transaction record
class BranchTransaction {
  final String id;
  final String userId;
  final String userName;
  final DateTime date;
  final double openingUsd;
  final double openingLbp;
  final double closingUsd;
  final double closingLbp;
  final double sentToHoUsd;
  final double sentToHoLbp;
  final String? notes;
  final DateTime createdAt;

  BranchTransaction({
    required this.id,
    required this.userId,
    required this.userName,
    required this.date,
    required this.openingUsd,
    required this.openingLbp,
    required this.closingUsd,
    required this.closingLbp,
    this.sentToHoUsd = 0,
    this.sentToHoLbp = 0,
    this.notes,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Net change in USD
  double get netChangeUsd => closingUsd - openingUsd - sentToHoUsd;
  
  /// Net change in LBP
  double get netChangeLbp => closingLbp - openingLbp - sentToHoLbp;

  /// Remaining after sending to H.O.
  double get remainingUsd => closingUsd - sentToHoUsd;
  double get remainingLbp => closingLbp - sentToHoLbp;

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userName': userName,
    'date': date.toIso8601String(),
    'openingUsd': openingUsd,
    'openingLbp': openingLbp,
    'closingUsd': closingUsd,
    'closingLbp': closingLbp,
    'sentToHoUsd': sentToHoUsd,
    'sentToHoLbp': sentToHoLbp,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
  };

  factory BranchTransaction.fromJson(Map<String, dynamic> json) => BranchTransaction(
    id: json['id'],
    userId: json['userId'],
    userName: json['userName'],
    date: DateTime.parse(json['date']),
    openingUsd: (json['openingUsd'] as num).toDouble(),
    openingLbp: (json['openingLbp'] as num).toDouble(),
    closingUsd: (json['closingUsd'] as num).toDouble(),
    closingLbp: (json['closingLbp'] as num).toDouble(),
    sentToHoUsd: (json['sentToHoUsd'] as num?)?.toDouble() ?? 0,
    sentToHoLbp: (json['sentToHoLbp'] as num?)?.toDouble() ?? 0,
    notes: json['notes'],
    createdAt: json['createdAt'] != null 
        ? DateTime.parse(json['createdAt']) 
        : null,
  );

  BranchTransaction copyWith({
    String? id,
    String? userId,
    String? userName,
    DateTime? date,
    double? openingUsd,
    double? openingLbp,
    double? closingUsd,
    double? closingLbp,
    double? sentToHoUsd,
    double? sentToHoLbp,
    String? notes,
  }) {
    return BranchTransaction(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      date: date ?? this.date,
      openingUsd: openingUsd ?? this.openingUsd,
      openingLbp: openingLbp ?? this.openingLbp,
      closingUsd: closingUsd ?? this.closingUsd,
      closingLbp: closingLbp ?? this.closingLbp,
      sentToHoUsd: sentToHoUsd ?? this.sentToHoUsd,
      sentToHoLbp: sentToHoLbp ?? this.sentToHoLbp,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }
}

/// Current branch cash state
class BranchCashState {
  final double currentUsd;
  final double currentLbp;
  final DateTime lastUpdated;
  final String? lastUpdatedBy;
  final String? lastUpdatedByName;

  BranchCashState({
    this.currentUsd = 0,
    this.currentLbp = 0,
    DateTime? lastUpdated,
    this.lastUpdatedBy,
    this.lastUpdatedByName,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'currentUsd': currentUsd,
    'currentLbp': currentLbp,
    'lastUpdated': lastUpdated.toIso8601String(),
    'lastUpdatedBy': lastUpdatedBy,
    'lastUpdatedByName': lastUpdatedByName,
  };

  factory BranchCashState.fromJson(Map<String, dynamic> json) => BranchCashState(
    currentUsd: (json['currentUsd'] as num?)?.toDouble() ?? 0,
    currentLbp: (json['currentLbp'] as num?)?.toDouble() ?? 0,
    lastUpdated: json['lastUpdated'] != null 
        ? DateTime.parse(json['lastUpdated']) 
        : null,
    lastUpdatedBy: json['lastUpdatedBy'],
    lastUpdatedByName: json['lastUpdatedByName'],
  );

  BranchCashState copyWith({
    double? currentUsd,
    double? currentLbp,
    DateTime? lastUpdated,
    String? lastUpdatedBy,
    String? lastUpdatedByName,
  }) {
    return BranchCashState(
      currentUsd: currentUsd ?? this.currentUsd,
      currentLbp: currentLbp ?? this.currentLbp,
      lastUpdated: lastUpdated ?? DateTime.now(),
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
      lastUpdatedByName: lastUpdatedByName ?? this.lastUpdatedByName,
    );
  }
}

/// Service for managing branch (safe) cash with history
class BranchCashService extends ChangeNotifier {
  static const String _stateKey = 'branch_cash_state';
  static const String _historyKey = 'branch_cash_history';
  
  BranchCashState _state = BranchCashState();
  List<BranchTransaction> _history = [];
  SharedPreferences? _prefs;

  BranchCashState get state => _state;
  List<BranchTransaction> get history => List.unmodifiable(_history);
  
  double get currentUsd => _state.currentUsd;
  double get currentLbp => _state.currentLbp;

  /// Initialize the service
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    await _loadState();
    await _loadHistory();
  }

  /// Load current state
  Future<void> _loadState() async {
    final data = _prefs?.getString(_stateKey);
    if (data != null) {
      _state = BranchCashState.fromJson(jsonDecode(data));
    }
  }

  /// Save current state
  Future<void> _saveState() async {
    await _prefs?.setString(_stateKey, jsonEncode(_state.toJson()));
    notifyListeners();
  }

  /// Load transaction history
  Future<void> _loadHistory() async {
    final data = _prefs?.getString(_historyKey);
    if (data != null) {
      final List<dynamic> jsonList = jsonDecode(data);
      _history = jsonList.map((j) => BranchTransaction.fromJson(j)).toList();
      // Sort by date descending (newest first)
      _history.sort((a, b) => b.date.compareTo(a.date));
    }
  }

  /// Save history
  Future<void> _saveHistory() async {
    final data = jsonEncode(_history.map((t) => t.toJson()).toList());
    await _prefs?.setString(_historyKey, data);
    notifyListeners();
  }

  /// Get opening balance for today (yesterday's remaining or current state)
  Map<String, double> getOpeningBalance() {
    // Find yesterday's closing transaction
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    final yesterdayTx = _history.where((tx) {
      final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
      final yesterdayDate = DateTime(yesterday.year, yesterday.month, yesterday.day);
      return txDate == yesterdayDate;
    }).toList();

    if (yesterdayTx.isNotEmpty) {
      // Use yesterday's remaining (after H.O. send)
      final lastTx = yesterdayTx.first;
      return {
        'usd': lastTx.remainingUsd,
        'lbp': lastTx.remainingLbp,
      };
    }

    // Otherwise use current state
    return {
      'usd': _state.currentUsd,
      'lbp': _state.currentLbp,
    };
  }

  /// Update branch cash (end of day close)
  Future<void> updateBranchCash({
    required String userId,
    required String userName,
    required double closingUsd,
    required double closingLbp,
    double sentToHoUsd = 0,
    double sentToHoLbp = 0,
    String? notes,
  }) async {
    final opening = getOpeningBalance();
    
    // Create transaction record
    final transaction = BranchTransaction(
      id: 'tx_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      userName: userName,
      date: DateTime.now(),
      openingUsd: opening['usd']!,
      openingLbp: opening['lbp']!,
      closingUsd: closingUsd,
      closingLbp: closingLbp,
      sentToHoUsd: sentToHoUsd,
      sentToHoLbp: sentToHoLbp,
      notes: notes,
    );

    _history.insert(0, transaction);
    
    // Update current state (remaining after H.O.)
    _state = _state.copyWith(
      currentUsd: transaction.remainingUsd,
      currentLbp: transaction.remainingLbp,
      lastUpdatedBy: userId,
      lastUpdatedByName: userName,
    );

    await _saveState();
    await _saveHistory();
  }

  /// Set initial branch cash (for first setup or correction)
  Future<void> setInitialCash({
    required double usd,
    required double lbp,
    required String userId,
    required String userName,
  }) async {
    _state = _state.copyWith(
      currentUsd: usd,
      currentLbp: lbp,
      lastUpdatedBy: userId,
      lastUpdatedByName: userName,
    );
    await _saveState();
  }

  /// Get history for a specific user
  List<BranchTransaction> getHistoryByUser(String userId) {
    return _history.where((tx) => tx.userId == userId).toList();
  }

  /// Get history for a date range
  List<BranchTransaction> getHistoryByDateRange(DateTime start, DateTime end) {
    return _history.where((tx) {
      return tx.date.isAfter(start.subtract(const Duration(days: 1))) &&
             tx.date.isBefore(end.add(const Duration(days: 1)));
    }).toList();
  }

  /// Get today's transaction if exists
  BranchTransaction? getTodayTransaction() {
    final today = DateTime.now();
    try {
      return _history.firstWhere((tx) {
        final txDate = DateTime(tx.date.year, tx.date.month, tx.date.day);
        final todayDate = DateTime(today.year, today.month, today.day);
        return txDate == todayDate;
      });
    } catch (e) {
      return null;
    }
  }

  /// Export for sync
  Map<String, dynamic> exportData() {
    return {
      'state': _state.toJson(),
      'history': _history.map((tx) => tx.toJson()).toList(),
    };
  }

  /// Import from sync
  Future<void> importData(Map<String, dynamic> data) async {
    // Merge state - newer wins
    if (data['state'] != null) {
      final importedState = BranchCashState.fromJson(data['state']);
      if (importedState.lastUpdated.isAfter(_state.lastUpdated)) {
        _state = importedState;
      }
    }

    // Merge history
    if (data['history'] != null) {
      final List<dynamic> historyJson = data['history'];
      final importedHistory = historyJson
          .map((j) => BranchTransaction.fromJson(j))
          .toList();

      for (final imported in importedHistory) {
        final existingIndex = _history.indexWhere((tx) => tx.id == imported.id);
        if (existingIndex == -1) {
          _history.add(imported);
        }
        // Don't update existing transactions (they're immutable records)
      }

      _history.sort((a, b) => b.date.compareTo(a.date));
    }

    await _saveState();
    await _saveHistory();
  }

  /// Get statistics for reporting
  Map<String, dynamic> getStatistics({DateTime? startDate, DateTime? endDate}) {
    var transactions = _history;
    
    if (startDate != null && endDate != null) {
      transactions = getHistoryByDateRange(startDate, endDate);
    }

    double totalSentUsd = 0;
    double totalSentLbp = 0;
    
    for (final tx in transactions) {
      totalSentUsd += tx.sentToHoUsd;
      totalSentLbp += tx.sentToHoLbp;
    }

    return {
      'transactionCount': transactions.length,
      'totalSentToHoUsd': totalSentUsd,
      'totalSentToHoLbp': totalSentLbp,
      'currentBalanceUsd': _state.currentUsd,
      'currentBalanceLbp': _state.currentLbp,
    };
  }
}
