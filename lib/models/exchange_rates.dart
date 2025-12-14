class ExchangeRates {
  // Rate when selling USD (paying customer LBP)
  static const double sellUsdRate = 89500;
  
  // Rate when selling LBP (customer pays LBP for USD account)
  static const double sellLbpRate = 89750;
  
  // Round LBP to nearest 1000
  static int roundLbp(double amount) {
    // Get the remainder when divided by 1000
    int remainder = (amount % 1000).round();
    int base = (amount ~/ 1000) * 1000;
    
    if (remainder >= 500) {
      return base + 1000;
    } else {
      return base;
    }
  }
  
  // Convert USD to LBP (Sell USD - pay customer LBP)
  static int usdToLbpSellUsd(double usd) {
    double lbp = usd * sellUsdRate;
    return roundLbp(lbp);
  }
  
  // Convert LBP to USD (Buy USD - customer pays LBP, gets USD)
  static double lbpToUsdBuyUsd(int lbp) {
    return lbp / sellUsdRate;
  }
  
  // Convert USD to LBP (Sell LBP - customer pays LBP for USD account)
  static int usdToLbpSellLbp(double usd) {
    double lbp = usd * sellLbpRate;
    return roundLbp(lbp);
  }
  
  // Convert LBP to USD (Buy LBP - customer account is LBP, paying in USD)
  static double lbpToUsdBuyLbp(int lbp) {
    return lbp / sellLbpRate;
  }
}

enum TransactionType {
  sellUsd,  // Pay customer LBP (1 USD = 89,500 LBP)
  buyUsd,   // Customer pays LBP to get USD (1 USD = 89,500 LBP)
  sellLbp,  // Customer pays LBP for USD account (1 USD = 89,750 LBP)
  buyLbp,   // Customer account is LBP, paying USD (1 USD = 89,750 LBP)
}

class Transaction {
  final String id;
  final DateTime timestamp;
  final TransactionType type;
  final double usdAmount;
  final int lbpAmount;
  final String? customerName;
  final String? notes;
  bool isExported;

  Transaction({
    required this.id,
    required this.timestamp,
    required this.type,
    required this.usdAmount,
    required this.lbpAmount,
    this.customerName,
    this.notes,
    this.isExported = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'type': type.index,
      'usdAmount': usdAmount,
      'lbpAmount': lbpAmount,
      'customerName': customerName,
      'notes': notes,
      'isExported': isExported,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      timestamp: DateTime.parse(json['timestamp']),
      type: TransactionType.values[json['type']],
      usdAmount: json['usdAmount'].toDouble(),
      lbpAmount: json['lbpAmount'],
      customerName: json['customerName'],
      notes: json['notes'],
      isExported: json['isExported'] ?? false,
    );
  }

  String get typeLabel {
    switch (type) {
      case TransactionType.sellUsd:
        return 'Sell USD (Pay LBP)';
      case TransactionType.buyUsd:
        return 'Buy USD (Receive LBP)';
      case TransactionType.sellLbp:
        return 'Sell LBP (Receive LBP for USD)';
      case TransactionType.buyLbp:
        return 'Buy LBP (Pay USD)';
    }
  }

  double get rate {
    switch (type) {
      case TransactionType.sellUsd:
      case TransactionType.buyUsd:
        return ExchangeRates.sellUsdRate;
      case TransactionType.sellLbp:
      case TransactionType.buyLbp:
        return ExchangeRates.sellLbpRate;
    }
  }
}
