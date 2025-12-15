import 'package:shared_preferences/shared_preferences.dart';

class BranchSettings {
  final List<int> usdQty; // [100, 50, 20, 10, 5, 1]
  final List<int> lbpQty; // [100000, 50000, 20000, 10000, 5000, 1000]
  final String pin;

  BranchSettings({
    required this.usdQty,
    required this.lbpQty,
    this.pin = '1234',
  });

  int get usdTotal {
    const multipliers = [100, 50, 20, 10, 5, 1];
    int total = 0;
    for (int i = 0; i < usdQty.length && i < multipliers.length; i++) {
      total += usdQty[i] * multipliers[i];
    }
    return total;
  }

  int get lbpTotal {
    const multipliers = [100000, 50000, 20000, 10000, 5000, 1000];
    int total = 0;
    for (int i = 0; i < lbpQty.length && i < multipliers.length; i++) {
      total += lbpQty[i] * multipliers[i];
    }
    return total;
  }

  BranchSettings copyWith({
    List<int>? usdQty,
    List<int>? lbpQty,
    String? pin,
  }) {
    return BranchSettings(
      usdQty: usdQty ?? List.from(this.usdQty),
      lbpQty: lbpQty ?? List.from(this.lbpQty),
      pin: pin ?? this.pin,
    );
  }
}

class BranchSettingsService {
  static const String _usdKey = 'branch_usd';
  static const String _lbpKey = 'branch_lbp';
  static const String _pinKey = 'branch_pin';

  static BranchSettings? _cached;

  /// Get branch settings (with caching)
  static Future<BranchSettings> getSettings() async {
    if (_cached != null) return _cached!;
    
    final prefs = await SharedPreferences.getInstance();
    
    final usdStr = prefs.getString(_usdKey);
    final lbpStr = prefs.getString(_lbpKey);
    final pin = prefs.getString(_pinKey) ?? '1234';

    List<int> usdQty = [0, 0, 0, 0, 0, 0];
    List<int> lbpQty = [0, 0, 0, 0, 0, 0];

    if (usdStr != null) {
      final parts = usdStr.split(',');
      for (int i = 0; i < parts.length && i < 6; i++) {
        usdQty[i] = int.tryParse(parts[i]) ?? 0;
      }
    }

    if (lbpStr != null) {
      final parts = lbpStr.split(',');
      for (int i = 0; i < parts.length && i < 6; i++) {
        lbpQty[i] = int.tryParse(parts[i]) ?? 0;
      }
    }

    _cached = BranchSettings(usdQty: usdQty, lbpQty: lbpQty, pin: pin);
    return _cached!;
  }

  /// Save branch settings
  static Future<void> saveSettings(BranchSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString(_usdKey, settings.usdQty.join(','));
    await prefs.setString(_lbpKey, settings.lbpQty.join(','));
    await prefs.setString(_pinKey, settings.pin);
    
    _cached = settings;
  }

  /// Verify PIN
  static Future<bool> verifyPin(String inputPin) async {
    final settings = await getSettings();
    return settings.pin == inputPin;
  }

  /// Change PIN
  static Future<void> changePin(String newPin) async {
    final settings = await getSettings();
    await saveSettings(settings.copyWith(pin: newPin));
  }

  /// Clear cache (useful for testing)
  static void clearCache() {
    _cached = null;
  }
}
