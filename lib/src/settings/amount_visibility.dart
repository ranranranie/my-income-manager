import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AmountVisibility extends ChangeNotifier {
  static const _key = 'show_amounts';
  bool _showAmounts = true;
  bool get showAmounts => _showAmounts;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_key);
    if (value != null && value != _showAmounts) {
      _showAmounts = value;
      notifyListeners();
    }
  }

  Future<void> setShowAmounts(bool value) async {
    if (_showAmounts == value) return;
    _showAmounts = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

String displayWon(int amount, {required bool showAmounts}) {
  if (!showAmounts) return '••••••••원';
  final digits = amount.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return (amount < 0 ? '-' : '') + buffer.toString() + '원';
}
