import 'package:flutter_test/flutter_test.dart';
import 'package:my_income_manager/src/settings/amount_visibility.dart';

void main() {
  group('displayWon', () {
    test('formats visible amounts with thousands separators', () {
      expect(displayWon(1234567, showAmounts: true), '1,234,567원');
      expect(displayWon(-1234567, showAmounts: true), '-1,234,567원');
      expect(displayWon(0, showAmounts: true), '0원');
    });

    test('keeps amount hidden when visibility is disabled', () {
      expect(displayWon(1234567, showAmounts: false), '••••••••원');
    });
  });
}
